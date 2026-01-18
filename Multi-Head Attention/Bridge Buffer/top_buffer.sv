// top_buffer.sv
// This code combines buffer_ctrl + buffer_wrappers
import buffer0_pkg::*;

module top_buffer #(
    parameter NUMBER_OF_BUFFER_INSTANCES = 4
) (
    input logic clk, rst_n,
    input logic in_valid_w,
    input logic in_valid_n,
    input logic acc_done_wrap, systolic_finish_wrap,

    // For West Bank
    input logic [W0_IN_WIDTH-1:0] w_bank0_din [NUMBER_OF_BUFFER_INSTANCES][TOTAL_INPUT_W_W0],
    output logic [W0_MODULE_WIDTH-1:0] w_dout [NUMBER_OF_BUFFER_INSTANCES],

    // For North Bank
    input logic [N0_IN_WIDTH-1:0] n_bank0_din [NUMBER_OF_BUFFER_INSTANCES][TOTAL_INPUT_W_N0],
    output logic [N0_MODULE_WIDTH-1:0] n_dout [NUMBER_OF_BUFFER_INSTANCES],

    // Global Controllers
    output logic internal_rst_n_ctrl,
    output logic internal_reset_acc_ctrl,
    output logic out_valid,
    output logic enable_matmul
);
    // ************************************ BUFFER CONTROLLER ************************************
    // West bank control
    logic w_bank0_ena_ctr;
    logic w_bank0_enb_ctrl;
    logic w_bank0_wea_ctrl;
    logic [ADDR_WIDTH_W0-1:0] w_bank0_addra_ctrl, w_bank0_addrb_ctrl;

    // North bank control
    logic n_bank0_ena_ctrl;
    logic n_bank0_enb_ctrl;
    logic n_bank0_wea_ctrl;
    logic [ADDR_WIDTH_N0-1:0] n_bank0_addra_ctrl, n_bank0_addrb_ctrl;

    // Slicing + global control
    logic [$clog2(W0_TOTAL_MODULES)-1:0] w_slicing_idx;
    logic [$clog2(N0_TOTAL_MODULES)-1:0] n_slicing_idx;

    logic state_now;

    buffer_ctrl #(
        .TOTAL_MODULES_N   (N0_TOTAL_MODULES),
        .TOTAL_MODULES_W   (W0_TOTAL_MODULES),
        .ADDR_WIDTH_N      (ADDR_WIDTH_N),
        .ADDR_WIDTH_W      (ADDR_WIDTH_W),

        .W_COL_X           (W0_COL_X),
        .W_ROW_X           (W0_ROW_X)
        .N_ROW_X           (N0_ROW_X),
        .N_COL_X           (N0_COL_X),
        
        .N_TOTAL_DEPTH     (N0_TOTAL_DEPTH),
        .W_TOTAL_DEPTH     (W0_TOTAL_DEPTH),
        .MAX_FLAG          (MAX_FLAG_B0),
        .COL_Y             (COL_SIZE_MAT_C_B0),
        .INNER_DIMENSION   (INNER_DIMENSION)
    ) buffer_controller (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .in_valid_w             (in_valid_w),
        .in_valid_n             (in_valid_n),
        .acc_done_wrap          (acc_done_wrap),
        .systolic_finish_wrap   (systolic_finish_wrap),

        // -------- West Interface --------
        .w_bank0_ena_ctrl       (w_bank0_ena_ctrl),
        .w_bank0_enb_ctrl       (w_bank0_enb_ctrl),
        .w_bank0_wea_ctrl       (w_bank0_wea_ctrl),
        .w_bank0_addra_ctrl     (w_bank0_addra_ctrl),
        .w_bank0_addrb_ctrl     (w_bank0_addrb_ctrl),

        // -------- North Interface --------
        .n_bank0_ena_ctrl       (n_bank0_ena_ctrl),
        .n_bank0_enb_ctrl       (n_bank0_enb_ctrl),
        .n_bank0_wea_ctrl       (n_bank0_wea_ctrl),     
        .n_bank0_addra_ctrl     (n_bank0_addra_ctrl),   
        .n_bank0_addrb_ctrl     (n_bank0_addrb_ctrl),   

        // -------- Global Control --------
        .w_slicing_idx          (w_slicing_idx),
        .n_slicing_idx          (n_slicing_idx),
        .internal_rst_n_ctrl    (internal_rst_n_ctrl),
        .internal_reset_acc_ctrl(internal_reset_acc_ctrl),
        .out_valid              (out_valid),
        .enable_matmul          (enable_matmul),
        .state_now              (state_now)
    );

    // ************************************ PING PONG BUFFERS ************************************
    logic [W0_MODULE_WIDTH-1:0] w_bank0_dout_i [NUMBER_OF_BUFFER_INSTANCES];

    logic [N0_MODULE_WIDTH-1:0] n_bank0_dout_i [NUMBER_OF_BUFFER_INSTANCES];

    genvar i;
    generate
        for (i = 0; i < NUMBER_OF_BUFFER_INSTANCES; i++) begin : GEN_BUFFER
            top_buffer_buffers #(
                .WIDTH(WIDTH),
                .W_NUM_CORES_A(W_NUM_CORES_A),
                .W_NUM_CORES_B(W_NUM_CORES_B),
                .W_TOTAL_MODULES(W_TOTAL_MODULES),
                .W_COL_X(W_COL_X),
                .W_ROW_X(W_ROW_X),
                .TOTAL_INPUT_W_W(TOTAL_INPUT_W_W),
                .ADDR_WIDTH_W(ADDR_WIDTH_W),
                .W_IN_WIDTH(W_IN_WIDTH),
                .W_MODULE_WIDTH(W_MODULE_WIDTH),
                .W_MEMORY_SIZE(W_MEMORY_SIZE),
                .W_TOTAL_DEPTH(W_TOTAL_DEPTH),

                .N_NUM_CORES_A(N_NUM_CORES_A),
                .N_NUM_CORES_B(N_NUM_CORES_B),
                .N_TOTAL_MODULES(N_TOTAL_MODULES),
                .N_ROW_X(N_ROW_X),
                .TOTAL_INPUT_W_N(TOTAL_INPUT_W_N),
                .ADDR_WIDTH_N(ADDR_WIDTH_N),
                .N_IN_WIDTH(N_IN_WIDTH),
                .N_MEMORY_SIZE(N_MEMORY_SIZE),
                .N_TOTAL_DEPTH(N_TOTAL_DEPTH),
                .N_SLICE_WIDTH(N_SLICE_WIDTH),
                .N_MODULE_WIDTH(N_MODULE_WIDTH)
            ) u_pingpong_buffers (
                .clk(clk),
                .rst_n(rst_n),

                .w_slicing_idx(w_slicing_idx),
                .n_slicing_idx(n_slicing_idx),

                // Control (shared)
                .w_bank0_ena(w_bank0_ena_ctrl),
                .w_bank0_enb(w_bank0_enb_ctrl),
                .w_bank0_wea(w_bank0_wea_ctrl),
                .w_bank0_addra(w_bank0_addra_ctrl),
                .w_bank0_addrb(w_bank0_addrb_ctrl),

                .n_bank0_ena(n_bank0_ena_ctrl),
                .n_bank0_enb(n_bank0_enb_ctrl),
                .n_bank0_wea(n_bank0_wea_ctrl),
                .n_bank0_addra(n_bank0_addra_ctrl),
                .n_bank0_addrb(n_bank0_addrb_ctrl),

                // Instance-specific data
                .w_bank0_din(w_bank0_din[i]),
                .n_bank0_din(n_bank0_din[i]),

                .w_bank0_dout(w_bank0_dout_i[i]),
                .n_bank0_dout(n_bank0_dout_i[i])
            );

        end
    endgenerate

    // ************************************ OUTPUT SELECTION ************************************
    genvar k;
    generate
        for (k = 0; k < NUMBER_OF_BUFFER_INSTANCES; k++) begin : GEN_BANK_MUX

            // ---------------- WEST (single input) ----------------
            assign w_dout[k][0] = w_bank0_dout_i;

            // ---------------- NORTH (single input) ----------------
            assign n_dout[k] = n_bank0_dout_i[k];

        end
    endgenerate




endmodule
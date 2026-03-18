// top_buffer.sv
// This code combines buffer_ctrl + buffer_wrappers
// import buffer0_pkg::*;

module top_buffer #(
    parameter NUMBER_OF_BUFFER_INSTANCES = 4,
    // ================= WEST PARAMETERS =================
    parameter WIDTH            = 16,
    parameter W_NUM_CORES_A      = 4,
    parameter W_NUM_CORES_B      = 4,
    parameter W_TOTAL_MODULES    = 8,
    parameter W_COL_X            = 8,
    parameter W_ROW_X            = 8,
    parameter TOTAL_INPUT_W_W    = 2,

    parameter ADDR_WIDTH_W       = 8,
    parameter W_IN_WIDTH         = 256,
    parameter W_SLICE_WIDTH      = 64,
    parameter W_MODULE_WIDTH     = 512,
    parameter W_MEMORY_SIZE      = 2048,
    parameter W_TOTAL_DEPTH      = 256,
    parameter W_TOTAL_IN         = 256,

    // ================= NORTH PARAMETERS =================
    parameter N_NUM_CORES_A      = 4,
    parameter N_NUM_CORES_B      = 4,
    parameter N_TOTAL_MODULES    = 8,
    parameter N_ROW_X            = 8,
    parameter N_COL_X            = 8,
    parameter TOTAL_INPUT_W_N    = 2,

    parameter ADDR_WIDTH_N       = 8,
    parameter N_IN_WIDTH         = 256,
    parameter N_MEMORY_SIZE      = 2048,
    parameter N_TOTAL_DEPTH      = 256,
    parameter N_SLICE_WIDTH      = 64,
    parameter N_MODULE_WIDTH     = 512,

    // ================= GLOBAL PARAMETERS =================
    parameter MAX_FLAG           = 256,
    parameter COL_Y              = 256,
    parameter INNER_DIMENSION    = 256
) (
    input logic clk, rst_n,
    input logic in_valid_w,
    input logic in_valid_n,
    input logic acc_done_wrap, systolic_finish_wrap,

    // For West Bank
    input logic [W_IN_WIDTH-1:0] w_bank0_din [NUMBER_OF_BUFFER_INSTANCES][TOTAL_INPUT_W_W],
    output logic [W_SLICE_WIDTH-1:0] w_dout [NUMBER_OF_BUFFER_INSTANCES][TOTAL_INPUT_W_W],

    // For North Bank
    input logic [N_IN_WIDTH-1:0] n_bank0_din [NUMBER_OF_BUFFER_INSTANCES][TOTAL_INPUT_W_N],
    output logic [N_MODULE_WIDTH-1:0] n_dout [NUMBER_OF_BUFFER_INSTANCES],

    // Global Controllers
    output logic internal_rst_n_ctrl,
    output logic internal_reset_acc_ctrl,
    output logic out_valid,
    output logic enable_matmul
);
    // ************************************ BUFFER CONTROLLER ************************************
    // West bank control
    logic w_bank0_ena_ctrl;
    logic w_bank0_enb_ctrl;
    logic w_bank0_wea_ctrl;
    logic [ADDR_WIDTH_W-1:0] w_bank0_addra_ctrl, w_bank0_addrb_ctrl;

    // North bank control
    logic n_bank0_ena_ctrl;
    logic n_bank0_enb_ctrl;
    logic n_bank0_wea_ctrl;
    logic [ADDR_WIDTH_N-1:0] n_bank0_addra_ctrl, n_bank0_addrb_ctrl;

    // Slicing + global control
    logic [$clog2(W_TOTAL_MODULES)-1:0] w_slicing_idx;
    logic [$clog2(N_TOTAL_MODULES)-1:0] n_slicing_idx;

    logic state_now;
    
    buffer_ctrl #(
    
        .TOTAL_MODULES_N   (N_TOTAL_MODULES),
        .TOTAL_MODULES_W   (W_TOTAL_MODULES),
    
        .ADDR_WIDTH_N      (ADDR_WIDTH_N),
        .ADDR_WIDTH_W      (ADDR_WIDTH_W),
    
        .W_TOTAL_IN        (W_TOTAL_IN),
        .W_COL_X           (W_COL_X),
        .W_ROW_X           (W_ROW_X),
    
        .N_ROW_X           (N_ROW_X),
        .N_COL_X           (N_COL_X),
    
        .N_TOTAL_DEPTH     (N_TOTAL_DEPTH),
        .W_TOTAL_DEPTH     (W_TOTAL_DEPTH),
    
        .MAX_FLAG          (MAX_FLAG),
        .COL_Y             (COL_Y),
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
    logic [W_MODULE_WIDTH-1:0] w_bank0_dout_i [NUMBER_OF_BUFFER_INSTANCES];

    logic [N_MODULE_WIDTH-1:0] n_bank0_dout_i [NUMBER_OF_BUFFER_INSTANCES];

    genvar i;
    generate
        for (i = 0; i < NUMBER_OF_BUFFER_INSTANCES; i++) begin : GEN_BUFFER
            buffer_wrapper #(
                // WEST
                .WIDTH              (WIDTH),
                .W_NUM_CORES_A      (W_NUM_CORES_A),
                .W_NUM_CORES_B      (W_NUM_CORES_B),
                .W_TOTAL_MODULES    (W_TOTAL_MODULES),
                .W_COL_X            (W_COL_X),
                .W_ROW_X            (W_ROW_X),
                .TOTAL_INPUT_W_W    (TOTAL_INPUT_W_W),
                .ADDR_WIDTH_W       (ADDR_WIDTH_W),
                .W_IN_WIDTH         (W_IN_WIDTH),
                .W_SLICE_WIDTH      (W_SLICE_WIDTH),
                .W_MODULE_WIDTH     (W_MODULE_WIDTH),
                .W_MEMORY_SIZE      (W_MEMORY_SIZE),
                .W_TOTAL_DEPTH      (W_TOTAL_DEPTH),
        
                // NORTH
                .N_NUM_CORES_A      (N_NUM_CORES_A),
                .N_NUM_CORES_B      (N_NUM_CORES_B),
                .N_TOTAL_MODULES    (N_TOTAL_MODULES),
                .N_ROW_X            (N_ROW_X),
                .N_COL_X            (N_COL_X),
                .TOTAL_INPUT_W_N    (TOTAL_INPUT_W_N),
                .ADDR_WIDTH_N       (ADDR_WIDTH_N),
                .N_IN_WIDTH         (N_IN_WIDTH),
                .N_MEMORY_SIZE      (N_MEMORY_SIZE),
                .N_TOTAL_DEPTH      (N_TOTAL_DEPTH),
                .N_SLICE_WIDTH      (N_SLICE_WIDTH),
                .N_MODULE_WIDTH     (N_MODULE_WIDTH)
            ) u_buffers (
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
    genvar k, l;
    generate
        for (k = 0; k < NUMBER_OF_BUFFER_INSTANCES; k++) begin : GEN_BANK_MUX
            for (l = 0; l < TOTAL_INPUT_W_W; l++) begin
                // ---------------- WEST (single input) ----------------
                assign w_dout[k][l] = w_bank0_dout_i[k][(TOTAL_INPUT_W_W*W_SLICE_WIDTH - 1) - l*W_SLICE_WIDTH -: W_SLICE_WIDTH];
            end

            // ---------------- NORTH (single input) ----------------
            assign n_dout[k] = n_bank0_dout_i[k];

        end
    endgenerate




endmodule

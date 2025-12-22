// top_ping_pong.sv
// This code combines top_ping_pong_buffers + ping_pong_ctrl
import ping_pong_pkg::*;

module top_ping_pong #(
    parameter NUMBER_OF_BUFFER_INSTANCES = 4
) (
    input logic clk, rst_n,
    input logic in_valid,
    input logic acc_done_wrap, systolic_finish_wrap,

    // For West Bank
    input logic [W_IN_WIDTH-1:0] w_bank0_din [NUMBER_OF_BUFFER_INSTANCES][TOTAL_INPUT_W],
    input logic [W_IN_WIDTH-1:0] w_bank1_din [NUMBER_OF_BUFFER_INSTANCES][TOTAL_INPUT_W],
    output logic [W_MODULE_WIDTH-1:0] w_bank0_douta [NUMBER_OF_BUFFER_INSTANCES],
    output logic [W_MODULE_WIDTH-1:0] w_bank0_doutb [NUMBER_OF_BUFFER_INSTANCES],
    output logic [W_MODULE_WIDTH-1:0] w_bank1_douta [NUMBER_OF_BUFFER_INSTANCES], 
    output logic [W_MODULE_WIDTH-1:0] w_bank1_doutb [NUMBER_OF_BUFFER_INSTANCES],

    // For North Bank
    input logic [N_IN_WIDTH-1:0] n_bank0_din [NUMBER_OF_BUFFER_INSTANCES][TOTAL_INPUT_W],
    input logic [N_IN_WIDTH-1:0] n_bank1_din [NUMBER_OF_BUFFER_INSTANCES][TOTAL_INPUT_W],
    output logic [N_MODULE_WIDTH-1:0] n_bank0_dout [NUMBER_OF_BUFFER_INSTANCES],
    output logic [N_MODULE_WIDTH-1:0] n_bank1_dout [NUMBER_OF_BUFFER_INSTANCES],

    // Global Controllers
    output logic internal_rst_n_ctrl,
    output logic internal_reset_acc_ctrl,
    output logic out_valid,
    output logic enable_matmul
);
    // ************************************ PING-PONG CONTROLLER ************************************
    // West bank control
    logic w_bank0_ena_ctrl, w_bank0_enb_ctrl;
    logic w_bank0_wea_ctrl, w_bank0_web_ctrl;
    logic [ADDR_WIDTH_W-1:0] w_bank0_addra_ctrl, w_bank0_addrb_ctrl;

    logic w_bank1_ena_ctrl, w_bank1_enb_ctrl;
    logic w_bank1_wea_ctrl, w_bank1_web_ctrl;
    logic [ADDR_WIDTH_W-1:0] w_bank1_addra_ctrl, w_bank1_addrb_ctrl;

    // North bank control
    logic n_bank0_ena_ctrl;
    logic n_bank0_wea_ctrl;
    logic [ADDR_WIDTH_N-1:0] n_bank0_addra_ctrl;

    logic n_bank1_ena_ctrl;
    logic n_bank1_wea_ctrl;
    logic [ADDR_WIDTH_N-1:0] n_bank1_addra_ctrl;

    // Slicing + global control
    logic [$clog2(W_TOTAL_MODULES)-1:0] w_slicing_idx;
    logic [$clog2(N_TOTAL_MODULES)-1:0] n_slicing_idx;

    logic internal_rst_n_ctrl;
    logic internal_reset_acc_ctrl;
    logic out_valid;
    logic enable_matmul;

    ping_pong_ctrl #(
        .TOTAL_MODULES_N   (N_TOTAL_MODULES),
        .TOTAL_MODULES_W   (W_TOTAL_MODULES),
        .ADDR_WIDTH_N      (ADDR_WIDTH_N),
        .ADDR_WIDTH_W      (ADDR_WIDTH_W),
        .N_COL_X           (N_COL_X),
        .W_COL_X           (W_COL_X),
        .MAX_FLAG          (MAX_FLAG),
        .COL_Y             (COL_Y),
        .INNER_DIMENSION   (INNER_DIMENSION)
    ) pingpong_controller (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .in_valid               (in_valid),
        .acc_done_wrap          (acc_done_wrap),
        .systolic_finish_wrap   (systolic_finish_wrap),

        // -------- West Interface --------
        .w_bank0_ena_ctrl       (w_bank0_ena_ctrl),
        .w_bank0_enb_ctrl       (w_bank0_enb_ctrl),
        .w_bank0_wea_ctrl       (w_bank0_wea_ctrl),
        .w_bank0_web_ctrl       (w_bank0_web_ctrl),
        .w_bank0_addra_ctrl     (w_bank0_addra_ctrl),
        .w_bank0_addrb_ctrl     (w_bank0_addrb_ctrl),

        .w_bank1_ena_ctrl       (w_bank1_ena_ctrl),
        .w_bank1_enb_ctrl       (w_bank1_enb_ctrl),
        .w_bank1_wea_ctrl       (w_bank1_wea_ctrl),
        .w_bank1_web_ctrl       (w_bank1_web_ctrl),
        .w_bank1_addra_ctrl     (w_bank1_addra_ctrl),
        .w_bank1_addrb_ctrl     (w_bank1_addrb_ctrl),

        // -------- North Interface --------
        .n_bank0_ena_ctrl       (n_bank0_ena_ctrl),
        .n_bank0_wea_ctrl       (n_bank0_wea_ctrl),
        .n_bank0_addra_ctrl     (n_bank0_addra_ctrl),

        .n_bank1_ena_ctrl       (n_bank1_ena_ctrl),
        .n_bank1_wea_ctrl       (n_bank1_wea_ctrl),
        .n_bank1_addra_ctrl     (n_bank1_addra_ctrl),

        // -------- Global Control --------
        .w_slicing_idx          (w_slicing_idx),
        .n_slicing_idx          (n_slicing_idx),
        .internal_rst_n_ctrl    (internal_rst_n_ctrl),
        .internal_reset_acc_ctrl(internal_reset_acc_ctrl),
        .out_valid              (out_valid),
        .enable_matmul          (enable_matmul)
    );

    // ************************************ PING PONG BUFFERS ************************************
    genvar i;
    generate
        for (i = 0; i < NUMBER_OF_BUFFER_INSTANCES - 1; i++) begin : GEN_PINGPONG

            top_ping_pong_buffers u_pingpong_buffers (
                .clk(clk),
                .rst_n(rst_n),

                .w_slicing_idx(w_slicing_idx),
                .n_slicing_idx(n_slicing_idx),

                // Control (shared)
                .w_bank0_ena(w_bank0_ena_ctrl),
                .w_bank0_enb(w_bank0_enb_ctrl),
                .w_bank0_wea(w_bank0_wea_ctrl),
                .w_bank0_web(w_bank0_web_ctrl),
                .w_bank0_addra(w_bank0_addra_ctrl),
                .w_bank0_addrb(w_bank0_addrb_ctrl),

                .w_bank1_ena(w_bank1_ena_ctrl),
                .w_bank1_enb(w_bank1_enb_ctrl),
                .w_bank1_wea(w_bank1_wea_ctrl),
                .w_bank1_web(w_bank1_web_ctrl),
                .w_bank1_addra(w_bank1_addra_ctrl),
                .w_bank1_addrb(w_bank1_addrb_ctrl),

                .n_bank0_ena(n_bank0_ena_ctrl),
                .n_bank0_wea(n_bank0_wea_ctrl),
                .n_bank0_addra(n_bank0_addra_ctrl),

                .n_bank1_ena(n_bank1_ena_ctrl),
                .n_bank1_wea(n_bank1_wea_ctrl),
                .n_bank1_addra(n_bank1_addra_ctrl),

                // Instance-specific data
                .w_bank0_din(w_bank0_din[i]),
                .w_bank1_din(w_bank1_din[i]),
                .n_bank0_din(n_bank0_din[i]),
                .n_bank1_din(n_bank1_din[i]),

                .w_bank0_douta(w_bank0_douta[i]),
                .w_bank0_doutb(w_bank0_doutb[i]),
                .w_bank1_douta(w_bank1_douta[i]),
                .w_bank1_doutb(w_bank1_doutb[i]),
                .n_bank0_dout(n_bank0_dout[i]),
                .n_bank1_dout(n_bank1_dout[i])
            );

        end
    endgenerate



endmodule
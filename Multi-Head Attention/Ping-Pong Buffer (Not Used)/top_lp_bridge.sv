// top_lp_bridge.sv
// This top module combines top_linear_projection + top_ping_pong + matmul
// This will model the behavior between linear projection and its bridge buffer with the next matmul

import linear_proj_pkg::*;
import self_attention_pkg::*;
import ping_pong_pkg::*;

module top_lp_bridge #(
    parameter OUT_KEYS = WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A*NUM_CORES_B*TOTAL_MODULES,
    parameter NUMBER_OF_BUFFER_INSTANCES = 1
) (
    input logic clk, rst_n,
    input logic in_mat_ena,
    input logic in_mat_wea,
    input logic [ADDR_WIDTH_A-1:0] in_mat_wr_addra,
    input logic [DATA_WIDTH_A-1:0] in_mat_dina,

    input logic in_mat_enb,
    input logic in_mat_web,
    input logic [ADDR_WIDTH_A-1:0] in_mat_wr_addrb,
    input logic [DATA_WIDTH_A-1:0] in_mat_dinb,

    output logic [(WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A_Qn_KnT*NUM_CORES_B_Qn_KnT*TOTAL_MODULES_LP_Q)-1:0] out_lp_bridge [TOTAL_INPUT_W]

);
    // ************************************ TOP LINEAR PROJECTION ************************************
    logic [(OUT_KEYS)-1:0] out_q1_wire [TOTAL_INPUT_W];
    /*
    logic [(OUT_KEYS)-1:0] out_q2_wire [TOTAL_INPUT_W];
    logic [(OUT_KEYS)-1:0] out_q3_wire [TOTAL_INPUT_W];
    logic [(OUT_KEYS)-1:0] out_q4_wire [TOTAL_INPUT_W]; */

    logic [(OUT_KEYS)-1:0] out_k1_wire [TOTAL_INPUT_W];
    /*
    logic [(OUT_KEYS)-1:0] out_k2_wire [TOTAL_INPUT_W];
    logic [(OUT_KEYS)-1:0] out_k3_wire [TOTAL_INPUT_W];
    logic [(OUT_KEYS)-1:0] out_k4_wire [TOTAL_INPUT_W];

    logic [(OUT_KEYS)-1:0] out_v1_wire [TOTAL_INPUT_W];
    logic [(OUT_KEYS)-1:0] out_v2_wire [TOTAL_INPUT_W];
    logic [(OUT_KEYS)-1:0] out_v3_wire [TOTAL_INPUT_W];
    logic [(OUT_KEYS)-1:0] out_v4_wire [TOTAL_INPUT_W]; */

    logic lp_valid, lp_done;

    top_linear_projection #(
        .OUT_KEYS(OUT_KEYS)
    ) linear_projection_inst (
        .clk(clk), .rst_n(rst_n),
        
        .in_mat_ena(in_mat_ena),
        .in_mat_wea(in_mat_wea),
        .in_mat_wr_addra(in_mat_wr_addra),
        .in_mat_dina(in_mat_dina),

        .in_mat_enb(in_mat_enb),
        .in_mat_web(in_mat_web),
        .in_mat_wr_addrb(in_mat_wr_addrb),
        .in_mat_dinb(in_mat_dinb),

        .out_q1(out_q1_wire), // We're just using one output to see the behavior
        /* 
        .out_q2(out_q2_wire),
        .out_q3(out_q3_wire),
        .out_q4(out_q4_wire), */

        .out_k1(out_k1_wire),
        /*
        .out_k2(out_k2_wire),
        .out_k3(out_k3_wire),
        .out_k4(out_k4_wire), */

        /*
        .out_v1(out_v1_wire),
        .out_v2(out_v2_wire),
        .out_v3(out_v3_wire),
        .out_v4(out_v4_wire), */

        .out_valid(lp_valid),
        .done(lp_done)
    );

    // ************************************ TOP PING PONG  ************************************
    // For West Bank
    logic [W_IN_WIDTH-1:0] w_bank0_din_bridge [NUMBER_OF_BUFFER_INSTANCES][TOTAL_INPUT_W]; // [1] because the NUMBER_OF_BUFFER_INSTANCES for this test is just 1
    logic [W_IN_WIDTH-1:0] w_bank1_din_bridge [NUMBER_OF_BUFFER_INSTANCES][TOTAL_INPUT_W];

    // For North Bank
    logic [N_IN_WIDTH-1:0] n_bank0_din_bridge [NUMBER_OF_BUFFER_INSTANCES][TOTAL_INPUT_W];

    genvar t, u;
    generate
        for (u = 0; u < NUMBER_OF_BUFFER_INSTANCES; u++) begin
            for (t = 0; t < TOTAL_INPUT_W; t++) begin
                if (u == 0) begin
                    assign w_bank0_din_bridge[0][t] = out_q1_wire[t];
                    assign w_bank1_din_bridge[0][t] = out_q1_wire[t];

                    assign n_bank0_din_bridge[0][t] = out_k1_wire[t];
                end /*
                else if (u == 1) begin
                    assign w_bank0_din_bridge[1][t] = out_q2_wire[t];
                    assign w_bank1_din_bridge[1][t] = out_q2_wire[t];

                    assign n_bank0_din_bridge[1][t] = out_k2_wire[t];
                    assign n_bank1_din_bridge[1][t] = out_k2_wire[t];
                end
                else if (u == 2) begin
                    assign w_bank0_din_bridge[2][t] = out_q3_wire[t];
                    assign w_bank1_din_bridge[2][t] = out_q3_wire[t];

                    assign n_bank0_din_bridge[2][t] = out_k3_wire[t];
                    assign n_bank1_din_bridge[2][t] = out_k3_wire[t];
                end
                else if (u == 3) begin
                    assign w_bank0_din_bridge[3][t] = out_q4_wire[t];
                    assign w_bank1_din_bridge[3][t] = out_q4_wire[t];

                    assign n_bank0_din_bridge[3][t] = out_k4_wire[t];
                    assign n_bank1_din_bridge[3][t] = out_k4_wire[t]; 
                end */
            end
        end
    endgenerate

    logic [W_MODULE_WIDTH-1:0] w_dout_pp [NUMBER_OF_BUFFER_INSTANCES][TOTAL_INPUT_W];
    logic [N_MODULE_WIDTH-1:0] n_dout_pp [NUMBER_OF_BUFFER_INSTANCES];

    logic sig_internal_rst_n_ctrl;
    logic sig_internal_reset_acc_ctrl;
    logic sig_out_valid;
    logic sig_enable_matmul;

    logic sig_acc_done_wrap;
    logic sig_systolic_finish_wrap;

    top_ping_pong #(
        .NUMBER_OF_BUFFER_INSTANCES(NUMBER_OF_BUFFER_INSTANCES)
    ) ping_pong_bridge (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(lp_valid),
        .acc_done_wrap(sig_acc_done_wrap),
        .systolic_finish_wrap(sig_systolic_finish_wrap),

        // -------- West --------
        .w_bank0_din(w_bank0_din_bridge),
        .w_bank1_din(w_bank1_din_bridge),
        .w_dout     (w_dout_pp),

        // -------- North --------
        .n_bank0_din(n_bank0_din_bridge),
        .n_dout     (n_dout_pp),

        // -------- Global --------
        .internal_rst_n_ctrl     (sig_internal_rst_n_ctrl),
        .internal_reset_acc_ctrl (sig_internal_reset_acc_ctrl),
        .out_valid               (sig_out_valid),
        .enable_matmul           (sig_enable_matmul)
    );

    // ************************************ NEXT MATMUL  ************************************
    multi_matmul_wrapper #(
        .WIDTH_A(WIDTH_A),
        .FRAC_WIDTH_A(FRAC_WIDTH_A),
        .WIDTH_B(WIDTH_B),
        .FRAC_WIDTH_B(FRAC_WIDTH_B),
        .WIDTH_OUT(WIDTH_OUT),
        .FRAC_WIDTH_OUT(FRAC_WIDTH_OUT),
        .BLOCK_SIZE(BLOCK_SIZE),
        .CHUNK_SIZE(CHUNK_SIZE),
        .INNER_DIMENSION(INNER_DIMENSION_Qn_KnT),
        .TOTAL_MODULES(TOTAL_MODULES_LP_Q),
        .TOTAL_INPUT_W(TOTAL_INPUT_W_Qn_KnT),
        .NUM_CORES_A(NUM_CORES_A_Qn_KnT),
        .NUM_CORES_B(NUM_CORES_B_Qn_KnT)
    ) matmul_Qn_KnT (
        .clk(clk),
        .rst_n(sig_internal_rst_n_ctrl),
        .en(sig_enable_matmul),
        .reset_acc(sig_internal_reset_acc_ctrl),
        .input_w(w_dout_pp[0]), 
        .input_n(n_dout_pp[0]), 
        .acc_done_wrap(sig_acc_done_wrap), 
        .systolic_finish_wrap(sig_systolic_finish_wrap),
        .out_multi_matmul(out_lp_bridge)
    );


endmodule
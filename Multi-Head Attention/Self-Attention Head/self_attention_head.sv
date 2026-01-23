// self_attention_head.sv
// Top level of self attention-head
import buffer0_pkg::W0_SLICE_WIDTH;
import buffer0_pkg::N0_MODULE_WIDTH;
import buffer0_pkg::TOTAL_INPUT_W_W0;

import self_attention_pkg::*;

module self_attention_head #(
    parameter NUMBER_OF_BUFFER_INSTANCES = 4
) (
    input clk, rst_n,
    input en_Qn_KnT,
    input rst_n_Qn_KnT,
    input reset_acc_Qn_KnT,
    input out_valid_Qn_KnT,
    input logic [W0_SLICE_WIDTH-1:0] input_w_Qn_KnT [NUMBER_OF_BUFFER_INSTANCES][TOTAL_INPUT_W_W0];
    input logic [N0_MODULE_WIDTH-1:0] input_n_Qn_KnT [NUMBER_OF_BUFFER_INSTANCES];

    // Output
    output logic sys_finish_wrap_Qn_KnT, 
    output logic acc_done_wrap_Qn_KnT
);
    // ************************** Matmul Module Qn x Kn^T **************************
    logic [(WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A_Qn_KnT*NUM_CORES_B_Qn_KnT*TOTAL_MODULES_LP_Q)-1:0] out_matmul_Qn_KnT [TOTAL_INPUT_W_Qn_KnT]
    genvar i;
    generate
        for (i = 0; i < NUMBER_OF_BUFFER_INSTANCES; i++) begin : GEN_MATMUL_QN_KNT
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
                .rst_n(rst_n_Qn_KnT),
                .en(en_Qn_KnT),
                .reset_acc(reset_acc_Qn_KnT),
                .input_w(input_w_Qn_KnT[i]), 
                .input_n(input_n_Qn_KnT[i]), 
                .acc_done_wrap(acc_done_wrap_Qn_KnT), 
                .systolic_finish_wrap(sys_finish_wrap_Qn_KnT),
                .out_multi_matmul(out_matmul_Qn_KnT)
            );
        end
    endgenerate
    


    // ************************** 4-BIT SHIFTER **************************
    logic [(WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A*NUM_CORES_B*TOTAL_MODULES_LP_Q)-1:0] out_shifted [TOTAL_INPUT_W_Qn_KnT];

    rshift #(
        .WIDTH_A(WIDTH_A),
        .FRAC_WIDTH_A(FRAC_WIDTH_A),
        .WIDTH_B(WIDTH_B),
        .FRAC_WIDTH_B(FRAC_WIDTH_B),
        .WIDTH_OUT(WIDTH_OUT),
        .FRAC_WIDTH_OUT(FRAC_WIDTH_OUT),
        .BLOCK_SIZE(BLOCK_SIZE),
        .CHUNK_SIZE(CHUNK_SIZE),
        .TOTAL_MODULES(TOTAL_MODULES_LP_Q),
        .TOTAL_INPUT_W(TOTAL_INPUT_W_Qn_KnT),
        .NUM_CORES_A(NUM_CORES_A_Qn_KnT),
        .NUM_CORES_B(NUM_CORES_B_Qn_KnT)
    ) rshift_four_bit (
        .clk(clk), .rst_n(rst_n),
        .in_valid(acc_done_wrap_Qn_KnT),
        .in_4bit_rshift(out_matmul_Qn_KnT),
        .out_valid()
        .out_shifted(out_shifted)
    );

    // ************************** B2R CONVERTER **************************
    


endmodule
// self_attention_head.sv
// Top level of self attention-head
import self_attention_pkg::*;

module self_attention_head #(
    parameter XXXX = YY 
) (
    input clk, rst_n,
    input enable_self_attention,
    input 

    output XXXX
);
    // ************************** Matmul Module Qn x Kn^T **************************
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
        .TOTAL_MODULES(TOTAL_MODULES_LP),
        .TOTAL_INPUT_W(TOTAL_INPUT_W_Qn_KnT),
        .NUM_CORES_A(NUM_CORES_A_Qn_KnT),
        .NUM_CORES_B(NUM_CORES_B_Qn_KnT)
    ) matmul_Qn_KnT (
        .clk(clk),
        .rst_n(rst_n),
        .en(),
        .reset_acc(),
        .input_w(), 
        .input_n(), 
        .acc_done_wrap(), 
        .systolic_finish_wrap(),
        .out_multi_matmul()
    );

    // ************************** 4-BIT SHIFTER **************************


endmodule
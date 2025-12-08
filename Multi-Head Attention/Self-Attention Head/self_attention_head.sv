// self_attention_head.sv
// Top level of self attention-head
import self_attention_pkg::*;

module self_attention_head #(
    parameter XXXX = YY 
) (
    input clk, rst_n,
    input enable_self_attention,
    input reset_acc_self_attention,
    input logic [(WIDTH_A*CHUNK_SIZE*NUM_CORES_A)-1:0] input_w_qkt [TOTAL_INPUT_W],
    input logic [(WIDTH_B*CHUNK_SIZE*NUM_CORES_B*TOTAL_MODULES)-1:0] input_n_qkt, 

    output sys_finish_wrap_qkt, acc_done_wrap_qkt
);
    // ************************** Matmul Module Qn x Kn^T **************************
    logic [(WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A*NUM_CORES_B*TOTAL_MODULES_LP_Q)-1:0] out_matmul_qkt [TOTAL_INPUT_W_Qn_KnT];
    logic sig_acc_done_wrap_qkt;

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
        .rst_n(rst_n),
        .en(enable_self_attention),
        .reset_acc(reset_acc_self_attention),
        .input_w(input_w_qkt), 
        .input_n(input_n_qkt), 
        .acc_done_wrap(sig_acc_done_wrap_qkt), 
        .systolic_finish_wrap(sys_finish_wrap_qkt),
        .out_multi_matmul(out_matmul_qkt)
    );

    assign acc_done_wrap_qkt = sig_acc_done_wrap_qkt;

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
        .in_valid(sig_acc_done_wrap_qkt),
        .in_4bit_rshift(out_matmul_qkt),
        .out_valid()
        .out_shifted(out_shifted)
    );

    // ************************** B2R CONVERTER **************************
    


endmodule
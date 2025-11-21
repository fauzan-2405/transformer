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
        .INNER_DIMENSION(),
        .TOTAL_MODULES(),
        .TOTAL_INPUT_W(),
        .NUM_CORES_A(),
        .NUM_CORES_B()
    ) matmul_Qn_KnT (
        .clk(clk),
        .rst_n(internal_rst_n),
        .en(en_module),
        .reset_acc(internal_reset_acc),
        .input_w(in_multi_matmul), 
        .input_n(w_mat_doutb), 
        .acc_done_wrap(acc_done_wrap), 
        .systolic_finish_wrap(systolic_finish_wrap),
        .out_multi_matmul(out_multwrap_wbram)
    )


endmodule
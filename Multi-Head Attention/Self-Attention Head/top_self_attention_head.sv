// top_self_attention_head.sv
// This is the top module for self_attention_head + self_attention_ctrl

import self_attention_pkg::*;

module top_self_attention_head #(
    parameter NUMBER_OF_BUFFER_INSTANCES = 1
) (
    input clk, rst_n,
    input en_Qn_KnT,
    input rst_n_Qn_KnT,
    input reset_acc_Qn_KnT,
    input out_valid_Qn_KnT,
    input logic [W0_SLICE_WIDTH-1:0] input_w_Qn_KnT [NUMBER_OF_BUFFER_INSTANCES][TOTAL_INPUT_W_W0],
    input logic [N0_MODULE_WIDTH-1:0] input_n_Qn_KnT [NUMBER_OF_BUFFER_INSTANCES],

    // Output to bridge buffer
    output logic sys_finish_wrap_Qn_KnT, 
    output logic acc_done_wrap_Qn_KnT,

    // Temporary output to see the intermediate results
    output logic [TILE_SIZE_SOFTMAX*WIDTH_OUT-1:0] out_softmax_data [TOTAL_INPUT_W_Qn_KnT][TOTAL_SOFTMAX_ROW],
    output logic out_softmax_valid [TOTAL_INPUT_W_Qn_KnT][TOTAL_SOFTMAX_ROW]
    
);
    // ************************************ SELF ATTENTION HEAD ************************************
    // To controller
    logic slice_done_b2r_wrap_sig;
    logic out_ready_b2r_wrap_sig;

    // From controller
    logic internal_rst_n_b2r_sig;
    logic internal_rst_n_softmax_sig;
    logic softmax_en_sig;
    logic softmax_valid_sig [TOTAL_SOFTMAX_ROW];

    genvar i;
    generate
        for (i = 0; i < NUMBER_OF_BUFFER_INSTANCES; i++) begin
            self_attention_head_unit (
                .clk(clk),
                .rst_n(rst_n),
                .rst_n_Qn_KnT(rst_n_Qn_KnT),
                .reset_acc_Qn_KnT(reset_acc_Qn_KnT),
                .out_valid_Qn_KnT(out_valid_Qn_KnT),

                .input_w_Qn_KnT(input_w_Qn_KnT[i]),
                .input_n_Qn_KnT(input_n_Qn_KnT[i]),

                // To/From bridge buffer
                .sys_finish_wrap_Qn_KnT(sys_finish_wrap_Qn_KnT),
                .acc_done_wrap_Qn_KnT(acc_done_wrap_Qn_KnT),

                // To/From controller
                .internal_rst_n_b2r(internal_rst_n_b2r_sig),
                
                .softmax_en(softmax_en_sig),
                .softmax_valid(softmax_valid_sig),
                .internal_rst_n_softmax(internal_rst_n_softmax_sig),

                .slice_done_b2r_wrap(slice_done_b2r_wrap_sig),
                .out_ready_b2r_wrap(out_ready_b2r_wrap_sig),

                // Temporary output to see the intermediate results
                .out_softmax_data(out_softmax_data),
                .out_softmax_valid(out_softmax_valid)
            );
        end
    endgenerate


    // ************************************ CONTROLLER ************************************
    self_attention_ctrl #(
        .WIDTH              (SA_WIDTH_OUT),
        .COL                (COL_B2R_CONVERTER),
        .TILE_SIZE          (TILE_SIZE_SOFTMAX),
        .NUM_CORES_A_Qn_KnT (NUM_CORES_A_Qn_KnT),
        .BLOCK_SIZE         (top_pkg::BLOCK_SIZE)
    ) self_attention_ctrl_u (
        .clk(clk),
        .rst_n(rst_n),
        .slice_done_b2r_wrap(slice_done_b2r_wrap_sig),
        .out_ready_b2r(out_ready_b2r_wrap_sig),
        .internal_rst_n_b2r(internal_rst_n_b2r_sig),

        .internal_rst_n_softmax(internal_rst_n_softmax_sig),
        .softmax_en(softmax_en_sig),
        .softmax_valid(softmax_valid_sig)
    );
    

endmodule
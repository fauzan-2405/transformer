// top_self_attention_head.sv
// This is the top module for self_attention_head + self_attention_ctrl

import self_attention_pkg::*;

module top_self_attention_head #(
    parameter TOTAL_SOFTMAX_ROW = NUM_CORES_A_Qn_KnT * BLOCK_SIZE,
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
    //output logic [(TILE_SIZE_SOFTMAX*SA_WIDTH_OUT)-1:0] out_softmax_data [NUMBER_OF_BUFFER_INSTANCES][TOTAL_INPUT_W_Qn_KnT][TOTAL_SOFTMAX_ROW],
    //output logic out_softmax_valid [NUMBER_OF_BUFFER_INSTANCES][TOTAL_INPUT_W_Qn_KnT][TOTAL_SOFTMAX_ROW]
    output logic [WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A_QKT_Vn-1:0] out_data_r2b [NUMBER_OF_BUFFER_INSTANCES][TOTAL_INPUT_W_Qn_KnT][TOTAL_TILE_SOFTMAX]
    
);
    // ************************************ SELF ATTENTION HEAD ************************************
    // To controller
    logic in_valid_b2r;
    logic slice_done_b2r_wrap_sig;
    logic out_ready_b2r_wrap_sig;
    logic slice_last_r2b_sig [TOTAL_TILE_SOFTMAX];

    // From controller
    logic internal_rst_n_b2r_sig;

    logic softmax_done_sig [NUMBER_OF_BUFFER_INSTANCES][TOTAL_INPUT_W_Qn_KnT][TOTAL_SOFTMAX_ROW];
    logic internal_rst_n_softmax_sig [NUMBER_OF_BUFFER_INSTANCES][TOTAL_INPUT_W_Qn_KnT][TOTAL_SOFTMAX_ROW];
    logic softmax_en_sig;
    logic softmax_valid_sig [TOTAL_SOFTMAX_ROW];

    logic [$clog2(TOTAL_SOFTMAX_ROW):0] r2b_row_idx_sig;
    logic internal_rst_n_r2b_conv [TOTAL_TILE_SOFTMAX];
    logic in_valid_r2b_sig [TOTAL_TILE_SOFTMAX];

    genvar i;
    generate
        for (i = 0; i < NUMBER_OF_BUFFER_INSTANCES; i++) begin
            self_attention_head #(
                .TOTAL_SOFTMAX_ROW(TOTAL_SOFTMAX_ROW)
            ) self_attention_head_u (
                .clk(clk),
                .rst_n(rst_n),
                .en_Qn_KnT(en_Qn_KnT),
                .rst_n_Qn_KnT(rst_n_Qn_KnT),
                .reset_acc_Qn_KnT(reset_acc_Qn_KnT),
                .out_valid_Qn_KnT(out_valid_Qn_KnT),

                .input_w_Qn_KnT(input_w_Qn_KnT[i]),
                .input_n_Qn_KnT(input_n_Qn_KnT[i]),

                // To/From bridge buffer
                .sys_finish_wrap_Qn_KnT(sys_finish_wrap_Qn_KnT),
                .acc_done_wrap_Qn_KnT(acc_done_wrap_Qn_KnT),

                // To/From controller
                .out_valid_shifted(in_valid_b2r),

                .internal_rst_n_b2r(internal_rst_n_b2r_sig),
                
                .softmax_en(softmax_en_sig),
                .softmax_valid(softmax_valid_sig),
                .internal_rst_n_softmax(internal_rst_n_softmax_sig[i]),
                .done_softmax(softmax_done_sig[i])

                .slice_done_b2r_wrap(slice_done_b2r_wrap_sig),
                .out_ready_b2r_wrap(out_ready_b2r_wrap_sig),
                
                .internal_rst_n_r2b_conv(internal_rst_n_r2b_conv),
                .r2b_row_idx(r2b_row_idx_sig),
                .slice_last_r2b(slice_last_r2b_sig),
                .in_valid_r2b(in_valid_r2b_sig),

                // Temporary output to see the intermediate results
                //.out_softmax_data(out_softmax_data[i]),
                //.out_softmax_valid(out_softmax_valid[i]),
                .out_data_r2b(out_data_r2b[i])
            );
        end
    endgenerate


    // ************************************ CONTROLLER ************************************
    self_attention_ctrl #(
        .WIDTH              (SA_WIDTH_OUT),
        .COL                (COL_B2R_CONVERTER),
        .TILE_SIZE          (TILE_SIZE_SOFTMAX),
        .NUM_CORES_A_Qn_KnT (NUM_CORES_A_Qn_KnT),
        .NUMBER_OF_BUFFER_INSTANCES(NUMBER_OF_BUFFER_INSTANCES),
        .TOTAL_INPUT_W_Qn_KnT(TOTAL_INPUT_W_Qn_KnT),
        .BLOCK_SIZE         (top_pkg::TOP_BLOCK_SIZE)
    ) self_attention_ctrl_u (
        .clk(clk),
        .rst_n(rst_n),

        .in_valid_b2r(in_valid_b2r),
        .slice_done_b2r_wrap(slice_done_b2r_wrap_sig),
        .out_ready_b2r_Wrap(out_ready_b2r_wrap_sig),
        .internal_rst_n_b2r(internal_rst_n_b2r_sig),

        .softmax_done(softmax_done_sig),
        .internal_rst_n_softmax(internal_rst_n_softmax_sig),
        .softmax_en(softmax_en_sig),
        .softmax_valid(softmax_valid_sig),

        .r2b_row_idx_sig(r2b_row_idx_sig),
        .internal_rst_n_r2b_conv(internal_rst_n_r2b_conv),
        .in_valid_r2b(in_valid_r2b_sig),
        .slice_last_r2b(slice_last_r2b_sig)
    );
    

endmodule
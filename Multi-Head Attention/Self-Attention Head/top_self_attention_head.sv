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
    //output logic [WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A_QKT_Vn-1:0] out_data_r2b [NUMBER_OF_BUFFER_INSTANCES][TOTAL_INPUT_W_Qn_KnT][TOTAL_TILE_SOFTMAX]
    output logic [(WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A_QKT_Vn)-1:0] out_data_fifo [TOTAL_INPUT_W_Qn_KnT][NUM_BANKS_FIFO]

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
    logic out_softmax_valid [NUMBER_OF_BUFFER_INSTANCES][TOTAL_INPUT_W_Qn_KnT][TOTAL_SOFTMAX_ROW];

    logic [$clog2(TOTAL_SOFTMAX_ROW):0] r2b_row_idx_sig [TOTAL_TILE_SOFTMAX];
    logic internal_rst_n_r2b_conv [TOTAL_TILE_SOFTMAX];
    logic in_valid_r2b_sig [TOTAL_TILE_SOFTMAX];

    logic [$clog2(TOTAL_TILE_SOFTMAX)-1:0] fifo_idx_sig [NUM_BANKS_FIFO]; // Determines the fifo unit that used in circular fashion
    logic fifo_rd_en_sig [TOTAL_TILE_SOFTMAX];
    logic internal_rst_n_fifo_sig [NUM_BANKS_FIFO];
    logic [RD_DATA_COUNT_WIDTH-1:0] rd_data_count_fifo_sig [NUM_BANKS_FIFO];
    logic [WR_DATA_COUNT_WIDTH-1:0] wr_data_count_fifo_sig [NUM_BANKS_FIFO];
    //logic fifo_full_sig [NUM_BANKS_FIFO];
    logic fifo_underflow_sig [TOTAL_TILE_SOFTMAX];

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
                .done_softmax(softmax_done_sig[i]),
                .out_softmax_valid(out_softmax_valid[i]),

                .slice_done_b2r_wrap(slice_done_b2r_wrap_sig),
                .out_ready_b2r_wrap(out_ready_b2r_wrap_sig),

                .internal_rst_n_r2b_conv(internal_rst_n_r2b_conv),
                .r2b_row_idx(r2b_row_idx_sig),
                .slice_last_r2b(slice_last_r2b_sig),
                .in_valid_r2b(in_valid_r2b_sig),

                .fifo_idx(fifo_idx_sig),
                .fifo_underflow(fifo_underflow_sig),
                .fifo_rd_en(fifo_rd_en_sig),
                .internal_rst_n_fifo(internal_rst_n_fifo_sig),
                .rd_data_count_fifo(rd_data_count_fifo_sig),
                .wr_data_count_fifo(wr_data_count_fifo_sig),
                //.fifo_full(fifo_full_sig),

                // Temporary output to see the intermediate results
                //.out_softmax_data(out_softmax_data[i]),
                //.out_data_r2b(out_data_r2b[i]),
                .out_data_fifo(out_data_fifo)
            );
        end
    endgenerate


    // ************************************ CONTROLLER ************************************
    self_attention_ctrl #(
        .WIDTH              (SA_WIDTH_OUT),
        .COL                (COL_B2R_CONVERTER),
        .TILE_SIZE          (TILE_SIZE_SOFTMAX),
        .NUM_CORES_A_Qn_KnT (NUM_CORES_A_Qn_KnT),
        .BLOCK_SIZE         (top_pkg::TOP_BLOCK_SIZE),
        .TOTAL_INPUT_W_Qn_KnT(TOTAL_INPUT_W_Qn_KnT),
        .NUMBER_OF_BUFFER_INSTANCES(NUMBER_OF_BUFFER_INSTANCES),
        .TILE_SIZE_SOFTMAX  (TILE_SIZE_SOFTMAX),
        .TOTAL_TILE_SOFTMAX (TOTAL_TILE_SOFTMAX),
        .NUM_BANKS_FIFO     (NUM_BANKS_FIFO),
        .NUM_CORES_V        (NUM_CORES_A_QKT_Vn),
        .TOTAL_OUTPUTS_PER_TILE(TOTAL_OUTPUTS_PER_TILE),
        .RD_DATA_COUNT_WIDTH(RD_DATA_COUNT_WIDTH),
        .WR_DATA_COUNT_WIDTH(WR_DATA_COUNT_WIDTH)
    ) self_attention_ctrl_u (
        .clk(clk),
        .rst_n(rst_n),

        .in_valid_b2r(in_valid_b2r),
        .slice_done_b2r_wrap(slice_done_b2r_wrap_sig),
        .out_ready_b2r_wrap(out_ready_b2r_wrap_sig),
        .internal_rst_n_b2r(internal_rst_n_b2r_sig),

        .softmax_done(softmax_done_sig),
        .internal_rst_n_softmax(internal_rst_n_softmax_sig),
        .softmax_en(softmax_en_sig),
        .softmax_valid(softmax_valid_sig),
        .softmax_out_valid(out_softmax_valid[0][0]), //[0][0] because we assume all of the other buffer instances have the same timing so we can minimize the HW usage

        .r2b_row_idx_sig(r2b_row_idx_sig),
        .internal_rst_n_r2b(internal_rst_n_r2b_conv),
        .in_valid_r2b(in_valid_r2b_sig),
        .slice_last_r2b(slice_last_r2b_sig),

        //.fifo_full(fifo_full_sig),
        .wr_data_count_fifo(wr_data_count_fifo_sig),
        .rd_data_count_fifo(rd_data_count_fifo_sig),
        .internal_rst_n_fifo(internal_rst_n_fifo_sig),
        .fifo_rd_en(fifo_rd_en_sig),
        .fifo_underflow(fifo_underflow_sig),
        .fifo_idx(fifo_idx_sig)
    );


endmodule

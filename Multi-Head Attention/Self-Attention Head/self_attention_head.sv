// Top level of self attention-head
import buffer0_pkg::W0_SLICE_WIDTH;
import buffer0_pkg::N0_MODULE_WIDTH;
import buffer0_pkg::TOTAL_INPUT_W_W0;
import linear_proj_pkg::*;

import self_attention_pkg::*;

module self_attention_head #(
    parameter TOTAL_SOFTMAX_ROW = NUM_CORES_A_Qn_KnT * BLOCK_SIZE
) (
    input clk, rst_n,
    input en_Qn_KnT,
    input rst_n_Qn_KnT,
    input reset_acc_Qn_KnT,
    input out_valid_Qn_KnT,
    input logic [W0_SLICE_WIDTH-1:0] input_w_Qn_KnT [TOTAL_INPUT_W_W0],
    input logic [N0_MODULE_WIDTH-1:0] input_n_Qn_KnT,

    input logic internal_rst_n_b2r,

    input logic softmax_en,
    input logic softmax_valid [TOTAL_SOFTMAX_ROW],
    input logic internal_rst_n_softmax [TOTAL_INPUT_W_Qn_KnT][TOTAL_SOFTMAX_ROW],

    input logic internal_rst_n_r2b_conv [TOTAL_TILE_SOFTMAX],

    //input logic [$clog2(TOTAL_SOFTMAX_ROW):0] r2b_row_idx,
    input logic [$clog2(TOTAL_SOFTMAX_ROW):0] r2b_row_idx [TOTAL_TILE_SOFTMAX],
    input logic in_valid_r2b [TOTAL_TILE_SOFTMAX],

    input logic [$clog2(TOTAL_TILE_SOFTMAX)-1:0] fifo_idx [NUM_BANKS_FIFO],
    input logic fifo_rd_en [TOTAL_TILE_SOFTMAX],
    input logic internal_rst_n_fifo [NUM_BANKS_FIFO],

    // Output
    output logic sys_finish_wrap_Qn_KnT,
    output logic acc_done_wrap_Qn_KnT,

    output logic out_valid_shifted,

    output logic slice_done_b2r_wrap,
    output logic out_ready_b2r_wrap,   // To Controller

    output logic done_softmax [TOTAL_INPUT_W_Qn_KnT][TOTAL_SOFTMAX_ROW],
    output logic out_softmax_valid [TOTAL_INPUT_W_Qn_KnT][TOTAL_SOFTMAX_ROW],

    output logic slice_last_r2b [TOTAL_TILE_SOFTMAX],

    output logic fifo_underflow [NUM_BANKS_FIFO],
    output logic [RD_DATA_COUNT_WIDTH-1:0] rd_data_count_fifo [NUM_BANKS_FIFO],
    output logic fifo_full [NUM_BANKS_FIFO],

    // Temporary
    //output logic [TILE_SIZE_SOFTMAX*WIDTH_OUT-1:0] out_softmax_data [TOTAL_INPUT_W_Qn_KnT][TOTAL_SOFTMAX_ROW]
    //output logic [WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A_QKT_Vn-1:0] out_data_r2b [TOTAL_INPUT_W_Qn_KnT][TOTAL_TILE_SOFTMAX]
    output logic [(WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A_QKT_Vn)-1:0] out_data_fifo [TOTAL_INPUT_W_Qn_KnT][NUM_BANKS_FIFO]
);
    // ************************** Matmul Module Qn x Kn^T **************************
    logic [(WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A_Qn_KnT*NUM_CORES_B_Qn_KnT*TOTAL_MODULES_LP_Q)-1:0]
        out_matmul_Qn_KnT [TOTAL_INPUT_W_Qn_KnT];

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
        .input_w(input_w_Qn_KnT),
        .input_n(input_n_Qn_KnT),
        .acc_done_wrap(acc_done_wrap_Qn_KnT),
        .systolic_finish_wrap(sys_finish_wrap_Qn_KnT),
        .out_multi_matmul(out_matmul_Qn_KnT)
    );

    // ************************** 4-BIT SHIFTER **************************
    logic [(WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A_Qn_KnT*NUM_CORES_B_Qn_KnT*TOTAL_MODULES_LP_Q)-1:0]
        out_shifted [TOTAL_INPUT_W_Qn_KnT];

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
        .in_valid(out_valid_Qn_KnT),
        .in_4bit_rshift(out_matmul_Qn_KnT),
        .out_valid(out_valid_shifted),
        .out_shifted(out_shifted)
    );


    // ************************** B2R CONVERTER **************************
    logic slice_done_b2r [TOTAL_INPUT_W_Qn_KnT];
    logic out_ready_b2r [TOTAL_INPUT_W_Qn_KnT];
    logic [(TILE_SIZE_SOFTMAX*WIDTH_OUT)-1:0] out_b2r_data [TOTAL_INPUT_W_Qn_KnT];
    assign slice_done_b2r_wrap  = slice_done_b2r[0] && slice_done_b2r[1];
    assign out_ready_b2r_wrap   = out_ready_b2r[0] && out_ready_b2r[1];

    genvar i;
    generate
        for (i = 0; i < TOTAL_INPUT_W_Qn_KnT; i++) begin: GEN_B2R_CONVERTER
            b2r_converter #(
                .WIDTH(WIDTH_OUT),
                .FRAC_WIDTH(FRAC_WIDTH_OUT),
                .ROW(ROW_B2R_CONVERTER),             // Resulting row
                .COL(COL_B2R_CONVERTER),             // Resulting col
                .BLOCK_SIZE(BLOCK_SIZE),
                .CHUNK_SIZE(CHUNK_SIZE),
                .NUM_CORES_H(NUM_CORES_H_B2R),
                .NUM_CORES_V(NUM_CORES_V_B2R)
            ) converter_b2r (
                .clk(clk),
                .rst_n(internal_rst_n_b2r),
                .en(1'b1),
                .in_data(out_shifted[i]),
                .in_valid(out_valid_shifted),
                .slice_done(slice_done_b2r[i]),
                .output_ready(out_ready_b2r[i]),
                .slice_last(),
                .buffer_done(),
                .out_data(out_b2r_data[i])
            );
        end
    endgenerate


    // ************************** SOFTMAX **************************
    logic [TILE_SIZE_SOFTMAX*WIDTH_OUT-1:0] out_softmax_data [TOTAL_INPUT_W_Qn_KnT][TOTAL_SOFTMAX_ROW];
    (* keep = "true" *) logic [(TILE_SIZE_SOFTMAX*WIDTH_OUT)-1:0] out_b2r_data_reg [TOTAL_INPUT_W_Qn_KnT]; // To delay the b2r_data

    genvar j,k;
    generate
        for (j = 0; j < TOTAL_INPUT_W_Qn_KnT; j++) begin
            for (k = 0; k < TOTAL_SOFTMAX_ROW; k++) begin
                softmax_vec #(
                    .WIDTH(WIDTH_OUT),
                    .FRAC_WIDTH(FRAC_WIDTH_OUT),
                    .TOTAL_ELEMENTS(TOTAL_ELEMENTS_SOFTMAX),
                    .TILE_SIZE(TILE_SIZE_SOFTMAX),
                    .USE_AMULT(0)
                ) softmax_unit (
                    .clk(clk),
                    .rst_n(internal_rst_n_softmax[j][k]),
                    .en(softmax_en),

                    .X_tile_in(out_b2r_data_reg[j]),
                    .tile_in_valid(softmax_valid[k]),

                    .Y_tile_out(out_softmax_data[j][k]),
                    .tile_out_valid(out_softmax_valid[j][k]),
                    .done(done_softmax[j][k])
                );
            end
        end
    endgenerate


    // ************************** R2B CONVERTER **************************
    logic [WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A_QKT_Vn-1:0] out_data_r2b [TOTAL_INPUT_W_Qn_KnT][TOTAL_TILE_SOFTMAX];
    logic output_valid_r2b [TOTAL_TILE_SOFTMAX];

    top_r2b_converter_v #(
        .WIDTH(WIDTH_OUT),
        .FRAC_WIDTH(FRAC_WIDTH_OUT),
        .BLOCK_SIZE(BLOCK_SIZE),
        .CHUNK_SIZE(CHUNK_SIZE),
        .ROW(TOTAL_SOFTMAX_ROW), // Real row representation
        .COL(TILE_SIZE_SOFTMAX), // Real col representation
        .NUM_CORES_V(NUM_CORES_A_QKT_Vn),
        .TOTAL_SOFTMAX_ROW(TOTAL_SOFTMAX_ROW),
        .TOTAL_TILE_SOFTMAX(TOTAL_TILE_SOFTMAX)
    ) top_r2b_converter_v_unit (
        .clk(clk),
        .rst_n(internal_rst_n_r2b_conv),
        .en(1'b1),
        .in_valid(in_valid_r2b),
        .in_data(out_softmax_data),
        .r2b_row_idx(r2b_row_idx),
        .slice_done(),
        .output_ready(output_valid_r2b),
        .slice_last(slice_last_r2b),
        .buffer_done(),
        .out_data(out_data_r2b)
    );

    // ************************** FIFO BUFFER **************************
    //logic [UNIT_WIDTH-1:0] out_data_fifo [TOTAL_INPUT_W_Qn_KnT][NUM_BANKS_FIFO]

    top_r2b_circular_fifo #(
        .WIDTH(WIDTH_OUT),
        .CHUNK_SIZE(CHUNK_SIZE),
        .NUM_CORES_V(NUM_CORES_A_QKT_Vn),
        .TOTAL_TILE_SOFTMAX(TOTAL_TILE_SOFTMAX),
        .TILE_SIZE_SOFTMAX(TILE_SIZE_SOFTMAX),
        .TOTAL_OUTPUTS_PER_TILE(TOTAL_OUTPUTS_PER_TILE),
        .NUM_BANKS_FIFO(NUM_BANKS_FIFO),
        .RD_DATA_COUNT_WIDTH(RD_DATA_COUNT_WIDTH),
        .FIFO_WRITE_DEPTH(FIFO_WRITE_DEPTH)
    ) top_r2b_circular_fifo_inst (
        .clk(clk),
        .rst_n(internal_rst_n_fifo),
        .fifo_wr_en(output_valid_r2b),
        .in_data(out_data_r2b),
        .fifo_idx(fifo_idx),
        .fifo_rd_en(fifo_rd_en),
        .fifo_full(fifo_full),
        .rd_data_count(rd_data_count_fifo),
        .fifo_empty(),
        .fifo_underflow(fifo_underflow),
        .out_data(out_data_fifo)
    );

    // ************************** Matmul Module (Qn x Kn^T) x Vn **************************
    /*
    top_buffer #(
        .NUMBER_OF_BUFFER_INSTANCES(1)
    ) fifo_to_matmul_QKT_V (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .in_valid_w             (),
        .in_valid_n             (),
        .acc_done_wrap          (),
        .systolic_finish_wrap   (),

        // -------- West --------
        .w_bank0_din(),
        .w_dout     (),

        // -------- North --------
        .n_bank0_din(),
        .n_dout     (),

        // -------- Global --------
        .internal_rst_n_ctrl     (),
        .internal_reset_acc_ctrl (),
        .out_valid               (),
        .enable_matmul           ()
    );

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
    ) matmul_QKT_V (
        .clk(clk),
        .rst_n(),
        .en(),
        .reset_acc(),
        .input_w(),
        .input_n(),
        .acc_done_wrap(),
        .systolic_finish_wrap(),
        .out_multi_matmul()
    ); */

    // ************************** DELAYER **************************
    // Used as a register: out_b2r_data_reg

    always @(posedge clk) begin
        if (!rst_n) begin
            for (int a = 0; a < TOTAL_INPUT_W_Qn_KnT; a++) begin
                out_b2r_data_reg[a] <= '0;
            end
        end
        else begin
            for (int a = 0; a < TOTAL_INPUT_W_Qn_KnT; a++) begin
                out_b2r_data_reg[a] <= out_b2r_data[a];
            end
        end
    end



endmodule

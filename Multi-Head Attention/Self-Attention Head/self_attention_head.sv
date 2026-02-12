// self_attention_head.sv
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

    // Output
    output logic sys_finish_wrap_Qn_KnT, 
    output logic acc_done_wrap_Qn_KnT,

    output logic out_valid_shifted,
    
    output logic slice_done_b2r_wrap,
    output logic out_ready_b2r_wrap,   // To Controller

    output logic done_softmax [TOTAL_INPUT_W_Qn_KnT][TOTAL_SOFTMAX_ROW],

    // Temporary
    output logic [TILE_SIZE_SOFTMAX*WIDTH_OUT-1:0] out_softmax_data [TOTAL_INPUT_W_Qn_KnT][TOTAL_SOFTMAX_ROW],
    output logic out_softmax_valid [TOTAL_INPUT_W_Qn_KnT][TOTAL_SOFTMAX_ROW]
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
        .acc_done_wrap(sys_finish_wrap_Qn_KnT), 
        .systolic_finish_wrap(acc_done_wrap_Qn_KnT),
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
    //logic [TILE_SIZE_SOFTMAX*WIDTH_OUT-1:0] out_softmax_data [TOTAL_INPUT_W_Qn_KnT][TOTAL_SOFTMAX_ROW];
    //logic out_softmax_valid [TOTAL_INPUT_W_Qn_KnT][TOTAL_SOFTMAX_ROW];

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

    // ************************** DELAYER **************************
    // Used as a register
    logic [(TILE_SIZE_SOFTMAX*WIDTH_OUT)-1:0] out_b2r_data_reg [TOTAL_INPUT_W_Qn_KnT]; // To delay the b2r_data
    
    integer l;

    always @(posedge clk) begin
        if (!rst_n) begin
            for (l = 0; l < TOTAL_INPUT_W_Qn_KnT; l++) begin
                out_b2r_data_reg[l] <= '0;
            end
        end 
        else begin
            for (l = 0; l < TOTAL_INPUT_W_Qn_KnT; l++) begin
                out_b2r_data_reg[l] <= out_b2r_data[l];
            end
        end
    end
    


endmodule
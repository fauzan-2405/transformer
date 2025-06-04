// n2r_to_matmul.v
// Used as a n2r_buffer and top module (with BRAM) wrapper

module n2r_to_matmul #(
    parameter WIDTH = 16,
    parameter FRAC_WIDTH = 8,
    parameter BLOCK_SIZE = 2, 
    parameter CHUNK_SIZE = 4,
    parameter INNER_DIMENSION = 4, 
    parameter W_OUTER_DIMENSION = 6,
    parameter I_OUTER_DIMENSION = 6,
    parameter NUM_CORES = (INNER_DIMENSION == 2754) ? 9 :
                               (INNER_DIMENSION == 256)  ? 8 :
                               (INNER_DIMENSION == 200)  ? 5 :
                               (INNER_DIMENSION == 64)   ? 4 : 2,
    parameter 

) (
    input clk, rst_n, en_buffer,
    input wire [WIDTH*I_OUTER_DIMENSION-1:0] in_n2r_buffer,
    input wire [WIDTH*COL-1:0] wb_n2r_buffer,
    output out_valid, matmul_done
    output reg [(WIDTH*CHUNK_SIZE*NUM_CORES)-1:0] out_matmul, 
);
    // Local Parameters for Top
    localparam ROW_SIZE_MAT_C = I_OUTER_DIMENSION / BLOCK_SIZE;
    localparam COL_SIZE_MAT_C = W_OUTER_DIMENSION / BLOCK_SIZE;
    localparam MAX_FLAG = ROW_SIZE_MAT_C * COL_SIZE_MAT_C / NUM_CORES;
    localparam ADDR_WIDTH_I = clog2((INNER_DIMENSION*I_OUTER_DIMENSION*WIDTH)/(WIDTH*CHUNK_SIZE*NUM_CORES)); // Used for determining the width of wb and input address and other parameters in BRAMs
    localparam ADDR_WIDTH_W = clog2((INNER_DIMENSION*W_OUTER_DIMENSION*WIDTH)/(WIDTH*CHUNK_SIZE));

    // *** Top *******************************************************************
    wire top_start;
    wire top_done;
    wire wb_ena;
    wire [ADDR_WIDTH_W-1:0] wb_addra;
    wire [WIDTH*CHUNK_SIZE-1:0] wb_dina;
    wire [7:0] wb_wea;
    wire in_ena;
    wire [ADDR_WIDTH_I-1:0] in_addra;
    wire [(WIDTH*CHUNK_SIZE*NUM_CORES)-1:0] in_dina;
    wire [7:0] in_wea;

    top_v2 #(
        .WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH), .BLOCK_SIZE(BLOCK_SIZE), .CHUNK_SIZE(CHUNK_SIZE),
        .INNER_DIMENSION(INNER_DIMENSION), .W_OUTER_DIMENSION(W_OUTER_DIMENSION), .I_OUTER_DIMENSION(I_OUTER_DIMENSION), 
        .ROW_SIZE_MAT_C(ROW_SIZE_MAT_C), .COL_SIZE_MAT_C(COL_SIZE_MAT_C), .NUM_CORES(NUM_CORES), .MAX_FLAG(MAX_FLAG),
        .ADDR_WIDTH_I(ADDR_WIDTH_I), .ADDR_WIDTH_W(ADDR_WIDTH_W)
    ) 
    top_inst
    (
        .clk(clk),
        .rst_n(rst_n),
        .start(top_start),
        .done(top_done),

        .wb_ena(wb_ena),
        .wb_addra(wb_addra),
        .wb_dina(wb_dina),
        .wb_wea(wb_wea),

        .in_ena(in_ena),
        .in_addra(in_addra),
        .in_dina(in_dina),
        .in_wea(in_wea),

        .out_bram(out_matmul),
        .top_ready(out_valid)
    );

endmodule
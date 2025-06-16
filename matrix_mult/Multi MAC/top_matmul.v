// top_matmul.v
// Used to wrap io_converter + r2b_converter_b + top_v2

module top_matmul #(
    parameter WIDTH                     = 16,
    parameter FRAC_WIDTH                = 8,
    parameter BLOCK_SIZE                = 2, 
    parameter CHUNK_SIZE                = 4,
    parameter I_OUTER_DIMENSION         = 12, 
    parameter W_OUTER_DIMENSION         = 6,
    parameter INNER_DIMENSION           = 6,
    parameter NUM_CORES = (I_OUTER_DIMENSION == 2754) ? 9 :
                        (I_OUTER_DIMENSION == 256)  ? 8 :
                        (I_OUTER_DIMENSION == 200)  ? 5 :
                        (I_OUTER_DIMENSION == 64)   ? 4 : 2
) (
    input wire clk, rst_n,
    input wire en_top_matmul,
    // *** Port for input_converter ***
    input wire input_i_valid,
    input wire [WIDTH*INNER_DIMENSION-1:0] input_i,
    // *** Port for weight_converter ***
    input wire input_w_valid,
    input wire [WIDTH*W_OUTER_DIMENSION-1:0] input_w,
    // *** Port for output_converter ***
    output wire out_matmul_ready,
    output wire out_matmul_last,
    output wire out_matmul_done,
    output reg  [64*NUM_CORES-1:0] out_matmul_data 
);
    // Local Parameters
    

    io_converter #(
        .WIDTH(WIDTH), FRAC_WIDTH(FRAC_WIDTH), .BLOCK_SIZE(BLOCK_SIZE), .CHUNK_SIZE(CHUNK_SIZE),
        .ROW(I_OUTER_DIMENSION), .COL(INNER_DIMENSION), .NUM_CORES(NUM_CORES)
    ) input_converter (
        .clk(clk), .rst_n(rst_n),
    )
endmodule
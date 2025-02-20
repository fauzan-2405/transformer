// mac.v
// basically systolic array + accumulator

`include "systolic_array_2x2.v"
`include "accumulator.v"

module mac #(
    parameter WIDTH = 16,
    parameter FRAC_WIDTH = 8,
    parameter BLOCK_SIZE = 2, // The size of systolic array dimension (N x N)
    parameter CHUNK_SIZE = 4,
    parameter INNER_DIMENSION = 64 // The same number of rows in one matrix and same number of columns in the other matrix
) (
    input clk, rst_n,
    input [WIDTH-1:0] in_north0, in_north1,
    input [WIDTH-1:0] in_west0, in_west2,
    output reg accumulator_done,
    output reg [WIDTH*CHUNK_SIZE-1:0] out
);
    // Systolic
    wire done_systolic; // output from systolic
    wire [WIDTH*CHUNK_SIZE-1:0] out_systolic;

    systolic_array_2x2 #(.WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH), .CHUNK_SIZE(CHUNK_SIZE)) systolic (
        .clk(clk), .rst_n(rst_n), .in_north0(in_north0), .in_north1(in_north1), .in_west0(in_west0), .in_west2(in_west2), .done(done_systolic), .out(out_systolic)
    );

    accumulator #(.WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH), .BLOCK_SIZE(BLOCK_SIZE), .CHUNK_SIZE(CHUNK_SIZE), .INNER_DIMENSION(INNER_DIMENSION)) acc (
        .clk(clk), .rst_n(rst_n), .in(out_systolic), .systolic_done(done_systolic), .accumulator_done(accumulator_done), .out(out)
    )

endmodule
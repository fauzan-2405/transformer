// mac_v2.v
// basically systolic array + accumulator

//`include "systolic_array_2x2_v2.v"
//`include "accumulator_v2.v"

module mac_v2 #(
    parameter WIDTH_A = 16,
    parameter FRAC_WIDTH_A = 8,
    parameter WIDTH_B = 16,
    parameter FRAC_WIDTH_B = 8,
    parameter WIDTH_OUT = 16,
    parameter FRAC_WIDTH_OUT = 8,
    parameter BLOCK_SIZE = 2, // The size of systolic array dimension (N x N)
    parameter CHUNK_SIZE = 4,
    parameter INNER_DIMENSION = 64 // The same number of rows in one matrix and same number of columns in the other matrix
) (
    input clk, en, rst_n, reset_acc,
    input [WIDTH_B-1:0] in_north0, in_north1,
    input [WIDTH_A-1:0] in_west0, in_west2,
    output wire accumulator_done, systolic_finish,
    output wire [WIDTH_OUT*CHUNK_SIZE-1:0] out_mac
);
    // Systolic
    // wire done_systolic; // output from systolic
    wire [WIDTH_OUT*CHUNK_SIZE-1:0] out_systolic;

    systolic_array_2x2_v2 #(.CHUNK_SIZE(CHUNK_SIZE), .WIDTH_A(WIDTH_A), .FRAC_WIDTH_A(FRAC_WIDTH_A), .WIDTH_B(WIDTH_B), .FRAC_WIDTH_B(FRAC_WIDTH_B), .WIDTH_OUT(WIDTH_OUT), .FRAC_WIDTH_OUT(FRAC_WIDTH_OUT)) 
        systolic (.clk(clk), .en(en), .rst_n(rst_n), .in_north0(in_north0), .in_north1(in_north1), .in_west0(in_west0), .in_west2(in_west2), .done(systolic_finish), .out(out_systolic)
    );

    accumulator_v2 #(.WIDTH_OUT(WIDTH_OUT), .FRAC_WIDTH_OUT(FRAC_WIDTH_OUT), .BLOCK_SIZE(BLOCK_SIZE), .CHUNK_SIZE(CHUNK_SIZE), .INNER_DIMENSION(INNER_DIMENSION)) 
        acc (.clk(clk), .rst_n(reset_acc), .in(out_systolic), .systolic_done(systolic_finish), .accumulator_done(accumulator_done), .out_accum(out_mac)
    );

endmodule
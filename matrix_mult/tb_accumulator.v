`include "accumulator.v"
`timescale 1ns / 1ps

module tb_accumulator;
parameter WIDTH = 16;
parameter FRAC_WIDTH = 8;
parameter BLOCK_SIZE = 2;
parameter INNER_DIMENSION = 64;
parameter CHUNK_SIZE = 4;

reg [WIDTH*CHUNK_SIZE-1:0] test_input;
reg rst_n;
reg clk;
reg systolic_done;
wire accumulator_done;
wire [WIDTH*CHUNK_SIZE-1:0] out;

accumulator #(.WIDTH(WIDTH),. FRAC_WIDTH(FRAC_WIDTH), . BLOCK_SIZE(BLOCK_SIZE), .INNER_DIMENSION(INNER_DIMENSION),.CHUNK_SIZE(CHUNK_SIZE)) acc (
	.clk(clk), .rst_n(rst_n), .in(test_input), .systolic_done(systolic_done), .accumulator_done(accumulator_done), .out(out)
	);
	
initial begin
rst_n <= 0;
systolic_done <= 0;
#10
rst_n <= 1;
test_input <= 'h0100_0200_0300_0400;
#10
test_input <= 'h0100_0100_0100_0100;
#15
test_input <= 'h0000_0000_0000_0000;


end

initial begin
	repeat(133)
		#5 systolic_done <= ~systolic_done;
end


initial begin
	$dumpfile("tb_accumulator.vcd");
	$dumpvars(0, tb_accumulator);
end





endmodule
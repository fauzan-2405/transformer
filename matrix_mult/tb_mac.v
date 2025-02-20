`include "mac.v"
`timescale 1ns/1ps

module tb_mac;
parameter WIDTH = 16;
parameter FRAC_WIDTH = 8;
parameter BLOCK_SIZE = 2;
parameter INNER_DIMENSION = 64;
parameter CHUNK_SIZE = 4;

reg clk;
reg rst_n;
reg reset_acc;
reg [WIDTH-1:0] in_north0, in_north1;
reg [WIDTH-1:0] in_west0, in_west2;
wire accumulator_done, systolic_finish;
wire [WIDTH*CHUNK_SIZE-1:0] out;

mac #(.WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH), .BLOCK_SIZE(BLOCK_SIZE), .INNER_DIMENSION(INNER_DIMENSION), .CHUNK_SIZE(CHUNK_SIZE)) mac_inst (
    .clk(clk), .rst_n(rst_n), .reset_acc(reset_acc), .in_north0(in_north0), .in_north1(in_north1), .in_west0(in_west0), .in_west2(in_west2),
    .accumulator_done(accumulator_done), .systolic_finish(systolic_finish), .out(out)
);

// Behavior
initial begin
    #10 in_north0 = 16'h0200;  
        in_west0 = 16'h0200;
    #10 in_north0 = 16'h0400;  
        in_west0 = 16'h0100;

	//
	#10 in_north0 = 16'h0000;  
        in_west0 = 16'h0000;
end

initial begin
    #10 in_north1 = 16'h0000;  
        in_west2 = 16'h0000;
	//
    #10 in_north1 = 16'h0300;  
        in_west2 = 16'h0400;
    #10 in_north1 = 16'h0100;  
        in_west2 = 16'h0300;
end

always @(posedge systolic_finish) begin
	#10 reset_acc <=1;
end


// Initial block to apply test cases
initial begin
    // Initialize signals
    clk = 0;
    rst_n = 0;
	reset_acc = 0;
    in_north0 = 0;
    in_north1 = 0;
    in_west0 = 0;
    in_west2 = 0;

    // Apply reset
    #10 rst_n = 1;  // Release reset after 10 ns
end

initial begin
	repeat(500)
		#5 clk <= ~clk;
end

initial begin
	$dumpfile("tb_mac.vcd");
	$dumpvars(0, tb_mac);
end

endmodule
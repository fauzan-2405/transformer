`include "systolic_array_2x2.v"
`timescale 1ns / 1ps

/*
We're gonna do multiplication for this simple matrix:
[ 1 2    times by 	[ 4 1   And the result:   [ 8 7
  3 4 ]               2 3 ] 					20 15]
*/
module tb_systolic_array_2x2;

// Parameters for the systolic array
parameter WIDTH = 16;
parameter FRAC_WIDTH = 8;

// Inputs to the systolic array
reg clk;
reg rst_n;
reg [WIDTH-1:0] in_north0, in_north1;
reg [WIDTH-1:0] in_west0, in_west2;

// Outputs from the systolic array
wire done;
wire [WIDTH*4-1:0] out;

// Instantiate the systolic array (Device Under Test)
systolic_array_2x2 #(
    .WIDTH(WIDTH),
    .FRAC_WIDTH(FRAC_WIDTH)
) uut (
    .clk(clk),
    .rst_n(rst_n),
    .in_north0(in_north0),
    .in_north1(in_north1),
    .in_west0(in_west0),
    .in_west2(in_west2),
    .done(done),
    .out(out)
);


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


// Initial block to apply test cases
initial begin
    // Initialize signals
    clk = 0;
    rst_n = 0;
    in_north0 = 0;
    in_north1 = 0;
    in_west0 = 0;
    in_west2 = 0;

    // Apply reset
    #10 rst_n = 1;  // Release reset after 10 ns
end

// Clock generation
initial begin
	repeat(50)
		#5 clk <= ~clk;
end

// Dumping to see the waveform file
initial begin
    // Set up VCD dump file
    $dumpfile("tb_systolic_array_2x2.vcd");  // VCD output file
    $dumpvars(0, tb_systolic_array_2x2);      // Dump all variables in the testbench
end

endmodule

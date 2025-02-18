`timescale 1ns / 1ps

/*
We're gonna do multiplication for this simple matrix:
[ 2 1 2 1    times by 	[ 0 1 4 3    And the result:   [ 8 10 13 10
  0 1 0 1                 3 0 1 0 						 6  0  3  0
  1 2 0 1				  1 4 1 2						 9  1  8  3
  1 1 1 0 ]				  3 0 2 0 ]						 4  5  6  5 ]
*/
module tb_systolic_array_4x4;

// Parameters for the systolic array
parameter WIDTH = 16;
parameter FRAC_WIDTH = 8;

// Inputs to the systolic array
reg clk;
reg rst_n;
reg [WIDTH-1:0] in_north0, in_north1, in_north2, in_north3;
reg [WIDTH-1:0] in_west0, in_west4, in_west8, in_west12;

// Outputs from the systolic array
wire done;
wire [WIDTH*WIDTH-1:0] out;

// Instantiate the systolic array (Device Under Test)
systolic_array #(
    .WIDTH(WIDTH),
    .FRAC_WIDTH(FRAC_WIDTH)
) uut (
    .clk(clk),
    .rst_n(rst_n),
    .in_north0(in_north0),
    .in_north1(in_north1),
    .in_north2(in_north2),
    .in_north3(in_north3),
    .in_west0(in_west0),
    .in_west4(in_west4),
    .in_west8(in_west8),
    .in_west12(in_west12),
    .done(done),
    .out(out)
);


initial begin
    #10 in_north0 = 16'h0300;  
        in_west0 = 16'h0100;
    #10 in_north0 = 16'h0100;  
        in_west0 = 16'h0200;
    #10 in_north0 = 16'h0300;  
        in_west0 = 16'h0100;
    #10 in_north0 = 16'h0000;  
        in_west0 = 16'h0200;
	//
	#10 in_north0 = 16'h0000;  
        in_west0 = 16'h0000;
	#10 in_north0 = 16'h0000;  
        in_west0 = 16'h0000;
	#10 in_north0 = 16'h0000;  
        in_west0 = 16'h0000;
end

initial begin
    #10 in_north1 = 16'h0000;  
        in_west4 = 16'h0000;
	//
    #10 in_north1 = 16'h0000;  
        in_west4 = 16'h0100;
    #10 in_north1 = 16'h0400;  
        in_west4 = 16'h0000;
    #10 in_north1 = 16'h0000;  
        in_west4 = 16'h0100;
	#10 in_north1 = 16'h0100;  
        in_west4 = 16'h0000;
	//
	#10 in_north1 = 16'h0000;  
        in_west4 = 16'h0000;
	#10 in_north1 = 16'h0000;  
        in_west4 = 16'h0000;
end

initial begin
    #10 in_north2 = 16'h0000;  
        in_west8 = 16'h0000;
    #10 in_north2 = 16'h0000;  
        in_west8 = 16'h0000;
		//
    #10 in_north2 = 16'h0200;  
        in_west8 = 16'h0100;
    #10 in_north2 = 16'h0100;  
        in_west8 = 16'h0000;
	#10 in_north2 = 16'h0100;  
        in_west8 = 16'h0200;
	#10 in_north2 = 16'h0400;  
        in_west8 = 16'h0100;
	//
	#10 in_north2 = 16'h0000;  
        in_west8 = 16'h0000;
end

initial begin
    #10 in_north3 = 16'h0000;  
        in_west12 = 16'h0000;
    #10 in_north3 = 16'h0000;  
        in_west12 = 16'h0000;
    #10 in_north3 = 16'h0000;  
        in_west12 = 16'h0000;
	//
    #10 in_north3 = 16'h0000;  
        in_west12 = 16'h0000;
	#10 in_north3 = 16'h0200;  
        in_west12 = 16'h0100;
	#10 in_north3 = 16'h0000;  
        in_west12 = 16'h0100;
	#10 in_north3 = 16'h0300;  
        in_west12 = 16'h0100;
end

// Initial block to apply test cases
initial begin
    // Initialize signals
    clk = 0;
    rst_n = 0;
    in_north0 = 0;
    in_north1 = 0;
    in_north2 = 0;
    in_north3 = 0;
    in_west0 = 0;
    in_west4 = 0;
    in_west8 = 0;
    in_west12 = 0;

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
    $dumpfile("tb_systolic_array_4x4.vcd");  // VCD output file
    $dumpvars(0, tb_systolic_array_4x4);      // Dump all variables in the testbench
end

endmodule

`timescale 1ns / 1ps
`include "control_mux.v"
`include "mux4_1.v"

/*
We're gonna test this matrix
[ 2 1 2 1 
  0 1 0 1           
  1 2 0 1				
  1 1 1 0 ]				  
*/

module tb_control_mux;
parameter WIDTH = 16;

// Input for mux & controller module
reg clk, rst_n;
reg [WIDTH-1:0] input_00, input_01, input_02, input_03;
reg [WIDTH-1:0] input_10, input_11, input_12, input_13;
reg [WIDTH-1:0] input_20, input_21, input_22, input_23;
reg [WIDTH-1:0] input_30, input_31, input_32, input_33;

reg [3:0] select;

// Output for mux & controller module
wire [WIDTH-1:0] out0, out1, out2, out3;
wire [3:0] mux_reset;

// Mux inst
mux4_1 #(.WIDTH(WIDTH)) mux_inst0 (.clk(clk), .rst_n(rst_n), .input_0(input_00), .input_1(input_01), .input_2(input_02), .input_3(input_03), .out(out0));
mux4_1 #(.WIDTH(WIDTH)) mux_inst1 (.clk(clk), .rst_n(rst_n), .input_0(input_10), .input_1(input_11), .input_2(input_12), .input_3(input_13), .out(out1));
mux4_1 #(.WIDTH(WIDTH)) mux_inst2 (.clk(clk), .rst_n(rst_n), .input_0(input_20), .input_1(input_21), .input_2(input_22), .input_3(input_23), .out(out2));
mux4_1 #(.WIDTH(WIDTH)) mux_inst3 (.clk(clk), .rst_n(rst_n), .input_0(input_30), .input_1(input_31), .input_2(input_32), .input_3(input_33), .out(out3));

initial begin
    rst_n <= 0;
    clk <= 0;
    #10;
    rst_n <=1;
    #50;
end


// Clock generation
initial begin
	repeat(50)
		#5 clk <= ~clk;
end

// Behavior
initial begin
	#10 input_00 = 16'h0200;
		input_01 = 16'h0100;
		input_02 = 16'h0200;
		input_03 = 16'h0100;
end

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


// Dumping to see the waveform file
initial begin
    // Set up VCD dump file
    $dumpfile("tb_control_mux.vcd");  // VCD output file
    $dumpvars(0, tb_control_mux);      // Dump all variables in the testbench
end


endmodule
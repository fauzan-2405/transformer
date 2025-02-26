`timescale 1ns / 1ps
`include "control_mux2_1.v"
`include "mux2_1.v"

/*
We're gonna test this matrix
[ 4 1
  2 3 ]		  
*/

module tb_control_mux2_1;
parameter WIDTH = 16;

// Input for mux & controller module
reg clk, rst_n;
reg [WIDTH-1:0] input_00, input_01;
reg [WIDTH-1:0] input_10, input_11;

// Output for mux & controller module
wire [WIDTH-1:0] out0, out1;
wire [1:0] mux_reset;

// Control Unit
control_mux2_1 cu_inst (.clk(clk), .rst_n(rst_n), .mux_reset(mux_reset)); 

// Mux inst
mux2_1 #(.WIDTH(WIDTH)) mux_inst0 (.clk(clk), .rst_n(mux_reset[1]), .input_0(input_00), .input_1(input_01), .out(out0));
mux2_1 #(.WIDTH(WIDTH)) mux_inst1 (.clk(clk), .rst_n(mux_reset[0]), .input_0(input_10), .input_1(input_11), .out(out1));

initial begin
    rst_n <= 0;
    clk <= 0;
	#5
	input_00 = 0;
	input_01 = 0;
    input_10 = 0;
    input_11 = 0;
	rst_n <=1;
end


// Clock generation
initial begin
	repeat(50)
		#5 clk <= ~clk;
end

// Behavior
initial begin
	#10 input_00 = 16'h0400;
		input_01 = 16'h0100;
		
		input_10 = 16'h0200;
		input_11 = 16'h0300;
end


// Dumping to see the waveform file
initial begin
    // Set up VCD dump file
    $dumpfile("tb_control_mux2_1.vcd");  // VCD output file
    $dumpvars(0, tb_control_mux2_1);      // Dump all variables in the testbench
end


endmodule
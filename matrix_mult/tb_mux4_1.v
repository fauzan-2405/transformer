`timescale 1ns / 1ps

module tb_mux4_1;
parameter WIDTH = 16;

// Input for mux module
reg clk;
reg rst_n;
reg [WIDTH-1:0] input_0, input_1, input_2, input_3;

reg [3:0] select;

// Output for mux module
wire [WIDTH-1:0] out;

mux4_1 #(.WIDTH(WIDTH)) mux_inst (.clk(clk), .rst_n(rst_n), .input_0(input_0), .input_1(input_1), .input_2(input_2), .input_3(input_3), .out(out));

// Clock generation
initial begin
	repeat(50)
		#5 clk <= ~clk;
end

// Initial block to apply test cases
initial begin
    // Initialize signals
    clk = 0;
    rst_n = 0;

end

// Behavior
initial begin
	#10 rst_n = 1;
		input_0 = 16'h0400;
		input_1 = 16'h0300;
		input_2 = 16'h0200;
		input_3 = 16'h0100;
end


// Dumping to see the waveform file
initial begin
    // Set up VCD dump file
    $dumpfile("tb_mux4_1.vcd");  // VCD output file
    $dumpvars(0, tb_mux4_1);      // Dump all variables in the testbench
end


endmodule

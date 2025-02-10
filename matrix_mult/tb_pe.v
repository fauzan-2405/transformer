`timescale 1ns / 1ps

module tb_pe;

// Parameters for the PE module
parameter WIDTH = 16;
parameter FRAC_WIDTH = 8;

// Inputs to the PE module
reg clk;
reg rst_n;
reg [WIDTH-1:0] in_north;
reg [WIDTH-1:0] in_west;

// Outputs from the PE module
wire [WIDTH-1:0] out_south;
wire [WIDTH-1:0] out_east;
wire [WIDTH-1:0] result;

// Instantiate the PE module (Device Under Test)
pe #(
    .WIDTH(WIDTH),
    .FRAC_WIDTH(FRAC_WIDTH)
) pe_inst (
    .clk(clk),
    .rst_n(rst_n),
    .in_north(in_north),
    .in_west(in_west),
    .out_south(out_south),
    .out_east(out_east),
    .result(result)
);

// Clock generation
always begin
    #5 clk = ~clk;  // Clock period of 10 ns
end

// Initial block to apply test cases
initial begin
    // Initialize signals
    clk = 0;
    rst_n = 0;
    in_north = 0;
    in_west = 0;
	
	// Set up VCD dump file
    $dumpfile("tb_pe.vcd");  // VCD output file
    $dumpvars(0, tb_pe);      // Dump all variables in the testbench

    // Apply reset
    #10 rst_n = 1;  // Release reset after 10 ns

    // Test case 1: Apply some values to the inputs
    #10 in_north = 16'h0300;  // Example input for in_north
        in_west = 16'h0400;   // Example input for in_west
    #10;
	
	/*
    // Test case 2: Apply different inputs
    #10 in_north = 16'h0005;
        in_west = 16'h0002;
    #10;

    // Test case 3: Apply zero inputs
    #10 in_north = 16'h0000;
        in_west = 16'h0000;
    #10;

    // Test case 4: Apply negative numbers (sign extension for 16-bit)
    #10 in_north = 16'hFFFD;  // Negative number (2's complement)
        in_west = 16'hFFFB;   // Negative number (2's complement)
    #10;

    // Finish simulation after a few clock cycles
    #10 $finish;
	*/
end

// Monitor the signals to observe output
initial begin
    $monitor("At time %t: in_north = %h, in_west = %h, out_south = %h, out_east = %h, result = %h",
             $time, in_north, in_west, out_south, out_east, result);
end

endmodule

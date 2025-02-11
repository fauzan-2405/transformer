`timescale 1ns / 1ps

module tb_systolic_array;

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

// Clock generation
always begin
    #5 clk = ~clk;  // Clock period of 10 ns
end

// Initial block to apply test cases
initial begin
    // Set up VCD dump file
    $dumpfile("tb_systolic_array.vcd");  // VCD output file
    $dumpvars(0, tb_systolic_array);      // Dump all variables in the testbench

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

    // Test case 1: Apply some values to the inputs
    #10 in_north0 = 16'h0300;  // Example input for in_north0
        in_north1 = 16'h0400;
        in_north2 = 16'h0500;
        in_north3 = 16'h0600;
        in_west0 = 16'h0700;
        in_west4 = 16'h0800;
        in_west8 = 16'h0900;
        in_west12 = 16'h0A00;
    #10;

    /*
    // Test case 2: Apply different values to the inputs
    #10 in_north0 = 16'h0011;
        in_north1 = 16'h0012;
        in_north2 = 16'h0013;
        in_north3 = 16'h0014;
        in_west0 = 16'h0015;
        in_west4 = 16'h0016;
        in_west8 = 16'h0017;
        in_west12 = 16'h0018;
    #10;

    // Test case 3: Apply zero inputs
    #10 in_north0 = 16'h0000;
        in_north1 = 16'h0000;
        in_north2 = 16'h0000;
        in_north3 = 16'h0000;
        in_west0 = 16'h0000;
        in_west4 = 16'h0000;
        in_west8 = 16'h0000;
        in_west12 = 16'h0000;
    #10;

    // Test case 4: Apply some negative numbers (sign extension for 16-bit)
    #10 in_north0 = 16'hFFFD;  // Negative number (2's complement)
        in_north1 = 16'hFFFB;
        in_north2 = 16'hFFF8;
        in_north3 = 16'hFFF5;
        in_west0 = 16'hFFF4;
        in_west4 = 16'hFFF3;
        in_west8 = 16'hFFF2;
        in_west12 = 16'hFFF1;
    #10;
    

    // Finish simulation after a few clock cycles
    #10 $finish;
    */
end

// Monitor the signals to observe output
initial begin
    $monitor("At time %t: in_north0 = %h, in_north1 = %h, in_north2 = %h, in_north3 = %h, in_west0 = %h, in_west4 = %h, in_west8 = %h, in_west12 = %h, done = %b, out = %h",
             $time, in_north0, in_north1, in_north2, in_north3, in_west0, in_west4, in_west8, in_west12, done, out);
end

endmodule

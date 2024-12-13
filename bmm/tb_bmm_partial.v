`timescale 1ns / 1ps
`include "bmm_partial.v"

module tb_bmm_partial;

    // Parameters
    parameter BLOCK_SIZE = 2; // Adjust as needed
    parameter DATA_WIDTH = 4; // Adjust as needed
    parameter SIZE = 4; // Adjust as needed

    // Inputs
    reg clk;
    reg rst;
    reg [BLOCK_SIZE*SIZE*DATA_WIDTH-1:0] A_rows;
    reg [BLOCK_SIZE*SIZE*DATA_WIDTH-1:0] B_cols;
    reg valid_in;

    // Outputs
    wire valid_out;
    wire [BLOCK_SIZE*BLOCK_SIZE*DATA_WIDTH-1:0] AB_partial;

    // Instantiate the bmm_partial module
    bmm_partial #(
        .BLOCK_SIZE(BLOCK_SIZE),
        .DATA_WIDTH(DATA_WIDTH),
        .SIZE(SIZE)
    ) uut (
        .clk(clk),
        .rst(rst),
        .A_rows(A_rows),
        .B_cols(B_cols),
        .valid_in(valid_in),
        .valid_out(valid_out),
        .AB_partial(AB_partial)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10 ns clock period
    end

    // Test sequence
    initial begin
		$dumpfile("tb_bmm_partial.vcd");
        $dumpvars(0, tb_bmm_partial);

        // Initialize inputs
        rst = 1;
        valid_in = 0;
        A_rows = 0;
        B_cols = 0;

        // Wait for a few clock cycles
        #10;
        
        // Release reset
        rst = 0;
        #10;

        // Set A_rows and B_cols
        A_rows = 32'h11110101; // Example input for A
        B_cols = 32'h10111010; // Example input for B
        valid_in = 1; // Indicate valid input

        // Wait for a clock cycle
        #10;

        // Deactivate valid input
        valid_in = 0;

        // Wait for a few clock cycles to observe output
        #50;

        // Finish simulation
        $finish;
    end

    // Monitor outputs
    initial begin
        $monitor("Time: %0t | valid_out: %b | AB_partial: %h", $time, valid_out, AB_partial);
    end

endmodule

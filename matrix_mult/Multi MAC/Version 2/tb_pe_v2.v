`timescale 1ns/1ps

module tb_pe_v2;

    // Parameters for this test case
    parameter WIDTH_A = 8;
    parameter FRAC_WIDTH_A = 4;

    parameter WIDTH_B = 16;
    parameter FRAC_WIDTH_B = 8;

    parameter WIDTH_OUT = 20;
    parameter FRAC_WIDTH_OUT = 8;

    // DUT inputs and outputs
    reg clk = 0, rst_n = 0;
    reg [WIDTH_A-1:0] in_west;
    reg [WIDTH_B-1:0] in_north;
    wire [WIDTH_A-1:0] out_east;
    wire [WIDTH_B-1:0] out_south;
    wire [WIDTH_OUT-1:0] result;

    // Clock generator
    always #5 clk = ~clk;

    // Instantiate the DUT
    pe_v2 #(
        .WIDTH_A(WIDTH_A),
        .FRAC_WIDTH_A(FRAC_WIDTH_A),
        .WIDTH_B(WIDTH_B),
        .FRAC_WIDTH_B(FRAC_WIDTH_B),
        .WIDTH_OUT(WIDTH_OUT),
        .FRAC_WIDTH_OUT(FRAC_WIDTH_OUT)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .in_west(in_west),
        .in_north(in_north),
        .out_east(out_east),
        .out_south(out_south),
        .result(result)
    );

    // Helper to convert real to fixed-point
    function [31:0] to_fixed;
        input real value;
        input integer WIDTH;
        input integer FRAC;
        begin
            to_fixed = $rtoi(value * (1 << FRAC));
        end
    endfunction

    // Test sequence
    initial begin
        $display("Starting PE testbench...");
        //$dumpfile("tb_pe.vcd");
        //$dumpvars(0, tb_pe);

        // Reset
        rst_n = 0;
        #15;
        rst_n = 1;
        #20;

        // Scenario 1: Simple multiply-accumulate (Q4.4 × Q8.8)
        apply_inputs(1.5, 2.0);     // 1.5 * 2.0 = 3.0
        #10;

        apply_inputs(1.0, -3.0);    // 1.0 * -3.0 = -3.0 → Accumulate → 0.0
        #10;

        // Scenario 2: Saturation test (high values)
        apply_inputs(10.0, 12.0);   // 10 * 12 = 120 → Should saturate
        #10;

        // Scenario 3: Negative overflow
        apply_inputs(-15.0, 10.0);  // -150 → saturation negative
        #10;

        // Scenario 4: Tiny values (underflow testing)
        apply_inputs(0.015625, 0.015625); // Smallest positive for Q4.4 and Q8.8
        #10;

        // Scenario 5: Back to normal range
        apply_inputs(2.25, 2.5);    // 5.625 → Should accumulate correctly
        #10;

        $display("Testbench completed.");
        //$finish;
    end

    // Procedure to apply test inputs
    task apply_inputs(input real a, input real b);
        begin
            in_west  = to_fixed(a, WIDTH_A, FRAC_WIDTH_A);
            in_north = to_fixed(b, WIDTH_B, FRAC_WIDTH_B);
            $display("Time %t | in_west = %f, in_north = %f => result = %0d", $time, a, b, result);
        end
    endtask

endmodule

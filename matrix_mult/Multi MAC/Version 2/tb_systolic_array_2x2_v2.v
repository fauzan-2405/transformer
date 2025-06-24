`timescale 1ns / 1ps

module tb_systolic_array_2x2_v2;

    // Parameters (customize for precision)
    parameter WIDTH_A = 8;
    parameter FRAC_WIDTH_A = 4;

    parameter WIDTH_B = 8;
    parameter FRAC_WIDTH_B = 4;

    parameter WIDTH_OUT = 16;
    parameter FRAC_WIDTH_OUT = 4;

    // DUT I/O
    reg clk = 0;
    reg en = 0;
    reg rst_n = 0;

    reg [WIDTH_B-1:0] in_north0, in_north1;
    reg [WIDTH_A-1:0] in_west0, in_west2;

    wire done;
    wire [WIDTH_OUT*4-1:0] out;

    // Instantiate DUT
    systolic_array_2x2_v2 #(
        .WIDTH_A(WIDTH_A), .FRAC_WIDTH_A(FRAC_WIDTH_A),
        .WIDTH_B(WIDTH_B), .FRAC_WIDTH_B(FRAC_WIDTH_B),
        .WIDTH_OUT(WIDTH_OUT), .FRAC_WIDTH_OUT(FRAC_WIDTH_OUT)
    ) dut (
        .clk(clk), .en(en), .rst_n(rst_n),
        .in_north0(in_north0), .in_north1(in_north1),
        .in_west0(in_west0), .in_west2(in_west2),
        .done(done), .out(out)
    );

    // Clock generation
    always #5 clk = ~clk;

    // Realtime variables for test vectors
    realtime A00, A01, A10, A11;
    realtime B00, B01, B10, B11;
    realtime E00, E01, E10, E11;

    // Convert real to fixed-point
    function [31:0] to_fixed;
        input real val;
        input integer frac_bits;
        begin
            to_fixed = $rtoi(val * (1 << frac_bits));
        end
    endfunction

    // Convert fixed-point back to real
    function real to_real;
        input integer val;
        input integer frac_bits;
        begin
            to_real = val * 1.0 / (1 << frac_bits);
        end
    endfunction

    initial begin
        $display("==== Starting Systolic Array 2x2 Test ====");
        //$dumpfile("tb_systolic_array_2x2_v2.vcd");
        //$dumpvars(0, tb_systolic_array_2x2_v2);

        // Define Matrix A
        A00 = 1.0; A01 = 2.0;
        A10 = 3.0; A11 = 4.0;

        // Define Matrix B
        B00 = 4.0; B01 = 1.0;
        B10 = 2.0; B11 = 3.0;

        // Expected Output
        E00 = 1*4 + 2*2;   // 8
        E01 = 1*1 + 2*3;   // 7
        E10 = 3*4 + 4*2;   // 20
        E11 = 3*1 + 4*3;   // 15

        // Reset
        rst_n = 0; #25;
        rst_n = 1;
        en = 1;

        // Feed matrix data into systolic array (2 cycles)
        in_west0  = to_fixed(A00, FRAC_WIDTH_A);  // PE0
        in_north0 = to_fixed(B00, FRAC_WIDTH_B);  // PE0
        in_west2  = to_fixed(A10, FRAC_WIDTH_A);  // PE2
        in_north1 = to_fixed(B01, FRAC_WIDTH_B);  // PE1
        #10;

        in_west0  = to_fixed(A01, FRAC_WIDTH_A);  // PE0
        in_north0 = to_fixed(B10, FRAC_WIDTH_B);  // PE0
        in_west2  = to_fixed(A11, FRAC_WIDTH_A);  // PE2
        in_north1 = to_fixed(B11, FRAC_WIDTH_B);  // PE1
        #10;

        // Remaining cycles for data to flow through
        repeat (3) begin
            in_west0 = 0;
            in_north0 = 0;
            in_west2 = 0;
            in_north1 = 0;
            #10;
        end

        // Wait for done signal
        wait(done == 1);
        #10;

        // Output Verification
        /*
        $display("==== Output Results ====");
        integer i;
        integer raw;
        real result_val;
        realtime expected_val;

        for (i = 0; i < 4; i = i + 1) begin
            raw = out >> (i * WIDTH_OUT);
            case (i)
                0: expected_val = E00;
                1: expected_val = E01;
                2: expected_val = E10;
                3: expected_val = E11;
            endcase
            result_val = to_real(raw[WIDTH_OUT-1:0], FRAC_WIDTH_OUT);
            $display("Result[%0d] = %f, Expected = %f", i, result_val, expected_val);
        end
        */
        $display("==== Test Done ====");
        //$finish;
    end

endmodule

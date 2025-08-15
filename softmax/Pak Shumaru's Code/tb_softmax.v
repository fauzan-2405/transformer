`timescale 1ns/1ps

module tb_softmax;
    localparam WIDTH      = 32;
    localparam FRAC_WIDTH = 16;

    reg clk;
    reg rst_n;
    reg start;
    reg signed [WIDTH-1:0] X1, X2, X3, X4;
    wire signed [WIDTH-1:0] Y1, Y2, Y3, Y4;
    wire done_out;

    // DUT instance
    softmax #(
        .WIDTH(WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH),
        .TOTAL_ELEMEN(4)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .X1(X1), .X2(X2), .X3(X3), .X4(X4),
        .Y1(Y1), .Y2(Y2), .Y3(Y3), .Y4(Y4),
        .done_out(done_out)
    );

    // Clock generator
    always #5 clk = ~clk;

    // Fixed-point to real conversion
    function real q16_16_to_real(input signed [WIDTH-1:0] val);
        begin
            q16_16_to_real = val / (1 << FRAC_WIDTH);
        end
    endfunction

    // Real to Q16.16 conversion
    function signed [WIDTH-1:0] real_to_q16_16(input real val);
        begin
            real_to_q16_16 = $rtoi(val * (1 << FRAC_WIDTH));
        end
    endfunction

    initial begin
        clk = 0;
        rst_n = 0;
        start = 0;
        X1 = 0; X2 = 0; X3 = 0; X4 = 0;
        #25;
        rst_n = 1;
        #10;

        // === Test vector ===
        // Example: 1.0, 2.0, 3.0, 4.0 (float)
        X1 = real_to_q16_16(1.0);
        X2 = real_to_q16_16(2.0);
        X3 = real_to_q16_16(3.0);
        X4 = real_to_q16_16(4.0);

        start = 1;
        #10;
        start = 0;

        // Wait for done
        wait(done_out);
        #10;

        // Display results
        /*
        $display("Softmax Results (Q16.16 -> float):");
        $display("Y1 = %f", q16_16_to_real(Y1));
        $display("Y2 = %f", q16_16_to_real(Y2));
        $display("Y3 = %f", q16_16_to_real(Y3));
        $display("Y4 = %f", q16_16_to_real(Y4));

        // Compare with reference softmax
        real x1_r, x2_r, x3_r, x4_r;
        real e1, e2, e3, e4, sum_e;
        real ref1, ref2, ref3, ref4;

        x1_r = 1.0; x2_r = 2.0; x3_r = 3.0; x4_r = 4.0;
        e1 = $exp(x1_r); e2 = $exp(x2_r); e3 = $exp(x3_r); e4 = $exp(x4_r);
        sum_e = e1 + e2 + e3 + e4;
        ref1 = e1 / sum_e;
        ref2 = e2 / sum_e;
        ref3 = e3 / sum_e;
        ref4 = e4 / sum_e;

        $display("Reference:");
        $display("Ref1 = %f", ref1);
        $display("Ref2 = %f", ref2);
        $display("Ref3 = %f", ref3);
        $display("Ref4 = %f", ref4);

        // Error
        $display("Error:");
        $display("E1 = %f", q16_16_to_real(Y1) - ref1);
        $display("E2 = %f", q16_16_to_real(Y2) - ref2);
        $display("E3 = %f", q16_16_to_real(Y3) - ref3);
        $display("E4 = %f", q16_16_to_real(Y4) - ref4);

        $stop;
        */
    end
endmodule

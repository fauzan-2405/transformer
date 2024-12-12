`timescale 1ns / 1ps

module tb_matrix_fill;

    reg [31:0] A_rows; // 32-bit input value
    reg [31:0] B_cols; // 32-bit input value
    wire [3:0] B [0:3][0:1]; // 4 rows and 2 columns (4x2 matrix)
    wire [3:0] A [0:1][0:3]; // 2 rows and 4 columns (2x4 matrix)

    // Instantiate the matrix_fill module
    matrix_fill #(
        .BLOCK_SIZE(2),
        .SIZE(4),
        .DATA_WIDTH(4)
    ) uut (
        .A_rows(A_rows), // Connect the input A_rows
        .B_cols(B_cols), // Connect the input B_cols
        .B(B), // Connect the output B matrix
        .A(A) // Connect the output A matrix
    );

    initial begin
        // Open a VCD file for GTKWave
        $dumpfile("tb_matrix_fill.vcd");
        $dumpvars(0, tb_matrix_fill);

        // Set the input values
        A_rows = 32'h11110101; // Example 32-bit hex value
        B_cols = 32'h10111010; // Example 32-bit hex value

        // Wait for some time to allow the always block in the module to execute
        #10;

        // Display the output matrices
        $display("Output Matrix A:");
        $display("A[0][0] = %d", A[0][0]);
        $display("A[0][1] = %d", A[0][1]);
        $display("A[0][2] = %d", A[0][2]);
        $display("A[0][3] = %d", A[0][3]);
        $display("A[1][0] = %d", A[1][0]);
        $display("A[1][1] = %d", A[1][1]);
        $display("A[1][2] = %d", A[1][2]);
        $display("A[1][3] = %d", A[1][3]);

        $display("Output Matrix B:");
        $display("B[0][0] = %d", B[0][0]);
        $display("B[0][1] = %d", B[0][1]);
        $display("B[1][0] = %d", B[1][0]);
        $display("B[1][1] = %d", B[1][1]);
        $display("B[2][0] = %d", B[2][0]);
        $display("B[2][1] = %d", B[2][1]);
        $display("B[3][0] = %d", B[3][0]);
        $display("B[3][1] = %d", B[3][1]);
    end
endmodule

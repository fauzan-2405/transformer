`timescale 1ns / 1ps

module tb_matrix_fill;

    reg [31:0] A_rows; // Declare the input for the matrix_fill module
    wire [3:0] A [0:1][0:3]; // Declare the output matrix

    // Instantiate the matrix_fill module
    matrix_fill uut (
        .A_rows(A_rows), // Connect the input A_rows
        .A(A)            // Connect the output matrix A
    );

    initial begin
        // Open a VCD file for GTKWave
        $dumpfile("matrix_fill_tb.vcd");
        $dumpvars(0, tb_matrix_fill);

        // Set the input value
        A_rows = 32'h01011101; // Example 32-bit hex value

        // Wait for some time to allow the always block in the module to execute
        #10;

        // Display the output matrix A
        $display("Output Matrix A:");
        $display("A[0][0] = %b", A[0][0]);
        $display("A[0][1] = %b", A[0][1]);
        $display("A[0][2] = %b", A[0][2]);
        $display("A[0][3] = %b", A[0][3]);
        $display("A[1][0] = %b", A[1][0]);
        $display("A[1][1] = %b", A[1][1]);
        $display("A[1][2] = %b", A[1][2]);
        $display("A[1][3] = %b", A[1][3]);

        // End the simulation
        $finish;
    end

endmodule

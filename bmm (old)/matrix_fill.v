///////////////////////////////
// Module	: Matrix Fill
// Instance	: matrix_fill
// Engineer	: Fauzan
///////////////////////////////

module matrix_fill #(
	parameter BLOCK_SIZE = 2,
	parameter SIZE		 = 4,
	parameter DATA_WIDTH = 4
)
(
    input [31:0] A_rows,
	input [31:0] B_cols,
    output reg [3:0] B [0:SIZE-1][0:BLOCK_SIZE-1], // 4 rows and 2 columns (4x2 matrix)
	output reg [3:0] A [0:BLOCK_SIZE-1][0:SIZE-1]//  2 rows and 4 columns (2x4 matrix)
);
	/*
	parameter BLOCK_SIZE = 2;
	parameter SIZE		 = 4;
	parameter DATA_WIDTH = 4; */

    integer i, j;

    always @(*) begin
        // Fill the output matrix A & B based on the input A_rows and B_cols
        for (i = 0; i < BLOCK_SIZE; i = i + 1) begin
            for (j = 0; j < SIZE; j = j + 1) begin
                // Extract 4 bits from A_rows and assign to A
                A[i][j] = A_rows[(i * SIZE + j) * DATA_WIDTH +: DATA_WIDTH]; // Extract 4 bits
                // Extract 4 bits from B_cols and assign to B
                B[j][i] = B_cols[(j * BLOCK_SIZE + i) * DATA_WIDTH +: DATA_WIDTH]; // Extract 4 bits
            end
        end
    end
endmodule

///////////////////////////////
// Module	: Matrix Fill
// Instance	: matrix_fill
// Engineer	: Fauzan
///////////////////////////////

module matrix_fill(
    input [31:0] A_rows,
    output reg [3:0] A [0:1][0:3] // 2 rows and 4 columns (2x4 matrix)
);

    integer i, j;

    always @(*) begin
        // Fill the output matrix A based on the input A_rows
        for (i = 0; i < 2; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                // Extract 4 bits from A_rows and assign to A
                A[i][j] = A_rows[(i * 4 + j) * 4 +: 4]; // Extract 4 bits
            end
        end
    end
endmodule

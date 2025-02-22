// RAM2_input.v
// Used to simulate the RAM if the matrix is same (MXN by NxM) we will simulate 6x4 4x6

module RAM2_input #(
    parameter WIDTH = 16,
    parameter CHUNK_SIZE = 4,
    parameter INNER_DIMENSION = 4, // The same number of rows in one matrix and same number of columns in the other matrix
    parameter OUTER_DIMENSION = 6 // The size of rows/cols of the matrix outside of inner dimension
) (
    input clk,
    input [WIDTH-1:0] counter_A,
    input [WIDTH-1:0] counter_B,
    output reg [(WIDTH*CHUNK_SIZE)-1:0] output1,
    output reg [(WIDTH*CHUNK_SIZE)-1:0] output2
);
    // (INNER DIMENSION / CHUNK SIZE) x OUTER DIMENSION
    // For 6x4 by 4x6 -> (4/4)x6=6
    reg [WIDTH-1:0] mem_array_A [((INNER_DIMENSION/CHUNK_SIZE)*OUTER_DIMENSION)-1:0];
    reg [WIDTH-1:0] mem_array_B [((INNER_DIMENSION/CHUNK_SIZE)*OUTER_DIMENSION)-1:0];
    
    initial begin
        $readmemh("A.txt", mem_array_A);
        $readmemh("B.txt", mem_array_B);
    end

    always @(posedge clk) begin
        output1 <= mem_array_A[counter_A];
        output2 <= mem_array_B[counter_B];
    end
endmodule
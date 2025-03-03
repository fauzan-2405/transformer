// RAM1_inputA.v
// Used to simulate the RAM if the matrix is not symmetrical (MXN) (NXP)

module RAM1_inputA #(
    parameter WIDTH = 16,
    parameter CHUNK_SIZE = 4,
    parameter INNER_DIMENSION = 8, // The same number of rows in one matrix and same number of columns in the other matrix
    parameter OUTER_DIMENSION = 10 // The size of rows/cols of the matrix outside of inner dimension
) (
    input clk,
    input [WIDTH-1:0] counter_A,
    output reg [(WIDTH*CHUNK_SIZE)-1:0] outputA
);
    // (INNER DIMENSION / CHUNK SIZE) x OUTER DIMENSION
    // For 10x8 -> (8/4)x10=20
	// reg [Number of bits per row] mem_array [(INNER DIMENSION / CHUNK SIZE) x OUTER DIMENSION]
    reg [(WIDTH*CHUNK_SIZE)-1:0] mem_array_A [((INNER_DIMENSION/CHUNK_SIZE)*OUTER_DIMENSION)-1:0];
    
    initial begin
        $readmemh("A.txt", mem_array_A);
    end

    always @(posedge clk) begin
        outputA <= mem_array_A[counter_A];
    end
endmodule
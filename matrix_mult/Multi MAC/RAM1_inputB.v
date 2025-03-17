// RAM1_inputB.v
// Used to simulate the RAM if the matrix is not symmetrical (MXN) (NXP)

module RAM1_inputB #(
    parameter WIDTH = 16,
    parameter CHUNK_SIZE = 4,
    parameter INNER_DIMENSION = 8, // The same number of rows in one matrix and same number of columns in the other matrix
    parameter OUTER_DIMENSION = 6 // The size of rows/cols of the matrix outside of inner dimension
) (
    input clk,
    input [WIDTH-1:0] counter_B,
    output reg [(WIDTH*CHUNK_SIZE)-1:0] outputB
);
    // (INNER DIMENSION / CHUNK SIZE) x OUTER DIMENSION
    // For 8x6 -> (8/4)x6=12
	// reg [Number of bits per row] mem_array [(INNER DIMENSION / CHUNK SIZE) x OUTER DIMENSION]
    reg [(WIDTH*CHUNK_SIZE)-1:0] mem_array_B [((INNER_DIMENSION/CHUNK_SIZE)*OUTER_DIMENSION)-1:0];
    
    initial begin
        $readmemh("A.txt", mem_array_B);
    end

    always @(posedge clk) begin
        outputB <= mem_array_B[counter_B];
    end
endmodule
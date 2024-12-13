///////////////////////////////
// Module	: Block Matrix Multiplication
// Instance	: bmm_partial
// Engineer	: Fauzan
///////////////////////////////

`timescale 1ns / 1ps
`include "mult_4bit.v"

// bmm_partial.v
module bmm_partial (
    input clk,
    input rst,
    input [BLOCK_SIZE*SIZE*DATA_WIDTH-1:0] A_rows,
    input [BLOCK_SIZE*SIZE*DATA_WIDTH-1:0] B_cols,
    input valid_in,
    output reg valid_out,
    output reg [BLOCK_SIZE*BLOCK_SIZE*DATA_WIDTH-1:0] AB_partial
);

parameter BLOCK_SIZE = 2; // Partial Sum Block Size (A x A)
parameter DATA_WIDTH = 4; // Bit size each element
parameter SIZE		 = 4; // Original matrix size (A x A)

reg [DATA_WIDTH-1:0] A [0:BLOCK_SIZE-1][0:SIZE-1];
reg [DATA_WIDTH-1:0] B [0:SIZE-1][0:BLOCK_SIZE-1];
reg [DATA_WIDTH-1:0] AB [0:BLOCK_SIZE-1][0:BLOCK_SIZE-1];

reg [(2*DATA_WIDTH)-1:0] mult_result; 	// Temporary register to hold multiplication
wire [DATA_WIDTH-1:0] mult_out; 		// Output from mult_4bit module 

integer i, j, k;

// Temporary registers to hold operands for multiplication
reg [DATA_WIDTH-1:0] operand1;
reg [DATA_WIDTH-1:0] operand2;

// Instantiate the mult_4bit module
mult_4bit mult_inst (
    .Operand_1(operand1),
    .Operand_2(operand2),
    .result(mult_out)
);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        valid_out <= 0;
        for (i = 0; i < BLOCK_SIZE; i = i + 1) begin
            for (j = 0; j < BLOCK_SIZE; j = j + 1) begin
                AB[i][j] <= 0;
            end
        end
    end else if (valid_in) begin
        // Unpack A_rows into A 2x4 matrix and B into 4x2
        for (i = 0; i < BLOCK_SIZE; i = i + 1) begin
			for (j = 0; j < SIZE; j = j + 1) begin 
				A[i][j] <= A_rows[(i * SIZE + j) * DATA_WIDTH +: DATA_WIDTH];
				B[j][i] <= B_cols[(j * BLOCK_SIZE + i) * DATA_WIDTH +: DATA_WIDTH];
            end
        end
		
		// Compute AB_partial
		for (i = 0; i < BLOCK_SIZE; i = i + 1) begin
			for (j = 0; j < BLOCK_SIZE; j = j + 1) begin
				AB[i][j] <= 0;
				for (k = 0; k < SIZE; k = k + 1) begin
					// Set operands for multiplication
					operand1 <= A[i][k];
					operand2 <= B[k][j];
					// Wait for multiplication result
					mult_result <= mult_out;	
					AB[i][j] <= AB[i][j] + mult_result;
				end
			end
		end
		
		// Pack AB_partial into output
		for (i = 0; i < BLOCK_SIZE; i = i + 1) begin
			for (j = 0; j < BLOCK_SIZE; j = j + 1) begin
				AB_partial[(i * BLOCK_SIZE + j) * DATA_WIDTH +: DATA_WIDTH] <= AB[i][j];
			end
		end
		
		valid_out <= 1;
    end else begin
        valid_out <= 0;
    end
end

endmodule

//////////////////////////////////////////////////////////////////////////////////
// Engineer    : Muhammad Fauzan
// Design Name : Multiplier Fixed Point
// Module Name : mult_4bit
//////////////////////////////////////////////////////////////////////////////////

module mult_4bit (
   input [3:0] Operand_1, 
   input [3:0] Operand_2,
   output [3:0] result
);

	wire [7:0] temp_op1, temp_op2; // 8-bit for sign extension
	wire [15:0] temp; // 16-bit for multiplication result

	// Sign extend the 4-bit inputs to 8-bit
	assign temp_op1 = {{4{Operand_1[3]}}, Operand_1}; 
	assign temp_op2 = {{4{Operand_2[3]}}, Operand_2};

	// Perform multiplication
	assign temp = temp_op1 * temp_op2;

	// Extract the result (shift right to account for fixed-point scaling)
	assign result = temp[7:4]; // Taking the upper 4 bits as the result

endmodule

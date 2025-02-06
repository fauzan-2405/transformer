// mult.v
// Used to do multiplication for 16-bit fixed-point Q8.8

module mult (
   input [15:0] Operand_1, 
   input [15:0] Operand_2,
   output [15:0] result
);
    wire [31:0] temp_op1, temp_op2;
    wire [63:0]temp;

    assign temp_op1 = {{16{Operand_1[15]}}, Operand_1}; 
    assign temp_op2 = {{16{Operand_2[15]}}, Operand_2};

    assign temp = temp_op1 * temp_op2;
    assign result[15:0] = temp[24:8];
endmodule
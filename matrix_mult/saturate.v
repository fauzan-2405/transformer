// saturate.v
// Used to check whether the output is saturated or not
`include "reg.v"

module saturate #(
    parameter WIDTH = 16,
    parameter FRAC_WIDTH = 8
) (
    input clk, rst_n,
    input [2*WIDTH-1:0] in,
    output [WIDTH-1:0] out
);
    wire [1:0] selector, temp_selector;

    // Calculate selector[0] - reduction OR to check if upper bits are non-zero
    assign selector[0] = |in[2*WIDTH-2:WIDTH+FRAC_WIDTH];  // Check if upper bits are non-zero
    assign selector[1] = in[2*WIDTH-1];  // The sign bit of the input

    // Register for storing the selector values
    register #(2) reg_0 (.clk(clk), .rst_n(rst_n), .in(selector), .out(temp_selector));

    // Assign the output based on saturation logic
    assign out = selector[1] ?
        (selector[0] ? in[WIDTH+FRAC_WIDTH-1:FRAC_WIDTH] : {1'b1, {WIDTH-1{1'b0}}}) :
        (selector[0] ? {1'b0, {WIDTH-1{1'b1}}} : in[WIDTH+FRAC_WIDTH-1:FRAC_WIDTH]);
        
endmodule

// reg.v
// Used as a register module

module register #(
    parameter WIDTH = 16
) (
    input clk, rst_n,
    input [WIDTH-1:0] in,
    output reg [WIDTH-1:0] out
);

    always @(posedge clk) begin
        if (!rst_n) out <= 0;
        else out <= in;
    end
    
endmodule
// mux4_1.v
// Used to stream inputs from RAM

module mux4_1 #(
    parameter WIDTH = 16
) (
    input clk, rst_n,
    input [WIDTH-1:0] input_0, input_1, input_2, input_3,
    output reg [WIDTH-1:0] out
);
    reg [1:0] select;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            out <= 16'd0;
            select <= 2'd0;
        end
        else begin
            case (select)
            2'b00 : out <= input_0;
            2'b01 : out <= input_1;
            2'b10 : out <= input_2;
            2'b11 : out <= input_3;
            endcase
            select <= select+1;
        end
    end

endmodule
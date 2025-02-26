// mux2_1.v
// Used to stream inputs from RAM

module mux2_1 #(
    parameter WIDTH = 16
) (
    input clk, rst_n,
    input [WIDTH-1:0] input_0, input_1, 
    output reg [WIDTH-1:0] out
);
    reg select = 1'b0;
    //reg select;
	
    always @(posedge clk) begin
        if (!rst_n) begin
            out <= 16'd0;
            select <= 1'd0;
        end
        else begin
            case (select)
            1'b0 : out <= input_0;
            1'b1 : out <= input_1;
            endcase
			select <= select+1;
        end
    end

endmodule
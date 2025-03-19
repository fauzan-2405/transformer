// pe.v
// Used as a processing element (PE) in systolic array

`include "saturate.v"

module pe #(
    parameter WIDTH = 16,
    parameter FRAC_WIDTH = 8
) (
    input clk, rst_n,
    input [WIDTH-1:0] in_north, in_west,
    output reg [WIDTH-1:0] out_south, out_east,
    output reg [WIDTH-1:0] result
);
    wire [2*WIDTH-1:0] mult_result;
    wire [2*WIDTH-1:0] add_result;
    wire [WIDTH-1:0] temp_acc;
	
	//reg count = 1'b0;
	
	/*
    always @(negedge clk) begin
        if (!rst_n) begin
            out_south <= 0;
            out_east <= 0;
            result <= 0;
        end
	end
	*/
	
	always @(posedge clk) begin
        if (!rst_n) begin
            out_south <= 0;
            out_east <= 0;
            result <= 0;
        end
		else begin
			out_east <= in_west;
			out_south <= in_north;
			result <= temp_acc;
        end
    end
	

	assign mult_result = {{WIDTH{in_west[WIDTH-1]}}, in_west} * {{WIDTH{in_north[WIDTH-1]}}, in_north};
    assign add_result = mult_result + {{FRAC_WIDTH{result[WIDTH-1]}}, result, {FRAC_WIDTH{1'b0}}};
    saturate #(.WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH)) saturation_block (.clk(clk), .rst_n(rst_n), .in(add_result), .out(temp_acc));

endmodule
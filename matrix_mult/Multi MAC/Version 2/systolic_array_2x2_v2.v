// systolic_array_2x2_v2.v
// Used as a multiplier

//`include "pe_v2.v"

module systolic_array_2x2_v2 #(
    parameter CHUNK_SIZE = 4,
    parameter WIDTH_A = 16,
    parameter FRAC_WIDTH_A = 8,
    parameter WIDTH_B = 16,
    parameter FRAC_WIDTH_B = 8,
    parameter WIDTH_OUT = 16,
    parameter FRAC_WIDTH_OUT = 8
) (
    input clk, en, rst_n,
    input [WIDTH_B-1:0] in_north0, in_north1,
    input [WIDTH_A-1:0] in_west0, in_west2,
    output reg done,
    output [WIDTH_OUT*CHUNK_SIZE-1:0] out
);
    // Dont initialize counter if you want to do systolic_array_2x2 or mac simulation on testbench
    //reg [2:0] count = 3'b111;
    reg [2:0] count;
    
    // For convenience
    //wire [WIDTH-1:0] in_north0, in_north1;
    //wire [WIDTH-1:0] in_west0, in_west2;
    wire [WIDTH_B-1:0] out_south0, out_south1, out_south2, out_south3;
    wire [WIDTH_A-1:0] out_east0, out_east1, out_east2, out_east3;
    wire [WIDTH_OUT-1:0] result0, result1, result2, result3;

    // First Row
    pe_v2 #(.WIDTH_A(WIDTH_A), .FRAC_WIDTH_A(FRAC_WIDTH_A), .WIDTH_B(WIDTH_B), .FRAC_WIDTH_B(FRAC_WIDTH_B), .WIDTH_OUT(WIDTH_OUT), .FRAC_WIDTH_OUT(FRAC_WIDTH_OUT)) 
        pe0 (.clk(clk), .rst_n(rst_n), .in_north(in_north0), .in_west(in_west0), .out_south(out_south0), .out_east(out_east0), .result(result0)); 
    pe_v2 #(.WIDTH_A(WIDTH_A), .FRAC_WIDTH_A(FRAC_WIDTH_A), .WIDTH_B(WIDTH_B), .FRAC_WIDTH_B(FRAC_WIDTH_B), .WIDTH_OUT(WIDTH_OUT), .FRAC_WIDTH_OUT(FRAC_WIDTH_OUT)) 
        pe1 (.clk(clk), .rst_n(rst_n), .in_north(in_north1), .in_west(out_east0), .out_south(out_south1), .out_east(out_east1), .result(result1)); 

    // Second row
    pe_v2 #(.WIDTH_A(WIDTH_A), .FRAC_WIDTH_A(FRAC_WIDTH_A), .WIDTH_B(WIDTH_B), .FRAC_WIDTH_B(FRAC_WIDTH_B), .WIDTH_OUT(WIDTH_OUT), .FRAC_WIDTH_OUT(FRAC_WIDTH_OUT)) 
         pe2 (.clk(clk), .rst_n(rst_n), .in_north(out_south0), .in_west(in_west2), .out_south(out_south2), .out_east(out_east2), .result(result2));
    pe_v2 #(.WIDTH_A(WIDTH_A), .FRAC_WIDTH_A(FRAC_WIDTH_A), .WIDTH_B(WIDTH_B), .FRAC_WIDTH_B(FRAC_WIDTH_B), .WIDTH_OUT(WIDTH_OUT), .FRAC_WIDTH_OUT(FRAC_WIDTH_OUT)) 
         pe3 (.clk(clk), .rst_n(rst_n), .in_north(out_south1), .in_west(out_east2), .out_south(out_south3), .out_east(out_east3), .result(result3));

    assign out = {result0, result1, result2, result3};

    always @(posedge clk) begin
        if (!rst_n) begin
            done <= 0;
            count <= 0;
        end
        else begin
			if (en) begin
			    if (count == 4) begin
					done <= 1;
					count <= 0;
				end
				else begin
					count <= count + 1;
					done <= 0;
				end
			end
        end
    end
endmodule

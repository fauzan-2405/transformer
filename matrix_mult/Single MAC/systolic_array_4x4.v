// systolic_array_4x4.v
// Used as a multiplier

`include "pe.v"

module systolic_array_4x4 #(
    parameter WIDTH = 16,
    parameter FRAC_WIDTH = 8
) (
    input clk, rst_n,
    input [WIDTH-1:0] in_north0, in_north1, in_north2, in_north3,
    input [WIDTH-1:0] in_west0, in_west4, in_west8, in_west12,
    output reg done,
    output [WIDTH*WIDTH-1:0] out
);
    // For counting 
    reg [3:0] count;

    // For convenience
    wire [WIDTH-1:0] in_north0, in_north1, in_north2, in_north3;
    wire [WIDTH-1:0] in_west0, in_west4, in_west8, in_west12;
    wire [WIDTH-1:0] out_south0, out_south1, out_south2, out_south3, out_south4, out_south5, out_south6, out_south7, out_south8, out_south9, out_south10, out_south11, out_south12, out_south13, out_south14, out_south15;
    wire [WIDTH-1:0] out_east0, out_east1, out_east2, out_east3, out_east4, out_east5, out_east6, out_east7, out_east8, out_east9, out_east10, out_east11, out_east12, out_east13, out_east14, out_east15;
    wire [WIDTH-1:0] result0, result1, result2, result3, result4, result5, result6, result7, result8, result9, result10, result11, result12, result13, result14, result15;

    // NORTH + west
    pe #(.WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH)) pe0 (.clk(clk), .rst_n(rst_n), .in_north(in_north0), .in_west(in_west0), .out_south(out_south0), .out_east(out_east0), .result(result0)); 
    // NORTH
    pe #(.WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH)) pe1 (.clk(clk), .rst_n(rst_n), .in_north(in_north1), .in_west(out_east0), .out_south(out_south1), .out_east(out_east1), .result(result1)); 
    pe #(.WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH)) pe2 (.clk(clk), .rst_n(rst_n), .in_north(in_north2), .in_west(out_east1), .out_south(out_south2), .out_east(out_east2), .result(result2));
    pe #(.WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH)) pe3 (.clk(clk), .rst_n(rst_n), .in_north(in_north3), .in_west(out_east2), .out_south(out_south3), .out_east(out_east3), .result(result3));

    // WEST
    pe #(.WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH)) pe4 (.clk(clk), .rst_n(rst_n), .in_north(out_south0), .in_west(in_west4), .out_south(out_south4), .out_east(out_east4), .result(result4));
    pe #(.WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH)) pe8 (.clk(clk), .rst_n(rst_n), .in_north(out_south4), .in_west(in_west8), .out_south(out_south8), .out_east(out_east8), .result(result8));
    pe #(.WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH)) pe12 (.clk(clk), .rst_n(rst_n), .in_north(out_south8), .in_west(in_west12), .out_south(out_south12), .out_east(out_east12), .result(result12));

    // So far, we already defined this area in systolic array:
    /* 
    X X X X 
    X 0 0 0
    X 0 0 0
    X 0 0 0
    */

    // WITHOUT DIRECT INPUTS
    // Second row
    pe #(.WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH)) pe5 (.clk(clk), .rst_n(rst_n), .in_north(out_south1), .in_west(out_east4), .out_south(out_south5), .out_east(out_east5), .result(result5));
    pe #(.WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH)) pe6 (.clk(clk), .rst_n(rst_n), .in_north(out_south2), .in_west(out_east5), .out_south(out_south6), .out_east(out_east6), .result(result6));
    pe #(.WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH)) pe7 (.clk(clk), .rst_n(rst_n), .in_north(out_south3), .in_west(out_east6), .out_south(out_south7), .out_east(out_east7), .result(result7));

    // Third row
    pe #(.WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH)) pe9 (.clk(clk), .rst_n(rst_n), .in_north(out_south5), .in_west(out_east8), .out_south(out_south9), .out_east(out_east9), .result(result9));
    pe #(.WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH)) pe10 (.clk(clk), .rst_n(rst_n), .in_north(out_south6), .in_west(out_east9), .out_south(out_south10), .out_east(out_east10), .result(result10));
    pe #(.WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH)) pe11 (.clk(clk), .rst_n(rst_n), .in_north(out_south7), .in_west(out_east10), .out_south(out_south11), .out_east(out_east11), .result(result11));

    // Fourth row
    pe #(.WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH)) pe13 (.clk(clk), .rst_n(rst_n), .in_north(out_south9), .in_west(out_east12), .out_south(out_south13), .out_east(out_east13), .result(result13));
    pe #(.WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH)) pe14 (.clk(clk), .rst_n(rst_n), .in_north(out_south10), .in_west(out_east13), .out_south(out_south14), .out_east(out_east14), .result(result14));
    pe #(.WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH)) pe15 (.clk(clk), .rst_n(rst_n), .in_north(out_south11), .in_west(out_east14), .out_south(out_south15), .out_east(out_east15), .result(result15));

    assign out = {result0, result1, result2, result3, result4, result5, result6, result7, result8, result9, result10, result11, result12, result13, result14, result15};

    always @(posedge clk) begin
        if (!rst_n) begin
            done <= 0;
            count <= 0;
        end
        else begin
            if (count == 9) begin
                done <= 1;
                count <= 0;
            end
            else begin
                count <= count + 1;
                done <= 0;
            end
        end
    end
endmodule

		      
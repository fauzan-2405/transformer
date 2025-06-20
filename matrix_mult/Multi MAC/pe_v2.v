// pe_v2.v
// Used as a processing element (PE) in systolic array
// Now it can take any different input and weight length, along with desired length of output as well

module pe #(
    parameter WIDTH_A = 16,
    parameter FRAC_WIDTH_A = 8,
    parameter WIDTH_B = 16,
    parameter FRAC_WIDTH_B = 8,
    parameter WIDTH_OUT = 16,
    parameter FRAC_WIDTH_OUT = 8
) (
    input clk, rst_n,
    input [WIDTH_A-1:0] in_west,
    input [WIDTH_B-1:0] in_north,
    output reg [WIDTH_A-1:0] out_east,
    output reg [WIDTH_B-1:0] out_south,
    output reg [WIDTH_OUT-1:0] result
);

    localparam MULT_WIDTH = WIDTH_A + WIDTH_B;
    localparam MULT_FRAC = FRAC_WIDTH_A + FRAC_WIDTH_B;
    localparam ACC_WIDTH = MULT_WIDTH + 4;  // extra headroom to avoid overflow

    wire signed [MULT_WIDTH-1:0] mult_result;
    wire signed [ACC_WIDTH-1:0] add_result;
    wire signed [WIDTH_OUT-1:0] temp_acc;

    // Sign-extend inputs before multiplying
    wire signed [WIDTH_A-1:0] a_signed = in_west;
    wire signed [WIDTH_B-1:0] b_signed = in_north;

    assign mult_result = a_signed * b_signed;

    // Align 'result' to the same fixed-point scale as mult_result before accumulation
    wire signed [ACC_WIDTH-1:0] aligned_result = {{(ACC_WIDTH-WIDTH_OUT){result[WIDTH_OUT-1]}}, result} <<< (MULT_FRAC - FRAC_WIDTH_OUT);
    assign add_result = {{(ACC_WIDTH-MULT_WIDTH){mult_result[MULT_WIDTH-1]}}, mult_result} + aligned_result;

    // Saturation + truncation
    saturate_v2 #(
        .IN_WIDTH(ACC_WIDTH),
        .OUT_WIDTH(WIDTH_OUT),
        .FRAC_IN(MULT_FRAC),
        .FRAC_OUT(FRAC_WIDTH_OUT)
    ) saturation_block (
        .clk(clk), .rst_n(rst_n),
        .in(add_result),
        .out(temp_acc)
    );

    always @(posedge clk) begin
        if (!rst_n) begin
            out_south <= 0;
            out_east <= 0;
            result <= 0;
        end else begin
            out_east <= in_west;
            out_south <= in_north;
            result <= temp_acc;
        end
    end
endmodule

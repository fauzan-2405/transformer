// softmax_e_2nd_function.v
// Used to calculate the e^x function with second order of McLaurin Series
// e^x = e^i * e^f = e^i*(1 + x + 0.5 * x^2)

module softmax_e_2nd_function #(
    parameter WIDTH = 16,
    parameter FRAC_WIDTH = 8,
    parameter INT_WIDTH = 8
) (
    input  wire         clk,
    input  wire [31:0]              e_i,    // 
    input  wire [FRAC_WIDTH-1:0]    f,      //
    output wire  [31:0]              result  // 
);
    // Stage 1: Compute f² = f * f 
    reg [FRAC_WIDTH*2-1:0] f_squared;
    always @(posedge clk) begin
        f_squared <= f * f;
    end

    // Stage 2: Compute f² / 2 
    reg [WIDTH-1:0] f2_div2;
    always @(posedge clk) begin
        f2_div2 <= f_squared[47:16] >> 1; // Q16.16 / 2
    end

    // Stage 3: Add (1 + f + f²/2)
    reg [31:0] approx;
    always @(posedge clk) begin
        approx <= 32'h0001_0000 + f + f2_div2; // (1 + f + f²/2)
    end

    // Stage 4: Multiply e^i * (approx)
    reg [63:0] mult_result;
    always @(posedge clk) begin
        mult_result <= e_i * approx; // Q32.32
    end

    // Stage 5: Downscale to Q16.16
    /*
    always @(posedge clk) begin
        result <= mult_result[47:16];
    end
    */
    assign result = mult_result[47:16];
endmodule

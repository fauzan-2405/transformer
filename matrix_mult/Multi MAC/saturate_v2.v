// saturate_v2.v
// Used to check whether the output is saturated or not
// Now with arbitrary length of output

module saturate #(
    parameter IN_WIDTH = 32,
    parameter OUT_WIDTH = 16,
    parameter FRAC_IN = 16,
    parameter FRAC_OUT = 8
)(
    input clk, rst_n,
    input signed [IN_WIDTH-1:0] in,
    output reg signed [OUT_WIDTH-1:0] out
);

    wire signed [IN_WIDTH-1:0] shifted = in >>> (FRAC_IN - FRAC_OUT);

    // Clamp to max/min if overflow
    wire signed [OUT_WIDTH-1:0] max_val = {1'b0, {(OUT_WIDTH-1){1'b1}}};
    wire signed [OUT_WIDTH-1:0] min_val = {1'b1, {(OUT_WIDTH-1){1'b0}}};

    always @(posedge clk) begin
        if (!rst_n) begin
            out <= 0;
        end else begin
            if (shifted > max_val)
                out <= max_val;
            else if (shifted < min_val)
                out <= min_val;
            else
                out <= shifted[OUT_WIDTH-1:0];
        end
    end
endmodule

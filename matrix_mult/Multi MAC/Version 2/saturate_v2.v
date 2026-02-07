// saturate_v2.v
// Used to check whether the output is saturated or not
// Now with arbitrary length of output

module saturate_v2 #(
    parameter IN_WIDTH = 32,
    parameter OUT_WIDTH = 16,
    parameter FRAC_IN = 16,
    parameter FRAC_OUT = 8
)(
    //input clk, rst_n,
    input signed [IN_WIDTH-1:0] in,
    output wire signed [OUT_WIDTH-1:0] out
);
    // Generic saturation limits
    localparam signed [OUT_WIDTH-1:0] MAX_OUT = {1'b0, {(OUT_WIDTH-1){1'b1}}};
    localparam signed [OUT_WIDTH-1:0] MIN_OUT = {1'b1, {(OUT_WIDTH-1){1'b0}}};

    wire signed [IN_WIDTH-1:0] shifted = in >>> (FRAC_IN - FRAC_OUT);

    // Clamp to max/min if overflow
    wire signed [IN_WIDTH-1:0] max_val = {{(IN_WIDTH-OUT_WIDTH){1'b0}}, MAX_OUT};
    wire signed [IN_WIDTH-1:0] min_val = {{(IN_WIDTH-OUT_WIDTH){1'b1}}, MIN_OUT};
    
    assign out = (shifted > max_val) ? MAX_OUT :
                    (shifted < min_val) ? MIN_OUT : shifted[OUT_WIDTH-1:0];
    
    /*
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
    */
endmodule

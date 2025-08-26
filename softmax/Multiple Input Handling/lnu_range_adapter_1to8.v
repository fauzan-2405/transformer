// lnu_range_adapter_1to8.v
// This module will calculate ln(sum_exp) = ln(m) + k*ln(2)

module lnu_range_adapter_1to8 #(
    parameter WIDTH = 32,
    parameter FRAC  = 16
) (
    input wire [WIDTH+16-1:0] x_sum_exp,
    output wire [WIDTH-1:0] y_ln_out
);
    // Constants
    localparam integer SUMW = WIDTH + 16;
    wire [WIDTH-1:0] ln2_q    = 32'h0000B172; // ~0.693147 in Q16.16
    
    // Clamp non-positive value
    wire [WIDTH+16-1:0] x_clamped = (x_sum_exp[WIDTH+16-1] || (x_sum_exp == {WIDTH+16{1'b0}})) ?
                                    {{(WIDTH+16-FRAC-1){1'b0}}, 1'b1, {FRAC{1'b0}}} : // ~1.0 in Q16.16
                                    x_sum_exp;
    
    // Leading one detector
    integer i;
    reg found;
    reg [$clog2(SUMW)-1:0] lead_one_pos;
    always @(*) begin
        found = 0;
        lead_one_pos = 0;
        for (i = SUMW-1; i >= 0; i = i-1) begin
            if (!found) begin
                if (x_clamped[i]) begin
                    lead_one_pos = i;
                    found = 1; // break after first one
                end
            end
        end
    end

    // Normalizing, Target: integer part of m is in [1,7], i.e. m in [1,8).
    reg signed [15:0] k_shift;
    reg [WIDTH-1:0]   m_norm;

    always @(*) begin
        if (lead_one_pos > (FRAC+2)) begin
            k_shift = lead_one_pos - (FRAC+2);
            m_norm  = x_clamped >> k_shift;
        end else begin
            k_shift = -((FRAC+2) - lead_one_pos);
            m_norm  = x_clamped << ((FRAC+2) - lead_one_pos);
        end
    end

    // Calling the LNU
    wire [WIDTH-1:0] ln_m;
    lnu LNU (
        .x_in(m_norm), .ln_out(ln_m)
    );

    // ln(sum_exp) = ln(m_q) + k*ln(2)
    wire [63:0] k_ln2_full = $signed(k_shift) * $signed({{16{ln2_q[31]}}, ln2_q});
    wire [WIDTH-1:0] k_ln2_q = k_ln2_full[WIDTH-1:0];

    assign y_ln_out = ln_m + k_ln2_q;

endmodule
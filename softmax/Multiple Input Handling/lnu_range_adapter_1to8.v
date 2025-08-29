// lnu_range_adapter_1to8.v
// ln(sum_exp) = ln(m) + k*ln(2)

module lnu_range_adapter_1to8 #(
    parameter WIDTH     = 32,
    parameter FRAC      = 16,
    parameter SUM_WIDTH = 20
) (
    input  wire [SUM_WIDTH-1:0] x_sum_exp,
    output wire [WIDTH-1:0]     y_ln_out
);
    // Constants
    localparam [WIDTH-1:0] LN2_Q = 32'h0000B172; // ~0.693147 in Q16.16

    // ------------------ Clamp non-positive ------------------
    wire [SUM_WIDTH-1:0] x_clamped =
        (x_sum_exp == {SUM_WIDTH{1'b0}}) ? 
        {{(SUM_WIDTH-FRAC-1){1'b0}}, 1'b1, {FRAC{1'b0}}} : // ~1.0 in Q format
        x_sum_exp;

    // ------------------ Leading One Detector ------------------
    integer i;
    reg found;
    reg [$clog2(SUM_WIDTH)-1:0] lead_one_pos;

    always @(*) begin
        found = 0;
        lead_one_pos = 0;
        for (i = SUM_WIDTH-1; i >= 0; i = i-1) begin
            if (!found && x_clamped[i]) begin
                lead_one_pos = i[$clog2(SUM_WIDTH)-1:0];
                found = 1; // break
            end
        end
    end

    // ------------------ Normalize ------------------
    // target: m_norm in [1,8)
    reg signed [$clog2(SUM_WIDTH):0] k_shift;
    reg [WIDTH-1:0]                  m_norm;

    always @(*) begin
        if (lead_one_pos > (FRAC+2)) begin
            k_shift = lead_one_pos - (FRAC+2);
            m_norm  = x_clamped >> k_shift;
        end else begin
            k_shift = -((FRAC+2) - lead_one_pos);
            m_norm  = x_clamped << ((FRAC+2) - lead_one_pos);
        end
    end

    // ------------------ LNU core ------------------
    wire [WIDTH-1:0] ln_m;
    lnu LNU (
        .x_in(m_norm),
        .ln_out(ln_m)
    );

    // ------------------ k * ln2 ------------------
    wire signed [WIDTH+15:0] k_mult   = $signed(k_shift) * $signed(LN2_Q);
    wire [WIDTH-1:0]         k_ln2_q  = k_mult[WIDTH-1:0];

    assign y_ln_out = ln_m + k_ln2_q;

endmodule
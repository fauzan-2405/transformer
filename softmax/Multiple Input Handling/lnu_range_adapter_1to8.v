// lnu_range_adapter_1to8.v
// This module will calculate ln(sum_exp) = ln(m) + k*ln(2)

module lnu_range_adapter_1to8 #(
    parameter WIDTH = 32,
    parameter FRAC  = 16
) (
    input wire [WIDTH+16-1:0] x_sum_exp,
    output wire [WIDTH-1:0] y_ln_out
);
    wire [WIDTH-1:0] ln2_q    = 32'h0000B172; // ~0.693147 in Q16.16
    
    // Clamp non-positive value
    wire [WIDTH+16-1:0] x_clamped = (x_sum_exp[WIDTH+16-1] || (x_sum_exp == {WIDTH+16{1'b0}})) ?
                                    {{(WIDTH+16-FRAC-1){1'b0}}, 1'b1, {FRAC{1'b0}}} : // ~1.0 in Q16.16
                                    x_sum_exp;
    
    // Finding the k so sum_exp = m * 2^k
    // Reduce sum_exp to 32-bit Q16.16
    localparam integer SUMW = WIDTH + 16;
    wire [31:0] x32 = (SUMW > 32) ? x_clamped[SUMW-1 -: 32] : { {(32-SUMW){1'b0}}, x_clamped };

    // Bring x32 into [1,8) by shifting and compute how many bits to shift to get integer part in [1 ... 7]
    wire [WIDTH-1:0] int_part = x32[(2*WIDTH)-1:WIDTH];
    integer k_signed;
    reg [2*WIDTH-1:0] m_q;

    always @(*) begin
        k_signed = 0;
        m_q      = x32;

        // scaling it down if > 8.0
        while (m_q[(2*WIDTH)-1:WIDTH] >= 16'd8) begin
            m_q      = {1'b0, m_q[31:1]}; // divide by 2
            k_signed = k_signed + 1;
        end

        // scaling it up if < 1.0
        while (m_q[(2*WIDTH)-1:WIDTH] < 16'd1) begin
            m_q      = {m_q[30:0], 1'b0}; // multiply by 2
            k_signed = k_signed - 1;
        end
    end

    // Calling the LNU
    wire [31:0] ln_m;
    lnu LNU (
        .x_in(m_q), .ln_out(ln_m)
    );

    // ln(sum_exp) = ln(m_q) + k*ln(2)
    wire [63:0] k_ln2_full = $signed(k_signed) * $signed({{16{ln2_q[31]}}, ln2_q}); // extend to 48b then multiply
    wire [31:0] k_ln2_q    = k_ln2_full[31:0]; // ok for modest |k|

    assign y_ln_out = ln_m + k_ln2_q;

endmodule
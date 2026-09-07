// lnu_range_adapter_1to8.v
// This module will calculate ln(sum_exp) = ln(m) + k*ln(2)

module lnu_range_adapter_1to8 #(
    parameter DELAY = 3,
    parameter WIDTH = 32,
    parameter FRAC  = 16,
    parameter SUM_WIDTH = 20
) (
    input wire clk,
    input wire rst_n,
    input wire data_in_valid,
    input wire [SUM_WIDTH-1:0] x_sum_exp,
    output wire data_out_valid,
    output wire [WIDTH-1:0] y_ln_out
);
    // Constants
    localparam [WIDTH-1:0] LN2_Q    = 32'h0000B172; // ~0.693147 in Q16.16
    
    // Clamp non-positive value
//    wire [SUM_WIDTH-1:0] x_clamped = 
//        (x_sum_exp == {SUM_WIDTH{1'b0}}) ? {{(SUM_WIDTH-FRAC-1){1'b0}}, 1'b1, {FRAC{1'b0}}} : // ~1.0 in Q16.16
//            x_sum_exp;
    wire [SUM_WIDTH-1:0] x_clamped = (data_in_valid) ? 
                                     ((x_sum_exp == {SUM_WIDTH{1'b0}}) ? {{(SUM_WIDTH-FRAC-1){1'b0}}, 1'b1, {FRAC{1'b0}}} : // ~1.0 in Q16.16
                                        x_sum_exp) : 0;
    
    // Leading one detector
    integer i;
    reg found;
    reg [$clog2(SUM_WIDTH)-1:0] lead_one_pos;
    
    always @(*) begin
        found = 0;
        lead_one_pos = 0;
        for (i = SUM_WIDTH-1; i >= 0; i = i-1) begin
            if (!found && (x_clamped[i]) ) begin
                lead_one_pos = i;
                found = 1; // break after first one
            end
        end
    end

    // Normalizing, 
    // Target: integer part of m is in [1,7], i.e. m in [1,8).
    reg signed [$clog2(SUM_WIDTH):0] k_shift;
    reg [WIDTH-1:0]   m_norm;
    
    // =========== Pipeline =========== 
    reg [$clog2(SUM_WIDTH)-1:0] lead_one_pos_d;
    reg signed [$clog2(SUM_WIDTH):0] k_shift_d;
    reg [WIDTH-1:0]   m_norm_d;

    always @(*) begin
        if (lead_one_pos_d > (FRAC+2)) begin
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
        .clk(clk),
        .rst_n(rst_n),
        .x_in(m_norm_d), 
        .ln_out(ln_m)
    );

    // ln(sum_exp) = ln(m_q) + k*ln(2)
    wire signed [WIDTH+15:0] k_mult  = $signed(k_shift_d) * $signed(LN2_Q);
    reg signed [WIDTH+15:0] k_mult_d;  
    wire [WIDTH-1:0] k_ln2_q = k_mult_d[WIDTH-1:0];
    reg [WIDTH-1:0] k_ln2_q_d;

    assign y_ln_out = ln_m + k_ln2_q_d;
            
    always @(posedge clk) begin
        if (!rst_n) begin
            lead_one_pos_d  <= 0;
            k_shift_d       <= 0;
            m_norm_d        <= 0;
            k_ln2_q_d       <= 0;
            k_mult_d        <= 0;
        end else begin
            lead_one_pos_d  <= lead_one_pos;
            k_shift_d       <= k_shift;
            m_norm_d        <= m_norm;
            k_mult_d        <= k_mult;
            k_ln2_q_d       <= k_ln2_q;
        end
    end
    
    delay_register #(
        .WIDTH(1), .DELAY(DELAY)
    ) delay_valid_in (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(data_in_valid),
        .data_out(data_out_valid)
    );

endmodule

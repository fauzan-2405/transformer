// self_attention_ctrl.sv

module self_attention_ctrl #(
    parameter XXX = YY
)(
    input logic clk, rst_n,
    input slice_done_b2r_wrap,

    output logic internal_rst_n_b2r
);
    logic slice_done_b2r_wrap_reg;

    always @(posedge clk) begin
        if (!rst_n) begin
            internal_rst_n_b2r  <= rst_n;
        end else begin
            slice_done_b2r_wrap_reg <= slice_done_b2r_wrap;
            if (slice_done_b2r_wrap_reg) begin
                internal_rst_n_b2r <= ~slice_done_b2r_wrap_reg;
            end

        end
    end
endmodule
module axis_pe
    (
        input wire         aclk,
        input wire         aresetn,
        // *** Control ***
        input wire         en,
        // *** AXIS slave a_b port ***
        output wire        s_axis_ab_tready,
        input wire [31:0]  s_axis_ab_tdata,
        input wire         s_axis_ab_tvalid,
        input wire         s_axis_ab_tlast,
        // *** AXIS slave y_in port ***
        output wire        s_axis_yin_tready,
        input wire [31:0]  s_axis_yin_tdata,
        input wire         s_axis_yin_tvalid,
        input wire         s_axis_yin_tlast,
        // *** AXIS master port ***
        input wire         m_axis_tready,
        output wire [31:0] m_axis_tdata,
        output wire        m_axis_tvalid,
        output wire        m_axis_tlast
    );
    
    wire [7:0] y_out;
    
    // AXI-Stream control
    assign s_axis_ab_tready = m_axis_tready;
    assign s_axis_yin_tready = m_axis_tready;
    assign m_axis_tdata = en ? {24'h000000, y_out} : 32'd0;
    assign m_axis_tvalid = s_axis_ab_tvalid && s_axis_yin_tvalid;
    assign m_axis_tlast = s_axis_ab_tlast && s_axis_yin_tlast;
    
    // PE
    pe #(8, 0) pe_0
    (
        .a_in(s_axis_ab_tdata[7:0]),
        .y_in(s_axis_yin_tdata[7:0]),
        .b(s_axis_ab_tdata[15:8]),
        .a_out(),
        .y_out(y_out)
    );
    
endmodule

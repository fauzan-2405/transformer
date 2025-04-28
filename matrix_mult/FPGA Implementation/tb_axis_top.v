`timescale 1ns / 1ps

module tb_axis_top();
    
    reg aclk;
    reg aresetn;
    
    wire s_axis_i_tready;
    reg [64*9-1:0] s_axis_i_tdata;
    reg s_axis_i_tvalid;
    reg s_axis_i_tlast;

    wire s_axis_w_tready;
    reg [64-1:0] s_axis_w_tdata;
    reg s_axis_w_tvalid;
    reg s_axis_w_tlast;
    
    reg m_axis_tready;
    wire [64*9-1:0] m_axis_tdata;
    wire m_axis_tvalid;
    wire m_axis_tlast;
    
    axis_top dut
    (
        .aclk(aclk),
        .aresetn(aresetn),
        .s_axis_i_tready(s_axis_i_tready),
        .s_axis_i_tdata(s_axis_i_tdata),
        .s_axis_i_tvalid(s_axis_i_tvalid),
        .s_axis_i_tlast(s_axis_i_tlast),

        .s_axis_w_tready(s_axis_w_tready),
        .s_axis_w_tdata(s_axis_w_tdata),
        .s_axis_w_tvalid(s_axis_w_tvalid),
        .s_axis_w_tlast(s_axis_w_tlast),

        .m_axis_tready(m_axis_tready),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tlast(m_axis_tlast)
    );
    
    always #5 aclk = ~aclk;

    initial
    begin
        s_axis_i_tdata = 0;
        s_axis_i_tvalid = 0;
        s_axis_i_tlast = 0;

        s_axis_w_tdata = 0;
        s_axis_w_tvalid = 0;
        s_axis_w_tlast = 0;

        m_axis_tready = 1;
        
        aresetn = 0;
        #50
        aresetn = 1;
        #50

        s_axis_i_tvalid = 1;
        s_axis_w_tvalid = 1;

        s_axis_w_tdata = 64'h0200020001000100;
        s_axis_i_tdata = 128'h02000100020002000100020001000100;
        #10;

        s_axis_w_tdata = 64'h0200010002000100;
        s_axis_i_tdata = 128'h01000100020002000100010001000200;
        #10;

        s_axis_w_tdata = 64'h0100010001000100;
        s_axis_i_tdata = 128'h00000100020001000100010001000200;
        #10;

        s_axis_w_tdata = 64'h0200010001000200;
        s_axis_i_tdata = 128'h01000200010001000200010002000100;
        s_axis_i_tlast = 1;
        #10;

        s_axis_i_tvalid = 0;
        s_axis_i_tdata = 0; 
        s_axis_i_tlast = 0;   
        s_axis_w_tdata = 64'h0100010001000100;
        #10;

        s_axis_w_tdata = 64'h0200010002000100;
        s_axis_w_tlast = 1;
        #10;

        s_axis_w_tvalid = 0;
        s_axis_w_tdata = 0; 
        s_axis_w_tlast = 0;   
    end
        
endmodule
// tb_axis_top.sv
`timescale 1ns/1ps

import linear_proj_pkg::*;
import self_attention_pkg::*;

module tb_axis_top;
    parameter MEM_INPUT_MAT   = "mat_A_lp_bridge.mem";

    // AXI Signals
    logic                    aclk;
    logic                    aresetn;
    logic [DATA_WIDTH_A-1:0] s_axis_0_tdata;
    logic                    s_axis_0_tvalid;
    logic                    s_axis_0_tlast;
    wire                     s_axis_0_tready;

    logic [DATA_WIDTH_A-1:0] s_axis_1_tdata;
    logic                    s_axis_1_tvalid;
    logic                    s_axis_1_tlast;
    wire                     s_axis_1_tready;

    logic [DATA_WIDTH_A-1:0] mem_A [0:NUM_A_ELEMENTS-1];

    axis_top dut #(
        .MEM_INIT_FILE_Q(MEM_INIT_FILE_Q),
        .MEM_INIT_FILE_K(MEM_INIT_FILE_K),
        .MEM_INIT_FILE_V(MEM_INIT_FILE_V)
    ) (
        .aclk(aclk),
        .aresetn(aresetn),

        .s_axis_0_tready(s_axis_0_tready),
        .s_axis_0_tdata(s_axis_0_tdata),
        .s_axis_0_tvalid(s_axis_0_tvalid),
        .s_axis_0_tlast(s_axis_0_tlast),

        .s_axis_1_tready(s_axis_1_tready),
        .s_axis_1_tdata(s_axis_1_tdata),
        .s_axis_1_tvalid(s_axis_1_tvalid),
        .s_axis_1_tlast(s_axis_1_tlast),

        .m_axis_tready(1'b1)
    );

    task automatic send_inputs;
    begin

        s_axis_0_tvalid = 0;
        s_axis_1_tvalid = 0;

        @(posedge clk);

        for(int i=0;i<(NUM_A_ELEMENTS+1)/2;i++)
        begin

            s_axis_0_tdata  <= mem_A[2*i];

            if(2*i+1 < NUM_A_ELEMENTS)
                s_axis_1_tdata <= mem_A[2*i+1];
            else
                s_axis_1_tdata <= mem_A[NUM_A_ELEMENTS-1];

            s_axis_0_tvalid <= 1;
            s_axis_1_tvalid <= 1;

            s_axis_0_tlast <= (i == ((NUM_A_ELEMENTS+1)/2-1));
            s_axis_1_tlast <= (i == ((NUM_A_ELEMENTS+1)/2-1));

            do begin
                @(posedge clk);
            end while(!(s_axis_0_tready && s_axis_1_tready));

        end

        @(posedge clk);

        s_axis_0_tvalid <= 0;
        s_axis_1_tvalid <= 0;

        s_axis_0_tlast <= 0;
        s_axis_1_tlast <= 0;

    end
    endtask

    initial begin

        $readmemh(MEM_INPUT_MAT, mem_A);

        s_axis_0_tvalid = 0;
        s_axis_1_tvalid = 0;

        rst_n = 0;

        repeat(10) @(posedge clk);

        rst_n = 1;

        repeat(5) @(posedge clk);

        send_inputs();

        $display("[%0t] DMA transfer complete", $time);

        repeat(5000) @(posedge clk);

        $finish;

    end
endmodule
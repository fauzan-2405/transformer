// tb_axis_top.sv
`timescale 1ns/1ps

import linear_proj_pkg::*;
import self_attention_pkg::*;

module tb_axis_top;
    parameter MEM_INPUT_MAT   = "mat_A_lp_bridge.mem";
    parameter MEM_INIT_FILE_Q = "mat_B_lp_bridge.mem";
    parameter MEM_INIT_FILE_K = "mat_B_lp_bridge.mem";
    parameter MEM_INIT_FILE_V = "mat_B_lp_bridge.mem";
    localparam OUT_MULTIHEAD  = TOP_WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A_QKT_Vn*NUM_CORES_B_QKT_Vn*TOTAL_MODULES_LP_V;

    // AXI Signals
    logic                    aclk = 0; 
    always #5 aclk = ~aclk;   // 100 MHz
    logic                    aresetn;
    logic [DATA_WIDTH_A-1:0] s_axis_0_tdata;
    logic                    s_axis_0_tvalid;
    logic                    s_axis_0_tlast;
    wire                     s_axis_0_tready;

    logic [DATA_WIDTH_A-1:0] s_axis_1_tdata;
    logic                    s_axis_1_tvalid;
    logic                    s_axis_1_tlast;
    wire                     s_axis_1_tready;
    
    logic                    m_axis_tready = 1;
    logic [OUT_MULTIHEAD-1:0]m_axis_tdata;
    logic                    m_axis_tvalid;
    logic                    m_axis_tlast;
    
    logic [DATA_WIDTH_A-1:0] mem_A [0:NUM_A_ELEMENTS-1];
    logic computation_done_wire;

    axis_top #(
        .MEM_INIT_FILE_Q(MEM_INIT_FILE_Q),
        .MEM_INIT_FILE_K(MEM_INIT_FILE_K),
        .MEM_INIT_FILE_V(MEM_INIT_FILE_V)
    ) dut (
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
        
        .computation_done(computation_done_wire),

        .m_axis_tready(m_axis_tready),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tlast(m_axis_tlast)
    );

    task automatic send_inputs;
    begin

        s_axis_0_tvalid = 0;
        s_axis_1_tvalid = 0;

        @(posedge aclk);

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
                @(posedge aclk);
            end while(!(s_axis_0_tready && s_axis_1_tready));

        end

        @(posedge aclk);

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
        s_axis_0_tlast  = 0;
        s_axis_1_tlast  = 0;

        aresetn = 0;

        repeat(10) @(posedge aclk);

        aresetn = 1;

        repeat(5) @(posedge aclk);

        send_inputs();

        $display("[%0t] DMA transfer complete", $time);

        fork
            begin
                @(posedge m_axis_tlast);
                $display("[%0t] FINAL DONE detected", $time);
            end
            
            begin
                #20ms;
                $display("[%0t] TIMEOUT reached", $time);
            end
        join_any
        
        repeat(10) @(posedge aclk);
//        #20us
        $finish;

    end
endmodule
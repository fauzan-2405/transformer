`timescale 1ns/1ps

import linear_proj_pkg::*;

module tb_top_multwrap_bram;
    localparam MEMORY_SIZE_A = INNER_DIMENSION*A_OUTER_DIMENSION*WIDTH_A;
    localparam MEMORY_SIZE_B = INNER_DIMENSION*B_OUTER_DIMENSION*WIDTH_B;
    localparam DATA_WIDTH_A  = WIDTH_A*CHUNK_SIZE*NUM_CORES_A;
    localparam DATA_WIDTH_B  = WIDTH_B*CHUNK_SIZE*NUM_CORES_B*TOTAL_MODULES;
    localparam int ADDR_WIDTH_A = $clog2(MEMORY_SIZE_A/DATA_WIDTH_A); 
    localparam int ADDR_WIDTH_B = $clog2(MEMORY_SIZE_A/DATA_WIDTH_B); 

    // ************** Clock and Reset **************
    logic clk = 0;
    logic rst_n = 0;
    logic start = 0;

    // Clock generation
    always #5 clk = ~clk; // 100 MHz clock

    // ************** DUT I/O **************
    logic in_mat_ena, in_mat_wea;
    logic [ADDR_WIDTH_A-1:0] in_mat_wr_addra;
    logic [WIDTH_A*CHUNK_SIZE*NUM_CORES_A-1:0] in_mat_dina;

    logic in_mat_enb, in_mat_web;
    logic [ADDR_WIDTH_A-1:0] in_mat_wr_addrb;
    logic [WIDTH_A*CHUNK_SIZE*NUM_CORES_A-1:0] in_mat_dinb;

    logic w_mat_ena, w_mat_wea;
    logic [ADDR_WIDTH_B-1:0] w_mat_wr_addra;
    logic [WIDTH_B*CHUNK_SIZE*NUM_CORES_B*TOTAL_MODULES-1:0] w_mat_dina;

    logic w_mat_enb, w_mat_web;
    logic [ADDR_WIDTH_B-1:0] w_mat_wr_addrb;
    logic [WIDTH_B*CHUNK_SIZE*NUM_CORES_B*TOTAL_MODULES-1:0] w_mat_dinb;

    logic done, out_valid;
    logic [(WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A*NUM_CORES_B*TOTAL_MODULES)-1:0] out_multi_matmul [TOTAL_INPUT_W];

    // ************** Instantiate DUT **************
    top_multwrap_bram dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),

        .in_mat_ena(in_mat_ena),
        .in_mat_wea(in_mat_wea),
        .in_mat_wr_addra(in_mat_wr_addra),
        .in_mat_dina(in_mat_dina),

        .in_mat_enb(in_mat_enb),
        .in_mat_web(in_mat_web),
        .in_mat_wr_addrb(in_mat_wr_addrb),
        .in_mat_dinb(in_mat_dinb),

        .w_mat_ena(w_mat_ena),
        .w_mat_wea(w_mat_wea),
        .w_mat_wr_addra(w_mat_wr_addra),
        .w_mat_dina(w_mat_dina),

        .w_mat_enb(w_mat_enb),
        .w_mat_web(w_mat_web),
        .w_mat_wr_addrb(w_mat_wr_addrb),
        .w_mat_dinb(w_mat_dinb),

        .done(done),
        .out_valid(out_valid),
        .out_multi_matmul(out_multi_matmul)
    );

    // ************** Memory Arrays **************
    logic [WIDTH_A*CHUNK_SIZE*NUM_CORES_A-1:0] mem_A [0:(1<<ADDR_WIDTH_A)-1];
    logic [WIDTH_B*CHUNK_SIZE*NUM_CORES_B*TOTAL_MODULES-1:0] mem_B [0:(1<<ADDR_WIDTH_B)-1];

    // ************** Test Sequence **************
    initial begin
        $display("[%0t] Starting Simulation...", $time);

        // Load memory data
        $readmemb("mem_A.mem", mem_A);
        $readmemb("mem_B.mem", mem_B);

        // Initialize control signals
        in_mat_ena = 0; in_mat_wea = 0;
        in_mat_enb = 0; in_mat_web = 0;
        w_mat_ena = 0; w_mat_wea = 0;
        w_mat_enb = 0; w_mat_web = 0;

        in_mat_wr_addra = 0; in_mat_wr_addrb = 0;
        w_mat_wr_addra = 0; w_mat_wr_addrb = 0;

        rst_n = 0;
        #50;
        rst_n = 1;
        #20;

        // ************** Fill Input BRAMs (even/odd split) **************
        $display("[%0t] Writing Input BRAM (mem_A.mem)...", $time);
        in_mat_ena = 1; in_mat_enb = 1;
        in_mat_wea = 1; in_mat_web = 1;

        for (int i = 0; i < (1<<ADDR_WIDTH_A)/2; i++) begin
            @(posedge clk);
            // Port A writes even addresses
            in_mat_wr_addra = 2*i;
            in_mat_dina = mem_A[2*i];
            // Port B writes odd addresses
            in_mat_wr_addrb = 2*i + 1;
            in_mat_dinb = mem_A[2*i + 1];
        end
        @(posedge clk);
        in_mat_wea = 0; in_mat_web = 0;
        $display("[%0t] Input BRAM Write Done.", $time);

        // ************** Fill Weight BRAMs (even/odd split) **************
        $display("[%0t] Writing Weight BRAM (mem_B.mem)...", $time);
        w_mat_ena = 1; w_mat_enb = 1;
        w_mat_wea = 1; w_mat_web = 1;

        for (int j = 0; j < (1<<ADDR_WIDTH_B)/2; j++) begin
            @(posedge clk);
            // Port A writes even addresses
            w_mat_wr_addra = 2*j;
            w_mat_dina = mem_B[2*j];
            // Port B writes odd addresses
            w_mat_wr_addrb = 2*j + 1;
            w_mat_dinb = mem_B[2*j + 1];
        end
        @(posedge clk);
        w_mat_wea = 0; w_mat_web = 0;
        $display("[%0t] Weight BRAM Write Done.", $time);

        // ************** Start Computation **************
        $display("[%0t] Starting Computation Phase...", $time);
        start = 1;
        @(posedge clk);
        start = 0;

        // ************** Wait for Completion **************
        wait(done);
        $display("[%0t] Computation Done!", $time);

        // ************** Display Output **************
        for (int k = 0; k < TOTAL_INPUT_W; k++) begin
            $display("Output block %0d:", k);
            for (int m = 0; m < WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A*NUM_CORES_B*TOTAL_MODULES; m++) begin
                $write("%b", out_multi_matmul[k][m]);
            end
            $display("\n");
        end

        #50;
        $display("[%0t] Simulation Complete.", $time);
        $finish;
    end

endmodule

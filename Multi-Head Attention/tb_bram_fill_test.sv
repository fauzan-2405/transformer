// ==========================================================
// tb_bram_fill_test.sv
// ==========================================================
`timescale 1ns/1ps
import linear_proj_pkg::*;

module tb_bram_fill_test;
    localparam MEMORY_SIZE_A = INNER_DIMENSION*A_OUTER_DIMENSION*WIDTH_A;
    localparam MEMORY_SIZE_B = INNER_DIMENSION*B_OUTER_DIMENSION*WIDTH_B;
    localparam DATA_WIDTH_A  = WIDTH_A*CHUNK_SIZE*NUM_CORES_A;
    localparam DATA_WIDTH_B  = WIDTH_B*CHUNK_SIZE*NUM_CORES_B*TOTAL_MODULES;
    localparam int ADDR_WIDTH_A = $clog2(MEMORY_SIZE_A/DATA_WIDTH_A);
    localparam int ADDR_WIDTH_B = $clog2(MEMORY_SIZE_B/DATA_WIDTH_B);

    // Clock/reset
    logic clk = 0; always #5 clk = ~clk;
    logic rst_n = 0;

    // DUT I/O
    logic in_mat_ena, in_mat_wea;
    logic [ADDR_WIDTH_A-1:0] in_mat_wr_addra;
    logic [DATA_WIDTH_A-1:0] in_mat_dina;
    logic in_mat_enb, in_mat_web;
    logic [ADDR_WIDTH_A-1:0] in_mat_wr_addrb;
    logic [DATA_WIDTH_A-1:0] in_mat_dinb;
    logic w_mat_ena, w_mat_wea;
    logic [ADDR_WIDTH_B-1:0] w_mat_wr_addra;
    logic [DATA_WIDTH_B-1:0] w_mat_dina;
    logic w_mat_enb, w_mat_web;
    logic [ADDR_WIDTH_B-1:0] w_mat_wr_addrb;
    logic [DATA_WIDTH_B-1:0] w_mat_dinb;
    logic write_phase_done;
    logic [DATA_WIDTH_A-1:0] in_read_a, in_read_b;
    logic [DATA_WIDTH_B-1:0] w_read_b;

    // Instantiate DUT
    bram_fill_test dut (
        .clk(clk), .rst_n(rst_n),
        .in_mat_ena(in_mat_ena), .in_mat_wea(in_mat_wea),
        .in_mat_wr_addra(in_mat_wr_addra), .in_mat_dina(in_mat_dina),
        .in_mat_enb(in_mat_enb), .in_mat_web(in_mat_web),
        .in_mat_wr_addrb(in_mat_wr_addrb), .in_mat_dinb(in_mat_dinb),
        .w_mat_ena(w_mat_ena), .w_mat_wea(w_mat_wea),
        .w_mat_wr_addra(w_mat_wr_addra), .w_mat_dina(w_mat_dina),
        .w_mat_enb(w_mat_enb), .w_mat_web(w_mat_web),
        .w_mat_wr_addrb(w_mat_wr_addrb), .w_mat_dinb(w_mat_dinb),
        .write_phase_done(write_phase_done),
        .in_read_a(in_read_a), .in_read_b(in_read_b), .w_read_b(w_read_b)
    );

    // Local memories for test data
    logic [DATA_WIDTH_A-1:0] mem_A [0:NUM_A_ELEMENTS-1];
    logic [DATA_WIDTH_B-1:0] mem_B [0:NUM_B_ELEMENTS-1];

    initial begin
        $display("[%0t] Starting BRAM fill test...", $time);
        $readmemb("mem_A.mem", mem_A);
        $readmemb("mem_B.mem", mem_B);

        // Reset
        rst_n = 0;
        {in_mat_ena,in_mat_enb,w_mat_ena,w_mat_enb} = 0;
        {in_mat_wea,in_mat_web,w_mat_wea,w_mat_web} = 0;
        #30; rst_n = 1;

        // --- Fill Input BRAM ---
        $display("[%0t] Writing Input BRAM", $time);
        in_mat_ena = 1; in_mat_enb = 1; in_mat_wea = 1; in_mat_web = 1;
        for (int i=0; i<(NUM_A_ELEMENTS+1)/2; i++) begin
            @(posedge clk);
            in_mat_wr_addra = 2*i;
            in_mat_wr_addrb = 2*i+1;
            in_mat_dina = mem_A[2*i];
            in_mat_dinb = mem_A[2*i+1];
        end
        @(posedge clk);
        in_mat_wea = 0; in_mat_web = 0;

        // --- Fill Weight BRAM ---
        $display("[%0t] Writing Weight BRAM", $time);
        w_mat_ena = 1; w_mat_enb = 1; w_mat_wea = 1; w_mat_web = 1;
        for (int j=0; j<(NUM_B_ELEMENTS+1)/2; j++) begin
            @(posedge clk);
            w_mat_wr_addra = 2*j;
            w_mat_wr_addrb = 2*j+1;
            w_mat_dina = mem_B[2*j];
            w_mat_dinb = mem_B[2*j+1];
        end
        @(posedge clk);
        w_mat_wea = 0; w_mat_web = 0;
        $display("[%0t] Write phase complete.", $time);

        // --- Trigger read phase ---
        dut.state <= dut.WAIT;
        repeat (3) @(posedge clk);

        // --- Observe readback for a few cycles ---
        for (int k=0; k<10; k++) begin
            @(posedge clk);
            $display("[%0t] ReadBack A=%b B=%b W=%b", $time, in_read_a, in_read_b, w_read_b);
        end

        $display("[%0t] BRAM test complete.", $time);
        #20; $finish;
    end
endmodule

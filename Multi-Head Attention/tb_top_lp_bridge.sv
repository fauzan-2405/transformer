`timescale 1ns/1ps

import linear_proj_pkg::*;
import self_attention_pkg::*;

module tb_top_lp_bridge;

    // ============================================================
    // Localparams (match packages)
    // ============================================================
    localparam MEMORY_SIZE_A  = INNER_DIMENSION * A_OUTER_DIMENSION * WIDTH_A;
    localparam DATA_WIDTH_A  = WIDTH_A * CHUNK_SIZE * NUM_CORES_A;
    localparam OUT_KEYS      = WIDTH_OUT*CHUNK_SIZE*
                              NUM_CORES_A*NUM_CORES_B*TOTAL_MODULES;
    localparam int ADDR_WIDTH_A = $clog2(MEMORY_SIZE_A / DATA_WIDTH_A);

    // ============================================================
    // Clock & Reset
    // ============================================================
    logic clk = 0;
    logic rst_n = 0;

    always #5 clk = ~clk;   // 100 MHz

    // ============================================================
    // DUT inputs
    // ============================================================
    logic in_mat_ena, in_mat_wea;
    logic [ADDR_WIDTH_A-1:0] in_mat_wr_addra;
    logic [DATA_WIDTH_A-1:0] in_mat_dina;

    logic in_mat_enb, in_mat_web;
    logic [ADDR_WIDTH_A-1:0] in_mat_wr_addrb;
    logic [DATA_WIDTH_A-1:0] in_mat_dinb;

    // ============================================================
    // DUT outputs
    // ============================================================
    logic [
        (WIDTH_OUT*CHUNK_SIZE*
         NUM_CORES_A_Qn_KnT*
         NUM_CORES_B_Qn_KnT*
         TOTAL_MODULES_LP_Q)-1:0
    ] out_lp_bridge [TOTAL_INPUT_W];

    // ============================================================
    // Memory for stimulus
    // ============================================================
    logic [DATA_WIDTH_A-1:0] mem_A [0:NUM_A_ELEMENTS-1];

    // ============================================================
    // DUT
    // ============================================================
    top_lp_bridge #(
        .OUT_KEYS(OUT_KEYS),
        .NUMBER_OF_BUFFER_INSTANCES(1)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),

        .in_mat_ena(in_mat_ena),
        .in_mat_wea(in_mat_wea),
        .in_mat_wr_addra(in_mat_wr_addra),
        .in_mat_dina(in_mat_dina),

        .in_mat_enb(in_mat_enb),
        .in_mat_web(in_mat_web),
        .in_mat_wr_addrb(in_mat_wr_addrb),
        .in_mat_dinb(in_mat_dinb),

        .out_lp_bridge(out_lp_bridge)
    );

    // ============================================================
    // Test sequence
    // ============================================================
    initial begin
        $display("[%0t] TB start", $time);

        // Load input matrix
        $readmemb("mem_A.mem", mem_A);

        // Default values
        in_mat_ena = 0; in_mat_wea = 0;
        in_mat_enb = 0; in_mat_web = 0;
        in_mat_wr_addra = '0;
        in_mat_wr_addrb = '0;
        in_mat_dina = '0;
        in_mat_dinb = '0;

        // Reset
        rst_n = 0;
        repeat (10) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // ========================================================
        // Write input BRAM (dual-port even/odd)
        // ========================================================
        $display("[%0t] Writing input BRAM...", $time);
        in_mat_ena = 1; in_mat_enb = 1;
        in_mat_wea = 1; in_mat_web = 1;

        for (int i = 0; i < (NUM_A_ELEMENTS + 1)/2; i++) begin
            @(posedge clk);

            // Port A: even
            in_mat_wr_addra <= 2*i;
            in_mat_dina     <= mem_A[2*i];

            // Port B: odd
            if (2*i + 1 < NUM_A_ELEMENTS) begin
                in_mat_wr_addrb <= 2*i + 1;
                in_mat_dinb     <= mem_A[2*i + 1];
            end else begin
                in_mat_wr_addrb <= NUM_A_ELEMENTS - 1;
                in_mat_dinb     <= mem_A[NUM_A_ELEMENTS - 1];
            end
        end

        @(posedge clk);
        in_mat_wea = 0; in_mat_web = 0;
        in_mat_ena = 0; in_mat_enb = 0;
        $display("[%0t] Input write done", $time);

        // ========================================================
        // Observe pipeline
        // ========================================================
        $display("[%0t] Waiting for pipeline activity...", $time);
        repeat (2000) @(posedge clk);

        // Dump some outputs
        for (int t = 0; t < TOTAL_INPUT_W; t++) begin
            $display("out_lp_bridge[%0d] = %h", t, out_lp_bridge[t]);
        end

        $display("[%0t] TB finished", $time);
        $finish;
    end

endmodule

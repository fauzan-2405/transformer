`timescale 1ns/1ps

import linear_proj_pkg::*;
import self_attention_pkg::*;

module tb_multihead_attention;

    // ============================================================
    // Localparams (match packages)
    // ============================================================
    localparam MEMORY_SIZE_A  = INNER_DIMENSION * A_OUTER_DIMENSION * WIDTH_A;
    localparam DATA_WIDTH_A  = WIDTH_A * CHUNK_SIZE * NUM_CORES_A;
    localparam OUT_KEYS      = WIDTH_OUT*CHUNK_SIZE*
                              NUM_CORES_A*NUM_CORES_B*TOTAL_MODULES;
    localparam int ADDR_WIDTH_A = $clog2(MEMORY_SIZE_A / DATA_WIDTH_A);
    localparam TOTAL_SOFTMAX_ROW = NUM_CORES_A_Qn_KnT * BLOCK_SIZE;
    localparam NUMBER_OF_BUFFER_INSTANCES = 1;

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
    // DUT outputs (CAN BE EDITED)
    // ============================================================
    //logic [TILE_SIZE_SOFTMAX*WIDTH_OUT-1:0] out_softmax_data [NUMBER_OF_BUFFER_INSTANCES][TOTAL_INPUT_W_Qn_KnT][TOTAL_SOFTMAX_ROW];
    //logic out_softmax_valid [NUMBER_OF_BUFFER_INSTANCES][TOTAL_INPUT_W_Qn_KnT][TOTAL_SOFTMAX_ROW];
    logic [WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A_QKT_Vn-1:0] out_data_r2b [NUMBER_OF_BUFFER_INSTANCES][TOTAL_INPUT_W_Qn_KnT][TOTAL_TILE_SOFTMAX];

    // ============================================================
    // Memory for stimulus
    // ============================================================
    logic [DATA_WIDTH_A-1:0] mem_A [0:NUM_A_ELEMENTS-1];

    // ============================================================
    // DUT
    // ============================================================
    multihead_attention #(
        .OUT_KEYS(OUT_KEYS),
        .NUMBER_OF_BUFFER_INSTANCES(NUMBER_OF_BUFFER_INSTANCES1)
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
        
        // Temporary output to see the intermediate results
        //.out_softmax_data(out_softmax_data),
        //.out_softmax_valid(out_softmax_valid)
        .out_data_r2b(out_data_r2b)
    );

    // ============================================================
    // Test sequence
    // ============================================================
    initial begin
        $display("[%0t] TB start", $time);

        // Load input matrix
        $readmemh("mat_A_lp_bridge.mem", mem_A);

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

        $finish;
    end

endmodule

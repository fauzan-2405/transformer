// tb_top_linear_projection.sv
`timescale 1ns/1ps

import linear_proj_pkg::*;

module tb_top_linear_projection;
    // localparams (match your package params)
    localparam MEMORY_SIZE_A = INNER_DIMENSION * A_OUTER_DIMENSION * WIDTH_A;
    localparam DATA_WIDTH_A   = WIDTH_A * CHUNK_SIZE * NUM_CORES_A;
    localparam OUT_KEYS      = WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A*NUM_CORES_B*TOTAL_MODULES;
    localparam int ADDR_WIDTH_A = $clog2(MEMORY_SIZE_A / DATA_WIDTH_A);

    // ************** Clock and Reset **************
    logic clk = 0;
    logic rst_n = 0;

    // simple 100 MHz clock
    always #5 clk = ~clk;

    // ************** DUT I/O signals **************
    logic in_mat_ena, in_mat_wea;
    logic [ADDR_WIDTH_A-1:0] in_mat_wr_addra;
    logic [DATA_WIDTH_A-1:0] in_mat_dina;

    logic in_mat_enb, in_mat_web;
    logic [ADDR_WIDTH_A-1:0] in_mat_wr_addrb;
    logic [DATA_WIDTH_A-1:0] in_mat_dinb;

    // Outputs from DUT (Q/K/V arrays)
    logic [(OUT_KEYS)-1:0] out_q1 [TOTAL_INPUT_W];
    logic [(OUT_KEYS)-1:0] out_q2 [TOTAL_INPUT_W];
    logic [(OUT_KEYS)-1:0] out_q3 [TOTAL_INPUT_W];
    logic [(OUT_KEYS)-1:0] out_q4 [TOTAL_INPUT_W];

    logic [(OUT_KEYS)-1:0] out_k1 [TOTAL_INPUT_W];
    logic [(OUT_KEYS)-1:0] out_k2 [TOTAL_INPUT_W];
    logic [(OUT_KEYS)-1:0] out_k3 [TOTAL_INPUT_W];
    logic [(OUT_KEYS)-1:0] out_k4 [TOTAL_INPUT_W];

    logic [(OUT_KEYS)-1:0] out_v1 [TOTAL_INPUT_W];
    logic [(OUT_KEYS)-1:0] out_v2 [TOTAL_INPUT_W];
    logic [(OUT_KEYS)-1:0] out_v3 [TOTAL_INPUT_W];
    logic [(OUT_KEYS)-1:0] out_v4 [TOTAL_INPUT_W];

    logic out_valid;
    logic done;

    // ************** Memory Array (for loading from file) **************
    // mem_A length should be NUM_A_ELEMENTS (defined in your package)
    logic [DATA_WIDTH_A-1:0] mem_A [0:NUM_A_ELEMENTS-1];

    // ************** Instantiate DUT **************
    top_linear_projection dut (
        .clk(clk),
        .rst_n(rst_n),

        // writer side signals (we'll toggle these in TB)
        .in_mat_ena(in_mat_ena),
        .in_mat_wea(in_mat_wea),
        .in_mat_wr_addra(in_mat_wr_addra),
        .in_mat_dina(in_mat_dina),

        .in_mat_enb(in_mat_enb),
        .in_mat_web(in_mat_web),
        .in_mat_wr_addrb(in_mat_wr_addrb),
        .in_mat_dinb(in_mat_dinb),

        // projection outputs
        .out_q1(out_q1),
        .out_q2(out_q2),
        .out_q3(out_q3),
        .out_q4(out_q4),

        .out_k1(out_k1),
        .out_k2(out_k2),
        .out_k3(out_k3),
        .out_k4(out_k4),

        .out_v1(out_v1),
        .out_v2(out_v2),
        .out_v3(out_v3),
        .out_v4(out_v4),

        .out_valid(out_valid),
        .done(done)
    );

    // ************** Test Sequence **************
    initial begin
        $display("[%0t] Testbench: start", $time);

        // Load input memory file (binary values)
        // mem_A.mem must contain NUM_A_ELEMENTS lines, each DATA_WIDTH_A wide in binary
        $readmemb("mem_A.mem", mem_A);

        // initialize controls
        in_mat_ena = 0; in_mat_wea = 0;
        in_mat_enb = 0; in_mat_web = 0;
        in_mat_wr_addra = '0;
        in_mat_wr_addrb = '0;
        in_mat_dina = '0;
        in_mat_dinb = '0;

        // reset pulse
        rst_n = 0;
        repeat (10) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // ************** Fill Input BRAMs (even/odd split) **************
        $display("[%0t] Writing Input BRAM from mem_A.mem...", $time);
        in_mat_ena = 1; in_mat_enb = 1;
        in_mat_wea = 1; in_mat_web = 1;

        // write pairs (port A even, port B odd)
        for (int i = 0; i < (NUM_A_ELEMENTS + 1) / 2; i++) begin
            @(posedge clk);
            // Port A writes even address 2*i
            in_mat_wr_addra <= 2*i;
            in_mat_dina <= mem_A[2*i];

            // Port B writes odd address 2*i+1 if within range, otherwise write last element
            if (2*i + 1 < NUM_A_ELEMENTS) begin
                in_mat_wr_addrb <= 2*i + 1;
                in_mat_dinb <= mem_A[2*i + 1];
            end else begin
                // write a safe default if mem_A index would overflow
                in_mat_wr_addrb <= NUM_A_ELEMENTS - 1;
                in_mat_dinb <= mem_A[NUM_A_ELEMENTS - 1];
            end
        end

        // finish writes
        @(posedge clk);
        in_mat_wea = 0; in_mat_web = 0;
        in_mat_ena = 0; in_mat_enb = 0;
        $display("[%0t] Input BRAM write complete.", $time);

        // Allow a few cycles for controller detection and start of compute
        // Controller in your top checks address A >= NUM_A_ELEMENTS-2 to start en_module
        // so give a couple clocks
        repeat (10) @(posedge clk);

        // Wait for done
        wait (done == 1);
        $display("[%0t] Computation Done!", $time);

        // Print outputs (Q/K/V) per TOTAL_INPUT_W
        $display("=== Outputs ===");
        // Q
        for (int t = 0; t < TOTAL_INPUT_W; t++) begin
            $display("out_q1[%0d] = %b", t, out_q1[t]);
            $display("out_q2[%0d] = %b", t, out_q2[t]);
            $display("out_q3[%0d] = %b", t, out_q3[t]);
            $display("out_q4[%0d] = %b", t, out_q4[t]);
        end
        // K
        for (int t = 0; t < TOTAL_INPUT_W; t++) begin
            $display("out_k1[%0d] = %b", t, out_k1[t]);
            $display("out_k2[%0d] = %b", t, out_k2[t]);
            $display("out_k3[%0d] = %b", t, out_k3[t]);
            $display("out_k4[%0d] = %b", t, out_k4[t]);
        end
        // V
        for (int t = 0; t < TOTAL_INPUT_W; t++) begin
            $display("out_v1[%0d] = %b", t, out_v1[t]);
            $display("out_v2[%0d] = %b", t, out_v2[t]);
            $display("out_v3[%0d] = %b", t, out_v3[t]);
            $display("out_v4[%0d] = %b", t, out_v4[t]);
        end

        $display("[%0t] Testbench finished.", $time);
        #100 
        $finish;
    end

endmodule

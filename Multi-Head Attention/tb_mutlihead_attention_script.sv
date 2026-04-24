// TO DO: STEP 3 on the GPT

`timescale 1ns/1ps

import linear_proj_pkg::*;
import self_attention_pkg::*;

module tb_multihead_attention_script;
    string OUT_DIR;
    string MEM_INPUT_PATH;
    string MEM_Q_FILE;
    string MEM_K_FILE;
    string MEM_V_FILE;

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
    
    /*
    parameter MEM_INPUT_MAT   = "mat_A_lp_bridge.mem";
    parameter MEM_INIT_FILE_Q = "mat_B_lp_bridge.mem";
    parameter MEM_INIT_FILE_K = "mat_B_lp_bridge.mem";
    parameter MEM_INIT_FILE_V = "mat_B_lp_bridge.mem";*/

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
    logic [OUT_KEYS-1:0] out_Q_matrix [TOTAL_INPUT_W];
    logic [OUT_KEYS-1:0] out_K_matrix [TOTAL_INPUT_W]; 
    logic [OUT_KEYS-1:0] out_V_matrix [TOTAL_INPUT_W];
    logic linproj_valid, linproj_done;
    
    logic [(WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A_Qn_KnT*NUM_CORES_B_Qn_KnT*TOTAL_MODULES_LP_Q)-1:0]
        out_matmul_Qn_KnT [NUMBER_OF_BUFFER_INSTANCES][TOTAL_INPUT_W_Qn_KnT];
    logic out_Qn_KnT_valid;
    logic Qn_KnT_done;
    
    logic [(WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A_QKT_Vn*NUM_CORES_B_QKT_Vn*TOTAL_MODULES_LP_V)-1:0]
        out_matmul_QKT_Vn [NUMBER_OF_BUFFER_INSTANCES][TOTAL_INPUT_W_Qn_KnT];
    logic out_QKT_Vn_valid;
    logic QKT_Vn_done;
    
    //logic [TILE_SIZE_SOFTMAX*WIDTH_OUT-1:0] out_softmax_data [NUMBER_OF_BUFFER_INSTANCES][TOTAL_INPUT_W_Qn_KnT][TOTAL_SOFTMAX_ROW];
    //logic out_softmax_valid [NUMBER_OF_BUFFER_INSTANCES][TOTAL_INPUT_W_Qn_KnT][TOTAL_SOFTMAX_ROW];
    //logic [WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A_QKT_Vn-1:0] out_data_r2b [NUMBER_OF_BUFFER_INSTANCES][TOTAL_INPUT_W_Qn_KnT][TOTAL_TILE_SOFTMAX];
    //logic [(WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A_QKT_Vn)-1:0] out_data_fifo [TOTAL_INPUT_W_Qn_KnT][NUM_BANKS_FIFO];


    // ============================================================
    // Memory for stimulus
    // ============================================================
    logic [DATA_WIDTH_A-1:0] mem_A [0:NUM_A_ELEMENTS-1];
    logic linproj_done_seen = 0;
    logic qkt_done_seen     = 0;
    logic final_done_seen   = 0;

    // ============================================================
    // DUT
    // ============================================================
    // Weight
    initial begin
        if (!$value$plusargs("MEM_Q=%s", MEM_Q_FILE)) begin
            MEM_Q_FILE = "mat_B_lp_bridge.mem";
        end
        if (!$value$plusargs("MEM_K=%s", MEM_K_FILE)) begin
            MEM_K_FILE = "mat_B_lp_bridge.mem";
        end
        if (!$value$plusargs("MEM_V=%s", MEM_V_FILE)) begin
            MEM_V_FILE = "mat_B_lp_bridge.mem";
        end
    end

    multihead_attention #(
        .MEM_INIT_FILE_Q(MEM_Q_FILE),
        .MEM_INIT_FILE_K(MEM_K_FILE),
        .MEM_INIT_FILE_V(MEM_V_FILE),
        .OUT_KEYS(OUT_KEYS),
        .NUMBER_OF_BUFFER_INSTANCES(NUMBER_OF_BUFFER_INSTANCES)
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
        
        // Output
        .out_Q_matrix(out_Q_matrix),
        .out_K_matrix(out_K_matrix),
        .out_V_matrix(out_V_matrix),
        .linproj_valid(linproj_valid), 
        .linproj_done(linproj_done),
        
        .out_matmul_Qn_KnT(out_matmul_Qn_KnT),
        .out_Qn_KnT_valid(out_Qn_KnT_valid),
        .Qn_KnT_done(Qn_KnT_done),
        
        .out_matmul_QKT_Vn(out_matmul_QKT_Vn),
        .out_QKT_Vn_valid(out_QKT_Vn_valid),
        .QKT_Vn_done(QKT_Vn_done)
        
        // Temporary output to see the intermediate results
        //.out_softmax_data(out_softmax_data),
        //.out_softmax_valid(out_softmax_valid)
        //.out_data_r2b(out_data_r2b)
        //.out_data_fifo(out_data_fifo)
    );

    // ============================================================
    // Test sequence
    // ============================================================
    initial begin
        $display("[%0t] TB start", $time);

        // Load input matrix
        if (!$value$plusargs("INPUT_FILE=%s", MEM_INPUT_PATH)) begin
            MEM_INPUT_PATH = "mat_A_lp_bridge.mem";
        end

        $display("[TB] Input file = %s", MEM_INPUT_PATH);
        $readmemh(MEM_INPUT_PATH, mem_A);

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
        wait(QKT_Vn_done);
        repeat(10) @(posedge clk);
        $display("Simulation finished cleanly");
        $finish;
    end

    // ========================================================
    // Linear Projection
    // ========================================================
    integer f_q, f_k, f_v;

    initial begin
        if (!$value$plusargs("OUT_DIR=%s", OUT_DIR)) begin
            OUT_DIR = "./";  // fallback
        end

        $display("[TB] Output directory = %s", OUT_DIR);

        f_q = $fopen({OUT_DIR, "/out_Q.mem"}, "w");
        f_k = $fopen({OUT_DIR, "/out_K.mem"}, "w");
        f_v = $fopen({OUT_DIR, "/out_V.mem"}, "w");
        f_qkt = $fopen({OUT_DIR, "/out_QKT.mem"}, "w");
        f_final = $fopen({OUT_DIR, "/out_FINAL.mem"}, "w");
    end

    always @(posedge clk) begin
        if (rst_n && linproj_valid && !linproj_done_seen) begin
            for (int iw = 0; iw < TOTAL_INPUT_W; iw++) begin
                for (int k = 0; k < OUT_KEYS; k += WIDTH_OUT) begin
                    $fwrite(f_q, "%h ", out_Q_matrix[iw][k +: WIDTH_OUT]);
                    $fwrite(f_k, "%h ", out_K_matrix[iw][k +: WIDTH_OUT]);
                    $fwrite(f_v, "%h ", out_V_matrix[iw][k +: WIDTH_OUT]);
                end
            end
            $fwrite(f_q, "\n");
            $fwrite(f_k, "\n");
            $fwrite(f_v, "\n");
        end

        //  STOP CONDITION
        if (linproj_done && !linproj_done_seen) begin
            linproj_done_seen <= 1;
            $display("[%0t] Linear Projection DONE → stop dumping", $time);

            $fclose(f_q);
            $fclose(f_k);
            $fclose(f_v);
        end
    end

    // ========================================================
    // QKT Calculation
    // ========================================================
    integer f_qkt;
    
    always @(posedge clk) begin
        if (rst_n && out_Qn_KnT_valid && !qkt_done_seen) begin
            for (int iw = 0; iw < TOTAL_INPUT_W_Qn_KnT; iw++) begin
                for (int l = 0; l < WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A_Qn_KnT*NUM_CORES_B_Qn_KnT*TOTAL_MODULES_LP_Q;
                    l += WIDTH_OUT) begin
                    $fwrite(f_qkt, "%h ",
                        out_matmul_Qn_KnT[0][iw][l +: WIDTH_OUT]);
                end
            end
            $fwrite(f_qkt, "\n");
        end

        if (Qn_KnT_done && !qkt_done_seen) begin
            qkt_done_seen <= 1;
            $display("[%0t] QK^T DONE → stop dumping", $time);
            $fclose(f_qkt);
        end
    end

    // ========================================================
    // Final Calculation
    // ========================================================
    integer f_final;

    always @(posedge clk) begin
        if (rst_n && out_QKT_Vn_valid && !final_done_seen) begin
            for (int iw = 0; iw < TOTAL_INPUT_W_Qn_KnT; iw++) begin
                for (int l = 0; l < WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A_QKT_Vn*NUM_CORES_B_QKT_Vn*TOTAL_MODULES_LP_V;
                    l += WIDTH_OUT) begin
                    $fwrite(f_final, "%h ",
                        out_matmul_QKT_Vn[0][iw][l +: WIDTH_OUT]);
                end
            end
            $fwrite(f_final, "\n");
        end

        if (QKT_Vn_done && !final_done_seen) begin
            final_done_seen <= 1;
            $display("[%0t] FINAL DONE → stop dumping", $time);
            $fclose(f_final);
        end
    end

endmodule


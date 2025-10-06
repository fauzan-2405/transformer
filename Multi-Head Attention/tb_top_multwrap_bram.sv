`timescale 1ns/1ps

import linear_proj_pkg::*;

module tb_top_multwrap_bram;

    // Clock & Reset
    logic clk;
    logic rst_n;
    logic start;

    // For input matrix BRAM
    logic in_mat_ena, in_mat_wea, in_mat_enb, in_mat_web;
    logic [ADDR_WIDTH_A-1:0] in_mat_wr_addra, in_mat_wr_addrb;
    logic [WIDTH_A*CHUNK_SIZE*NUM_CORES_A-1:0] in_mat_dina, in_mat_dinb;

    // For weight matrix BRAM
    logic w_mat_ena, w_mat_wea, w_mat_enb, w_mat_web;
    logic [ADDR_WIDTH_B-1:0] w_mat_wr_addra, w_mat_wr_addrb;
    logic [WIDTH_B*CHUNK_SIZE*NUM_CORES_B*TOTAL_MODULES-1:0] w_mat_dina, w_mat_dinb;

    // Outputs
    logic done, out_valid;
    logic [(WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A*NUM_CORES_B*TOTAL_MODULES)-1:0] out_multi_matmul [TOTAL_INPUT_W];

    // Instantiate DUT
    top_multwrap_bram uut (
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

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk; // 100 MHz clock

    // Randomization helper function (returns logic vector)
    function automatic [WIDTH_A*CHUNK_SIZE*NUM_CORES_A-1:0] random_input_A();
        for (int i = 0; i < WIDTH_A*CHUNK_SIZE*NUM_CORES_A; i++)
            random_input_A[i] = $urandom_range(0, 1);
    endfunction

    function automatic [WIDTH_B*CHUNK_SIZE*NUM_CORES_B*TOTAL_MODULES-1:0] random_input_B();
        for (int i = 0; i < WIDTH_B*CHUNK_SIZE*NUM_CORES_B*TOTAL_MODULES; i++)
            random_input_B[i] = $urandom_range(0, 1);
    endfunction

    // Main stimulus
    initial begin
        // Initial state
        rst_n = 0;
        start = 0;
        in_mat_ena = 0; in_mat_enb = 0;
        in_mat_wea = 0; in_mat_web = 0;
        w_mat_ena = 0; w_mat_enb = 0;
        w_mat_wea = 0; w_mat_web = 0;

        in_mat_wr_addra = 0;
        in_mat_wr_addrb = 0;
        w_mat_wr_addra = 0;
        w_mat_wr_addrb = 0;

        in_mat_dina = 0;
        in_mat_dinb = 0;
        w_mat_dina = 0;
        w_mat_dinb = 0;

        // Reset pulse
        #50;
        rst_n = 1;
        #20;

        // ************** Fill Input BRAM *****************
        $display("Writing Input Matrix BRAM...");
        in_mat_ena = 1; in_mat_enb = 1;
        in_mat_wea = 1; in_mat_web = 1;
        for (int i = 0; i < (1<<ADDR_WIDTH_A); i++) begin
            @(posedge clk);
            in_mat_wr_addra = i;
            in_mat_wr_addrb = i;
            in_mat_dina = random_input_A();
            in_mat_dinb = random_input_A();
        end
        @(posedge clk);
        in_mat_wea = 0; in_mat_web = 0;
        $display("Input Matrix BRAM Write Complete.");

        // ************** Fill Weight BRAM *****************
        $display("Writing Weight Matrix BRAM...");
        w_mat_ena = 1; w_mat_enb = 1;
        w_mat_wea = 1; w_mat_web = 1;
        for (int j = 0; j < (1<<ADDR_WIDTH_B); j++) begin
            @(posedge clk);
            w_mat_wr_addra = j;
            w_mat_wr_addrb = j;
            w_mat_dina = random_input_B();
            w_mat_dinb = random_input_B();
        end
        @(posedge clk);
        w_mat_wea = 0; w_mat_web = 0;
        $display("Weight Matrix BRAM Write Complete.");

        // ************** Start Computation ***************
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
        $display("Computation Started...");

        // Wait for 'done'
        wait (done == 1);
        $display("Computation Done!");

        // ************** Display Output ******************
        for (int k = 0; k < TOTAL_INPUT_W; k++) begin
            $display("Output %0d: %h", k, out_multi_matmul[k]);
        end

        #100;
        $finish;
    end

endmodule

`timescale 1ns / 1ps

module tb_top_matmul;

    parameter WIDTH = 16;
    parameter FRAC_WIDTH = 8;
    parameter BLOCK_SIZE = 2;
    parameter CHUNK_SIZE = 4;
    parameter I_ROWS = 12;
    parameter W_COLS = 6;
    parameter INNER_DIM = 8;

    parameter NUM_CORES = 2;

    // DUT ports
    reg clk, rst_n, en_top_matmul;
    reg input_i_valid, input_w_valid;
    wire out_matmul_ready, out_matmul_done, out_matmul_last;
    wire [WIDTH*W_COLS-1:0] out_matmul_data;

    reg [WIDTH*INNER_DIM-1:0] input_i;
    reg [WIDTH*W_COLS-1:0]    input_w;

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // Instantiate DUT
    top_matmul #(
        .WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH),
        .BLOCK_SIZE(BLOCK_SIZE), .CHUNK_SIZE(CHUNK_SIZE),
        .I_OUTER_DIMENSION(I_ROWS), .W_OUTER_DIMENSION(W_COLS),
        .INNER_DIMENSION(INNER_DIM)
    ) dut (
        .clk(clk), .rst_n(rst_n), .en_top_matmul(en_top_matmul),
        .input_i_valid(input_i_valid), .input_i(input_i),
        .input_w_valid(input_w_valid), .input_w(input_w),
        .out_matmul_ready(out_matmul_ready),
        .out_matmul_last(out_matmul_last),
        .out_matmul_done(out_matmul_done),
        .out_matmul_data(out_matmul_data)
    );

    // Random Q8.8 values: 0.0 or 1.0
    function [15:0] random_q8_8;
        input dummy;
        begin
            if ($urandom_range(0,1) == 1)
                random_q8_8 = 16'h0100; // 1.0 in Q8.8
            else
                random_q8_8 = 16'h0000; // 0.0 in Q8.8
        end
    endfunction

    // Stimulus
    integer i, j;
    initial begin
        $display("Starting top_matmul testbench...");

        rst_n = 0;
        en_top_matmul = 0;
        input_i_valid = 0;
        input_w_valid = 0;
        input_i = 0;
        input_w = 0;
        #20;

        rst_n = 1;
        en_top_matmul = 1;
        #10;

        // === Feed weight matrix: 8 rows of 6 cols ===
        for (i = 0; i < INNER_DIM; i = i + 1) begin
            input_w_valid = 1;
            for (j = 0; j < W_COLS; j = j + 1)
                input_w[j*WIDTH +: WIDTH] = random_q8_8(0);
            #10;
        end
        input_w_valid = 0;

        // === Feed input matrix: 12 rows of 8 cols ===
        for (i = 0; i < I_ROWS; i = i + 1) begin
            input_i_valid = 1;
            for (j = 0; j < INNER_DIM; j = j + 1)
                input_i[j*WIDTH +: WIDTH] = random_q8_8(0);
            #10;
        end
        input_i_valid = 0;

        // === Wait for output ===
        wait(out_matmul_done);
        $display("Matrix multiplication done.");
        #20;
        $finish;
    end

    // Output Monitor
    always @(posedge clk) begin
        if (out_matmul_ready) begin
            $write("Output at %0t ns => ", $time);
            for (j = 0; j < W_COLS; j = j + 1)
                $write("%0d ", $signed(out_matmul_data[WIDTH*(W_COLS-j)-1 -: WIDTH]) >>> FRAC_WIDTH);
            $write("\n");
        end
    end

endmodule


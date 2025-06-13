`timescale 1ns / 1ps

module tb_b2r_buffer;

    // === Parameters ===
    parameter WIDTH         = 16;
    parameter FRAC_WIDTH    = 8;
    parameter ROW           = 8;
    parameter COL           = 6;
    parameter BLOCK_SIZE    = 2;
    parameter NUM_CORES     = 2;

    localparam ELEM_PER_INPUT = BLOCK_SIZE * NUM_CORES;
    localparam IN_WIDTH       = WIDTH * ELEM_PER_INPUT;
    localparam OUT_WIDTH      = WIDTH * COL;
    localparam TOTAL_ELEM     = ROW * COL;

    // === Signals ===
    reg clk, rst, start;
    reg top_valid;
    reg [IN_WIDTH-1:0] top_data;
    reg row_ready;

    wire row_valid;
    wire [OUT_WIDTH-1:0] row_data;
    wire done;

    // === DUT Instantiation ===
    b2r_converter #(
        .WIDTH(WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH),
        .ROW(ROW),
        .COL(COL),
        .BLOCK_SIZE(BLOCK_SIZE),
        .NUM_CORES(NUM_CORES)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .top_valid(top_valid),
        .top_data(top_data),
        .row_ready(row_ready),
        .row_valid(row_valid),
        .row_data(row_data),
        .done(done)
    );

    // === Clock Generation ===
    always #5 clk = ~clk;

    // === Simulation Data ===
    reg [WIDTH-1:0] test_input [0:TOTAL_ELEM-1];
    integer i, j, k, idx;

    initial begin
        $display("==== Vivado Simulation of r2n_buffer (Sequential Data) ====");
        clk = 0;
        rst = 1;
        start = 0;
        top_valid = 0;
        row_ready = 0;
        top_data = 0;

        #20;
        rst = 0;
        #10;

        // === Fill input matrix with Q8.8 values: 0x0000, 0x0100, 0x0200, ...
        for (i = 0; i < TOTAL_ELEM; i = i + 1) begin
            test_input[i] = i << 8;
        end

        #10;
        start = 1;
        #10;
        start = 0;

        idx = 0;

        // === Feed in block-wise input
        for (i = 0; i < (TOTAL_ELEM / ELEM_PER_INPUT); i = i + 1) begin
            @(posedge clk);
            top_valid <= 1;
            for (j = 0; j < ELEM_PER_INPUT; j = j + 1) begin
                top_data[(j+1)*WIDTH-1 -: WIDTH] = test_input[idx];
                idx = idx + 1;
            end
            @(posedge clk);
            top_valid <= 0;
            #10;
        end

        // === Start row-wise output
        repeat (5) @(posedge clk);
        row_ready = 1;

        // === Wait for done
        wait (done);
        $display("==== All rows received ====");

        repeat (10) @(posedge clk);
        $finish;
    end

    // === Output monitor
    always @(posedge clk) begin
        if (row_valid) begin
            $display("Row output:");
            for (k = COL-1; k >= 0; k = k - 1) begin
                $write("%h ", row_data[k*WIDTH +: WIDTH]);
            end
            $write("\n");
        end
    end

endmodule

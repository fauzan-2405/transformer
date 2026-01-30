`timescale 1ns / 1ps

module tb_top_b2r_converter;

    // ------------------------------------------------------------
    // Parameters (keep small for debug)
    // ------------------------------------------------------------
    parameter WIDTH         = 16;
    parameter FRAC_WIDTH    = 8;
    parameter ROW           = 12;
    parameter COL           = 12;
    parameter BLOCK_SIZE    = 2;
    parameter CHUNK_SIZE    = 4;
    parameter NUM_CORES_H   = 3;
    parameter NUM_CORES_V   = 2;
    parameter TILE_SIZE     = 4;

    localparam ELEM_PER_INPUT = CHUNK_SIZE * NUM_CORES_H * NUM_CORES_V;
    localparam IN_WIDTH       = WIDTH * ELEM_PER_INPUT;
    localparam TOTAL_ELEM     = ROW * COL;
    localparam TILES_PER_ROW  = COL / TILE_SIZE;

    // ------------------------------------------------------------
    // Signals
    // ------------------------------------------------------------
    reg  clk, rst_n, en;
    reg  in_valid;
    reg  [IN_WIDTH-1:0] in_data;

    wire out_valid;
    wire [WIDTH*TILE_SIZE-1:0] out_b2r_top;

    // ------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------
    top_b2r_converter #(
        .WIDTH(WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH),
        .ROW(ROW),
        .COL(COL),
        .BLOCK_SIZE(BLOCK_SIZE),
        .CHUNK_SIZE(CHUNK_SIZE),
        .NUM_CORES_H(NUM_CORES_H),
        .NUM_CORES_V(NUM_CORES_V),
        .TILE_SIZE(TILE_SIZE)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .en_b2r(en),
        .in_valid(in_valid),
        .in_data(in_data),
        .out_valid(out_valid),
        .out_b2r_top(out_b2r_top)
    );

    // ------------------------------------------------------------
    // Clock
    // ------------------------------------------------------------
    always #5 clk = ~clk;

    // ------------------------------------------------------------
    // Test data
    // ------------------------------------------------------------
    reg [WIDTH-1:0] test_input [0:TOTAL_ELEM-1];
    integer i, j, idx;

    // ------------------------------------------------------------
    // Stimulus
    // ------------------------------------------------------------
    initial begin
        $display("==== Running top_b2r_converter TB ====");
        clk = 0;
        rst_n = 0;
        en = 0;
        in_valid = 0;
        in_data = '0;

        // Reset
        #20;
        rst_n = 1;
        #20;
        en = 1;

        // Fill matrix with incremental fixed-point values
        for (i = 0; i < TOTAL_ELEM; i = i + 1)
            test_input[i] = i << FRAC_WIDTH;

        // Start streaming
        #20;
        in_valid = 1;

        idx = 0;
        for (i = 0; i < TOTAL_ELEM / ELEM_PER_INPUT; i = i + 1) begin
            @(posedge clk);
            for (j = 0; j < ELEM_PER_INPUT; j = j + 1) begin
                in_data[(j+1)*WIDTH-1 -: WIDTH] = test_input[idx];
                idx = idx + 1;
            end
        end

        @(posedge clk);
        in_valid = 0;

        // Let tiles flush
        #1000;
        $display("==== Simulation done ====");
        $finish;
    end

    // ------------------------------------------------------------
    // Output monitor (tile-aware)
    // ------------------------------------------------------------
    integer t;
    integer tile_cnt = 0;
    integer row_cnt  = 0;

    always @(posedge clk) begin
        if (out_valid) begin
            $write("Row %0d | Tile %0d : ", row_cnt, tile_cnt);
            for (t = 0; t < TILE_SIZE; t = t + 1) begin
                $write("%04h ",
                    out_b2r_top[(TILE_SIZE-1-t)*WIDTH +: WIDTH]
                );
            end
            $write("\n");

            if (tile_cnt == TILES_PER_ROW-1) begin
                tile_cnt = 0;
                row_cnt  = row_cnt + 1;
            end else begin
                tile_cnt = tile_cnt + 1;
            end
        end
    end

endmodule

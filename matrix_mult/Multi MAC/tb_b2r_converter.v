`timescale 1ns / 1ps

module tb_b2r_converter;

    parameter WIDTH         = 16;
    parameter FRAC_WIDTH    = 8;
    parameter ROW           = 8;
    parameter COL           = 6;
    parameter BLOCK_SIZE    = 2;
    parameter CHUNK_SIZE    = 4;
    parameter NUM_CORES     = 2;

    localparam ELEM_PER_INPUT = CHUNK_SIZE * NUM_CORES;
    localparam IN_WIDTH       = WIDTH * ELEM_PER_INPUT;
    localparam OUT_WIDTH      = WIDTH * COL;
    localparam TOTAL_ELEM     = ROW * COL;

    reg clk, rst_n, en;
    reg in_valid;
    reg [IN_WIDTH-1:0] in_data;

    wire output_ready;
    wire [OUT_WIDTH-1:0] out_data;
    wire buffer_done;

    // DUT Instantiation
    b2r_converter #(
        .WIDTH(WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH),
        .ROW(ROW),
        .COL(COL),
        .BLOCK_SIZE(BLOCK_SIZE),
        .CHUNK_SIZE(CHUNK_SIZE),
        .NUM_CORES(NUM_CORES)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .in_valid(in_valid),
        .in_data(in_data),
        .output_ready(output_ready),
        .out_data(out_data),
        .buffer_done(buffer_done)
    );

    // Clock Generation
    always #5 clk = ~clk;

    reg [WIDTH-1:0] test_input [0:TOTAL_ELEM-1];
    integer i, j, idx;

    initial begin
        $display("==== Running b2r_converter ====");
        clk = 0;
        rst_n = 0;
        en = 0;
        in_valid = 0;
        in_data = 0;

        // === Reset
        #15;
        rst_n = 1;
        #30 en = 1;

        // === Fill matrix with incrementing Q8.8 values
        for (i = 0; i < TOTAL_ELEM; i = i + 1)
            test_input[i] = i << 8;

        // === Start write
        #30 in_valid = 1;
        //en = 1;

        idx = 0;
        for (i = 0; i < (TOTAL_ELEM / ELEM_PER_INPUT); i = i + 1) begin
            @(posedge clk);
            //in_valid <= 1;
            for (j = 0; j < ELEM_PER_INPUT; j = j + 1) begin
                in_data[(j+1)*WIDTH-1 -: WIDTH] = test_input[idx];
                idx = idx + 1;
            end
            @(posedge clk);
            //#10;
            //in_valid <= 0;
        end
        in_valid <= 0;
        
        #1000;

        // Wait for done
        //wait (done);
        //$display("==== All rows emitted ====");
        //repeat (5) @(posedge clk);
        //$finish;
    end

    // Output Monitor
    integer k;
    always @(posedge clk) begin
        if (output_ready) begin
            $display("Row output:");
            for (k = COL-1; k >= 0; k = k - 1) begin
                $write("%h ", out_data[k*WIDTH +: WIDTH]);
            end
            $write("\n");
        end
    end

endmodule

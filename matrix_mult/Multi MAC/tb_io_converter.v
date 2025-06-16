`timescale 1ns / 1ps

module tb_io_converter;

    parameter WIDTH       = 16;
    parameter COL         = 6;
    parameter ROW         = 8;
    parameter BLOCK_SIZE  = 2;
    parameter CHUNK_SIZE  = 4;
    parameter NUM_CORES   = 2;
    parameter DATA_WIDTH  = WIDTH * COL; // 96
    parameter OUT_WIDTH   = WIDTH * CHUNK_SIZE * NUM_CORES; // 64

    reg clk = 0;
    reg rst_n = 0;
    reg en = 0;
    reg in_valid = 0;;
    reg [DATA_WIDTH-1:0] in_n2r_buffer;
    wire [OUT_WIDTH-1:0] out_n2r_buffer;
    wire slice_done;

    // Instantiate n2r_buffer
    io_converter #(
        .WIDTH(WIDTH),
        .FRAC_WIDTH(8),
        .BLOCK_SIZE(BLOCK_SIZE),
        .CHUNK_SIZE(CHUNK_SIZE),
        .ROW(ROW),
        .COL(COL),
        .NUM_CORES(NUM_CORES)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .in_valid(in_valid),
        .in_n2r_buffer(in_n2r_buffer),
        .slice_done(slice_done),
        .out_n2r_buffer(out_n2r_buffer)
    );

    // Clock
    always #5 clk = ~clk;

    integer i, j;
    reg [WIDTH*COL-1:0] temp_row;
    reg [15:0] val;
    reg [15:0] q88_val;

    initial begin
        rst_n = 0;
        #15 rst_n = 1;
        #30  en = 1;
        #30 in_valid = 1;

        // Feed ROW rows
        for (i = 0; i < ROW; i = i + 1) begin
            temp_row = 0;
            $write("in_n2r_buffer = %0d'h", WIDTH*COL); // Print bit width
            for (j = 0; j < COL; j = j + 1) begin
                val = i * COL + j;        // Start from 0.0
                q88_val = val * 256;      // Q8.8 format (val << 8)
                temp_row = (temp_row << 16) | q88_val;
                $write("%04h", q88_val);
                if (j != COL - 1) $write("_");
            end
            $write("; // ");
            for (j = 0; j < COL; j = j + 1) begin
                val = i * COL + j;
                $write("%0d.0 ", val);
            end
            $write("\n");

            in_n2r_buffer = temp_row;
            #10;
        end
        in_valid = 0;

        //en = 0;
        #1000;
        $finish;
    end

endmodule

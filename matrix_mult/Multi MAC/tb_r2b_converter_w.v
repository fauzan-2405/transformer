`timescale 1ns / 1ps

module tb_r2b_converter_w;

    parameter WIDTH        = 16;
    parameter ROW          = 8;
    parameter COL          = 6;
    parameter BLOCK_SIZE   = 2;
    parameter CHUNK_SIZE   = 4;
    parameter NUM_CORES    = 1;
    parameter DATA_WIDTH   = WIDTH * COL;
    parameter OUT_WIDTH    = WIDTH * CHUNK_SIZE * NUM_CORES;

    reg clk = 0;
    reg rst_n = 0;
    reg en = 0;

    reg  [DATA_WIDTH-1:0] in_n2r_buffer;
    wire [OUT_WIDTH-1:0]  out_n2r_buffer;
    wire slice_last, output_ready, buffer_done;

    // Instantiate the DUT
    r2b_converter_w #(
        .WIDTH(WIDTH),
        .ROW(ROW),
        .COL(COL),
        .BLOCK_SIZE(BLOCK_SIZE),
        .CHUNK_SIZE(CHUNK_SIZE),
        .NUM_CORES(NUM_CORES)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .in_n2r_buffer(in_n2r_buffer),
        .out_n2r_buffer(out_n2r_buffer),
        .slice_last(slice_last),
        .output_ready(output_ready),
        .buffer_done(buffer_done)
    );

    // Clock generation
    always #5 clk = ~clk;

    // Initialization
    integer i, j;
    reg [WIDTH-1:0] q88_val;
    reg [WIDTH*COL-1:0] temp_row;

    initial begin
        // Reset
        rst_n = 0;
        #15 rst_n = 1;
        #10 en = 1;
        //#10

        // Feed 8 rows (ROW=8, COL=6), values from 0.0 to 47.0 in Q8.8 format
        for (i = 0; i < ROW; i = i + 1) begin
            temp_row = 0;
            $write("in_n2r_buffer = %0d'h", WIDTH*COL);
            for (j = 0; j < COL; j = j + 1) begin
                q88_val = (i * COL + j) * 256;
                temp_row = (temp_row << WIDTH) | q88_val;
                $write("%04h", q88_val);
                if (j != COL - 1) $write("_");
            end
            in_n2r_buffer = temp_row;
            $write("; // Row %0d\n", i);
            #10;
        end

        // Stop feeding input
        //en = 0;

        #1000;
        $finish;
    end

    // Output monitor
    always @(posedge clk) begin
        if (output_ready) begin
            $display("Output Block: %h | Decimal: %0d.%02d %0d.%02d %0d.%02d %0d.%02d",
                out_n2r_buffer,
                out_n2r_buffer[63:56], (out_n2r_buffer[55:48]*100)>>8,
                out_n2r_buffer[47:40], (out_n2r_buffer[39:32]*100)>>8,
                out_n2r_buffer[31:24], (out_n2r_buffer[23:16]*100)>>8,
                out_n2r_buffer[15:8],  (out_n2r_buffer[7:0]*100)>>8
            );
        end
    end

endmodule

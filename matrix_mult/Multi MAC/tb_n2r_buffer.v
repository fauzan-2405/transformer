`timescale 1ns / 1ps

module tb_n2r_buffer;

    parameter WIDTH       = 16;
    parameter COL         = 6;
    parameter ROW         = 8;
    parameter BLOCK_SIZE  = 2;
    parameter CHUNK_SIZE  = 2;
    parameter NUM_CORES   = 2;
    parameter DATA_WIDTH  = WIDTH * COL; // 96
    parameter OUT_WIDTH   = WIDTH * CHUNK_SIZE * NUM_CORES; // 64

    reg clk = 0;
    reg rst_n = 0;
    reg en = 0;
    reg [DATA_WIDTH-1:0] in_n2r_buffer;
    wire [OUT_WIDTH-1:0] out_n2r_buffer;
    wire slice_done;

    // Instantiate n2r_buffer
    n2r_buffer #(
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
        .in_n2r_buffer(in_n2r_buffer),
        .slice_done(slice_done),
        .out_n2r_buffer(out_n2r_buffer)
    );

    // Clock
    always #5 clk = ~clk;

    integer i;

    initial begin
        // Reset
        rst_n = 0;
        #10 rst_n = 1;
        #5 en = 1;

        // Feed 8 rows (96 bits each)
        // Q8.8 values from 1.0 to 48.0 (just for clarity)
        for (i = 0; i < 8; i = i + 1) begin
            in_n2r_buffer = {
                16'h0000 + (i*6 + 1)*256,
                16'h0000 + (i*6 + 2)*256,
                16'h0000 + (i*6 + 3)*256,
                16'h0000 + (i*6 + 4)*256,
                16'h0000 + (i*6 + 5)*256,
                16'h0000 + (i*6 + 6)*256
            };
            #10;
        end

        en = 0;
        #200;
        $finish;
    end

    // Display output in Q8.8 format
    always @(posedge clk) begin
        if (slice_done) begin
            $display("OUT: %h | %0d.%0d %0d.%0d %0d.%0d %0d.%0d",
                out_n2r_buffer,
                out_n2r_buffer[63:56], out_n2r_buffer[55:48], // 1st 16-bit value
                out_n2r_buffer[47:40], out_n2r_buffer[39:32],
                out_n2r_buffer[31:24], out_n2r_buffer[23:16],
                out_n2r_buffer[15:8],  out_n2r_buffer[7:0]
            );
        end
    end

endmodule

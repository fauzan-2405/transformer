`timescale 1ns / 1ps

module tb_n2r_buffer;

    parameter WIDTH       = 16;
    parameter COL         = 4;
    parameter ROW         = 4;
    parameter BLOCK_SIZE  = 2;
    parameter CHUNK_SIZE  = 2;
    parameter NUM_CORES   = 1;
    parameter DATA_WIDTH  = WIDTH * COL;
    parameter OUT_WIDTH   = WIDTH * CHUNK_SIZE * BLOCK_SIZE;

    reg clk = 0;
    reg rst_n = 0;
    reg en = 0;
    reg [DATA_WIDTH-1:0] in_n2r_buffer;
    wire [OUT_WIDTH-1:0] out_n2r_buffer;
    wire slice_done;

    // Instantiate the module
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

    // Clock generator
    always #5 clk = ~clk;

    // Q8.8 matrix
    reg [15:0] matrix [0:ROW-1][0:COL-1];
    integer i;

    initial begin
        // Initialize 4x4 Q8.8 matrix
        matrix[0][0] = 16'h0400; // 4.0
        matrix[0][1] = 16'h0500; // 5.0
        matrix[0][2] = 16'h0600; // 6.0
        matrix[0][3] = 16'h0700; // 7.0
        matrix[1][0] = 16'h0800; // 8.0
        matrix[1][1] = 16'h0900; // 9.0
        matrix[1][2] = 16'h0A00; // 10.0
        matrix[1][3] = 16'h0B00; // 11.0
        matrix[2][0] = 16'h0C00; // 12.0
        matrix[2][1] = 16'h0D00; // 13.0
        matrix[2][2] = 16'h0E00; // 14.0
        matrix[2][3] = 16'h0F00; // 15.0
        matrix[3][0] = 16'h1000; // 16.0
        matrix[3][1] = 16'h1100; // 17.0
        matrix[3][2] = 16'h1200; // 18.0
        matrix[3][3] = 16'h1300; // 19.0

        // Reset and enable
        #2 rst_n = 0;
        #10 rst_n = 1;
        #5  en = 1;

        // Feed 4 rows (one per clock)
        for (i = 0; i < ROW; i = i + 1) begin
            in_n2r_buffer = {
                matrix[i][0], matrix[i][1],
                matrix[i][2], matrix[i][3]
            };
            #10;
        end

        // Stop feeding input
        en = 0;

        // Wait and watch
        #100 $finish;
    end

    // Display output when done
    always @(posedge clk) begin
        if (slice_done) begin
            $display("OUT: %h | %h %h %h %h",
                out_n2r_buffer,
                out_n2r_buffer[63:48],  // First element (MSB)
                out_n2r_buffer[47:32],
                out_n2r_buffer[31:16],
                out_n2r_buffer[15:0]    // Last element (LSB)
            );
        end
    end

endmodule

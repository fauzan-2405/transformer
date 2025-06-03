// n2r_to_matmul.v
// Used as a n2r_buffer and top module (with BRAM) wrapper

module n2r_to_matmul #(
    parameter
) (
    input                               clk, rst_n, en_buffer,
    input wire [WIDTH*COL-1:0]          in_n2r_buffer,
    output first_out, matmul_done
    output reg [(WIDTH*CHUNK_SIZE*NUM_CORES)-1:0] out_matmul, 
);
    localparam

endmodule
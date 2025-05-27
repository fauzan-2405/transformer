// n2r_buffer.v
// Normal to Ready buffer
// Used for changing the shape of the matrix from the normal version (row by row) to the ready to be inputted to the matrix multiplication module

module n2r_buffer_v2 #(
    parameter WIDTH       = 16,
    parameter FRAC_WIDTH  = 8,
    parameter BLOCK_SIZE  = 2, 
    parameter CHUNK_SIZE  = 4,
    parameter ROW         = 2754, 
    parameter COL         = 256,
    parameter NUM_CORES   = (COL == 2754) ? 9 :
                            (COL == 256)  ? 8 :
                            (COL == 200)  ? 5 :
                            (COL == 64)   ? 4 : 2
) (
    input  wire                          clk,
    input  wire                          rst_n,
    input  wire                          en,
    input  wire [WIDTH*COL-1:0]          in_n2r_buffer,
    output wire                          slice_done,
    output reg  [WIDTH*CHUNK_SIZE*NUM_CORES-1:0] out_n2r_buffer
);
    // Local parameters
    localparam BUFFER_DEPTH = ROW;
    localparam CHUNKS_PER_ROW = COL/BLOCK_SIZE;

endmodule
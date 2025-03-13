// top.v
// Used to combine toplevel.v with BRAM

`include "toplevel.v"

module top #(
    parameter WIDTH = 16,
    parameter FRAC_WIDTH = 8,
    parameter BLOCK_SIZE = 2, // The size of systolic array dimension (N x N)
    parameter CHUNK_SIZE = 4,
    parameter INNER_DIMENSION = 256, // The same number of rows in one matrix and same number of columns in the other matrix
    // W stands for weight
    parameter W_OUTER_DIMENSION = 64,
    // I stands for input
    parameter I_OUTER_DIMENSION = 2754
) (
    input clk, rst_n, en, clr,
    // Control and status port
    output ready,
    input  start,
    output done,
    // Weight port
    // For weight, there is 256x64 data with 16 bits each
    input wb_en,
    input [(INNER_DIMENSION/CHUNK_SIZE)*W_OUTER_DIMENSION-1:0] wb_addr, // 256/4 = 64 x 256
    input [WIDTH*CHUNK_SIZE-1:0] wb_din,
    input [7:0] wb_we,
    // Data input port
    input in_en,
    input [(INNER_DIMENSION/CHUNK_SIZE)*I_OUTER_DIMENSION-1:0] in_addr,
    input [WIDTH*CHUNK_SIZE-1:0] in_din,
    input [7:0] in_we,
    // Data output port
    input out_en,
    input [(W_OUTER_DIMENSION/CHUNK_SIZE)*I_OUTER_DIMENSION],
    output [WIDTH*CHUNK_SIZE-1:0] out_dout
);
endmodule
// top.v
// Used to combine toplevel.v with BRAM

`include "toplevel.v"

module top #(
    parameter WIDTH = 16,
    parameter FRAC_WIDTH = 8,
    parameter BLOCK_SIZE = 2, // The size of systolic array dimension (N x N)
    parameter CHUNK_SIZE = 4,
    parameter INNER_DIMENSION = 64 // The same number of rows in one matrix and same number of columns in the other matrix
) (
    input clk, rst_n, en, clr,
    // Control and status port
    output  ready,
    input   start,
    output  done,
    // Weight port
    input   wb_en,
    input   wb_addr,
    input   

)
// top_pkg.sv
// This used as the top level of the parameter package for the entire multi-head-attention

package top_pkg;
    parameter int WIDTH_A        = 16;
    parameter int FRAC_WIDTH_A   = 8;
    parameter int WIDTH_B        = 16;
    parameter int FRAC_WIDTH_B   = 8;
    parameter int WIDTH_OUT      = 16;
    parameter int FRAC_WIDTH_OUT = 8;

    parameter int BLOCK_SIZE     = 2; 
    parameter int CHUNK_SIZE     = 4;
endpackage
// top_pkg.sv
// This used as the top level of the parameter package for the entire multi-head-attention

package top_pkg;
    parameter int TOP_WIDTH_A        = 16;
    parameter int TOP_FRAC_WIDTH_A   = 8;
    parameter int TOP_WIDTH_B        = 16;
    parameter int TOP_FRAC_WIDTH_B   = 8;
    parameter int TOP_WIDTH_OUT      = 16;
    parameter int TOP_FRAC_WIDTH_OUT = 8;

    parameter int TOP_BLOCK_SIZE     = 2; 
    parameter int TOP_CHUNK_SIZE     = 4;

    parameter TOTAL_MODULES_K    = 4; // N parameters
    parameter TOTAL_MODULES_Q    = 4; // P parameters
    parameter TOTAL_MODULES_V    = 4; // T parameters
endpackage
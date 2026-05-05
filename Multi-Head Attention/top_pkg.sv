// top_pkg.sv
// This used as the top level of the parameter package for the entire multi-head-attention
`include "config.svh"

package top_pkg;
    parameter int TOP_WIDTH_A        = `SYSTEM_TOP_WIDTH;
    parameter int TOP_FRAC_WIDTH_A   = `SYSTEM_FRAC_WIDTH;
    parameter int TOP_WIDTH_B        = `SYSTEM_TOP_WIDTH;
    parameter int TOP_FRAC_WIDTH_B   = `SYSTEM_FRAC_WIDTH;
    parameter int TOP_WIDTH_OUT      = `SYSTEM_TOP_WIDTH;
    parameter int TOP_FRAC_WIDTH_OUT = `SYSTEM_FRAC_WIDTH;

    parameter int TOP_BLOCK_SIZE     = `TOP_BLOCK_SIZE; 
    parameter int TOP_CHUNK_SIZE     = `TOP_CHUNK_SIZE;
    
    parameter int I_MATRIX_DIMENSION = `I_MATRIX_DIMENSION;
    parameter int INNER_MATRIX_DIMENSION = `INNER_MATRIX_DIMENSION;
    parameter int W_MATRIX_DIMENSION = `W_MATRIX_DIMENSION;
    
    parameter int LP_NUM_CORES_A = `SYSTEM_NUM_CORES_A;

    parameter TOTAL_MODULES_K    = `SYSTEM_TOTAL_MODULES; 
    parameter TOTAL_MODULES_Q    = `SYSTEM_TOTAL_MODULES; 
    parameter TOTAL_MODULES_V    = `SYSTEM_TOTAL_MODULES;
endpackage

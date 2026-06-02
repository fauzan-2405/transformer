// top_pkg.sv
// This used as the top level of the parameter package for the entire multi-head-attention
`include "config.svh"

package top_pkg;
    // Linear projection stage
    parameter int TOP_WIDTH_A        = `SYSTEM_TOP_WIDTH_INPUT;   // For input matrix
    parameter int TOP_FRAC_WIDTH_A   = `SYSTEM_FRAC_WIDTH_INPUT;  // For input matrix
    parameter int TOP_WIDTH_B        = `SYSTEM_TOP_WIDTH_WEIGHT;   // For weight matrices (Q, K, V)
    parameter int TOP_FRAC_WIDTH_B   = `SYSTEM_FRAC_WIDTH_WEIGHT;  // For weight matrices (Q, K, V)
    // Linear projection output (Q_KT input)
    parameter int TOP_WIDTH_KEYS        = `SYSTEM_TOP_WIDTH_KEYS;
    parameter int TOP_FRAC_WIDTH_KEYS   = `SYSTEM_FRAC_WIDTH_KEYS;
    
    // Q_KT output (softmax input)
    parameter int TOP_WIDTH_QKT         = `SYSTEM_TOP_WIDTH_QKT;
    parameter int TOP_FRAC_WIDTH_QKT    = `SYSTEM_FRAC_WIDTH_QKT;
    
    // Softmax output (QKT_V input)
    parameter int TOP_WIDTH_SOFTMAX     = `SYSTEM_TOP_WIDTH_SOFTMAX;
    parameter int TOP_FRAC_WIDTH_SOFTMAX= `SYSTEM_FRAC_WIDTH_SOFTMAX;
    
    // Final output stage 
    parameter int TOP_WIDTH_OUT      = `SYSTEM_TOP_WIDTH_FINAL;   // For the final output
    parameter int TOP_FRAC_WIDTH_OUT = `SYSTEM_FRAC_WIDTH_FINAL;  // For the final output

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

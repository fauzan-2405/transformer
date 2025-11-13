// This package contains parameters used in linear projection operation
// TODO: 
// 1. Review the dimension of ADDR_WIDTH_* parameter

package linear_proj_pkg;
    // Parameterization
    parameter int WIDTH_A        = 16;
    parameter int FRAC_WIDTH_A   = 8;
    parameter int WIDTH_B        = 16;
    parameter int FRAC_WIDTH_B   = 8;
    parameter int WIDTH_OUT      = 16;
    parameter int FRAC_WIDTH_OUT = 8;

    parameter int BLOCK_SIZE     = 2; 
    parameter int CHUNK_SIZE     = 4;

    parameter int A_OUTER_DIMENSION = 8;
    parameter int B_OUTER_DIMENSION = 8;
    parameter int INNER_DIMENSION= 6;
    parameter int NUM_CORES_B    = 1;
    parameter int NUM_CORES_A    = 2;

    parameter TOTAL_INPUT_W = 2; // Total port from input matrix (to be used in multi_matmul_wrapper.sv)
    parameter TOTAL_MODULES = 4; // Total matmul module used in multi_matmul.v (the value does not have to be the same as TOTAL_WEIGHT_PER_KEY)
    parameter TOTAL_WEIGHT_PER_KEY = 4; // Total of weight per key (Q1, Q2, ..., Q4 etc)
    
    parameter int NUM_A_ELEMENTS = ((A_OUTER_DIMENSION/BLOCK_SIZE)*(INNER_DIMENSION/BLOCK_SIZE))/(NUM_CORES_A); // Total elements of Input if we converted the inputs based on the NUM_CORES
    parameter int NUM_B_ELEMENTS = ((B_OUTER_DIMENSION/BLOCK_SIZE)*(INNER_DIMENSION/BLOCK_SIZE))/(NUM_CORES_B*TOTAL_MODULES);

    parameter int ROW_SIZE_MAT_C = A_OUTER_DIMENSION / (BLOCK_SIZE * NUM_CORES_A * TOTAL_INPUT_W); 
    parameter int COL_SIZE_MAT_C = B_OUTER_DIMENSION / (BLOCK_SIZE * NUM_CORES_B * TOTAL_MODULES); 
    parameter int MAX_FLAG = (ROW_SIZE_MAT_C * COL_SIZE_MAT_C);

endpackage
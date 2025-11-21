// This package contains parameters used in linear projection operation

package linear_proj_pkg;
    // Parameterization
    parameter int WIDTH_A        = top_pkg::WIDTH_A;
    parameter int FRAC_WIDTH_A   = top_pkg::FRAC_WIDTH_A;
    parameter int WIDTH_B        = top_pkg::WIDTH_B;
    parameter int FRAC_WIDTH_B   = top_pkg::FRAC_WIDTH_B;
    parameter int WIDTH_OUT      = top_pkg::WIDTH_OUT;
    parameter int FRAC_WIDTH_OUT = top_pkg::FRAC_WIDTH_OUT;

    parameter int BLOCK_SIZE     = top_pkg::BLOCK_SIZE; 
    parameter int CHUNK_SIZE     = top_pkg::CHUNK_SIZE;

    parameter int A_OUTER_DIMENSION = 8;
    parameter int B_OUTER_DIMENSION = 8;
    parameter int INNER_DIMENSION= 6;
    parameter int NUM_CORES_B    = 1;
    parameter int NUM_CORES_A    = 2;

    parameter TOTAL_INPUT_W = 2; // Total port from input matrix (to be used in multi_matmul_wrapper.sv)
    parameter TOTAL_MODULES = 4; // Total matmul module used in multi_matmul.v (the value does not have to be the same as TOTAL_WEIGHT_PER_KEY)
    parameter TOTAL_WEIGHT_PER_KEY = 4; // Total of weight per key (Q1, Q2, ..., Q4 etc)

    parameter MEMORY_SIZE_A = INNER_DIMENSION*A_OUTER_DIMENSION*WIDTH_A;
    parameter DATA_WIDTH_A  = WIDTH_A*CHUNK_SIZE*NUM_CORES_A;
    parameter int ADDR_WIDTH_A = $clog2(MEMORY_SIZE_A/DATA_WIDTH_A);
    
    parameter MEMORY_SIZE_B = INNER_DIMENSION*B_OUTER_DIMENSION*WIDTH_B;
    parameter DATA_WIDTH_B  = WIDTH_B*CHUNK_SIZE*NUM_CORES_B*TOTAL_MODULES;
    parameter int ADDR_WIDTH_B = $clog2(MEMORY_SIZE_B/DATA_WIDTH_B);
    
    parameter int NUM_A_ELEMENTS = ((A_OUTER_DIMENSION/BLOCK_SIZE)*(INNER_DIMENSION/BLOCK_SIZE))/(NUM_CORES_A); // Total elements of Input if we converted the inputs based on the NUM_CORES
    parameter int NUM_B_ELEMENTS = ((B_OUTER_DIMENSION/BLOCK_SIZE)*(INNER_DIMENSION/BLOCK_SIZE))/(NUM_CORES_B*TOTAL_MODULES);

    parameter int ROW_SIZE_MAT_C = A_OUTER_DIMENSION / (BLOCK_SIZE * NUM_CORES_A * TOTAL_INPUT_W); 
    parameter int COL_SIZE_MAT_C = B_OUTER_DIMENSION / (BLOCK_SIZE * NUM_CORES_B * TOTAL_MODULES); 
    parameter int MAX_FLAG = (ROW_SIZE_MAT_C * COL_SIZE_MAT_C);

endpackage
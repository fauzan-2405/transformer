// This package contains parameters used in linear projection operation
//import top_pkg::*;

package linear_proj_pkg;
    // Parameterization
    parameter int WIDTH_A        = top_pkg::TOP_WIDTH_A;
    parameter int FRAC_WIDTH_A   = top_pkg::TOP_FRAC_WIDTH_A;
    parameter int WIDTH_B        = top_pkg::TOP_WIDTH_B;
    parameter int FRAC_WIDTH_B   = top_pkg::TOP_FRAC_WIDTH_B;
    parameter int WIDTH_OUT      = top_pkg::TOP_WIDTH_OUT;
    parameter int FRAC_WIDTH_OUT = top_pkg::TOP_FRAC_WIDTH_OUT;

    parameter int BLOCK_SIZE     = top_pkg::TOP_BLOCK_SIZE;
    parameter int CHUNK_SIZE     = top_pkg::TOP_CHUNK_SIZE;

    parameter int A_OUTER_DIMENSION = 60;
    parameter int B_OUTER_DIMENSION = 42;
    parameter int INNER_DIMENSION= 24;
    parameter int NUM_CORES_B    = 1;
    parameter int NUM_CORES_A    = 5;

    parameter TOTAL_INPUT_W = 2;
    parameter TOTAL_MODULES = top_pkg::TOTAL_MODULES_Q; // The real one: TOTAL_MODULES_Q
    // For now it's okay all of these three are the same because we use this only in the linear_projection
    parameter LP_TOTAL_MODULES_Q = TOTAL_MODULES;      // Used in buffer0_pkg: W0_COL_X, W0_TOTAL_IN
    parameter LP_TOTAL_MODULES_K = TOTAL_MODULES;
    parameter LP_TOTAL_MODULES_V = TOTAL_MODULES;      // Used in buffer0_pkg: N1_COL_X and out_matmul_QKT_Vn in self_attention_head.sv
    /*
    parameter TOTAL_MODULES_Q = top_pkg::TOTAL_MODULES_Q;
    parameter TOTAL_MODULES_K = top_pkg::TOTAL_MODULES_K;
    parameter TOTAL_MODULES_V = top_pkg::TOTAL_MODULES_V;
    */
    parameter TOTAL_WEIGHT_PER_KEY = 1; // In linear_projection.sv

    // PLEASE EDIT IN THE FUTURE IF WE WANT TO MAKE THE TOTAL_MODULES DIFFERENT BETWEEN THE KEYS!!!

    parameter MEMORY_SIZE_A = INNER_DIMENSION*A_OUTER_DIMENSION*WIDTH_A;    // Used to store input matrix, in top_linear_projection.sv
    parameter DATA_WIDTH_A  = WIDTH_A*CHUNK_SIZE*NUM_CORES_A;               // Used to store input matrix, in top_linear_projection.sv
    parameter int ADDR_WIDTH_A = $clog2(MEMORY_SIZE_A/DATA_WIDTH_A);        // Used to store input matrix, in top_linear_projection.sv from external inputs

    parameter MEMORY_SIZE_B = INNER_DIMENSION*B_OUTER_DIMENSION*WIDTH_B;    // Used to weight input matrix, in multwrap_wbram.sv
    parameter DATA_WIDTH_B  = WIDTH_B*CHUNK_SIZE*NUM_CORES_B*TOTAL_MODULES; // Used to weight input matrix, in multwrap_wbram.sv
    parameter int ADDR_WIDTH_B = $clog2(MEMORY_SIZE_B/DATA_WIDTH_B);        // Used to weight input matrix, in multwrap_wbram.sv

    parameter int NUM_A_ELEMENTS = ((A_OUTER_DIMENSION/BLOCK_SIZE)*(INNER_DIMENSION/BLOCK_SIZE))/(NUM_CORES_A); // Total elements of Input if we converted the inputs based on the NUM_CORES, in tb_multihead_attention.sv
    parameter int NUM_B_ELEMENTS = ((B_OUTER_DIMENSION/BLOCK_SIZE)*(INNER_DIMENSION/BLOCK_SIZE))/(NUM_CORES_B*TOTAL_MODULES);

    parameter int ROW_SIZE_MAT_C = A_OUTER_DIMENSION / (BLOCK_SIZE * NUM_CORES_A * TOTAL_INPUT_W);  // Used in linear_proj_ctrl.sv
    parameter int COL_SIZE_MAT_C = B_OUTER_DIMENSION / (BLOCK_SIZE * NUM_CORES_B * TOTAL_MODULES);
    parameter int MAX_FLAG = (ROW_SIZE_MAT_C * COL_SIZE_MAT_C);

endpackage

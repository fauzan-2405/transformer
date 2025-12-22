// ping_pong_pkg.sv
// This package contains all necessary parameters for ping_pong buffer
import top_pkg::*;
import linear_proj_pkg::*;

package ping_pong_pkg;
    parameter int WIDTH          = 16;
    parameter int FRAC_WIDTH     = 8;
    parameter int BLOCK_SIZE     = top_pkg::TOP_BLOCK_SIZE; 
    parameter int CHUNK_SIZE     = top_pkg::TOP_CHUNK_SIZE;
    parameter int INNER_DIMENSION = 4;
    parameter COL_Y              = 4;
    parameter TOTAL_INPUT_W      = 2;
    // COL_X and COL_Y are already computed and determined by NUM_CORES_*

    // For West Ping-Pong Buffer, PLEASE CHANGE THESE PARAMETERS ACCORDING TO YOUR USAGE
    parameter int W_ROW_X          = linear_proj_pkg::ROW_SIZE_MAT_C; // A_OUTER_DIMENSION in block
    parameter int W_COL_X          = linear_proj_pkg::COL_SIZE_MAT_C; // INNER DIMENSION in block size
    parameter int W_NUM_CORES_A    = 2;
    parameter int W_NUM_CORES_B    = 2;
    parameter int W_TOTAL_MODULES  = 4;
    localparam W_MODULE_WIDTH      = WIDTH*CHUNK_SIZE*W_NUM_CORES_A*W_NUM_CORES_B;
    localparam W_IN_WIDTH          = W_MODULE_WIDTH * W_TOTAL_MODULES;
    localparam W_TOTAL_DEPTH       = W_COL_X * TOTAL_INPUT_W;
    localparam W_MEMORY_SIZE       = W_TOTAL_DEPTH * W_MODULE_WIDTH;
    localparam int ADDR_WIDTH_W    = $clog2(W_TOTAL_DEPTH);

    // For North Ping-Pong Buffer, PLEASE CHANGE THESE PARAMETERS ACCORDING TO YOUR USAGE
    parameter int N_COL_X          = 4; // B_OUTER_DIMENSION or in other words COL_Y in block size
    parameter int N_NUM_CORES_A    = 2;
    parameter int N_NUM_CORES_B    = 2;
    parameter int N_TOTAL_MODULES  = 4;
    localparam N_SLICE_WIDTH       = WIDTH*CHUNK_SIZE*N_NUM_CORES_B;
    localparam N_MODULE_WIDTH      = N_SLICE_WIDTH*TOTAL_INPUT_W;
    localparam N_IN_WIDTH          = WIDTH*CHUNK_SIZE*N_TOTAL_MODULES*N_NUM_CORES_A;
    localparam N_TOTAL_DEPTH       = N_COL_X;
    localparam N_MEMORY_SIZE       = N_TOTAL_DEPTH * N_MODULE_WIDTH;
    localparam int ADDR_WIDTH_N    = $clog2(N_TOTAL_DEPTH);

    parameter int ROW_SIZE_MAT_C = W_ROW_X; // PLEASE REVISE THIS
    parameter int COL_SIZE_MAT_C = N_COL_X; // PLEASE REVISE THIS
    parameter int MAX_FLAG = (ROW_SIZE_MAT_C * COL_SIZE_MAT_C);

    
endpackage
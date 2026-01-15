// buffer0_pkg.sv
// This package contains all necessary parameters for buffer0 buffer

package buffer0_pkg;
    parameter int WIDTH          = top_pkg::TOP_WIDTH_OUT;
    parameter int FRAC_WIDTH     = top_pkg::TOP_FRAC_WIDTH_OUT;
    parameter int INNER_DIMENSION = self_attention_pkg::INNER_DIMENSION_Qn_KnT; // In decimal unit

    // For West Buffer, PLEASE CHANGE THESE PARAMETERS ACCORDING TO YOUR USAGE
    parameter TOTAL_INPUT_W_W0      = 2; 
    parameter int W0_ROW_X          = linear_proj_pkg::ROW_SIZE_MAT_C * linear_proj_pkg::NUM_CORES_A; // A_OUTER_DIMENSION in BLOCK_SIZE unit
    parameter int W0_COL_X          = linear_proj_pkg::COL_SIZE_MAT_C * linear_proj_pkg::TOTAL_MODULES_Q; // INNER DIMENSION in BLOCK_SIZE unit
    parameter int W0_NUM_CORES_A    = self_attention_pkg::NUM_CORES_A_Qn_KnT;
    parameter int W0_NUM_CORES_B    = 1;
    parameter int W0_TOTAL_MODULES  = self_attention_pkg::TOTAL_MODULES_LP_Q; // How many modules used from the last multiplication for this west buffer
    localparam W0_SLICE_WIDTH       = WIDTH*(top_pkg::TOP_CHUNK_SIZE)*W0_NUM_CORES_A;
    localparam W0_MODULE_WIDTH      = W0_SLICE_WIDTH*TOTAL_INPUT_W_W0;
    localparam W0_IN_WIDTH          = W0_SLICE_WIDTH * W0_NUM_CORES_B * W0_TOTAL_MODULES;
    localparam W0_TOTAL_DEPTH       = W0_ROW_X * W0_COL_X; // Can be reduced even further
    localparam W0_MEMORY_SIZE       = W0_TOTAL_DEPTH * W0_MODULE_WIDTH;
    localparam int ADDR_WIDTH_W0    = $clog2(W0_TOTAL_DEPTH);

    // For North Buffer, PLEASE CHANGE THESE PARAMETERS ACCORDING TO YOUR USAGE
    parameter TOTAL_INPUT_W_N0      = 2;
    parameter int N0_ROW_X          = W_COL_X;   
    parameter int N0_COL_X          = W_ROW_X
    parameter int N0_NUM_CORES_A    = 1;
    parameter int N0_NUM_CORES_B    = self_attention_pkg::NUM_CORES_B_Qn_KnT;
    parameter int N0_TOTAL_MODULES  = self_attention_pkg::TOTAL_MODULES_LP_K; // How many modules used from the last multiplication for this west buffer
    localparam N0_SLICE_WIDTH       = WIDTH*(top_pkg::TOP_CHUNK_SIZE)*N0_NUM_CORES_B;
    localparam N0_MODULE_WIDTH      = N0_SLICE_WIDTH*TOTAL_INPUT_W_N0;
    localparam N0_IN_WIDTH          = N0_SLICE_WIDTH * N0_NUM_CORES_A * N0_TOTAL_MODULES;
    localparam N0_TOTAL_DEPTH       = N0_ROW_X * N0_COL_X;
    localparam N0_MEMORY_SIZE       = N0_TOTAL_DEPTH * N0_MODULE_WIDTH;
    localparam int ADDR_WIDTH_N0    = $clog2(N0_TOTAL_DEPTH);

    parameter int ROW_SIZE_MAT_C_B0 = W0_ROW_X / TOTAL_INPUT_W_W0; 
    parameter int COL_SIZE_MAT_C_B0 = N0_COL_X / TOTAL_INPUT_W_N0;
    parameter int MAX_FLAG_B0       = (ROW_SIZE_MAT_C_B0 * COL_SIZE_MAT_C_B0);

    
endpackage
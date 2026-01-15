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

    // For North Ping-Pong Buffer, PLEASE CHANGE THESE PARAMETERS ACCORDING TO YOUR USAGE
    parameter TOTAL_INPUT_W_N0      = 2;
    parameter int N0_ROW_X          = W_COL_X;   
    parameter int N0_COL_X          = W_ROW_X
    parameter int N0_NUM_CORES_A    = 1;
    parameter int N0_NUM_CORES_B    = self_attention_pkg::NUM_CORES_B_Qn_KnT;
    parameter int N0_TOTAL_MODULES  = self_attention_pkg::TOTAL_MODULES_LP_K; // How many modules used from the last multiplication for this west buffer

    parameter int ROW_SIZE_MAT_C_B0 = W0_ROW_X / TOTAL_INPUT_W_W0; 
    parameter int COL_SIZE_MAT_C_B0 = N0_COL_X / TOTAL_INPUT_W_N0;
    parameter int MAX_FLAG_B0       = (ROW_SIZE_MAT_C_B0 * COL_SIZE_MAT_C_B0);

    
endpackage
// This package contains parameters used in self attention head 

package self_attention_pkg;
    parameter int WIDTH_A        = top_pkg::WIDTH_A;
    parameter int FRAC_WIDTH_A   = top_pkg::FRAC_WIDTH_A;
    parameter int WIDTH_B        = top_pkg::WIDTH_B;
    parameter int FRAC_WIDTH_B   = top_pkg::FRAC_WIDTH_B;
    parameter int WIDTH_OUT      = top_pkg::WIDTH_OUT;
    parameter int FRAC_WIDTH_OUT = top_pkg::FRAC_WIDTH_OUT;

    parameter int BLOCK_SIZE     = top_pkg::BLOCK_SIZE; 
    parameter int CHUNK_SIZE     = top_pkg::CHUNK_SIZE;

    parameter int A_OUTER_DIMENSION_Qn_KnT = linear_proj_pkg::A_OUTER_DIMENSION;
    parameter int B_OUTER_DIMENSION_Qn_KnT = linear_proj_pkg::A_OUTER_DIMENSION;
    parameter int INNER_DIMENSION_Qn_KnT = linear_proj_pkg::B_OUTER_DIMENSION;
    parameter int NUM_CORES_B_Qn_KnT    = linear_proj_pkg::NUM_CORES_A;
    parameter int NUM_CORES_A_Qn_KnT    = linear_proj_pkg::NUM_CORES_A;

    parameter TOTAL_INPUT_W_Qn_KnT = top_pkg::TOTAL_MODULES_Q; // TOTAL_INPUT_W from the linear projection
    parameter TOTAL_MODULES_LP_Q = linear_proj_pkg::TOTAL_MODULES; // TOTAL_MODULES from the linear projection
    parameter TOTAL_MODULES_LP_K = linear_proj_pkg::TOTAL_MODULES;
    parameter TOTAL_MODULES_LP_V = linear_proj_pkg::TOTAL_MODULES; 


endpackage
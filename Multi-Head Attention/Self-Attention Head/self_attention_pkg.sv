// This package contains parameters used in self attention head 

package self_attention_pkg;
    parameter int SA_WIDTH_A        = top_pkg::TOP_WIDTH_A;
    parameter int SA_FRAC_WIDTH_A   = top_pkg::TOP_FRAC_WIDTH_A;
    parameter int SA_WIDTH_B        = top_pkg::TOP_WIDTH_B;
    parameter int SA_FRAC_WIDTH_B   = top_pkg::TOP_FRAC_WIDTH_B;
    parameter int SA_WIDTH_OUT      = top_pkg::TOP_WIDTH_OUT;
    parameter int SA_FRAC_WIDTH_OUT = top_pkg::TOP_FRAC_WIDTH_OUT;

    parameter int SA_BLOCK_SIZE     = top_pkg::TOP_BLOCK_SIZE; 
    parameter int SA_CHUNK_SIZE     = top_pkg::TOP_CHUNK_SIZE;

    parameter int A_OUTER_DIMENSION_Qn_KnT  = linear_proj_pkg::A_OUTER_DIMENSION;
    parameter int B_OUTER_DIMENSION_Qn_KnT  = linear_proj_pkg::A_OUTER_DIMENSION;
    parameter int INNER_DIMENSION_Qn_KnT    = linear_proj_pkg::B_OUTER_DIMENSION;
    parameter int NUM_CORES_B_Qn_KnT    = linear_proj_pkg::NUM_CORES_A;
    parameter int NUM_CORES_A_Qn_KnT    = linear_proj_pkg::NUM_CORES_A;

    parameter TOTAL_INPUT_W_Qn_KnT  = linear_proj_pkg::TOTAL_INPUT_W; // TOTAL_INPUT_W from the linear projection
    parameter TOTAL_MODULES_LP_Q    = linear_proj_pkg::TOTAL_MODULES_Q; // TOTAL_MODULES from the linear projection
    parameter TOTAL_MODULES_LP_K    = linear_proj_pkg::TOTAL_MODULES_K;
    parameter TOTAL_MODULES_LP_V    = linear_proj_pkg::TOTAL_MODULES_V; 

    parameter ROW_B2R_CONVERTER  = NUM_CORES_A_Qn_KnT*(top_pkg::BLOCK_SIZE);
    parameter COL_B2R_CONVERTER  = NUM_CORES_B_Qn_KnT*TOTAL_MODULES_LP_K*(top_pkg::BLOCK_SIZE);
    parameter NUM_CORES_H_B2R    = NUM_CORES_B_Qn_KnT*TOTAL_MODULES_LP_Q;
    parameter NUM_CORES_V_B2R    = NUM_CORES_A_Qn_KnT;

    parameter TOTAL_ELEMENTS_SOFTMAX = B_OUTER_DIMENSION_Qn_KnT; // Column size, in decimal
    parameter TILE_SIZE_SOFTMAX      = COL_B2R_CONVERTER;

endpackage
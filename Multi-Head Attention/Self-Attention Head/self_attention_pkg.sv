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
    parameter TOTAL_MODULES_LP_Q    = TOTAL_INPUT_W_Qn_KnT;
    //parameter TOTAL_MODULES_LP_Q    = linear_proj_pkg::TOTAL_MODULES_Q;
    //parameter TOTAL_MODULES_LP_K    = linear_proj_pkg::TOTAL_MODULES;
    parameter TOTAL_MODULES_LP_K    = TOTAL_MODULES_LP_Q;
    parameter TOTAL_MODULES_LP_V    = 1;

    parameter ROW_B2R_CONVERTER  = NUM_CORES_A_Qn_KnT*(top_pkg::TOP_BLOCK_SIZE);
    parameter COL_B2R_CONVERTER  = NUM_CORES_B_Qn_KnT*TOTAL_MODULES_LP_K*(top_pkg::TOP_BLOCK_SIZE);     // Old
    //parameter COL_B2R_CONVERTER  = NUM_CORES_A_Qn_KnT*TOTAL_INPUT_W_Qn_KnT*(top_pkg::TOP_BLOCK_SIZE); // New, will be implemented later
                                                                                                        // Update: It's the same (new and old) because
                                                                                                        // TOTAL_MODULES_LP_K = TOTAL_INPUT_W_Qn_KnT
    parameter NUM_CORES_H_B2R    = NUM_CORES_B_Qn_KnT*TOTAL_MODULES_LP_K;       // Old, Looks like TOTAL_MODULES_LP_Q will be the problem
    //parameter NUM_CORES_H_B2R    = NUM_CORES_B_Qn_KnT*TOTAL_INPUT_W_Qn_KnT;   // New
                                                                                // Update, it's the same too, just like the previous COL_B2R_CONVERTER
    parameter NUM_CORES_V_B2R    = NUM_CORES_A_Qn_KnT;

    parameter TOTAL_ELEMENTS_SOFTMAX = B_OUTER_DIMENSION_Qn_KnT;    // Column size, in decimal
    parameter TILE_SIZE_SOFTMAX      = COL_B2R_CONVERTER;           // In decimal
    parameter TOTAL_TILE_SOFTMAX     = TOTAL_ELEMENTS_SOFTMAX/TILE_SIZE_SOFTMAX;
    parameter TOTAL_OUTPUTS_PER_TILE = TILE_SIZE_SOFTMAX/SA_BLOCK_SIZE;
    parameter TOTAL_SOFTMAX_ROW      = NUM_CORES_A_Qn_KnT * SA_BLOCK_SIZE;

    parameter NUM_BANKS_FIFO         = (TOTAL_OUTPUTS_PER_TILE*2 + 1 > TOTAL_TILE_SOFTMAX)? TOTAL_TILE_SOFTMAX : (TOTAL_OUTPUTS_PER_TILE*2 + 1);
    parameter int FIFO_WRITE_DEPTH   = (TOTAL_OUTPUTS_PER_TILE <= 16) ? 16 : TOTAL_OUTPUTS_PER_TILE;
    parameter int WR_DATA_COUNT_WIDTH= ($clog2(TOTAL_OUTPUTS_PER_TILE)+1 <= 5) ? 5 : ($clog2(TOTAL_OUTPUTS_PER_TILE)+1);
    parameter int RD_DATA_COUNT_WIDTH= ($clog2(TOTAL_OUTPUTS_PER_TILE)+1 <= 5) ? 5 : ($clog2(TOTAL_OUTPUTS_PER_TILE)+1);

    parameter int INNER_DIMENSION_QKT_Vn    = B_OUTER_DIMENSION_Qn_KnT;
    //parameter int NUM_CORES_A_QKT_Vn    = 2;    // Old
    parameter int NUM_CORES_A_QKT_Vn    = NUM_CORES_A_Qn_KnT; // New
    //parameter int NUM_CORES_B_QKT_Vn    = linear_proj_pkg::NUM_CORES_A; // Old
    parameter int NUM_CORES_B_QKT_Vn    = linear_proj_pkg::TOTAL_MODULES; // Is it right?

endpackage

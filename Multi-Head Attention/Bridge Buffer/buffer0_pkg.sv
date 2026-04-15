// buffer0_pkg.sv
// This package contains all necessary parameters for buffer0 buffer

package buffer0_pkg;
    parameter int B0_WIDTH          = top_pkg::TOP_WIDTH_OUT;
    parameter int FRAC_WIDTH        = top_pkg::TOP_FRAC_WIDTH_OUT;
    parameter int B0_INNER_DIMENSION = self_attention_pkg::INNER_DIMENSION_Qn_KnT; // In decimal unit
    //parameter int B0_INNER_DIMENSION = linear_proj_pkg::TOTAL_MODULES; // In decimal unit

    // =================================== BUFFER 0 ===================================
    // For West Buffer 0, PLEASE CHANGE THESE PARAMETERS ACCORDING TO YOUR USAGE
    parameter TOTAL_INPUT_W_W0      = 2;
    //parameter int W0_ROW_X          = linear_proj_pkg::ROW_SIZE_MAT_C * linear_proj_pkg::NUM_CORES_A; // A_OUTER_DIMENSION in BLOCK_SIZE unit
    parameter int W0_ROW_X          = linear_proj_pkg::ROW_SIZE_MAT_C; // A_OUTER_DIMENSION in BLOCK_SIZE unit
    parameter int W0_COL_X          = linear_proj_pkg::COL_SIZE_MAT_C * linear_proj_pkg::LP_TOTAL_MODULES_Q;   // INNER DIMENSION in BLOCK_SIZE unit
                                                                                                            // see W1_COL_X for more simplified calculation
    parameter int W0_NUM_CORES_A    = self_attention_pkg::NUM_CORES_A_Qn_KnT;
    parameter int W0_NUM_CORES_B    = 1;
    //parameter int W0_TOTAL_MODULES  = self_attention_pkg::TOTAL_MODULES_LP_Q;   // Old
    parameter int W0_TOTAL_MODULES  = linear_proj_pkg:: TOTAL_MODULES; // New, This used solely just for the slicing index,
                                                                        // this is not represent the actual number of TOTAL_MODULES used in the next calculation
    localparam W0_SLICE_WIDTH       = B0_WIDTH*(top_pkg::TOP_CHUNK_SIZE)*W0_NUM_CORES_A;
    localparam W0_MODULE_WIDTH      = W0_SLICE_WIDTH*TOTAL_INPUT_W_W0;
    localparam W0_IN_WIDTH          = W0_SLICE_WIDTH * W0_NUM_CORES_B * W0_TOTAL_MODULES;
    //localparam W0_TOTAL_DEPTH       = W0_ROW_X * W0_COL_X; // Can be reduced even further
    localparam W0_TOTAL_DEPTH       = ((2 * W0_COL_X) < (W0_ROW_X * W0_COL_X)) ? (2 * W0_COL_X) : (W0_ROW_X * W0_COL_X); // New formula, basically 2*W0_COL_X of TOTAL_DEPTH
    localparam W0_MEMORY_SIZE       = W0_TOTAL_DEPTH * W0_MODULE_WIDTH;
    localparam int ADDR_WIDTH_W0    = $clog2(W0_TOTAL_DEPTH);
    //localparam W0_TOTAL_IN          = W0_ROW_X * W0_COL_X / TOTAL_INPUT_W_W0;                 // Old
    localparam W0_TOTAL_IN          = W0_ROW_X * W0_COL_X / linear_proj_pkg::LP_TOTAL_MODULES_Q;   // New

    // For North Buffer 0 , PLEASE CHANGE THESE PARAMETERS ACCORDING TO YOUR USAGE
    parameter TOTAL_INPUT_W_N0      = 2;
    parameter int N0_ROW_X          = W0_COL_X;
    parameter int N0_COL_X          = W0_ROW_X;
    parameter int N0_NUM_CORES_A    = 1;
    parameter int N0_NUM_CORES_B    = self_attention_pkg::NUM_CORES_B_Qn_KnT;
    //parameter int N0_TOTAL_MODULES  = self_attention_pkg::TOTAL_MODULES_LP_K; // Old 1, This used solely just for the slicing index
                                                                                // this is not represent the actual number of TOTAL_MODULES used in the next calculation
    parameter int N0_TOTAL_MODULES  = linear_proj_pkg:: TOTAL_MODULES;
    localparam N0_SLICE_WIDTH       = B0_WIDTH*(top_pkg::TOP_CHUNK_SIZE)*N0_NUM_CORES_B;
    localparam N0_MODULE_WIDTH      = N0_SLICE_WIDTH*TOTAL_INPUT_W_N0;  // New
    //localparam N0_MODULE_WIDTH      = N0_SLICE_WIDTH*N0_TOTAL_MODULES;    // Old 1
    //localparam N0_IN_WIDTH          = N0_SLICE_WIDTH * N0_NUM_CORES_A * N0_TOTAL_MODULES;   // Old 0
    //localparam N0_IN_WIDTH          = N0_MODULE_WIDTH; // Old 1
    localparam N0_IN_WIDTH          = N0_SLICE_WIDTH * linear_proj_pkg::TOTAL_MODULES; // New
    localparam N0_TOTAL_DEPTH       = N0_ROW_X * N0_COL_X;
    localparam N0_MEMORY_SIZE       = N0_TOTAL_DEPTH * N0_MODULE_WIDTH;
    localparam int ADDR_WIDTH_N0    = $clog2(N0_TOTAL_DEPTH);

    parameter int ROW_SIZE_MAT_C_B0 = W0_ROW_X;
    parameter int COL_SIZE_MAT_C_B0 = N0_COL_X;
    parameter int MAX_FLAG_B0       = (ROW_SIZE_MAT_C_B0 * COL_SIZE_MAT_C_B0);

    // =================================== BUFFER 1 ===================================
    parameter int B1_WIDTH          = top_pkg::TOP_WIDTH_OUT;
    parameter int B1_INNER_DIMENSTION = 1;

    // For West Buffer 1
    parameter TOTAL_INPUT_W_W1      = 2;
    parameter int W1_ROW_X          = (self_attention_pkg::A_OUTER_DIMENSION_Qn_KnT)/
                                        (linear_proj_pkg::BLOCK_SIZE * self_attention_pkg::NUM_CORES_A_QKT_Vn * self_attention_pkg::TOTAL_INPUT_W_Qn_KnT);
    parameter int W1_COL_X          = (self_attention_pkg::B_OUTER_DIMENSION_Qn_KnT)/
                                        (linear_proj_pkg::BLOCK_SIZE);
    parameter int W1_NUM_CORES_A    = self_attention_pkg::NUM_CORES_A_QKT_Vn;
    parameter int W1_NUM_CORES_B    = 1;
    parameter int W1_TOTAL_MODULES  = 1;
    localparam W1_SLICE_WIDTH       = B1_WIDTH*(top_pkg::TOP_CHUNK_SIZE)*W1_NUM_CORES_A;
    localparam W1_MODULE_WIDTH      = W1_SLICE_WIDTH*TOTAL_INPUT_W_W1;
    localparam W1_IN_WIDTH          = W1_SLICE_WIDTH * W1_NUM_CORES_B * W1_TOTAL_MODULES;
    //localparam W1_TOTAL_DEPTH       = W1_ROW_X * W1_COL_X; // Old, Can be reduced even further (maybe == N_TOTAL_DEPTH because we will wait at the same time as the entire north matrix is loaded, then do the circular address computation)
    localparam W1_TOTAL_DEPTH       = ((2 * W1_COL_X) < (W1_ROW_X * W1_COL_X)) ? (2 * W1_COL_X) : (W1_ROW_X * W1_COL_X); // New formula
    localparam W1_MEMORY_SIZE       = W1_TOTAL_DEPTH * W1_MODULE_WIDTH;
    localparam int ADDR_WIDTH_W1    = $clog2(W1_TOTAL_DEPTH);
    //localparam W1_TOTAL_IN          = W1_ROW_X * W1_COL_X / TOTAL_INPUT_W_W1;
    localparam W1_TOTAL_IN          = W1_ROW_X * W1_COL_X;

    // For North Buffer 1 (Buffer N Special)
    parameter TOTAL_INPUT_W_N1      = TOTAL_INPUT_W_N0;
    parameter int N1_ROW_X          = linear_proj_pkg::A_OUTER_DIMENSION / linear_proj_pkg::BLOCK_SIZE; // In BLOCK_SIZE
    parameter int N1_COL_X          = linear_proj_pkg::B_OUTER_DIMENSION / (linear_proj_pkg::NUM_CORES_B * linear_proj_pkg::LP_TOTAL_MODULES_V * linear_proj_pkg::BLOCK_SIZE);
    //parameter int N1_NUM_CORES_A    = self_attention_pkg::NUM_CORES_A_Qn_KnT;   // Old, For slicing purpose
    parameter int N1_NUM_CORES_A    = linear_proj_pkg::NUM_CORES_A; // New, For slicing purpose
    //parameter int N1_NUM_CORES_B    = self_attention_pkg::NUM_CORES_B_Qn_KnT;   // Old,
    parameter int N1_NUM_CORES_B    = linear_proj_pkg::TOTAL_MODULES; // New
    parameter int N1_TOTAL_MODULES  = 1;
    localparam N1_SLICE_WIDTH       = B1_WIDTH*(top_pkg::TOP_CHUNK_SIZE);
    localparam N1_MODULE_WIDTH      = N1_SLICE_WIDTH*N1_NUM_CORES_B;
    localparam N1_IN_WIDTH          = N1_SLICE_WIDTH * N1_NUM_CORES_A * N1_NUM_CORES_B;
    localparam N1_TOTAL_DEPTH       = N1_ROW_X * N1_COL_X;
    localparam N1_MEMORY_SIZE       = N1_TOTAL_DEPTH * N1_MODULE_WIDTH;
    localparam int ADDR_WIDTH_N1    = $clog2(N1_TOTAL_DEPTH);

    parameter int ROW_SIZE_MAT_C_B1 = W1_ROW_X;
    parameter int COL_SIZE_MAT_C_B1 = N1_COL_X;
    parameter int MAX_FLAG_B1       = (ROW_SIZE_MAT_C_B1 * COL_SIZE_MAT_C_B1);

endpackage

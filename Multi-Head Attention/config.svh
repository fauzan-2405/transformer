// ============================================
// config.svh (GLOBAL CONFIGURATION)
// ============================================

// Widths
`ifndef SYSTEM_TOP_WIDTH
    `define SYSTEM_TOP_WIDTH 16
`endif

`ifndef SYSTEM_FRAC_WIDTH
    `define SYSTEM_FRAC_WIDTH 8
`endif

// Architecture
`ifndef TOP_BLOCK_SIZE
    `define TOP_BLOCK_SIZE 2
`endif

`ifndef TOP_CHUNK_SIZE
    `define TOP_CHUNK_SIZE 4
`endif

// Matrix Dimension
`ifndef I_MATRIX_DIMENSION
    `define I_MATRIX_DIMENSION 16
`endif

`ifndef INNER_MATRIX_DIMENSION
    `define INNER_MATRIX_DIMENSION 10
`endif

`ifndef W_MATRIX_DIMENSION
    `define W_MATRIX_DIMENSION 12
`endif

// Modules
`ifndef SYSTEM_NUM_CORES_A
    `define SYSTEM_NUM_CORES_A 2
`endif

`ifndef SYSTEM_TOTAL_MODULES
    `define SYSTEM_TOTAL_MODULES 2
`endif


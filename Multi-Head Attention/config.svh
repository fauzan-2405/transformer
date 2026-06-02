// ==================================
// config.svh
// ==================================

// Widths ==================================
// Input width
`ifndef SYSTEM_TOP_WIDTH_INPUT
	`define SYSTEM_TOP_WIDTH_INPUT 16
`endif

`ifndef SYSTEM_FRAC_WIDTH_INPUT
	`define SYSTEM_FRAC_WIDTH_INPUT 8
`endif

// Weight width
`ifndef SYSTEM_TOP_WIDTH_WEIGHT
	`define SYSTEM_TOP_WIDTH_WEIGHT 16
`endif

`ifndef SYSTEM_FRAC_WIDTH_WEIGHT
	`define SYSTEM_FRAC_WIDTH_WEIGHT 8
`endif

// Linear projection width
`ifndef SYSTEM_TOP_WIDTH_KEYS
	`define SYSTEM_TOP_WIDTH_KEYS (`SYSTEM_TOP_WIDTH_INPUT + 2)
`endif

`ifndef SYSTEM_FRAC_WIDTH_KEYS
	`define SYSTEM_FRAC_WIDTH_KEYS (`SYSTEM_FRAC_WIDTH_INPUT + 1)
`endif

// Q_KT width
`ifndef SYSTEM_TOP_WIDTH_QKT
	`define SYSTEM_TOP_WIDTH_QKT (`SYSTEM_TOP_WIDTH_KEYS + 4)
`endif

`ifndef SYSTEM_FRAC_WIDTH_QKT
	`define SYSTEM_FRAC_WIDTH_QKT (`SYSTEM_FRAC_WIDTH_KEYS + 1)
`endif

// Softmax width
`ifndef SYSTEM_TOP_WIDTH_SOFTMAX
	`define SYSTEM_TOP_WIDTH_SOFTMAX 8
`endif

`ifndef SYSTEM_FRAC_WIDTH_SOFTMAX
	`define SYSTEM_FRAC_WIDTH_SOFTMAX 7
`endif

// Final output width
`ifndef SYSTEM_TOP_WIDTH_FINAL
	`define SYSTEM_TOP_WIDTH_FINAL 16
`endif

`ifndef SYSTEM_FRAC_WIDTH_FINAL
	`define SYSTEM_FRAC_WIDTH_FINAL 8
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



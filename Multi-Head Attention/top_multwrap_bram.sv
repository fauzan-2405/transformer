// top_multwrap_bram
// This top module wraps multi_matmul_wrapper + bram for testing purposes

module top_multwrap_bram #(
    parameter TOTAL_INPUT_W = 2,
    parameter TOTAL_MODULES = 4
) (
    import linear_proj_pkg::*;
    input logic clk, rst_n,
    input logic en_module,

    input logic in_a_ena,
    input logic in_a_wea,
    input [ADDR_WIDTH_A-1:0] in_a_addra,
    input [WIDTH_A*CHUNK_SIZE*NUM_CORES_A-1:0] in_a_dina,

    output logic done, out_valid,
    output [(WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A*NUM_CORES_B*TOTAL_MODULES)-1:0] out_multi_matmul [TOTAL_INPUT_W]
);
    // Local Parameters
    localparam ROW_SIZE_MAT_C = A_OUTER_DIMENSION / (BLOCK_SIZE * NUM_CORES_A * TOTAL_INPUT_W); 
    localparam COL_SIZE_MAT_C = B_OUTER_DIMENSION / (BLOCK_SIZE * NUM_CORES_B * TOTAL_MODULES); 
    localparam MAX_FLAG = (ROW_SIZE_MAT_C * COL_SIZE_MAT_C);

    localparam MEMORY_SIZE_A = INNER_DIMENSION*A_OUTER_DIMENSION*WIDTH_A;
    localparam MEMORY_SIZE_B = INNER_DIMENSION*B_OUTER_DIMENSION*WIDTH_B;
    
    


endmodule
// 4bit_rshift.sv
// Used to do arithmetic right shift 4 bit

module 4bit_rshift #(
    parameter WIDTH_A = 16,
    parameter FRAC_WIDTH_A = 8,
    parameter WIDTH_B = 16,
    parameter FRAC_WIDTH_B = 8,
    parameter WIDTH_OUT = 16,
    parameter FRAC_WIDTH_OUT = 8,
    parameter BLOCK_SIZE = 2, 
    parameter CHUNK_SIZE = 4,
    parameter INNER_DIMENSION = 64,
    parameter TOTAL_MODULES = 2,
    parameter TOTAL_INPUT_W = 2,
    parameter NUM_CORES_B = 1,
    parameter NUM_CORES_A = 4
) (
    input logic clk, rst_n,
    input logic [(WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A*NUM_CORES_B*TOTAL_MODULES)-1:0] in_4bit_rshift [TOTAL_INPUT_W],

    output logic 
);
endmodule
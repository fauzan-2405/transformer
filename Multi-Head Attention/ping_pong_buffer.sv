// ping_pong_buffer.sv
// Used to bridge linear projection results with Qn x KnT matmul in self-head attention
import linear_proj_pkg::*;

module ping_pong_buffer #(
    parameter IN_WIDTH   = WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A*NUM_CORES_B*TOTAL_MODULES
) (
    input logic clk, rst_n,

    output logic 
);
endmodule
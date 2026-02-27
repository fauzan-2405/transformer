// top_r2b_converter_v.sv
// Used to wrap r2b_converter_v.v for easier use

module top_r2b_converter_v #(
    parameter WIDTH       = 16,
    parameter FRAC_WIDTH  = 8,
    parameter BLOCK_SIZE  = 2,
    parameter CHUNK_SIZE  = 4,
    parameter ROW         = 2754,
    parameter COL         = 256,
    parameter NUM_CORES_V = 2,
    parameter TOTAL_SOFTMAX_ROW  = 4,
    parameter TOTAL_TILE_SOFTMAX = 2
) (
    input logic clk,
    input logic rst_n [TOTAL_TILE_SOFTMAX],
    input logic en,
    input logic in_valid [TOTAL_TILE_SOFTMAX],
    input logic [WIDTH*COL-1:0] in_data [TOTAL_INPUT_W_Qn_KnT][TOTAL_SOFTMAX_ROW], // Take all softmax output data
    input logic [$clog2(TOTAL_SOFTMAX_ROW):0] r2b_row_idx [TOTAL_TILE_SOFTMAX],
    output logic slice_done [TOTAL_TILE_SOFTMAX],
    output logic output_ready [TOTAL_TILE_SOFTMAX],
    output logic slice_last [TOTAL_TILE_SOFTMAX],
    output logic buffer_done [TOTAL_TILE_SOFTMAX],
    output logic [WIDTH*CHUNK_SIZE*NUM_CORES_V-1:0] out_data [TOTAL_INPUT_W_Qn_KnT][TOTAL_TILE_SOFTMAX]
);

    // ************************** R2B CONVERTER **************************
    genvar l,m;
    generate
        for (l = 0; l < TOTAL_INPUT_W_Qn_KnT; l++) begin
            for (m = 0; m < TOTAL_TILE_SOFTMAX; m++) begin
                r2b_converter_v #(
                    .WIDTH(WIDTH),
                    .FRAC_WIDTH(FRAC_WIDTH),
                    .BLOCK_SIZE(BLOCK_SIZE),
                    .CHUNK_SIZE(CHUNK_SIZE),
                    .ROW(ROW), // Real row representation
                    .COL(COL), // Real col representation
                    .NUM_CORES_V(NUM_CORES_V)
                ) r2b_converter_unit (
                    .clk(clk),
                    .rst_n(rst_n[m]),
                    .en(en),
                    .in_valid(in_valid[m]),
                    .in_data(in_data[l][r2b_row_idx[m]]),
                    .slice_done(slice_done[m]),
                    .output_ready(output_ready[m]),
                    .slice_last(slice_last[m]),
                    .buffer_done(buffer_done[m]),
                    .out_data(out_data[l][m])
                );
            end
        end
    endgenerate

endmodule

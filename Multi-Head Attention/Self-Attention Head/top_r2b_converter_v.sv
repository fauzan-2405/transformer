// top_r2b_converter_v.sv
// Used to wrap r2b_converter_v.v for easier use

module top_r2b_converter_v #(
    parameter WIDTH       = 16,
    parameter FRAC_WIDTH  = 8,
    parameter BLOCK_SIZE  = 2,
    parameter CHUNK_SIZE  = 4,
    parameter ROW         = 4,
    parameter COL         = 2,
    parameter NUM_CORES_V = 2,
    parameter TOTAL_SOFTMAX_ROW  = 4,
    parameter TOTAL_TILE_SOFTMAX = 2,
    parameter TOTAL_INPUT_W_Qn_KnT = 2
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
    logic slice_done_sig [TOTAL_INPUT_W_Qn_KnT][TOTAL_TILE_SOFTMAX];
    logic output_ready_sig [TOTAL_INPUT_W_Qn_KnT][TOTAL_TILE_SOFTMAX];
    logic slice_last_sig [TOTAL_INPUT_W_Qn_KnT][TOTAL_TILE_SOFTMAX];
    logic buffer_done_sig [TOTAL_INPUT_W_Qn_KnT][TOTAL_TILE_SOFTMAX];
    
    always_comb begin
        for (int a = 0; a < TOTAL_TILE_SOFTMAX; a++) begin
            slice_done[a]   = slice_done_sig[0][a];
            output_ready[a] = output_ready_sig[0][a];
            slice_last[a]   = slice_last_sig[0][a];
            buffer_done[a]  = buffer_done_sig[0][a];
        end
    end

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
                    .slice_done(slice_done_sig[l][m]),         // Updated
                    .output_ready(output_ready_sig[l][m]),     // Updated
                    .slice_last(slice_last_sig[l][m]),         // Updated
                    .buffer_done(buffer_done_sig[l][m]),       // Updated
                    .out_data(out_data[l][m])
                );
            end
        end
    endgenerate

endmodule

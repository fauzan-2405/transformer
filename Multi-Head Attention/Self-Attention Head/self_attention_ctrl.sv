// self_attention_ctrl.sv

module self_attention_ctrl #(
    parameter WIDTH         = 16,
    parameter COL           = 64,
    parameter TILE_SIZE     = 8,
    parameter NUM_CORES_A_Qn_KnT = 2,
    parameter BLOCK_SIZE    = 2,

    localparam TOTAL_SOFTMAX_ROW = NUM_CORES_A_Qn_KnT * BLOCK_SIZE
)(
    input logic clk, rst_n,

    // From/To B2R converter
    input logic in_valid_b2r,
    input logic slice_done_b2r_wrap,
    input logic out_ready_b2r_wrap,
    //input logic [WIDTH_OUT*COL_B2R_CONVERTER-1:0] out_b2r_data [TOTAL_INPUT_W_Qn_KnT],
    output logic internal_rst_n_b2r, 

    // From/To Softmax
    output logic internal_rst_n_softmax,
    output logic softmax_en,
    output logic softmax_valid [TOTAL_SOFTMAX_ROW]
);
    // ************************** LOCALPARAMETERS & REGISTERS **************************
    localparam NUM_TILES    = COL / TILE_SIZE;
    localparam TILE_WIDTH   = WIDTH * TILE_SIZE;

    logic streaming;
    logic [$clog2(NUM_TILES):0] tile_idx;                 // Indicate the index of the tile that we give to the softmax
    logic [$clog2(TOTAL_SOFTMAX_ROW)-1:0] softmax_in_valid; // Indicate which softmax is valid to take the input
    integer i;


    // ************************** MAIN CONTROLLER **************************
    always @(posedge clk) begin
        if (!rst_n) begin
            internal_rst_n_b2r      <= rst_n;
            internal_rst_n_softmax  <= rst_n;
            softmax_en      <= 0;
            tile_idx        <= '0;
            softmax_in_valid <= '0;

            for (i = 0; i < TOTAL_SOFTMAX_ROW; i++) begin
                softmax_valid[i] <= 0;
            end
        end else begin
            internal_rst_n_b2r      <= ~slice_done_b2r_wrap;
            //streaming               <= out_ready_b2r_wrap;

            // Activate the softmax_en for the first time
            if (!softmax_en && in_valid_b2r) begin
                softmax_en  <= 1'b1;
            end

            // tile_in valid for softmax
            if (streaming) begin
                // Update tile index to indicate what is the next tile_idx that we working on
                if (tile_idx < NUM_TILES) begin
                    tile_idx    <= tile_idx + 1; 
                end

                // Toggling the correct softmax_valid for the corresponding softmax
                for (i = 0; i < TOTAL_SOFTMAX_ROW; i++) begin
                    softmax_valid[i] <= (i == TOTAL_SOFTMAX_ROW - 1 - softmax_in_valid);
                end

                // Advancing the softmax_valid through the entire TOTAL_SOFTMAX_ROW
                if (softmax_in_valid != TOTAL_SOFTMAX_ROW) begin
                    softmax_in_valid <= softmax_in_valid + 1;
                end else begin
                    // If we already reached the TOTAL_SOFTMAX_ROW:
                    softmax_in_valid <= '0;     
                end
            end else begin
                for (i = 0; i < TOTAL_SOFTMAX_ROW; i++) begin
                    softmax_valid[i] <= 1'b0;
                end
            end

        end
    end

    assign streaming = out_ready_b2r_wrap;
endmodule
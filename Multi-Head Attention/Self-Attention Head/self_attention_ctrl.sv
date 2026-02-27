// self_attention_ctrl.sv

module self_attention_ctrl #(
    parameter WIDTH         = 16,
    parameter COL           = 64,
    parameter TILE_SIZE     = 8,
    parameter NUM_CORES_A_Qn_KnT = 2,
    parameter BLOCK_SIZE    = 2,
    parameter TOTAL_INPUT_W_Qn_KnT = 2,
    parameter NUMBER_OF_BUFFER_INSTANCES = 1,
    parameter TILE_SIZE_SOFTMAX = 8,
    parameter TOTAL_TILE_SOFTMAX = 2,

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
    input logic softmax_done [NUMBER_OF_BUFFER_INSTANCES][TOTAL_INPUT_W_Qn_KnT][TOTAL_SOFTMAX_ROW],
    input logic softmax_out_valid [TOTAL_SOFTMAX_ROW],
    output logic internal_rst_n_softmax [NUMBER_OF_BUFFER_INSTANCES][TOTAL_INPUT_W_Qn_KnT][TOTAL_SOFTMAX_ROW],
    output logic softmax_en,
    output logic softmax_valid [TOTAL_SOFTMAX_ROW],

    // From/To R2B Converter
    output logic [$clog2(TOTAL_SOFTMAX_ROW):0] r2b_row_idx_sig [TOTAL_TILE_SOFTMAX],
    output logic in_valid_r2b [TOTAL_TILE_SOFTMAX],
    output logic internal_rst_n_r2b [TOTAL_TILE_SOFTMAX],
    input logic slice_last_r2b [TOTAL_TILE_SOFTMAX]
);
    // ************************** LOCALPARAMETERS & REGISTERS **************************
    localparam NUM_TILES    = COL / TILE_SIZE;
    localparam TILE_WIDTH   = WIDTH * TILE_SIZE;

    logic streaming;
    logic [$clog2(TOTAL_SOFTMAX_ROW)-1:0] softmax_in_valid; // Indicate which softmax is valid to take the input
    logic softmax_valid_sig [TOTAL_SOFTMAX_ROW];

    logic [$clog2(TOTAL_SOFTMAX_ROW):0] global_row_ptr;
    logic [$clog2(TOTAL_SOFTMAX_ROW):0] r2b_row_idx [TOTAL_TILE_SOFTMAX];    // Which softmax row output we are currently consuming
    logic any_softmax_valid;

    integer i, j, k;


    // ************************** MAIN CONTROLLER **************************
    always @* begin/*
        for (int a = 0; a < NUMBER_OF_BUFFER_INSTANCES; a++) begin
            for (int b = 0; b < TOTAL_INPUT_W_Qn_KnT; b++) begin
                for (int c = 0; c < TOTAL_SOFTMAX_ROW; c++) begin
                    internal_rst_n_softmax[a][b][c]  = ~softmax_done[a][b][c];
                end
            end
        end*/

        any_softmax_valid = 0;
        for (int r = 0; r < TOTAL_SOFTMAX_ROW; r++) begin
            any_softmax_valid |= softmax_out_valid[r];
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            internal_rst_n_b2r      <= rst_n;

            for (i = 0; i < NUMBER_OF_BUFFER_INSTANCES; i++) begin
                for (j = 0; j < TOTAL_INPUT_W_Qn_KnT; j++) begin
                    for (k = 0; k < TOTAL_SOFTMAX_ROW; k++) begin
                        internal_rst_n_softmax[i][j][k]  <= rst_n;
                    end
                end
            end


            softmax_en      <= 0;
            softmax_in_valid <= '0;

            for (i = 0; i < TOTAL_SOFTMAX_ROW; i++) begin
                softmax_valid_sig[i] <= 0;
            end

            // R2B controller
            global_row_ptr  <= '0;
            for (int m = 0; m < TOTAL_TILE_SOFTMAX; m++) begin
                in_valid_r2b[m] <= '0;
                internal_rst_n_r2b[m]   <= rst_n;
                r2b_row_idx[m]     <= '0;
            end

        end else begin
            // ************************************** B2R & SOFTMAX CONTROLLER **************************************
            internal_rst_n_b2r  <= ~slice_done_b2r_wrap;

            for (i = 0; i < NUMBER_OF_BUFFER_INSTANCES; i++) begin
                for (j = 0; j < TOTAL_INPUT_W_Qn_KnT; j++) begin
                    for (k = 0; k < TOTAL_SOFTMAX_ROW; k++) begin
                        internal_rst_n_softmax[i][j][k]  <= ~softmax_done[i][j][k];
                    end
                end
            end


            // Activate the softmax_en for the first time
            if (!softmax_en && in_valid_b2r) begin
                softmax_en  <= 1'b1;
            end

            // tile_in valid for softmax
            if (streaming) begin
                // Toggling the correct softmax_valid_sig for the corresponding softmax
                for (i = 0; i < TOTAL_SOFTMAX_ROW; i++) begin
                    //softmax_valid_sig[i] <= (i == TOTAL_SOFTMAX_ROW - 1 - softmax_in_valid); // In reverse
                    softmax_valid_sig[i] <= (i == softmax_in_valid); // In forward
                end

                // Advancing the softmax_valid_sig through the entire TOTAL_SOFTMAX_ROW
                if (softmax_in_valid != TOTAL_SOFTMAX_ROW) begin
                    softmax_in_valid <= softmax_in_valid + 1;
                end else begin
                    // If we already reached the TOTAL_SOFTMAX_ROW:
                    softmax_in_valid <= '0;
                end
            end else begin
                for (i = 0; i < TOTAL_SOFTMAX_ROW; i++) begin
                    softmax_valid_sig[i] <= 1'b0;
                    //softmax_in_valid[i] <= 1'b0;
                end
            end

            // ************************************** R2B CONTROLLER **************************************
            // default clear
            for (int m = 0; m < TOTAL_TILE_SOFTMAX; m++) begin
                in_valid_r2b[m] <= 0;
                internal_rst_n_r2b[m]   <= ~slice_last_r2b[m];
            end

            // Advance head pointer
            if (any_softmax_valid) begin
                if (global_row_ptr < TOTAL_SOFTMAX_ROW) begin
                    global_row_ptr  <= global_row_ptr + 1;
                end
            end

            // Progressive diagonal mapping
            for (int m = 0; m < TOTAL_TILE_SOFTMAX; m++) begin
                if (global_row_ptr >= m) begin

                    logic [$clog2(TOTAL_SOFTMAX_ROW):0] computed_row;
                    computed_row = global_row_ptr - m;

                    r2b_row_idx[m] <= computed_row;

                    if (softmax_out_valid[computed_row]) begin
                        in_valid_r2b[m] <= 1;
                    end
                end
                else begin
                    // hold 0 before pipeline fill
                    r2b_row_idx[m] <= 0;
                end
            end
        end
    end

    assign r2b_row_idx_sig = r2b_row_idx;
    assign streaming = out_ready_b2r_wrap;
    assign softmax_valid = softmax_valid_sig;
endmodule

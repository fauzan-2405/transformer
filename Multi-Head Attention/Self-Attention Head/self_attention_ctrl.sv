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
    parameter NUM_BANKS_FIFO = 2,
    parameter NUM_CORES_V    = 2,
    parameter RD_DATA_COUNT_WIDTH = 4,
    parameter WR_DATA_COUNT_WIDTH = 4,
    parameter TOTAL_OUTPUTS_PER_TILE = 4,

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
    input logic slice_last_r2b [TOTAL_TILE_SOFTMAX],

    // From/To FIFO Buffer
    //input logic fifo_full [NUM_BANKS_FIFO],
    input logic [WR_DATA_COUNT_WIDTH-1:0] wr_data_count_fifo [NUM_BANKS_FIFO],
    input logic [RD_DATA_COUNT_WIDTH-1:0] rd_data_count_fifo [NUM_BANKS_FIFO],
    output logic internal_rst_n_fifo [NUM_BANKS_FIFO],
    output logic fifo_rd_en [TOTAL_TILE_SOFTMAX],
    input logic fifo_underflow [TOTAL_TILE_SOFTMAX],
    //output logic fifo_out_valid [NUM_BANKS_FIFO],
    output logic fifo_out_valid,
    output logic [$clog2(TOTAL_TILE_SOFTMAX)-1:0] fifo_idx [NUM_BANKS_FIFO] // Determines the fifo unit that used in circular fashion
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

    logic first_time_fifo;  // Indicates the first time FIFO is filled
    logic last_fifo_done;   // Indicates the last FIFO is already finished
    logic fifo_rd_en_reg[TOTAL_TILE_SOFTMAX];   // Delayed version of fifo_rd_en
    logic fifo_out_valid_sig [NUM_BANKS_FIFO];
    integer i, j, k;


    // ************************** MAIN CONTROLLER **************************
    always @* begin
        // ************************************** SOFTMAX & R2B CONTROLLER **************************************
        // Progressive diagonal mapping
        for (int m = 0; m < TOTAL_TILE_SOFTMAX; m++) begin
            in_valid_r2b[m] = 0;
            if (global_row_ptr >= m) begin

                logic [$clog2(TOTAL_SOFTMAX_ROW):0] computed_row;
                computed_row = global_row_ptr - m;

                r2b_row_idx[m] = computed_row;

                if (softmax_out_valid[computed_row]) begin
                    in_valid_r2b[m] = 1;
                end
            end
            else begin
                // hold 0 before pipeline fill
                r2b_row_idx[m] = 0;
                //in_valid_r2b[m] = 0;
            end
        end

        any_softmax_valid = 0;
        for (int r = 0; r < TOTAL_SOFTMAX_ROW; r++) begin
            any_softmax_valid |= softmax_out_valid[r];
        end
        
        // ************************************** FIFO R2B CONTROLLER **************************************
        fifo_out_valid = 1'b0;
        for (int m = 0; m < NUM_BANKS_FIFO; m++) begin
            fifo_out_valid_sig[m] = fifo_rd_en[fifo_idx[m]] & fifo_rd_en_reg[fifo_idx[m]];
            fifo_out_valid |= fifo_out_valid_sig[m];
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
                //in_valid_r2b[m] <= '0;
                internal_rst_n_r2b[m]   <= rst_n;
                //r2b_row_idx[m]     <= '0;
            end

            // FIFO controller
            for (int a = 0; a < NUM_BANKS_FIFO; a++) begin
                internal_rst_n_fifo[a]  <= rst_n;
                fifo_idx[a]             <= a; // Initialize each index as their respective number of their fifo banks
            end
            for (int m = 0; m < TOTAL_TILE_SOFTMAX; m++) begin
                fifo_rd_en[m]           <= 0;
                fifo_rd_en_reg[m]       <= 0;   
            end
            first_time_fifo <= 0;
            last_fifo_done  <= 0;
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
                //in_valid_r2b[m] <= 0;
                internal_rst_n_r2b[m]   <= ~slice_last_r2b[m];
                if (!internal_rst_n_r2b[TOTAL_TILE_SOFTMAX-1]) begin
                    global_row_ptr  <= '0;
                end
            end

            // Advance head pointer
            if (any_softmax_valid) begin
                if (global_row_ptr < TOTAL_SOFTMAX_ROW) begin
                    global_row_ptr  <= global_row_ptr + 1;
                end
            end

            // ************************************** FIFO BUFFER **************************************
            // Toggle first_time_fifo when wr_data_count from first fifo unit is 1 
            //(there will be a bug when the total data is just 1, i.e. idx == 0, but let's hope that wont happen)
            if (!first_time_fifo && wr_data_count_fifo[0] == 1) begin
                first_time_fifo <= 1'b1;
            end
            
            for (int m = 0; m < TOTAL_TILE_SOFTMAX; m++) begin
                fifo_rd_en_reg[m]   <= fifo_rd_en[m];
            end
            
            for (int a = 0; a < NUM_BANKS_FIFO; a++) begin
                // if FIFO full, turn on the read_enable
                if (wr_data_count_fifo[a] == TOTAL_OUTPUTS_PER_TILE) begin
                    if ((a == 0) && (first_time_fifo)) begin    // If this is the first time
                        fifo_rd_en[0]   <= 1'b1;
                        first_time_fifo <= 1'b0;    // Toggle first_time_fifo to LOW
                    end else begin
                        if (a == 0) begin
                            if (fifo_underflow[NUM_BANKS_FIFO-1]) begin
                                fifo_rd_en[a]   <= 1'b1;
                            end
                        end else begin
                            if (fifo_underflow[a-1]) begin
                                fifo_rd_en[a]   <= 1'b1;
                            end
                        end
                    end
                end
                
                /*
                // if FIFO full, turn on the read_enable
                if (wr_data_count_fifo[a] == TOTAL_OUTPUTS_PER_TILE-1) begin
                    fifo_rd_en[a]   <= 1'b1;
                end*/

                // if FIFO empty and/or near empty, turn off the read_enable and reset
                if (rd_data_count_fifo[a] == 1) begin
                    fifo_rd_en[a]   <= 1'b0;
                end

                if (rd_data_count_fifo[a] == 0) begin
                    //internal_rst_n_fifo[a]  <= 1'b0;

                    // Advance the fifo index (to be determined whether we place this block in fifo_empty or fifo_underflow)
                    if (fifo_idx[a] + NUM_BANKS_FIFO < TOTAL_TILE_SOFTMAX) begin
                        fifo_idx[a] <= fifo_idx[a] + NUM_BANKS_FIFO;
                    end
                end
                
                // After resetting the fifo, release the reset so it can advance for the next index ASAP
                internal_rst_n_fifo[a]  <= ~fifo_underflow[a];
            end
        end
    end

    assign r2b_row_idx_sig = r2b_row_idx;
    assign streaming = out_ready_b2r_wrap;
    assign softmax_valid = softmax_valid_sig;
endmodule


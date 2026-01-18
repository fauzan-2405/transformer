// buffer_ctrl.sv
// Used to control buffers
// Basically utilizing the linear_proj_ctrl.sv but tweaks some of the settings
// Combinational control assertion

module buffer_ctrl #(
    parameter TOTAL_MODULES_N     = 4,
    parameter TOTAL_MODULES_W     = 4,
    parameter ADDR_WIDTH_W      = 2,
    parameter ADDR_WIDTH_N      = 4,
    parameter W_COL_X           = 4, // Indicates how many columns from W_COL_X that being used as a west input
    parameter W_ROW_X           = 4,
    parameter N_ROW_X           = 4, // Indicates how many columns from N_ROW_X that being used as a north input
    parameter N_COL_X           = 4,
    parameter N_TOTAL_DEPTH     = 16,
    parameter W_TOTAL_DEPTH     = 10,
    parameter MAX_FLAG          = 16,
    parameter COL_Y             = 2,  // Indicates how many columns for the next resulting matrix
    parameter INNER_DIMENSION   = 2,
    localparam BLOCK_SIZE       = 2
) (
    input logic clk, rst_n,
    input logic in_valid_w,
    input logic in_valid_n,
    input logic acc_done_wrap, systolic_finish_wrap,

    // ------------- West Input Interface -------------
    // Bank 0 Interface
    output logic                     w_bank0_ena_ctrl,         
    output logic                     w_bank0_enb_ctrl,            
    output logic                     w_bank0_wea_ctrl, 
    output logic [ADDR_WIDTH_W-1:0]  w_bank0_addra_ctrl,
    output logic [ADDR_WIDTH_W-1:0]  w_bank0_addrb_ctrl,

    // ------------- North Input Interface -------------
    // Bank 0 Interface
    output logic                     n_bank0_ena_ctrl,         
    output logic                     n_bank0_enb_ctrl,            
    output logic                     n_bank0_wea_ctrl, 
    output logic [ADDR_WIDTH_N-1:0]  n_bank0_addra_ctrl,
    output logic [ADDR_WIDTH_N-1:0]  n_bank0_addrb_ctrl,


    output logic [$clog2(TOTAL_MODULES_W)-1:0] w_slicing_idx,
    output logic [$clog2(TOTAL_MODULES_N)-1:0] n_slicing_idx,
    output logic                             internal_rst_n_ctrl, internal_reset_acc_ctrl,
    output logic                             out_valid,
    output logic                             enable_matmul,
    output logic                             state_now
);
    // ************************************ Wires & Parameters ************************************
    typedef enum logic [1:0] {
        S_IDLE,
        S_LOAD_N,
        S_LOAD_N_FINISHED,
        S_DONE
    } fsm_state_t;
    fsm_state_t state_reg, state_next;

    logic [1:0] bank_valid, writing_phase;
    logic write_now_w, write_now_n;
        
    // ------------- Logics for address generation -------------
    logic internal_rst_n, internal_reset_acc;
    logic acc_done_wrap_rising;
    logic acc_done_wrap_d;
    assign acc_done_wrap_rising = ~acc_done_wrap_d & acc_done_wrap;
    logic [7:0] counter, counter_row, counter_col, flag;
    logic counter_acc_done;
    logic [$clog2(N_ROW_X):0] n_ready;// Revise the size later!
    logic [$clog2(W_ROW_X):0] w_ready;// Revise the size later!

    // ------------------- For West Input -------------------
    // For bank 0
    logic [ADDR_WIDTH_W-1:0] w_bank0_addra_wr;
    logic [ADDR_WIDTH_W-1:0] w_bank0_addrb_rd;

    // ------------------- For North Input -------------------
    // For bank 0
    logic [ADDR_WIDTH_N-1:0] n_bank0_addra_wr;
    logic [ADDR_WIDTH_N-1:0] n_bank0_addrb_rd;

    // ************************************ FSM Next State Logic ************************************
    always @* begin
        state_next = state_reg;
        case (state_reg)
            S_IDLE: begin
                state_next = (in_valid_n) ? S_LOAD_N : S_IDLE;
            end

            S_LOAD_N: begin // Load North Matrix + compute for the first time (if w matrix available)
                state_next = (n_bank0_addra_wr == N_TOTAL_DEPTH - 1) ? S_LOAD_N_FINISHED : S_LOAD_N;
            end

            S_LOAD_N_FINISHED: begin // The entire north matrix is loaded, begin computing like usual
                state_next = (flag == MAX_FLAG) ? S_DONE : S_LOAD_N_FINISHED;
            end

            S_DONE : begin
                state_next = (~rst_n) ? S_IDLE : S_DONE;
            end

            default: begin
                state_next = S_IDLE;
            end
        endcase
    end

    // ------------------- For West Input -------------------
    // For bank 0
    assign w_bank0_ena_ctrl   = (state_reg == S_LOAD_N);
    assign w_bank0_enb_ctrl   = (state_reg != S_DONE) && (state_reg != S_IDLE);
    assign w_bank0_wea_ctrl   = ((state_reg == S_LOAD_N) || (state_reg == S_LOAD_N_FINISHED)) ? ((write_now_w) ? 1 : 0) : 0;
    assign w_bank0_addra_ctrl = ((state_reg == S_LOAD_N) || (state_reg == S_LOAD_N_FINISHED)) ? w_bank0_addra_wr : '0;
    assign w_bank0_addrb_ctrl = ((state_reg != S_DONE) && (state_reg != S_IDLE)) ? w_bank0_addrb_rd : '0;
  
    // ------------------- For North Input -------------------
    // For bank 0
    assign n_bank0_ena_ctrl   = (state_reg != S_LOAD_N);
    assign n_bank0_enb_ctrl   = (state_reg != S_DONE) && (state_reg != S_IDLE);
    assign n_bank0_wea_ctrl   = (state_reg == S_LOAD_N) ? ((write_now_n) ? 1 : 0) : 0;
    assign n_bank0_addra_ctrl = (state_reg == S_LOAD_N) ? n_bank0_addra_wr : '0;
    assign n_bank0_addrb_ctrl = ((state_reg != S_DONE) && (state_reg != S_IDLE)) ? n_bank0_addrb_rd : '0;


    // ************************************ FSM Sequential Logic ************************************
    always @(posedge clk) begin 
        if (!rst_n) begin
            state_reg           <= S_IDLE;
            // Address generation
            counter             <= 0;
            counter_col         <= 0;
            counter_row         <= 0;
            counter_acc_done    <= 0;
            acc_done_wrap_d     <= 0;
            flag                <= 0;
            n_ready             <= '0;
            w_ready             <= '0;

            internal_rst_n      <= 1'b0;
            internal_reset_acc  <= 1'b0;

            // West Input Bank Controllers
            w_bank0_addra_wr      <= '0;
            w_bank0_addrb_rd      <= '0;

            // North Input Bank Controllers
            n_bank0_addra_wr      <= '0;
            n_bank0_addrb_rd      <= '0;

            write_now_n           <= 0;
            write_now_w           <= 0;
            w_slicing_idx         <= '0;      // For slicing the WEST input into SLICE_WIDTH using extract_module func
            n_slicing_idx         <= '0;      // For slicing the NORTH input into SLICE_WIDTH (see ping_pong_buffer_n.sv) using extract_module func
        end
        else begin
            state_reg             <= state_next;
            acc_done_wrap_d       <= acc_done_wrap;
            counter_acc_done      <= 0;

            // ------------------------------------------------------ WRITING PHASE ------------------------------------------------------
            if (in_valid_w) begin
                write_now_w   <= 1'b1;
            end else begin
                // Turning off the write enable for west matrix
                if (write_now_w && (w_slicing_idx == TOTAL_MODULES_W - 1)) begin
                    write_now_w   <= 1'b0;
                end
            end

            if (in_valid_n) begin
                write_now_n   <= 1'b1;
            end else begin
                // Turning off the write enable for north matrix
                if (write_now_n && (n_slicing_idx == TOTAL_MODULES_N - 1)) begin
                    write_now_n   <= 1'b0;
                end
            end

            //  --------------- Slicing Index ---------------
            if (write_now_w) begin
                w_slicing_idx       <= w_slicing_idx + 1;
                if (w_bank0_addra_wr == W_TOTAL_DEPTH -1) begin
                    w_bank0_addra_wr    <= '0; // Move to first address again after traversing until the end of the W address
                end else begin
                    w_bank0_addra_wr    <= w_bank0_addra_wr + 1; // West Address Generation, when slicing idx change
                    if (w_bank0_addra_wr % (INNER_DIMENSION/BLOCK_SIZE) == (INNER_DIMENSION/BLOCK_SIZE - 1)) begin
                        if (w_ready < W_ROW_X) begin
                            w_ready <= w_ready + 1;
                        end
                    end
                end
            end else begin
                w_slicing_idx       <= '0;
            end

            if (write_now_n) begin
                n_slicing_idx       <= n_slicing_idx + 1;
                n_bank0_addra_wr    <= n_bank0_addra_wr + 1; // North Address Generation, when slicing idx change
                // Checking the availability for north bank for the first time
                if (n_bank0_addra_wr % (INNER_DIMENSION/BLOCK_SIZE) == (INNER_DIMENSION/BLOCK_SIZE - 1)) begin
                    if (n_ready < N_ROW_X) begin
                        n_ready <= n_ready + 1;
                    end
                end
            end else begin
                n_slicing_idx       <= '0;
            end

            // ------------------------------------------------------ READING PHASE ------------------------------------------------------
            // Internal Reset Control
            if (enable_matmul) begin
                internal_rst_n  <= ~systolic_finish_wrap;
            end

            if ((w_ready >= 1) && (n_ready >= 1)) begin
                if (systolic_finish_wrap) begin
                    internal_reset_acc <= ~acc_done_wrap;

                    // Address controller
                    w_bank0_addrb_rd <= counter + (INNER_DIMENSION/BLOCK_SIZE)*counter_row; 
                    n_bank0_addrb_rd <= counter + (INNER_DIMENSION/BLOCK_SIZE)*counter_col;

                    // counter indicates the matrix C element iteration
                    if (counter == ((INNER_DIMENSION/BLOCK_SIZE) - 1)) begin 
                        counter <= '0;
                        // Substract the *_ready to check if the next set is available or not
                        w_ready <= w_ready - 1;
                        n_ready <= n_ready - 1;
                    end
                    else begin
                        counter <= counter + 1;
                    end
                end
            end

            // Column/Row Update
            if (acc_done_wrap_rising) begin
                // counter_row indicates the i-th row of the matrix C that we are working right now
                // counter_col indicates the i-th column of the matrix C that we are working right now

                // Check if we already at the end of the MAT C column
                if (counter_col == (COL_Y - 1)) begin
                    counter_col <= 0;
                    // Check if the counter_row exceeded the W_TOTAL_DEPTH so we rollback to the first set
                    if ((INNER_DIMENSION/BLOCK_SIZE)*(counter_row + 1) >= W_TOTAL_DEPTH) begin
                        counter_row <= '0;
                    end else begin
                        counter_row <= counter_row + 1;
                    end
                end else begin
                    counter_col <= counter_col + 1;
                end

                counter_acc_done <= 1;

                // Flag assigning for 'done' variable
                if (flag != MAX_FLAG) begin
                    flag <= flag + 1;   
                end
            end
            
        end
    end
    
    assign out_valid = counter_acc_done;
    assign enable_matmul = (state_reg != S_DONE) ;
    assign internal_reset_acc_ctrl  = internal_reset_acc;
    assign internal_rst_n_ctrl      = internal_rst_n;
    assign state_now                = (state_reg == S_LOAD_N) ? 0 : 
                                      (state_reg == S_LOAD_N_FINISHED) ? 1 : 0;

endmodule
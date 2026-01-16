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
    parameter MAX_FLAG          = 16,
    parameter COL_Y             = 2,  // Indicates how many columns for the next resulting matrix
    parameter INNER_DIMENSION   = 2,
    localparam BLOCK_SIZE       = 2
) (
    input logic clk, rst_n,
    input logic in_valid,
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
    logic write_now;
        
    // ------------- Logics for address generation -------------
    logic internal_rst_n, internal_reset_acc;
    logic acc_done_wrap_rising;
    logic acc_done_wrap_d;
    assign acc_done_wrap_rising = ~acc_done_wrap_d & acc_done_wrap;
    logic [7:0] counter, counter_row, counter_col, flag;
    logic counter_acc_done;

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
                state_next = (in_valid) ? S_W0_R1 : S_IDLE;
            end

            S_W0_R1: begin // Bank 0 is writing and Bank 1 is reading
                state_next = 
                            (flag == MAX_FLAG) ? S_DONE :
                            (bank_valid[0] == 1) ? S_W1_R0 : S_W0_R1;
            end

            S_W1_R0: begin // Bank 0 is reading and Bank 1 is writing
                state_next = 
                            (flag == MAX_FLAG) ? S_DONE :
                            (bank_valid[1] == 1) ? S_W0_R1 : S_W1_R0;
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
    assign w_bank0_ena_ctrl   = (state_reg != S_DONE) ? 1 : 0;
    assign w_bank0_enb_ctrl   = (state_reg != S_DONE) ? 1 : 0;
    assign w_bank0_wea_ctrl   = (state_reg == S_W0_R1) ? ((write_now) ? 1 : 0) : 0;
    assign w_bank0_web_ctrl   = (state_reg == S_W0_R1) ? ((write_now) ? 1 : 0) : 0;
    assign w_bank0_addra_ctrl = 
                                (state_reg == S_W0_R1) ? w_bank0_addra_wr : 
                                (state_reg == S_W1_R0) ? w_bank0_addra_rd : '0;
    assign w_bank0_addrb_ctrl = 
                                (state_reg == S_W0_R1) ? w_bank0_addrb_wr : 
                                (state_reg == S_W1_R0) ? w_bank0_addrb_rd : '0;
    
    // For bank 1
    assign w_bank1_ena_ctrl   = (state_reg != S_DONE) ? 1 : 0;
    assign w_bank1_enb_ctrl   = (state_reg != S_DONE) ? 1 : 0;
    assign w_bank1_wea_ctrl   = (state_reg == S_W1_R0) ? ((write_now) ? 1 : 0) : 0;
    assign w_bank1_web_ctrl   = (state_reg == S_W1_R0) ? ((write_now) ? 1 : 0) : 0;
    assign w_bank1_addra_ctrl = 
                                (state_reg == S_W1_R0) ? w_bank1_addra_wr : 
                                (state_reg == S_W0_R1) ? w_bank1_addra_rd : '0;
    assign w_bank1_addrb_ctrl = 
                                (state_reg == S_W1_R0) ? w_bank1_addrb_wr : 
                                (state_reg == S_W0_R1) ? w_bank1_addrb_rd : '0;
  
    // ------------------- For North Input -------------------
    // For bank 0
    assign n_bank0_ena_ctrl   = (state_reg != S_DONE) ? 1 : 0;
    assign n_bank0_enb_ctrl   = (state_reg != S_DONE) ? 1 : 0;
    assign n_bank0_wea_ctrl   = ((state_reg == S_W0_R1) || (state_reg == S_W1_R0)) &&
                                (n_bank0_addra_wr < (N_COL_X * N_ROW_X)) &&
                                write_now;
    assign n_bank0_addra_ctrl = ((state_reg == S_W1_R0) || (state_reg == S_W0_R1)) ? n_bank0_addra_wr : '0;
    assign n_bank0_addrb_ctrl = ((state_reg == S_W1_R0) || (state_reg == S_W0_R1)) ? n_bank0_addrb_rd : '0;


    // ************************************ FSM Sequential Logic ************************************
    always @(posedge clk) begin 
        if (!rst_n) begin
            state_reg           <= S_IDLE;
            // Address generation
            counter             <= 0;
            counter_col         <= 0;
            counter_row         <= 0; // Technically speaking, because we just operate in one row, counter_row value is always 0 (indicating 1/first row)
            counter_acc_done    <= 0;
            acc_done_wrap_d     <= 0;
            flag                <= 0;
            north_col_valid     <= '0;

            internal_rst_n      <= 1'b0;
            internal_reset_acc  <= 1'b0;

            // West Input Bank Controllers
            w_bank0_addra_wr      <= '0;
            w_bank0_addrb_wr      <= W_COL_X; // Because we started at the new line
            w_bank0_addra_rd      <= '0;
            w_bank0_addrb_rd      <= '0;
            
            w_bank1_addra_wr      <= '0;
            w_bank1_addrb_wr      <= W_COL_X; // Because we started at the new line
            w_bank1_addra_rd      <= '0;
            w_bank1_addrb_rd      <= '0;

            // North Input Bank Controllers
            n_bank0_addra_wr      <= '0;
            n_bank0_addrb_rd      <= '0;

            writing_phase         <= 2'b11;   // At reset, both directions will write (see README.MD for further explanation)
            bank_valid            <= 2'b00;   // To tell this bank[i] contains valid data / never read this bank
            write_now             <= 0;
            w_slicing_idx         <= '0;      // For slicing the WEST input into MODULE_WIDTH using extract_module func
            n_slicing_idx         <= '0;      // For slicing the NORTH input into SLICE_WIDTH (see ping_pong_buffer_n.sv) using extract_module func
        end
        else begin
            state_reg             <= state_next;
            acc_done_wrap_d       <= acc_done_wrap;
            counter_acc_done      <= 0;
        end
    end
    
    assign out_valid = counter_acc_done;
    assign enable_matmul = (state_reg != S_DONE) && (north_col_valid >= counter_col);
    assign internal_reset_acc_ctrl  = internal_reset_acc;
    assign internal_rst_n_ctrl      = internal_rst_n;
    assign state_now                = (state_reg == S_W0_R1) ? 0 : 
                                      (state_reg == S_W1_R0) ? 1 : 0;

endmodule
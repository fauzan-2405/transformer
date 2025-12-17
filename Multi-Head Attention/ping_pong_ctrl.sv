// ping_pong_ctrl.sv
// Used to control ping_pong_buffer
// Basically utilizing the linear_proj_ctrl.sv but tweaks some of the settings
// Combinational control assertion

module ping_pong_ctrl #(
    parameter TOTAL_MODULES = 4,
    parameter ADDR_WIDTH    = 4,
    parameter W_COL_X       = 4, // Indicates how many columns from W_COL_X that being used as a west input
    parameter N_COL_X       = 4, // Indicates how many columns from N_COL_X that being used as a north input
    parameter COL_Y         = 2  // Indicates how many columns for the next resulting matrix
) (
    input logic clk, rst_n,
    input logic in_valid,
    input logic acc_done_wrap, systolic_finish_wrap,

    // ------------- West Input Interface -------------
    // Bank 0 Interface
    output logic                     w_bank0_ena_ctrl, w_bank0_enb_ctrl,
    output logic                     w_bank0_wea_ctrl, w_bank0_web_ctrl,
    output logic [ADDR_WIDTH-1:0]    w_bank0_addra_ctrl, w_bank0_addrb_ctrl,

    // Bank 1 Interface
    output logic                     w_bank1_ena_ctrl, w_bank1_enb_ctrl,
    output logic                     w_bank1_wea_ctrl, w_bank1_web_ctrl,
    output logic [ADDR_WIDTH-1:0]    w_bank1_addra_ctrl, w_bank1_addrb_ctrl,

    // ------------- North Input Interface -------------
    // Bank 0 Interface
    output logic                     n_bank0_ena_ctrl,            
    output logic                     n_bank0_wea_ctrl, 
    output logic [ADDR_WIDTH-1:0]    n_bank0_addra_ctrl,

    // Bank 1 Interface
    output logic                     n_bank1_ena_ctrl,            
    output logic                     n_bank1_wea_ctrl, 
    output logic [ADDR_WIDTH-1:0]    n_bank1_addra_ctrl,

    output logic [$clog2(TOTAL_MODULES)-1:0] w_slicing_idx,
    output logic [$clog2(TOTAL_MODULES)-1:0] n_slicing_idx,
    output logic                             enable_matmul
);
    // ************************************ Wires & Parameters ************************************
    typedef enum logic [1:0] {
        S_IDLE,
        S_W0_R1,
        S_W1_R0,
        S_DONE
    } fsm_state_t;
    fsm_state_t state_reg, state_next;

    logic [1:0] reading_phase, writing_phase;
    logic write_now;
        
    // ------------- Logics for address generation -------------
    logic internal_rst_n, internal_reset_acc;
    logic acc_done_wrap_rising;
    logic acc_done_wrap_d;
    assign acc_done_wrap_rising = ~acc_done_wrap_d & acc_done_wrap;
    logic en_module; 
    logic [7:0] counter, counter_row, counter_col, flag;
    logic counter_acc_done;

    // ------------------- For West Input -------------------
    // For bank 0
    logic [ADDR_WIDTH-1:0] w_bank0_addra_rd, w_bank0_addra_wr;
    logic [ADDR_WIDTH-1:0] w_bank0_addrb_rd, w_bank0_addrb_wr;
    // For bank 1
    logic [ADDR_WIDTH-1:0] w_bank1_addra_rd, w_bank1_addra_wr;
    logic [ADDR_WIDTH-1:0] w_bank1_addrb_rd, w_bank1_addrb_wr;

    // ------------------- For North Input -------------------
    // For north input, we explicitly use SPRAM so we only utilize port A
    // For bank 0
    logic [ADDR_WIDTH-1:0] n_bank0_addra_wr;
    logic [ADDR_WIDTH-1:0] n_bank0_addra_rd;
     // For bank 1
    logic [ADDR_WIDTH-1:0] n_bank1_addra_wr;
    logic [ADDR_WIDTH-1:0] n_bank1_addra_rd;

    // ************************************ FSM Next State Logic ************************************
    always @* begin
        state_next = state_reg
        case (state_reg)
            S_IDLE: begin
                w_bank0_ena_ctrl    = 1; w_bank0_enb_ctrl   = 1;
                w_bank1_ena_ctrl    = 1; w_bank1_enb_ctrl   = 1;

                n_bank0_ena_ctrl    = 1;
                n_bank1_ena_ctrl    = 1;
                
                state_next = (in_valid) ? S_W0_R1 : S_IDLE;
            end

            S_W0_R1: begin // Bank 0 is writing and Bank 1 is reading
                state_next = (~writing_phase[1] & ~writing_phase[0]) ? S_W1_R0 : S_W0_R1;
            end

            S_W1_R0: begin // Bank 0 is reading and Bank 1 is writing

            end
        endcase
    end

    // ------------------- For West Input -------------------
    // For bank 0
    assign w_bank0_wea_ctrl   = (state_reg == S_W0_R1) ? ((write_now) ? 1 : 0) : 0;
    assign w_bank0_web_ctrl   = (state_reg == S_W0_R1) ? ((write_now) ? 1 : 0) : 0;
    assign w_bank0_addra_ctrl = 
                                (state_reg == S_W0_R1) ? w_bank0_addra_wr : 
                                (state_reg == S_W1_R0) ? ((reading_phase[0]) ? w_bank0_addra_rd : '0) : '0;
    assign w_bank0_addrb_ctrl = 
                                (state_reg == S_W0_R1) ? w_bank0_addrb_wr : 
                                (state_reg == S_W1_R0) ? ((reading_phase[0]) ? w_bank0_addrb_rd : '0) : '0;
    
    // For bank 1
    assign w_bank1_wea_ctrl   = (state_reg == S_W1_R0) ? ((write_now) ? 1 : 0) : 0;
    assign w_bank1_web_ctrl   = (state_reg == S_W1_R0) ? ((write_now) ? 1 : 0) : 0;
    assign w_bank1_addra_ctrl = 
                                (state_reg == S_W1_R0) ? w_bank1_addra_wr : 
                                (state_reg == S_W0_R1) ? ((reading_phase[1]) ? w_bank1_addra_rd : '0) : '0;
    assign w_bank1_addrb_ctrl = 
                                (state_reg == S_W1_R0) ? w_bank1_addrb_wr : 
                                (state_reg == S_W0_R1) ? ((reading_phase[1]) ? w_bank1_addrb_rd : '0) : '0;
  
    // ------------------- For North Input -------------------
    // For bank 0
    assign n_bank0_wea_ctrl   = (state_reg == S_W0_R1) ? ((write_now) ? 1 : 0) : 0;
    assign n_bank0_addra_ctrl = 
                                (state_reg == S_W0_R1) ? n_bank0_addra_wr : 
                                (state_reg == S_W1_R0) ? ((reading_phase[0]) ? n_bank0_addra_rd : '0) : '0;

     // For bank 1
    assign n_bank1_wea_ctrl   = (state_reg == S_W1_R0) ? ((write_now) ? 1 : 0) : 0;
    assign n_bank1_addra_ctrl = 
                                (state_reg == S_W1_R0) ? n_bank1_addra_wr : 
                                (state_reg == S_W0_R1) ? ((reading_phase[0]) ? n_bank1_addra_rd : '0) : '0;


    // ************************************ FSM Sequential Logic ************************************
    always @(posedge clk) begin 
        if (!rst_n) begin
            // Address generation
            counter             <= 0;
            counter_col         <= 0;
            counter_row         <= 0; // Technically speaking, because we just operate in one row, counter_row value is always 0 (indicating 1/first row)
            counter_acc_done    <= 0;
            internal_rst_n      <= 0;
            internal_reset_acc  <= 0;
            acc_done_wrap_d     <= 0;
            flag                <= 0;

            en_module           <= 1'b0;
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
            n_bank0_addra_rd      <= '0;

            n_bank1_addra_wr      <= '0;
            n_bank1_addra_rd      <= '0;

            current_bank          <= 2'b01;   // At reset, bank 0 state is writing (marked by 1) and bank 1 state is reading (marked by 0)
            writing_phase         <= 2'b11;   // At reset, both directions will write (see README.MD for further explanation)
            reading_phase         <= 2'b01;   // (see README.MD for further explanation)
            write_now             <= 0;
            w_slicing_idx         <= '0;      // For slicing the WEST input into MODULE_WIDTH using extract_module func
            n_slicing_idx         <= '0;      // For slicing the NORTH input into SLICE_WIDTH (see ping_pong_buffer_n.sv) using extract_module func
        end
        else begin
            state_reg             <= state_next;
            // ------------------------------------------------------ WRITING PHASE ------------------------------------------------------
            if (in_valid) begin
                write_now   <= 1'b1;
            end else if (write_now && (w_slicing_idx == TOTAL_MODULES - 1) && (n_slicing_idx == TOTAL_MODULES - 1)) begin
                write_now   <= 1'b0;
            end

            //  --------------- Slicing Index ---------------
            if (write_now) begin
                w_slicing_idx       <= w_slicing_idx + 1;
                n_slicing_idx       <= n_slicing_idx + 1;

                // Address Generation, when slicing idx change:
                if (state_reg == S_W0_R1) begin
                    if ((w_bank0_addra_wr == W_COL_X -1) && (w_bank0_addrb_wr == 2*W_COL_X - 1)) begin // Both West BRAMs are fully filled
                        w_bank0_addra_wr    <= '0;
                        w_bank0_addrb_wr    <= W_COL_X; // Because we started at the new line
                        writing_phase[0]    <= ~writing_phase[0]; 
                    end else if (writing_phase[0]) begin
                        w_bank0_addra_wr  <= w_bank0_addra_wr + 1;
                        w_bank0_addrb_wr  <= w_bank0_addrb_wr + 1;
                    end
                   
                    if (n_bank0_addra_wr == N_COL_X - 1) begin // North BRAM is fully filled
                        n_bank0_addra_wr    <= 0';;
                        writing_phase[1]    <= ~writing_phase[1]
                    end else if (writing_phase[1]) begin
                        n_bank0_addra_wr  <= n_bank0_addra_wr + 1;
                    end
                end 
                else if (state_reg == S_W1_R0) begin
                    if ((w_bank1_addra_wr == W_COL_X -1) && (w_bank1_addrb_wr) == 2*W_COL_X - 1) begin // Both West BRAMs are fully filled
                        w_bank1_addra_wr    <= '0;
                        w_bank1_addrb_wr    <= W_COL_X; // Because we started at the new line
                        writing_phase[0]    <= ~writing_phase[0]; 
                    end else if (~writing_phase[0]) begin
                        w_bank1_addra_wr  <= w_bank1_addra_wr + 1;
                        w_bank1_addrb_wr  <= w_bank1_addrb_wr + 1;
                    end
                    
                    if (n_bank1_addra_wr == N_COL_X - 1) begin // North BRAM is fully filled
                        n_bank1_addra_wr    <= 0';
                        writing_phase[1]    <= ~writing_phase[1]
                    end else if (~writing_phase[1]) begin
                        n_bank1_addra_wr  <= n_bank1_addra_wr + 1;
                    end
                end
            end else begin
                w_slicing_idx       <= '0;
                n_slicing_idx       <= '0;
            end

            // ------------------------------------------------------ READING PHASE ------------------------------------------------------


        end
    end
    
    //assign enable_matmul = en_module;

endmodule
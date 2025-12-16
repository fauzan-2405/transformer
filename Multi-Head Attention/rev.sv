// ping_pong_ctrl.sv
// Used to control ping_pong_buffer
// Basically utilizing the linear_proj_ctrl.sv but tweaks some of the settings
// IN THE FUTURE: Check whether we need to toggle we*_ctrl via combinational or sequential

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
    output logic                     n_bank0_ena_ctrl, n_bank0_enb_ctrl,            
    output logic                     n_bank0_wea_ctrl, 
    output logic [ADDR_WIDTH-1:0]    n_bank0_addra_ctrl, n_bank0_addrb_ctrl,

    // Bank 1 Interface
    output logic                     n_bank1_ena_ctrl, n_bank1_enb_ctrl,            
    output logic                     n_bank1_wea_ctrl, 
    output logic [ADDR_WIDTH-1:0]    n_bank1_addra_ctrl, n_bank1_addrb_ctrl

    output logic [$clog2(TOTAL_MODULES)-1:0] w_slicing_idx,
    output logic [$clog2(TOTAL_MODULES)-1:0] n_slicing_idx,
    output logic                             enable_matmul
);
    // ************************************ Controller ************************************
    logic [1:0] current_bank;   // We use this logic for both of inputs,
                                // So, current_bank[0] represents bank_0 for w_input & n_input
                                // and current_bank[1] represents bank_1 for w_input & n_input
                                // When either current_bank is 1, its state is writing
                                // When it is 0, its state is reading
    logic [1:0] writing_phase, reading_phase;
    logic write_now; // To toggle write after one in_valid is arrived

    assign write_now = (in_valid) ? 1 
                        : ((w_slicing_idx == TOTAL_MODULES - 1) && (n_slicing_idx == TOTAL_MODULES - 1)) ? 1 : 0;

    // ------------------- For West Input -------------------
    // For bank 0
    logic [ADDR_WIDTH-1:0] w_bank0_addra_rd, w_bank0_addra_wr;
    logic [ADDR_WIDTH-1:0] w_bank0_addrb_rd, w_bank0_addrb_wr;
    assign w_bank0_addra_ctrl = (current_bank[0]) ? w_bank0_addra_wr : w_bank0_addra_rd;
    assign w_bank0_addrb_ctrl = (current_bank[0]) ? w_bank0_addrb_wr : w_bank0_addrb_rd;
    
    // For bank 1
    logic [ADDR_WIDTH-1:0] w_bank1_addra_rd, w_bank1_addra_wr;
    logic [ADDR_WIDTH-1:0] w_bank1_addrb_rd, w_bank1_addrb_wr;
    assign w_bank1_addra_ctrl = (current_bank[1]) ? w_bank1_addra_wr : w_bank1_addra_rd;
    assign w_bank1_addrb_ctrl = (current_bank[1]) ? w_bank1_addrb_wr : w_bank1_addrb_rd;

    // ------------------- For North Input -------------------
    // For north input, we explicitly use port A JUST for writing 
    // and port B JUST for reading

    // For bank 0
    logic [ADDR_WIDTH-1:0] n_bank0_addra_wr;
    logic [ADDR_WIDTH-1:0] n_bank0_addrb_rd;
    assign n_bank0_addra_ctrl = (current_bank[0]) ? n_bank0_addra_wr : 0;
    assign n_bank0_addrb_ctrl = (current_bank[0]) ? 0 : n_bank0_addrb_rd;

     // For bank 1
    logic [ADDR_WIDTH-1:0] n_bank1_addra_wr;
    logic [ADDR_WIDTH-1:0] n_bank1_addrb_rd;
    assign n_bank1_addra_ctrl = (current_bank[1]) ? n_bank1_addra_wr : 0;
    assign n_bank1_addrb_ctrl = (current_bank[1]) ? 0 : n_bank1_addrb_rd;

    // ------------- Logics for address generation -------------
    logic internal_rst_n, internal_reset_acc;
    logic acc_done_wrap_rising;
    logic acc_done_wrap_d;
    assign acc_done_wrap_rising = ~acc_done_wrap_d & acc_done_wrap;
    logic en_module; 
    logic [WIDTH_OUT-1:0] counter, counter_row, counter_col, flag;
    logic counter_acc_done;

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
            w_bank0_ena_ctrl      <= 0;
            w_bank0_enb_ctrl      <= 0;
            w_bank0_wea_ctrl      <= 0;
            w_bank0_web_ctrl      <= 0;
            w_bank0_addra_wr      <= '0;
            w_bank0_addrb_wr      <= W_COL_X; // Because we started at the new line
            w_bank0_addra_rd      <= '0;
            w_bank0_addrb_rd      <= '0;
            
            w_bank1_ena_ctrl      <= 0;
            w_bank1_enb_ctrl      <= 0;
            w_bank1_wea_ctrl      <= 0;
            w_bank1_web_ctrl      <= 0;
            w_bank1_addra_wr      <= '0;
            w_bank1_addrb_wr      <= W_COL_X; // Because we started at the new line
            w_bank1_addra_rd      <= '0;
            w_bank1_addrb_rd      <= '0;

            // North Input Bank Controllers
            n_bank0_ena_ctrl      <= 0;
            n_bank0_enb_ctrl      <= 0;
            n_bank0_addra_wr      <= '0;
            n_bank0_addrb_rd      <= '0;

            n_bank1_ena_ctrl      <= 0;
            n_bank1_enb_ctrl      <= 0;
            n_bank1_addra_wr      <= '0;
            n_bank1_addrb_rd      <= '0;

            current_bank          <= 2'b01;   // At reset, bank 0 state is writing (marked by 1) and bank 1 state is reading (marked by 0)
            writing_phase         <= 2'b11;   // At reset, both directions will write (see README.MD for further explanation)
            reading_phase         <= 2'b01;   // (see README.MD for further explanation)
            w_slicing_idx         <= '0;      // For slicing the WEST input into MODULE_WIDTH using extract_module func
            n_slicing_idx         <= '0;      // For slicing the NORTH input into SLICE_WIDTH (see ping_pong_buffer_n.sv) using extract_module func
        end
        else begin
            w_bank0_ena_ctrl <= 1; w_bank0_enb_ctrl <= 1;
            w_bank1_ena_ctrl <= 1; w_bank1_enb_ctrl <= 1;

            n_bank0_ena_ctrl <= 1; n_bank0_enb_ctrl <= 1;
            n_bank1_ena_ctrl <= 1; n_bank1_enb_ctrl <= 1;

            current_bank     <= {~writing_phase[1], writing_phase[0]};

            // ------------------------------------------------------ WRITING PHASE ------------------------------------------------------
            // --------------- BANK 0 for both North and West Input ---------------
            if (current_bank[0]) begin 
                //if ((w_slicing_idx == TOTAL_MODULES - 1) && (n_slicing_idx == TOTAL_MODULES - 1)) begin
                if (~write_now) begin
                    w_slicing_idx       <= '0;
                    w_bank0_wea_ctrl    <= 0;
                    w_bank0_web_ctrl    <= 0;
                    n_slicing_idx       <= '0;
                    n_bank0_wea_ctrl    <= 0;

                    if ((w_bank0_addra_wr == W_COL_X -1) && (w_bank0_addrb_wr == 2*W_COL_X - 1)) begin // Both West BRAMs are fully filled
                        w_bank0_addra_wr    <= '0;
                        w_bank0_addrb_wr    <= W_COL_X; // Because we started at the new line
                        writing_phase[0]    <= ~writing_phase[0]; 
                    end

                    if (n_bank0_addra_wr == N_COL_X - 1) begin // North BRAM is fully filled
                        n_bank0_addra_wr    <= 0';;
                        writing_phase[1]    <= ~writing_phase[1]
                    end
                end else begin
                    w_slicing_idx       <= w_slicing_idx + 1;
                    w_bank0_wea_ctrl    <= 1;
                    w_bank0_web_ctrl    <= 1;
                    n_slicing_idx       <= n_slicing_idx + 1;
                    n_bank0_wea_ctrl    <= 1;

                    // Address Generation, when slicing idx change:
                    w_bank0_addra_wr  <= w_bank0_addra_wr + 1;
                    w_bank0_addrb_wr  <= w_bank0_addrb_wr + 1;
                    n_bank0_addra_wr  <= n_bank0_addra_wr + 1;
                end
            end else begin
                // Reading Phase
                w_bank0_wea_ctrl <= 0; // Safeguard to ensure the write enables are turned off
                w_bank0_web_ctrl <= 0;
                n_bank0_wea_ctrl <= 0;
            end

            // --------------- BANK 1 for both North and West Input ---------------
            if (current_bank[1]) begin 
                if (~write_now) begin
                    w_slicing_idx       <= '0;
                    w_bank1_wea_ctrl    <= 0;
                    w_bank1_web_ctrl    <= 0;
                    n_slicing_idx       <= '0;
                    n_bank1_wea_ctrl    <= 0;

                    if ((w_bank1_addra_wr == W_COL_X -1) && (w_bank1_addrb_wr) == 2*W_COL_X - 1) begin // Both West BRAMs are fully filled
                        w_bank1_addra_wr      <= '0;
                        w_bank1_addrb_wr      <= W_COL_X; // Because we started at the new line
                        writing_phase[0]    <= ~writing_phase[0]; 
                    end

                    if (n_bank1_addra_wr == N_COL_X - 1) begin // North BRAM is fully filled
                        n_bank1_addra_wr    <= 0';;
                        writing_phase[1]    <= ~writing_phase[1]
                    end
                end else begin
                    w_slicing_idx <= w_slicing_idx + 1;
                    w_bank1_wea_ctrl <= 1;
                    w_bank1_web_ctrl <= 1;
                    // Address Generation, when slicing idx change:
                    w_bank1_addra_wr  <= w_bank1_addra_wr + 1;
                    w_bank1_addrb_wr  <= w_bank1_addrb_wr + 1;
                    n_bank1_addra_wr  <= n_bank1_addra_wr + 1;
                end
            end else begin
                // Reading Phase
                w_bank1_wea_ctrl <= 0;
                w_bank1_web_ctrl <= 0;
                n_bank1_wea_ctrl <= 0;
            end

            acc_done_wrap_d  <= acc_done_wrap;
            counter_acc_done <= 0;

            // ------------------------------------------------------ READING PHASE ------------------------------------------------------
            // --------------- BANK 0 for both North and West Input ---------------
            if (~current_bank[0]) begin
                if (reading_phase[0]) begin
                    // Imported from linear_proj_ctrl.sv
                    internal_rst_n <= ~systolic_finish_wrap;
                    if (systolic_finish_wrap) begin
                        internal_reset_acc <= ~acc_done_wrap;
                    end

                    // Counter Update
                    if (systolic_finish_wrap) begin
                        // counter indicates the matrix C element iteration
                        if (counter == ((INNER_DIMENSION/BLOCK_SIZE) - 1)) begin 
                            counter <=0;
                        end
                        else begin
                            counter <= counter + 1;
                        end
                        // Address controller
                        w_bank0_addra_rd <= counter + (INNER_DIMENSION/BLOCK_SIZE)*(counter_row*2);       // same as the old one but port A used for even addresses (starting from 0)
                        w_bank0_addrb_rd <= counter + (INNER_DIMENSION/BLOCK_SIZE)*(counter_row*2 + 1);   // and port B used for odd addresses (starting from 1)
                        n_bank0_addrb_rd <= counter + (INNER_DIMENSION/BLOCK_SIZE)*counter_col;
                    end

                    // Column/Row Update
                    if (acc_done_wrap_rising) begin
                        // counter_row indicates the i-th row of the matrix C that we are working right now
                        // counter_col indicates the i-th column of the matrix C that we are working right now

                        // Check if we already at the end of the MAT C column
                        if (counter_col == (COL_Y - 1)) begin
                            counter_col <= 0;
                            //counter_row <= counter_row + 1;   // This is the old formula if we want to traverse all rows
                            counter_row <= 0;                   // This is the new formula because we operate in one row only
                            reading_phase <= ~reading_phase;    // Terminate the process
                        end else begin
                            counter_col <= counter_col + 1;
                        end

                        counter_acc_done <= 1;
                    end
                end
            end

            // --------------- BANK 1 for both North and West Input ---------------
            if (~current_bank[1]) begin
                if (reading_phase[1]) begin
                    // Imported from linear_proj_ctrl.sv
                    internal_rst_n <= ~systolic_finish_wrap;
                    if (systolic_finish_wrap) begin
                        internal_reset_acc <= ~acc_done_wrap;
                    end

                    // Counter Update
                    if (systolic_finish_wrap) begin
                        // counter indicates the matrix C element iteration
                        if (counter == ((INNER_DIMENSION/BLOCK_SIZE) - 1)) begin 
                            counter <=0;
                        end
                        else begin
                            counter <= counter + 1;
                        end
                        // Address controller
                        w_bank1_addra_rd <= counter + (INNER_DIMENSION/BLOCK_SIZE)*(counter_row*2);       // same as the old one but port A used for even addresses (starting from 0)
                        w_bank1_addrb_rd <= counter + (INNER_DIMENSION/BLOCK_SIZE)*(counter_row*2 + 1);   // and port B used for odd addresses (starting from 1)
                        n_bank1_addrb_rd <= counter + (INNER_DIMENSION/BLOCK_SIZE)*counter_col;
                    end

                    // Column/Row Update
                    if (acc_done_wrap_rising) begin
                        // counter_row indicates the i-th row of the matrix C that we are working right now
                        // counter_col indicates the i-th column of the matrix C that we are working right now

                        // Check if we already at the end of the MAT C column
                        if (counter_col == (COL_Y - 1)) begin
                            counter_col <= 0;
                            //counter_row <= counter_row + 1;   // This is the old formula if we want to traverse all rows
                            counter_row <= 0;                   // This is the new formula because we operate in one row only
                            reading_phase <= ~reading_phase;    // Terminate the process
                        end else begin
                            counter_col <= counter_col + 1;
                        end

                        counter_acc_done <= 1;
                    end
                end
            end            

        end
    end
    
    assign enable_matmul = en_module;

endmodule
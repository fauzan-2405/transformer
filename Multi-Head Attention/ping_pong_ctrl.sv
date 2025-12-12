// ping_pong_ctrl.sv
// Used to control ping_pong_buffer
// Basically utilizing the linear_proj_ctrl.sv but tweaks some of the settings
// IN THE FUTURE: Check whether we need to toggle we*_ctrl via combinational or sequential

module ping_pong_ctrl #(
    parameter TOTAL_MODULES = 4,
    parameter ADDR_WIDTH    = 4,
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

    output logic [$clog2(TOTAL_MODULES)-1:0] slicing_idx,
    output logic                             enable_matmul
);
    // ************************************ Controller ************************************
    logic [0:0] current_bank;   // We use this logic for both of inputs,
                                // So, current_bank[0] represents bank_0 for w_input & n_input
                                // and current_bank[1] represents bank_1 for w_input & n_input
                                // When either current_bank is 1, its state is writing
                                // When it is 0, its state is reading

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
    assign w_bank0_addra_ctrl = (current_bank[0]) ? n_bank0_addra_wr : 0;
    assign w_bank0_addrb_ctrl = (current_bank[0]) ? 0 : n_bank0_addrb_rd;

     // For bank 1
    logic [ADDR_WIDTH-1:0] n_bank1_addra_wr;
    logic [ADDR_WIDTH-1:0] n_bank1_addrb_rd;
    assign w_bank1_addra_ctrl = (current_bank[1]) ? n_bank1_addra_wr : 0;
    assign w_bank1_addrb_ctrl = (current_bank[1]) ? 0 : n_bank1_addrb_rd;

    // ------------- Logics for address generation -------------
    logic internal_rst_n, internal_reset_acc;
    logic acc_done_wrap_rising;
    logic acc_done_wrap_d;
    assign acc_done_wrap_rising = ~acc_done_wrap_d & acc_done_wrap;
    logic en_module; 
    logic [WIDTH_OUT-1:0] counter, counter_col, flag;
    logic counter_acc_done;

    always @(posedge clk) begin 
        if (!rst_n) begin
            // Address generation
            counter             <= 0;
            counter_col         <= 0;
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
            w_bank0_addra_wr      <= '0;
            w_bank0_addrb_wr      <= COL_X; // Because we started at the new line
            w_bank0_addra_rd      <= '0;
            w_bank0_addrb_rd      <= '0;
            
            w_bank1_ena_ctrl      <= 0;
            w_bank1_enb_ctrl      <= 0;
            w_bank1_addra_wr      <= '0;
            w_bank1_addrb_wr      <= COL_X; // Because we started at the new line
            w_bank1_addra_rd      <= '0;
            w_bank1_addrb_rd      <= '0;

            // North Input Bank Controllers
            n_bank0_ena_ctrl      <= 0;
            n_bank0_enb_ctrl      <= 0;
            n_bank0_addra_wr      <= '0;
            n_bank0_addrb_rd      <= '0;

            current_bank        <= 2'b01;   // At reset, bank 0 is writing (marked by 1) and bank 1 is reading (marked by 0)
            slicing_idx         <= '0;      // For slicing the input into MODULE_WIDTH using extract_module func
        end
        else begin
            w_bank0_ena_ctrl <= 1; w_bank0_enb_ctrl <= 1;
            w_bank1_ena_ctrl <= 1; w_bank1_enb_ctrl <= 1;

            n_bank0_ena_ctrl <= 1; n_bank0_enb_ctrl <= 1;
            n_bank1_ena_ctrl <= 1; n_bank1_enb_ctrl <= 1;

            acc_done_wrap_d  <= acc_done_wrap;
            counter_acc_done <= 0;

            // ------------------------ BANK 0 ------------------------
            if (current_bank[0]) begin 
                // ----------- Writing/Filling Phase -----------
                if (slicing_idx == TOTAL_MODULES - 1) begin
                    slicing_idx <= '0;
                    w_bank0_wea_ctrl <= 0;
                    w_bank0_web_ctrl <= 0;
                    if ((w_bank0_addra_wr == COL_X -1) && (w_bank0_addrb_wr) == 2*COL_X - 1) begin // Both BRAMs are fully filled
                        w_bank0_addra_wr      <= '0;
                        w_bank0_addrb_wr      <= COL_X; // Because we started at the new line
                        current_bank[0]     <= ~current_bank[0]; // Toggle '0' aka read mode
                    end
                end else begin
                    slicing_idx <= slicing_idx + 1;
                    w_bank0_wea_ctrl <= 1;
                    w_bank0_web_ctrl <= 1;
                    // Address Generation, when slicing idx change:
                    w_bank0_addra_wr  <= w_bank0_addra_wr + 1;
                    w_bank0_addrb_wr  <= w_bank0_addrb_wr + 1;
                end
            end else begin
                // --------------- Reading Phase ---------------
                w_bank0_wea_ctrl <= 0; // Safeguard to ensure the write enables are turned off
                w_bank0_web_ctrl <= 0;
            end

            // ------------------------ BANK 1 ------------------------
            if (current_bank[1]) begin 
                // ----------- Writing/Filling Phase -----------
                if (slicing_idx == TOTAL_MODULES - 1) begin
                    slicing_idx <= '0;
                    w_bank1_wea_ctrl <= 0;
                    w_bank1_web_ctrl <= 0;
                    if ((w_bank1_addra_wr == COL_X -1) && (w_bank1_addrb_wr) == 2*COL_X - 1) begin // Both BRAMs are fully filled
                        w_bank1_addra_wr      <= '0;
                        w_bank1_addrb_wr      <= COL_X; // Because we started at the new line
                        current_bank[1]     <= ~current_bank[1]; // Toggle '0' aka read mode
                    end
                end else begin
                    slicing_idx <= slicing_idx + 1;
                    w_bank1_wea_ctrl <= 1;
                    w_bank1_web_ctrl <= 1;
                    // Address Generation, when slicing idx change:
                    w_bank1_addra_wr  <= w_bank1_addra_wr + 1;
                    w_bank1_addrb_wr  <= w_bank1_addrb_wr + 1;
                end
            end else begin
                // --------------- Reading Phase ---------------
                w_bank1_wea_ctrl <= 0; // Safeguard to ensure the write enables are turned off
                w_bank1_web_ctrl <= 0;
            end

            // Address Generation for Both Direction
            if a begin
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
                    /* These are the old controllers when I use only 1 port for input matrix
                    in_mat_rd_addrb <= counter + (INNER_DIMENSION/BLOCK_SIZE)*counter_row;
                    we_mat_rd_addrb <= counter + (INNER_DIMENSION/BLOCK_SIZE)*counter_col;
                    */
                    w_bank0_addra_rd <= counter + (INNER_DIMENSION/BLOCK_SIZE)*(counter_row*2); // same as the old one but port A used for even addresses (starting from 0)
                    w_bank0_addrb_rd <= counter + (INNER_DIMENSION/BLOCK_SIZE)*(counter_row*2 + 1); // and port B used for odd addresses (starting from 1)`
                    w_mat_rd_addrb <= counter + (INNER_DIMENSION/BLOCK_SIZE)*counter_col;
                end

                // Column/Row Update
                if (acc_done_wrap_rising) begin
                    // counter_row indicates the i-th row of the matrix C that we are working right now
                    // counter_col indicates the i-th column of the matrix C that we are working right now

                    // Check if we already at the end of the MAT C column
                    if (counter_col == (COL_SIZE_MAT_C - 1)) begin
                        counter_col <= 0;
                        counter_row <= counter_row + 1;
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
    end
    
    assign enable_matmul = en_module;

endmodule
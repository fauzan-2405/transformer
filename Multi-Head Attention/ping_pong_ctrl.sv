// ping_pong_ctrl.sv
// Used to control ping_pong_buffer
// Basically utilizing the linear_proj_ctrl.sv but tweaks some of the settings

module ping_pong_ctrl #(
    parameter TOTAL_MODULES = 4,
    parameter ADDR_WIDTH    = 4,
) (
    input logic clk, rst_n,
    input logic in_valid,
    input logic acc_done_wrap, systolic_finish_wrap,

    // Bank 0 Interface
    output logic                     bank0_ena_ctrl, bank0_enb_ctrl,
    output logic                     bank0_wea_ctrl, bank0_web_ctrl,
    output logic [ADDR_WIDTH-1:0]    bank0_addra_ctrl, bank0_addrb_ctrl,

    // Bank 1 Interface
    output logic                     bank1_ena_ctrl, bank1_enb_ctrl,
    output logic                     bank1_wea_ctrl, bank1_web_ctrl,
    output logic [ADDR_WIDTH-1:0]    bank1_addra_ctrl, bank1_addrb_ctrl,

    output logic [$clog2(TOTAL_MODULES)-1:0] slicing_idx,
    output logic                             enable_matmul
);
    // ************************************ Controller ************************************
    logic [0:0] current_bank;

    // For bank 0
    logic [ADDR_WIDTH-1:0] bank0_addra_rd, bank0_addra_wr;
    logic [ADDR_WIDTH-1:0] bank0_addrb_rd, bank0_addrb_wr;
    assign bank0_addra_ctrl = (current_bank[0]) ? bank0_addra_wr : bank0_addra_rd;
    assign bank0_addrb_ctrl = (current_bank[0]) ? bank0_addrb_wr : bank0_addrb_rd;
    
    // For bank 1
    logic [ADDR_WIDTH-1:0] bank1_addra_rd, bank1_addra_wr;
    logic [ADDR_WIDTH-1:0] bank1_addrb_rd, bank1_addrb_wr;
    assign bank1_addra_ctrl = (current_bank[1]) ? bank1_addra_wr : bank1_addra_rd;
    assign bank1_addrb_ctrl = (current_bank[1]) ? bank1_addrb_wr : bank1_addrb_rd;

    // Logics for address generation
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

            // Bank controllers    
            bank0_ena_ctrl      <= 0;
            bank0_enb_ctrl      <= 0;
            bank0_addra_wr      <= '0;
            bank0_addrb_wr      <= COL_X; // Because we started at the new line
            bank0_addra_rd      <= '0;
            bank0_addrb_rd      <= '0;
            
            bank1_ena_ctrl      <= 0;
            bank1_enb_ctrl      <= 0;
            bank1_addra_wr      <= '0;
            bank1_addrb_wr      <= COL_X; // Because we started at the new line
            bank1_addra_rd      <= '0;
            bank1_addrb_rd      <= '0;

            current_bank        <= 2'b01;   // At reset, bank 0 is writing (marked by 1) and bank 1 is reading (marked by 0)
            slicing_idx         <= '0;      // For slicing the input into MODULE_WIDTH using extract_module func
        end
        else begin
            bank0_ena_ctrl <= 1; bank0_enb_ctrl <= 1;
            bank1_ena_ctrl <= 1; bank1_enb_ctrl <= 1;

            acc_done_wrap_d  <= acc_done_wrap;
            counter_acc_done <= 0;

            // ------------------------ BANK 0 ------------------------
            if (current_bank[0]) begin 
                // ----------- Writing/Filling Phase -----------
                if (slicing_idx == TOTAL_MODULES - 1) begin
                    slicing_idx <= '0;
                    bank0_wea_ctrl <= 0;
                    bank0_web_ctrl <= 0;
                    if ((bank0_addra_wr == COL_X -1) && (bank0_addrb_wr) == 2*COL_X - 1) begin // Both BRAMs are fully filled
                        bank0_addra_wr      <= '0;
                        bank0_addrb_wr      <= COL_X; // Because we started at the new line
                        current_bank[0]     <= ~current_bank[0]; // Toggle '0' aka read mode
                    end
                end else begin
                    slicing_idx <= slicing_idx + 1;
                    bank0_wea_ctrl <= 1;
                    bank0_web_ctrl <= 1;
                    // Address Generation, when slicing idx change:
                    bank0_addra_wr  <= bank0_addra_wr + 1;
                    bank0_addrb_wr  <= bank0_addrb_wr + 1;
                end
            end else begin
                // --------------- Reading Phase ---------------
                bank0_wea_ctrl <= 0; // Safeguard to ensure the write enables are turned off
                bank0_web_ctrl <= 0;
            end

            // ------------------------ BANK 1 ------------------------
            if (current_bank[1]) begin 
                // ----------- Writing/Filling Phase -----------
                if (slicing_idx == TOTAL_MODULES - 1) begin
                    slicing_idx <= '0;
                    bank1_wea_ctrl <= 0;
                    bank1_web_ctrl <= 0;
                    if ((bank1_addra_wr == COL_X -1) && (bank1_addrb_wr) == 2*COL_X - 1) begin // Both BRAMs are fully filled
                        bank1_addra_wr      <= '0;
                        bank1_addrb_wr      <= COL_X; // Because we started at the new line
                        current_bank[1]     <= ~current_bank[1]; // Toggle '0' aka read mode
                    end
                end else begin
                    slicing_idx <= slicing_idx + 1;
                    bank1_wea_ctrl <= 1;
                    bank1_web_ctrl <= 1;
                    // Address Generation, when slicing idx change:
                    bank1_addra_wr  <= bank1_addra_wr + 1;
                    bank1_addrb_wr  <= bank1_addrb_wr + 1;
                end
            end else begin
                // --------------- Reading Phase ---------------
                bank1_wea_ctrl <= 0; // Safeguard to ensure the write enables are turned off
                bank1_web_ctrl <= 0;
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
                    bank0_addra_rd <= counter + (INNER_DIMENSION/BLOCK_SIZE)*(counter_row*2); // same as the old one but port A used for even addresses (starting from 0)
                    bank0_addrb_rd <= counter + (INNER_DIMENSION/BLOCK_SIZE)*(counter_row*2 + 1); // and port B used for odd addresses (starting from 1)`
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
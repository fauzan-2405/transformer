// linear_proj_ctrl.sv
// Used as a controller for top_linear_projection.sv

import linear_proj_pkg::*;

module linear_proj_ctrl
(
    input logic clk, rst_n,
    input logic in_mat_ena, in_mat_enb,
    input logic in_mat_wea, in_mat_web,
    input logic [ADDR_WIDTH_A-1:0] in_mat_wr_addra, in_mat_wr_addrb,
    
    // For input BRAM
    output logic in_mat_ena_mux, in_mat_enb_mux,
    output logic in_mat_wea_mux, in_mat_web_mux,
    output logic [ADDR_WIDTH_A-1:0] in_mat_addra_mux, in_mat_addrb_mux,

    // For weight BRAM, we just use port B
    output logic w_mat_enb_mux, 
    output logic [ADDR_WIDTH_B-1:0] w_mat_addrb_mux,
    
    output logic enable_linear_proj, internal_rst_n_ctrl, internal_reset_acc_ctrl,
    output logic out_valid, done
);

    // Internal read address counters (controller-driven)
    logic [ADDR_WIDTH_A-1:0] in_mat_rd_addra; // used when reading port A
    logic [ADDR_WIDTH_A-1:0] in_mat_rd_addrb; // used when reading port B
    logic [ADDR_WIDTH_B-1:0] w_mat_rd_addrb;    // reading weights (we'll use only one BRAM port for read later)
    logic multi_en; // enable to multi_matmul_wrapper
    

    // *************** Control Signals for Mux *************** 
    // These signals will be connected to the BRAM
    // write_phase == 1: BRAM ports are in write mode (external ena/we* used)
    // write_phase == 0: BRAM ports are in read mode (we* == 0)
    logic write_phase;
    
    // For input matrix BRAM (in_mat)
    assign in_mat_addra_mux = (write_phase) ? in_mat_wr_addra : in_mat_rd_addra;
    assign in_mat_addrb_mux = (write_phase) ? in_mat_wr_addrb : in_mat_rd_addrb;

    assign in_mat_wea_mux   = (write_phase) ? in_mat_wea : 1'b0;
    assign in_mat_web_mux   = (write_phase) ? in_mat_web : 1'b0;

    // In the future if we wanted to turn off the BRAM, but for now we just let it on
    //assign in_mat_ena_mux   = (write_phase) ? in_mat_ena : (en_module) ? 1'b1 : 1'b0; 
    //assign in_mat_enb_mux   = (write_phase) ? in_mat_enb : (en_module) ? 1'b1 : 1'b0;

    assign in_mat_ena_mux   = (write_phase) ? in_mat_ena : 1'b1; 
    assign in_mat_enb_mux   = (write_phase) ? in_mat_enb : 1'b1;

    // For weight matrix BRAM (w_mat)
    assign w_mat_addrb_mux  = (write_phase) ? 0 : w_mat_rd_addrb;
    
    // In the future if we wanted to turn off the BRAM, but for now we just let it on
    //assign w_mat_enb_mux    = (write_phase) ? w_mat_enb : (en_module) ? 1'b1 : 1'b0;
    assign w_mat_enb_mux    = (write_phase) ? w_mat_enb : 1'b1;

    // *** Main Controller **********************************************************
    // Create the mux here to toggle the write enable port and write/read addresses for BRAMs
    logic internal_rst_n, internal_reset_acc;
    logic systolic_finish_wrap;
    logic acc_done_wrap_rising;
    logic acc_done_wrap_d, acc_done_wrap;
    assign acc_done_wrap_rising = ~acc_done_wrap_d & acc_done_wrap;
    logic en_module; // Toggle to ALWAYS HIGH after both BRAMs are filled
    logic [WIDTH_OUT-1:0] counter, counter_row, counter_col, flag;
    logic counter_acc_done;

    // Main controller logic
    always @(posedge clk) begin
        if (~rst_n) begin
            // Counter for controllers
            counter <= 0;
            counter_row <=0;
            counter_col <=0;
            counter_acc_done <= 0;
            internal_rst_n <=0;
            internal_reset_acc <=0;
            acc_done_wrap_d <=0;
            flag <=0;
            // Addresses
            in_mat_rd_addra <= '0;
            in_mat_rd_addrb <= '0;
            w_mat_rd_addrb  <= '0;
            // Controllers
            write_phase     <= 1'b1;
            en_module       <= 1'b0;
            internal_rst_n  <= 1'b0;
            internal_reset_acc <= 1'b0;           
        end
        else begin
            acc_done_wrap_d  <= acc_done_wrap; // Assigninig the delayed version 
            counter_acc_done <= 0; // Assign this to zero every clock cycle
            //internal_rst_n   <= 1'b1; // Advice 
            //in_a_enb_d <= in_a_enb;
            //in_b_enb_d <= in_b_enb;
            
            // Port A & B Controller
            if ((in_mat_wr_addra >= NUM_A_ELEMENTS-1-1)) begin // enable AFTER BOTH of BRAMs are filled is HIGH
                en_module <= 1'b1;// Control write enable of each BRAMs for both ports
            end

            // Internal Reset Control
            if (en_module) begin
                write_phase     <= 1'b0;
                internal_rst_n  <= ~systolic_finish_wrap;
            end

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
                in_mat_rd_addra <= counter + (INNER_DIMENSION/BLOCK_SIZE)*(counter_row*2); // same as the old one but port A used for even addresses (starting from 0)
                in_mat_rd_addrb <= counter + (INNER_DIMENSION/BLOCK_SIZE)*(counter_row*2 + 1); // and port B used for odd addresses (starting from 1)`
                w_mat_rd_addrb = counter + (INNER_DIMENSION/BLOCK_SIZE)*counter_col;
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

    assign enable_linear_proj       = en_module;
    assign internal_reset_acc_ctrl  = internal_reset_acc;
    assign internal_rst_n_ctrl      = internal_rst_n;
    // Assign out_valid port when first acc_done_wrap is 1
    assign out_valid = counter_acc_done;
    // Done assigning based on flag
    assign done = (flag == MAX_FLAG);

endmodule
// top.v
// Used to combine toplevel_v2.v with BRAM
// The output will be 64-bit x NUM_CORES
// This version does not use buffer for its output. If you want to use a BRAM for the output, see top_v2.v

//`include "toplevel_v2.v"

module top_v2 #(
    parameter WIDTH = 16,
    parameter FRAC_WIDTH = 8,
    parameter BLOCK_SIZE = 2, // The size of systolic array dimension (N x N)
    parameter CHUNK_SIZE = 4,
    parameter INNER_DIMENSION = 4, // The same number of rows in one matrix and same number of columns in the other matrix
    // W stands for weight
    parameter W_OUTER_DIMENSION = 6,
    // I stands for input
    parameter I_OUTER_DIMENSION = 6,
    parameter ROW_SIZE_MAT_C = I_OUTER_DIMENSION / BLOCK_SIZE,
    parameter COL_SIZE_MAT_C = W_OUTER_DIMENSION / BLOCK_SIZE,
    // To calculate the max_flag, the formula is:
    // ROW_SIZE_MAT_C = (ROW_SIZE_MAT_A / BLOCK_SIZE)
    // COL_SIZE_MAT_C = (COL_SIZE_MAT_B / BLOCK_SIZE) 
    // MAX_FLAG = ROW_SIZE_MAT_C * COL_SIZE_MAT_C
    parameter NUM_CORES = (INNER_DIMENSION == 2754) ? 9 :
                               (INNER_DIMENSION == 256)  ? 8 :
                               (INNER_DIMENSION == 200)  ? 5 :
                               (INNER_DIMENSION == 64)   ? 4 : 2,
    parameter MAX_FLAG = ROW_SIZE_MAT_C * COL_SIZE_MAT_C / NUM_CORES,
    parameter ADDR_WIDTH_I = 2, // Used for determining the width of wb and input address and other parameters in BRAMs
    parameter ADDR_WIDTH_W = 2
) (
    input clk, rst_n,
    // Control and status port
    input  start, // start to compute

    input wb_ena,
    input [7:0] wb_wea,
    input [ADDR_WIDTH_W-1:0] wb_addra, 
    input [WIDTH*CHUNK_SIZE-1:0] wb_dina,

    input in_ena,
    input [7:0] in_wea,
    input [ADDR_WIDTH_I-1:0] in_addra, 
    input [(WIDTH*CHUNK_SIZE*NUM_CORES)-1:0] in_dina,

    // Data output port
    output reg [(WIDTH*CHUNK_SIZE*NUM_CORES)-1:0] out_bram, // DONT FORGET TO EDIT THIS EVERYTIME YOU USE DIFFERENT 
    output done
);

    localparam MEMORY_SIZE_I = INNER_DIMENSION*I_OUTER_DIMENSION*WIDTH;
    localparam MEMORY_SIZE_W = INNER_DIMENSION*W_OUTER_DIMENSION*WIDTH;

    // *** Input BRAM ***********************************************************
    // xpm_memory_tdpram: True Dual Port RAM
    // Xilinx Parameterized Macro, version 2018.3
    reg in_enb;
    reg [ADDR_WIDTH_I-1:0] in_addrb; // Same as in_addra
    wire [WIDTH*CHUNK_SIZE*NUM_CORES-1:0] in_doutb;

    xpm_memory_tdpram
    #(
        // Common module parameters
        .MEMORY_SIZE(MEMORY_SIZE_I),           // DECIMAL, 
        .MEMORY_PRIMITIVE("auto"),           // String
        .CLOCKING_MODE("common_clock"),      // String, "common_clock"
        .MEMORY_INIT_FILE("none"),           // String
        .MEMORY_INIT_PARAM("0"),             // String      
        .USE_MEM_INIT(1),                    // DECIMAL
        .WAKEUP_TIME("disable_sleep"),       // String
        .MESSAGE_CONTROL(0),                 // DECIMAL
        .AUTO_SLEEP_TIME(0),                 // DECIMAL          
        .ECC_MODE("no_ecc"),                 // String
        .MEMORY_OPTIMIZATION("true"),        // String              
        .USE_EMBEDDED_CONSTRAINT(0),         // DECIMAL
        
        // Port A module parameters
        .WRITE_DATA_WIDTH_A(WIDTH*CHUNK_SIZE*NUM_CORES), // DECIMAL, varying based on the matrix size
        .READ_DATA_WIDTH_A(WIDTH*CHUNK_SIZE*NUM_CORES),  // DECIMAL, varying based on the matrix size
        .BYTE_WRITE_WIDTH_A(8*NUM_CORES),                // DECIMAL, how many bytes in WRITE_DATA_WIDTH_A
        .ADDR_WIDTH_A(ADDR_WIDTH_I),                   // DECIMAL, clog2(MEMORY_SIZE/WRITE_DATA_WIDTH_A)
        .READ_RESET_VALUE_A("0"),            // String
        .READ_LATENCY_A(1),                  // DECIMAL
        .WRITE_MODE_A("write_first"),        // String
        .RST_MODE_A("SYNC"),                 // String
        
        // Port B module parameters  
        .WRITE_DATA_WIDTH_B(WIDTH*CHUNK_SIZE*NUM_CORES), // DECIMAL, varying based on the matrix size
        .READ_DATA_WIDTH_B(WIDTH*CHUNK_SIZE*NUM_CORES), // DECIMAL, varying based on the matrix size
        .BYTE_WRITE_WIDTH_B(8*NUM_CORES),              // DECIMAL, how many bytes in WRITE_DATA_WIDTH_A
        .ADDR_WIDTH_B(ADDR_WIDTH_I),                   // DECIMAL, clog2(MEMORY_SIZE/WRITE_DATA_WIDTH_A)
        .READ_RESET_VALUE_B("0"),            // String
        .READ_LATENCY_B(1),                  // DECIMAL
        .WRITE_MODE_B("write_first"),        // String
        .RST_MODE_B("SYNC")                  // String
    )
    xpm_memory_tdpram_in
    (
        .sleep(1'b0),
        .regcea(1'b1), //do not change
        .injectsbiterra(1'b0), //do not change
        .injectdbiterra(1'b0), //do not change   
        .sbiterra(), //do not change
        .dbiterra(), //do not change
        .regceb(1'b1), //do not change
        .injectsbiterrb(1'b0), //do not change
        .injectdbiterrb(1'b0), //do not change              
        .sbiterrb(), //do not change
        .dbiterrb(), //do not change
        
        // Port A module ports
        .clka(clk),
        .rsta(~rst_n),
        .ena(in_ena),
        .wea(in_wea),
        .addra(in_addra),
        .dina(in_dina),
        .douta(),
        
        // Port B module ports
        .clkb(clk),
        .rstb(~rst_n),
        .enb(in_enb),
        .web(0),
        .addrb(in_addrb),
        .dinb(0),
        .doutb(in_doutb)
    );

    // *** Weight BRAM **********************************************************
    // xpm_memory_tdpram: True Dual Port RAM
    // Xilinx Parameterized Macro, version 2018.3
    reg wb_enb;
    reg [ADDR_WIDTH_W-1:0] wb_addrb; // Same as wb_addra
    wire [WIDTH*CHUNK_SIZE-1:0] wb_doutb;

    xpm_memory_tdpram
    #(
        // Common module parameters
        .MEMORY_SIZE(MEMORY_SIZE_W),           // DECIMAL, 
        .MEMORY_PRIMITIVE("auto"),           // String
        .CLOCKING_MODE("common_clock"),      // String, "common_clock"
        .MEMORY_INIT_FILE("none"),           // String
        .MEMORY_INIT_PARAM("0"),             // String      
        .USE_MEM_INIT(1),                    // DECIMAL
        .WAKEUP_TIME("disable_sleep"),       // String
        .MESSAGE_CONTROL(0),                 // DECIMAL
        .AUTO_SLEEP_TIME(0),                 // DECIMAL          
        .ECC_MODE("no_ecc"),                 // String
        .MEMORY_OPTIMIZATION("true"),        // String              
        .USE_EMBEDDED_CONSTRAINT(0),         // DECIMAL
        
        // Port A module parameters
        .WRITE_DATA_WIDTH_A(WIDTH*CHUNK_SIZE), // DECIMAL, data width: 64-bit
        .READ_DATA_WIDTH_A(WIDTH*CHUNK_SIZE),  // DECIMAL, data width: 64-bit
        .BYTE_WRITE_WIDTH_A(8),              // DECIMAL, how many bytes in WRITE_DATA_WIDTH_A
        .ADDR_WIDTH_A(ADDR_WIDTH_W),                   // DECIMAL, clog2(MEMORY_SIZE/WRITE_DATA_WIDTH_A)
        .READ_RESET_VALUE_A("0"),            // String
        .READ_LATENCY_A(1),                  // DECIMAL
        .WRITE_MODE_A("write_first"),        // String
        .RST_MODE_A("SYNC"),                 // String
        
        // Port B module parameters  
        .WRITE_DATA_WIDTH_B(WIDTH*CHUNK_SIZE), // DECIMAL, data width: 64-bit
        .READ_DATA_WIDTH_B(WIDTH*CHUNK_SIZE), // DECIMAL, data width: 64-bit
        .BYTE_WRITE_WIDTH_B(8),              // DECIMAL
        .ADDR_WIDTH_B(ADDR_WIDTH_W),                   // DECIMAL, clog2(MEMORY_SIZE/WRITE_DATA_WIDTH_A)
        .READ_RESET_VALUE_B("0"),            // String
        .READ_LATENCY_B(1),                  // DECIMAL
        .WRITE_MODE_B("write_first"),        // String
        .RST_MODE_B("SYNC")                  // String
    )
    xpm_memory_tdpram_wb
    (
        .sleep(1'b0),
        .regcea(1'b1), //do not change
        .injectsbiterra(1'b0), //do not change
        .injectdbiterra(1'b0), //do not change   
        .sbiterra(), //do not change
        .dbiterra(), //do not change
        .regceb(1'b1), //do not change
        .injectsbiterrb(1'b0), //do not change
        .injectdbiterrb(1'b0), //do not change              
        .sbiterrb(), //do not change
        .dbiterrb(), //do not change
        
        // Port A module ports
        .clka(clk),
        .rsta(~rst_n),
        .ena(wb_ena),
        .wea(wb_wea),
        .addra(wb_addra),
        .dina(wb_dina),
        .douta(),
        
        // Port B module ports
        .clkb(clk),
        .rstb(~rst_n),
        .enb(wb_enb),
        .web(0),
        .addrb(wb_addrb),
        .dinb(0),
        .doutb(wb_doutb)
    );

    
    // *** Toplevel ***********************************************************
    wire systolic_finish_top, accumulator_done_top;
    wire [(WIDTH*CHUNK_SIZE*NUM_CORES)-1:0] out_core;
    reg internal_rst_n;
    reg internal_reset_acc;
    // Toggle start based on done variable
    wire top_start;
    assign top_start = ((start == 1) && (done == 0)) ? 1:0;

    toplevel_v2 #(.WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH), .BLOCK_SIZE(BLOCK_SIZE), .CHUNK_SIZE(CHUNK_SIZE), .INNER_DIMENSION(INNER_DIMENSION), .NUM_CORES(NUM_CORES)) 
    toplevel_inst (
        .clk(clk), .en(top_start), .rst_n(internal_rst_n), .reset_acc(internal_reset_acc),
        .input_n(wb_doutb), .input_w(in_doutb),
        .accumulator_done(accumulator_done_top), .systolic_finish(systolic_finish_top),
        .out_top(out_core)
    );

    // *** Main Controller **********************************************************
    // ADDD THE RESET ACC LOGICC (DONE)
    // EDIT THE RST_N AND RESET ACC LOGIC (DONE)
    // ADD THE RST_N CONDITION (DONE)
    // Based on the testbench behavior, one row of output takes 35 clock cycles
    reg [WIDTH-1:0] counter, counter_row, counter_col, flag;
    
    // Port B controller
    always @(posedge clk) begin
        if (start || ((wb_wea == 8'hFF) && (in_wea == 8'hFF))) begin
            wb_enb <= 1;
            in_enb <= 1;
        end
    end
    /*
    assign wb_enb = (wb_wea == 8'hFF) && (in_wea == 8'hFF) ? 1 : 0;
    assign in_enb = (wb_wea == 8'hFF) && (in_wea == 8'hFF) ? 1 : 0;
    */

    // Reset and counter controller
    always @(posedge clk) begin
        if (~rst_n) begin
            counter <= 0;
            counter_row <=0;
            counter_col <=0;
            internal_rst_n <=0;
            internal_reset_acc <=0;
        end
    end

    always @(posedge clk) begin
        if (start) begin
            if (systolic_finish_top == 1) begin
                internal_rst_n <= 0;
            end else begin // kalau 0
                internal_rst_n <= 1;
            end
        end
    end

    always @(posedge systolic_finish_top) begin
        if (accumulator_done_top == 1) begin
            internal_reset_acc <= 0;
        end else begin
            internal_reset_acc <= 1;
        end
    end

    // Counter controller (input matrix will be the stationary input)
    always @(posedge systolic_finish_top) begin
        in_addrb <= counter + (INNER_DIMENSION/BLOCK_SIZE)*counter_row;
        wb_addrb <= counter + (INNER_DIMENSION/BLOCK_SIZE)*counter_col;
    end

    // counter indicates the matrix C element iteration
    // counter_row indicates the i-th input matrix (I) row
    // counter_col indicates the i-th weight matrix (W) row
    always @(posedge systolic_finish_top) begin
        if (counter == ((INNER_DIMENSION/BLOCK_SIZE) - 1)) begin
            counter <=0;
        end
        else begin
            counter <= counter + 1;
        end
    end

    // Check if we already at the end of the MAT C column
    always @(posedge accumulator_done_top) begin 
        if (counter_col == (COL_SIZE_MAT_C - 1)) begin
            counter_col <= 0;
            counter_row <= counter_row + 1;
        end else begin
            counter_col <= counter_col + 1;
        end
    end

    // Output controller
    always @(posedge accumulator_done_top) begin
        out_bram <= out_core;
    end

    // Done assigning
    always @(posedge accumulator_done_top) begin
        if (flag == MAX_FLAG) begin
            flag <= flag;
        end
        else begin
            flag <= flag + 1;
        end
    end
    assign done = (flag == MAX_FLAG) ? 1:0;

endmodule
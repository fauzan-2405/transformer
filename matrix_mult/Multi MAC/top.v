// top.v
// Used to combine toplevel.v with BRAM
// TODO
/*
    1. Clean all unused ports (en, clr, ready on the main module) (DONE)
    2. Clean NUM_CORES variable in top.v module and toplevel.v module (NOT NECESSARY BECAUSE toplevel.v will be used in another matmul operations)
    3. Compute again the addra for both BRAMs (DONE)
    4. [Optional but really recommended] Change the buffer algorithm so it will eject the output horizontally and consecutively
*/

`include "toplevel.v"

module top #(
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
    parameter MAX_FLAG = ROW_SIZE_MAT_C * COL_SIZE_MAT_C;
) (
    input clk, rst_n,
    // Control and status port
    input  start, // start to compute
    //output done,
    // Weight port
    // For weight, there is 256x64 data with 16 bits each
    input wb_ena,
    input [11:0] wb_addra, // The WIDTH is corresponded with ADDR_WIDTH attribute of input BRAMs
    input [WIDTH*CHUNK_SIZE-1:0] wb_dina,
    input [7:0] wb_wea,

    // Data input port
    // For input, there is 2754x256 data with 16 bits each
    input in_ena,
    input [13:0] in_addra, // The WIDTH is corresponded with ADDR_WIDTH attribute of input BRAMs
    input [(WIDTH*CHUNK_SIZE*17)-1:0] in_dina,
    input [7:0] in_wea,

    // Data output port
    output [WIDTH*CHUNK_SIZE-1:0] out_bram
);

    localparam MEMORY_SIZE_I = INNER_DIMENSION*I_OUTER_DIMENSION*WIDTH;
    localparam MEMORY_SIZE_W = INNER_DIMENSION*W_OUTER_DIMENSION*WIDTH;
    localparam integer NUM_CORES = (INNER_DIMENSION == 2754) ? 17 :
                               (INNER_DIMENSION == 256)  ? 8 :
                               (INNER_DIMENSION == 200)  ? 5 :
                               (INNER_DIMENSION == 64)   ? 4 : 2;

    // *** Input BRAM ***********************************************************
    // xpm_memory_tdpram: True Dual Port RAM
    // Xilinx Parameterized Macro, version 2018.3
    wire in_enb;
    wire [13:0] in_addrb; // Same as in_addra
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
        .ADDR_WIDTH_A(14),                   // DECIMAL, clog2(MEMORY_SIZE/WRITE_DATA_WIDTH_A)
        .READ_RESET_VALUE_A("0"),            // String
        .READ_LATENCY_A(1),                  // DECIMAL
        .WRITE_MODE_A("write_first"),        // String
        .RST_MODE_A("SYNC"),                 // String
        
        // Port B module parameters  
        .WRITE_DATA_WIDTH_B(WIDTH*CHUNK_SIZE*NUM_CORES), // DECIMAL, varying based on the matrix size
        .READ_DATA_WIDTH_B(WIDTH*CHUNK_SIZE*NUM_CORES), // DECIMAL, varying based on the matrix size
        .BYTE_WRITE_WIDTH_B(8*NUM_CORES),              // DECIMAL, how many bytes in WRITE_DATA_WIDTH_A
        .ADDR_WIDTH_B(14),                   // DECIMAL, clog2(MEMORY_SIZE/WRITE_DATA_WIDTH_A)
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
    wire wb_enb;
    wire [11:0] wb_addrb; // Same as wb_addra
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
        .ADDR_WIDTH_A(12),                   // DECIMAL, clog2(MEMORY_SIZE/WRITE_DATA_WIDTH_A)
        .READ_RESET_VALUE_A("0"),            // String
        .READ_LATENCY_A(1),                  // DECIMAL
        .WRITE_MODE_A("write_first"),        // String
        .RST_MODE_A("SYNC"),                 // String
        
        // Port B module parameters  
        .WRITE_DATA_WIDTH_B(WIDTH*CHUNK_SIZE), // DECIMAL, data width: 64-bit
        .READ_DATA_WIDTH_B(WIDTH*CHUNK_SIZE), // DECIMAL, data width: 64-bit
        .BYTE_WRITE_WIDTH_B(8),              // DECIMAL
        .ADDR_WIDTH_B(12),                   // DECIMAL, clog2(MEMORY_SIZE/WRITE_DATA_WIDTH_A)
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
    reg internal_rst_n;
    reg internal_reset_acc;

    toplevel #(.WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH), .BLOCK_SIZE(BLOCK_SIZE), .CHUNK_SIZE(CHUNK_SIZE), .INNER_DIMENSION(INNER_DIMENSION)) toplevel_inst (
        .clk(clk), .en(start), .rst_n(internal_rst_n), .reset_acc(internal_reset_acc),
        .input_n(wb_doutb), .input_w(in_doutb),
        .accumulator_done(accumulator_done_top), .systolic_finish(systolic_finish_top),
        .out_top(out_bram)
    );

    // *** Main Controller **********************************************************
    // ADDD THE RESET ACC LOGICC (DONE)
    // EDIT THE RST_N AND RESET ACC LOGIC (DONE)
    // ADD THE RST_N CONDITION (DONE)
    // Based on the testbench behavior, one row of output takes 35 clock cycles
    reg [WIDTH-1:0] counter, counter_row, counter_col;
    
    // Port B controller
    always @(posedge clk) begin
        if ((wb_wea == 8'hFF) && (in_wea == 8'hFF)) begin
            wb_enb <= 1;
            in_enb <= 1;
        end
    end

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

    // EDIT THIS!!!!!!!!!!!!
    // (I think it's already okay)
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

endmodule
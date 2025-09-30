// top_multwrap_bram
// This top module wraps multi_matmul_wrapper + bram for testing purposes

module top_multwrap_bram #(
    parameter TOTAL_INPUT_W = 2,
    parameter TOTAL_MODULES = 4
) (
    import linear_proj_pkg::*;
    input logic clk, rst_n,
    input logic en_module,

    // For Input Matrix BRAM
    input logic in_mat_ena,
    input logic in_mat_wea,
    input [ADDR_WIDTH_A-1:0] in_mat_wr_addra,
    input [WIDTH_A*CHUNK_SIZE*NUM_CORES_A-1:0] in_mat_dina,

    input logic in_mat_enb,
    input logic in_mat_web,
    input [ADDR_WIDTH_A-1:0] in_mat_wr_addrb,
    input [WIDTH_A*CHUNK_SIZE*NUM_CORES_A-1:0] in_mat_dinb,

    // For Weight Matrix BRAM
    input logic w_mat_ena,
    input logic w_mat_wea,
    input [ADDR_WIDTH_A-1:0] w_mat_wr_addra,
    input [WIDTH_A*CHUNK_SIZE*NUM_CORES_A-1:0] w_mat_dina,

    input logic w_mat_enb,
    input logic w_mat_web,
    input [ADDR_WIDTH_A-1:0] w_mat_wr_addrb,
    input [WIDTH_A*CHUNK_SIZE*NUM_CORES_A-1:0] w_mat_dinb,

    output logic done, out_valid,
    output [(WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A*NUM_CORES_B*TOTAL_MODULES)-1:0] out_multi_matmul [TOTAL_INPUT_W]
);
    // Local Parameters
    localparam ROW_SIZE_MAT_C = A_OUTER_DIMENSION / (BLOCK_SIZE * NUM_CORES_A * TOTAL_INPUT_W); 
    localparam COL_SIZE_MAT_C = B_OUTER_DIMENSION / (BLOCK_SIZE * NUM_CORES_B * TOTAL_MODULES); 
    localparam MAX_FLAG = (ROW_SIZE_MAT_C * COL_SIZE_MAT_C);

    localparam MEMORY_SIZE_A = INNER_DIMENSION*A_OUTER_DIMENSION*WIDTH_A;
    localparam MEMORY_SIZE_B = INNER_DIMENSION*B_OUTER_DIMENSION*WIDTH_B;

    // *** Input Matrix BRAM ***********************************************************
    // xpm_memory_tdpram: True Dual Port RAM
    // Xilinx Parameterized Macro, version 2018.3
    logic [ADDR_WIDTH_A-1:0] in_mat_rd_addra, in_mat_rd_addrb; 
    logic [WIDTH_A*CHUNK_SIZE*NUM_CORES_A-1:0] in_mat_douta, in_mat_doutb;

    xpm_memory_tdpram
    #(
        // Common module parameters
        .MEMORY_SIZE(MEMORY_SIZE_A),           // DECIMAL, 
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
        .WRITE_DATA_WIDTH_A(WIDTH_A*CHUNK_SIZE*NUM_CORES_A), // DECIMAL, varying based on the matrix size
        .READ_DATA_WIDTH_A(WIDTH_A*CHUNK_SIZE*NUM_CORES_A),  // DECIMAL, varying based on the matrix size
        .BYTE_WRITE_WIDTH_A((WIDTH_A*CHUNK_SIZE*NUM_CORES_A)),                // DECIMAL, how many bytes in WRITE_DATA_WIDTH_A, use $clog2 maybe?
        .ADDR_WIDTH_A(ADDR_WIDTH_A),                   // DECIMAL, clog2(MEMORY_SIZE_A/WRITE_DATA_WIDTH_A)
        .READ_RESET_VALUE_A("0"),            // String
        .READ_LATENCY_A(1),                  // DECIMAL
        .WRITE_MODE_A("write_first"),        // String
        .RST_MODE_A("SYNC"),                 // String
        
        // Port B module parameters  
        .WRITE_DATA_WIDTH_B(WIDTH_A*CHUNK_SIZE*NUM_CORES_A), // DECIMAL, varying based on the matrix size
        .READ_DATA_WIDTH_B(WIDTH_A*CHUNK_SIZE*NUM_CORES_A), // DECIMAL, varying based on the matrix size
        .BYTE_WRITE_WIDTH_B((WIDTH_A*CHUNK_SIZE*NUM_CORES_A)),              // DECIMAL, how many bytes in WRITE_DATA_WIDTH_A
        .ADDR_WIDTH_B(ADDR_WIDTH_A),                   // DECIMAL, clog2(MEMORY_SIZE/WRITE_DATA_WIDTH_A)
        .READ_RESET_VALUE_B("0"),            // String
        .READ_LATENCY_B(1),                  // DECIMAL
        .WRITE_MODE_B("write_first"),        // String
        .RST_MODE_B("SYNC")                  // String
    )
    xpm_memory_tdpram_in_a
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
        .ena(in_mat_ena),
        .wea(in_mat_wea),
        .addra(), // ************ PLEASE CHANGE THIS ************
        .dina(in_a_dina),
        .douta(),
        
        // Port B module ports
        .clkb(clk),
        .rstb(~rst_n),
        .enb(in_mat_enb),
        .web(in_mat_web),
        .addrb(), // ************ PLEASE CHANGE THIS ************
        .dinb(0),
        .doutb(in_a_doutb)
    );


    // *** Input Weight BRAM **********************************************************
    // xpm_memory_tdpram: True Dual Port RAM
    // Xilinx Parameterized Macro, version 2018.3
    logic [ADDR_WIDTH_A-1:0] w_mat_rd_addra, w_mat_rd_addrb; 
    logic [WIDTH_A*CHUNK_SIZE*NUM_CORES_A-1:0] w_mat_douta, w_mat_doutb;

    xpm_memory_tdpram
    #(
        // Common module parameters
        .MEMORY_SIZE(MEMORY_SIZE_B),           // DECIMAL, 
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
        .WRITE_DATA_WIDTH_A(WIDTH_B*CHUNK_SIZE*NUM_CORES_B), // DECIMAL, data width: 64-bit
        .READ_DATA_WIDTH_A(WIDTH_B*CHUNK_SIZE*NUM_CORES_B),  // DECIMAL, data width: 64-bit
        .BYTE_WRITE_WIDTH_A((WIDTH_B*CHUNK_SIZE*NUM_CORES_B)),              // DECIMAL, how many bytes in WRITE_DATA_WIDTH_A, use $clog2 maybe?
        .ADDR_WIDTH_A(ADDR_WIDTH_B),                   // DECIMAL, clog2(MEMORY_SIZE/WRITE_DATA_WIDTH_A)
        .READ_RESET_VALUE_A("0"),            // String
        .READ_LATENCY_A(1),                  // DECIMAL
        .WRITE_MODE_A("write_first"),        // String
        .RST_MODE_A("SYNC"),                 // String
        
        // Port B module parameters  
        .WRITE_DATA_WIDTH_B(WIDTH_B*CHUNK_SIZE*NUM_CORES_B), // DECIMAL, data width: 64-bit
        .READ_DATA_WIDTH_B(WIDTH_B*CHUNK_SIZE*NUM_CORES_B), // DECIMAL, data width: 64-bit
        .BYTE_WRITE_WIDTH_B((WIDTH_B*CHUNK_SIZE*NUM_CORES_B)),              // DECIMAL
        .ADDR_WIDTH_B(ADDR_WIDTH_B),                   // DECIMAL, clog2(MEMORY_SIZE/WRITE_DATA_WIDTH_A)
        .READ_RESET_VALUE_B("0"),            // String
        .READ_LATENCY_B(1),                  // DECIMAL
        .WRITE_MODE_B("write_first"),        // String
        .RST_MODE_B("SYNC")                  // String
    )
    xpm_memory_tdpram_in_b
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
        .ena(w_mat_ena),
        .wea(w_mat_wea),
        .addra(), // ************ PLEASE CHANGE THIS ************
        .dina(w_mat_dina),
        .douta(),
        
        // Port B module ports
        .clkb(clk),
        .rstb(~rst_n),
        .enb(w_mat_wea),
        .web(0),
        .addrb(), // ************ PLEASE CHANGE THIS ************
        .dinb(w_mat_dinb),
        .doutb()
    );

    // *** Matmul wrapper ***********************************************************
    multi_matmul_wrapper #(
        .WIDTH_A(WIDTH_A),
        .FRAC_WIDTH_A(FRAC_WIDTH_A),
        .WIDTH_B(WIDTH_B),
        .FRAC_WIDTH_B(FRAC_WIDTH_B),
        .WIDTH_OUT(WIDTH_OUT),
        .FRAC_WIDTH_OUT(FRAC_WIDTH_OUT),
        .BLOCK_SIZE(BLOCK_SIZE),
        .CHUNK_SIZE(CHUNK_SIZE),
        .INNER_DIMENSION(INNER_DIMENSION),
        .NUM_CORES_A(NUM_CORES_A),
        .NUM_CORES_B(NUM_CORES_B)
    ) 
    multi_matmul_wrapper_inst (

    );

    // *** Controller **********************************************************
    // Create the mux here
    // *** Main Controller **********************************************************
    
    reg [WIDTH_OUT-1:0] counter, counter_row, counter_col, flag;
    reg counter_acc_done;

    // Main controller logic
    always @(posedge clk) begin
        if (~rst_n) begin
            top_start <= 0;
            counter <= 0;
            counter_row <=0;
            counter_col <=0;
            counter_acc_done <= 0;
            internal_rst_n <=0;
            internal_reset_acc <=0;
            accumulator_done_top_d <=0;
            flag <=0;
            in_a_enb <=0;
            in_b_enb <=0;
            in_a_enb_d <=0;
            in_b_enb_d <=0;
            in_a_addrb <=0;
            in_b_addrb <=0;
            out_bram <=0;
        end
        else begin
            accumulator_done_top_d <= accumulator_done_top; // Assigninig the delayed version 
            in_a_enb_d <= in_a_enb;
            in_b_enb_d <= in_b_enb;
            counter_acc_done <= 0; // Assign this to zero every clock cycle
            
            // Port B Controller
            //if (start || ((in_b_wea) && (in_a_wea))) begin
            if (start) begin
                in_b_enb <=1;
                in_a_enb <=1;
                top_start <= 1;
            end

            // Internal Reset Control
            if (start) begin
                internal_rst_n <= ~systolic_finish_top;
            end

            if (systolic_finish_top) begin
                internal_reset_acc <= ~accumulator_done_top;
            end

            // Counter Update
            if (systolic_finish_top) begin
                // counter indicates the matrix C element iteration
                if (counter == ((INNER_DIMENSION/BLOCK_SIZE) - 1)) begin // Please solve this later!
                //if (counter == ((NUM_CORES_A*BLOCK_SIZE) - 1)) begin // Change between these two
                    counter <=0;
                end
                else begin
                    counter <= counter + 1;
                end
                // Address controller
                in_a_addrb <= counter + (INNER_DIMENSION/BLOCK_SIZE)*counter_row;
                in_b_addrb <= counter + (INNER_DIMENSION/BLOCK_SIZE)*counter_col;
                //in_a_addrb <= counter + (NUM_CORES_A*BLOCK_SIZE)*counter_row;
                //in_b_addrb <= counter + (NUM_CORES_B*BLOCK_SIZE)*counter_col;
            end

            // Column/Row Update
            if (accumulator_done_top_rising) begin
                // counter_row indicates the i-th row of the matrix C that we are working right now
                // counter_col indicates the i-th column of the matrix C that we are working right now

                // Check if we already at the end of the MAT C column
                if (counter_col == (COL_SIZE_MAT_C - 1)) begin
                    counter_col <= 0;
                    counter_row <= counter_row + 1;
                end else begin
                    counter_col <= counter_col + 1;
                end

                // Assigning the output
                out_bram <= out_core;

                counter_acc_done <= 1;

                // Flag assigning for 'done' variable
                if (flag != MAX_FLAG) begin
                    flag <= flag + 1;   
                end
            end
        end
    end


    
    


endmodule
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
    input [ADDR_WIDTH_B-1:0] w_mat_wr_addra,
    input [WIDTH_B*CHUNK_SIZE*NUM_CORES_B*TOTAL_MODULES-1:0] w_mat_dina,

    input logic w_mat_enb,
    input logic w_mat_web,
    input [ADDR_WIDTH_B-1:0] w_mat_wr_addrb,
    input [WIDTH_B*CHUNK_SIZE*NUM_CORES_B*TOTAL_MODULES-1:0] w_mat_dinb,

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
    xpm_memory_tdpram_in_mat
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
        .wea(in_mat_wea), // Please toggle this to 1 when it's time to write and 0 when it's time to read
        .addra(), // in_mat_rd_addra or in_mat_wr_addra
        .dina(in_mat_dina),
        .douta(in_mat_douta),
        
        // Port B module ports
        .clkb(clk),
        .rstb(~rst_n),
        .enb(in_mat_enb),
        .web(in_mat_web), // Please toggle this to 1 when it's time to write and 0 when it's time to read
        .addrb(),  // please toggle between in_mat_rd_addrb or in_mat_wr_addrb
        .dinb(in_mat_dinb),
        .doutb(in_mat_doutb)
    );


    // *** Input Weight BRAM **********************************************************
    // xpm_memory_tdpram: True Dual Port RAM
    // Xilinx Parameterized Macro, version 2018.3
    logic [ADDR_WIDTH_B-1:0] w_mat_rd_addra, w_mat_rd_addrb; 
    logic [WIDTH_B*CHUNK_SIZE*NUM_CORES_B*TOTAL_MODULES-1:0] w_mat_doutb;

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
        .WRITE_DATA_WIDTH_A(WIDTH_B*CHUNK_SIZE*NUM_CORES_B*TOTAL_MODULES), // DECIMAL, data width: 64-bit
        .READ_DATA_WIDTH_A(WIDTH_B*CHUNK_SIZE*NUM_CORES_B*TOTAL_MODULES),  // DECIMAL, data width: 64-bit
        .BYTE_WRITE_WIDTH_A((WIDTH_B*CHUNK_SIZE*NUM_CORES_B*TOTAL_MODULES)),              // DECIMAL, how many bytes in WRITE_DATA_WIDTH_A, use $clog2 maybe?
        .ADDR_WIDTH_A(ADDR_WIDTH_B),                   // DECIMAL, clog2(MEMORY_SIZE/WRITE_DATA_WIDTH_A)
        .READ_RESET_VALUE_A("0"),            // String
        .READ_LATENCY_A(1),                  // DECIMAL
        .WRITE_MODE_A("write_first"),        // String
        .RST_MODE_A("SYNC"),                 // String
        
        // Port B module parameters  
        .WRITE_DATA_WIDTH_B(WIDTH_B*CHUNK_SIZE*NUM_CORES_B*TOTAL_MODULES), // DECIMAL, data width: 64-bit
        .READ_DATA_WIDTH_B(WIDTH_B*CHUNK_SIZE*NUM_CORES_B*TOTAL_MODULES), // DECIMAL, data width: 64-bit
        .BYTE_WRITE_WIDTH_B((WIDTH_B*CHUNK_SIZE*NUM_CORES_B*TOTAL_MODULES)),              // DECIMAL
        .ADDR_WIDTH_B(ADDR_WIDTH_B),                   // DECIMAL, clog2(MEMORY_SIZE/WRITE_DATA_WIDTH_A)
        .READ_RESET_VALUE_B("0"),            // String
        .READ_LATENCY_B(1),                  // DECIMAL
        .WRITE_MODE_B("write_first"),        // String
        .RST_MODE_B("SYNC")                  // String
    )
    xpm_memory_tdpram_we_mat
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
        .wea(w_mat_wea), // Please toggle this to 1 when it's time to write and 0 when it's time to read
        .addra(), // please toggle between w_mat_rd_addra or w_mat_wr_addra
        .dina(w_mat_dina),
        .douta(),
        
        // Port B module ports
        .clkb(clk),
        .rstb(~rst_n),
        .enb(w_mat_enb),
        .web(w_mat_web), // Please toggle this to 1 when it's time to write and 0 when it's time to read
        .addrb(), // please toggle between w_mat_rd_addrb or w_mat_wr_addrb
        .dinb(w_mat_dinb),
        .doutb(w_mat_doutb) // For now, we only use port B to read
    );

    // *** Matmul wrapper ***********************************************************
    reg internal_rst_n, internal_reset_acc;
    logic acc_done_wrap_rising;
    logic acc_done_wrap_d, acc_done_wrap; 
    assign acc_done_wrap_rising = ~acc_done_wrap_d & acc_done_wrap;
    logic systolic_finish_wrap;
    
    multi_matmul_wrapper #(
        .WIDTH_A(WIDTH_A),
        .FRAC_WIDTH_A(FRAC_WIDTH_A),
        .WIDTH_B(WIDTH_B),
        .FRAC_WIDTH_B(FRAC_WIDTH_B),
        .WIDTH_OUT(WIDTH_OUT),
        .FRAC_WIDTH_OUT(FRAC_WIDTH_OUT),
        .BLOCK_SIZE(BLOCK_SIZE),
        .CHUNK_SIZE(CHUNK_SIZE),
        .TOTAL_MODULES(TOTAL_MODULES),
        .TOTAL_INPUT_W(TOTAL_INPUT_W),
        .INNER_DIMENSION(INNER_DIMENSION),
        .NUM_CORES_A(NUM_CORES_A),
        .NUM_CORES_B(NUM_CORES_B),
    ) 
    multi_matmul_wrapper_inst (
        .clk(clk), .rst_n(internal_rst_n),
        .en(), // toggle enable after BOTH Input and Weight BRAM are entirely filled
        .reset_acc(internal_reset_acc),
        // in_bram
        .acc_done_wrap(acc_done_wrap), .systolic_finish_wrap(systolic_finish_wrap)
        // out_multi_matmul
    );

    // *** Main Controller **********************************************************
    // Create the mux here to toggle the write enable port and write/read addresses for BRAMs

    reg [WIDTH_OUT-1:0] counter, counter_row, counter_col, flag;
    reg counter_acc_done;

    // Main controller logic
    always @(posedge clk) begin
        if (~rst_n) begin
            counter <= 0;
            counter_row <=0;
            counter_col <=0;
            counter_acc_done <= 0;
            internal_rst_n <=0;
            internal_reset_acc <=0;
            acc_done_wrap_d <=0;
            flag <=0;
            // Initiliaze output to 0;
        end
        else begin
            acc_done_wrap_d <= acc_done_wrap; // Assigninig the delayed version 
            in_a_enb_d <= in_a_enb;
            in_b_enb_d <= in_b_enb;
            counter_acc_done <= 0; // Assign this to zero every clock cycle
            
            // Port A & B Controller
            if () begin // enable AFTER BOTH of BRAMs are filled is HIGH
                // Control write enable of each BRAMs for both ports
            end

            // Internal Reset Control
            if (en_module) begin
                internal_rst_n <= ~systolic_finish_wrap;
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
                in_mat_rd_addra <= ... // same as the old one but port A used for even addresses (starting from 0)
                in_mat_rd_addrb <= ... // and port B used for odd addresses (starting from 1)`
                we_mat_rd_addrb = counter + (INNER_DIMENSION/BLOCK_SIZE)*counter_col;
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
                out_bram <= out_core; // Please change this to output port of multi_matmul_wrapper

                counter_acc_done <= 1;

                // Flag assigning for 'done' variable
                if (flag != MAX_FLAG) begin
                    flag <= flag + 1;   
                end
            end
        end
    end

    // Assign out_valid port when first acc_done_wrap is 1
    assign out_valid = counter_acc_done;
    // Done assigning based on flag
    assign done = (flag == MAX_FLAG);

endmodule
// matmul_w_bram.v
// Used to combine matmul_module.v with BRAM
// The output will be 64-bit x NUM_CORES_A * NUM_CORES_B
//`include "matmul_module.v"

module matmul_w_bram #(
    // Matrix A n B parameters
    parameter WIDTH_A = 16,
    parameter FRAC_WIDTH_A = 8,
    parameter WIDTH_B = 16,
    parameter FRAC_WIDTH_B = 8,
    parameter WIDTH_OUT = 16,
    parameter FRAC_WIDTH_OUT = 8,
    parameter INNER_DIMENSION = 64,
    parameter A_OUTER_DIMENSION = 6,
    parameter B_OUTER_DIMENSION = 6,
    // General parameter
    parameter BLOCK_SIZE = 2, 
    parameter CHUNK_SIZE = 4,
    parameter NUM_CORES_A = (INNER_DIMENSION == 2754) ? 9 :
                               (INNER_DIMENSION == 256)  ? 8 :
                               (INNER_DIMENSION == 200)  ? 5 :
                               (INNER_DIMENSION == 64)   ? 4 : 2,
    parameter NUM_CORES_B = (INNER_DIMENSION == 2754) ? 9 :
                               (INNER_DIMENSION == 256)  ? 8 :
                               (INNER_DIMENSION == 200)  ? 5 :
                               (INNER_DIMENSION == 64)   ? 4 : 2,
    parameter ADDR_WIDTH_A = $clog2((INNER_DIMENSION*A_OUTER_DIMENSION*WIDTH_A)/(WIDTH_A*CHUNK_SIZE*NUM_CORES_A)),
    parameter ADDR_WIDTH_B = $clog2((INNER_DIMENSION*B_OUTER_DIMENSION*WIDTH_B)/(WIDTH_B*CHUNK_SIZE*NUM_CORES_B));
) (
    input clk, rst_n,
    // Control and status port
    input start, // start to compute

    input in_b_ena,
    input [7:0] in_b_wea,
    input [ADDR_WIDTH_B-1:0] in_b_addra,
    input [WIDTH*CHUNK_SIZE*NUM_CORES_B-1:0] in_b_dina,

    input in_a_ena,
    input [7:0] in_a_wea,
    input [ADDR_WIDTH_A-1:0] in_a_addra,
    input [WIDTH*CHUNK_SIZE*NUM_CORES_A-1:0] in_a_dina,

    // Data output port
    output done, out_valid,
    output reg [(WIDTH*CHUNK_SIZE*NUM_CORES)-1:0] out_bram
);
    localparam ROW_SIZE_MAT_C = A_OUTER_DIMENSION / BLOCK_SIZE;
    localparam COL_SIZE_MAT_C = B_OUTER_DIMENSION / BLOCK_SIZE;
    localparam MAX_FLAG = (ROW_SIZE_MAT_C * COL_SIZE_MAT_C) / (NUM_CORES_A * NUM_CORES_B);

    localparam MEMORY_SIZE_A = INNER_DIMENSION*A_OUTER_DIMENSION*WIDTH_A;
    localparam MEMORY_SIZE_B = INNER_DIMENSION*B_OUTER_DIMENSION*WIDTH_B;

    // *** Input A BRAM ***********************************************************
    // xpm_memory_tdpram: True Dual Port RAM
    // Xilinx Parameterized Macro, version 2018.3
    reg in_a_enb;
    reg [ADDR_WIDTH_A-1:0] in_a_addrb; // Same as in_a_addra
    wire [WIDTH_A*CHUNK_SIZE*NUM_CORES_A-1:0] in_a_doutb;

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
        .BYTE_WRITE_WIDTH_A(WIDTH_A*CHUNK_SIZE*NUM_CORES_A),                // DECIMAL, how many bytes in WRITE_DATA_WIDTH_A, use $clog2 maybe?
        .ADDR_WIDTH_A(ADDR_WIDTH_A),                   // DECIMAL, clog2(MEMORY_SIZE_A/WRITE_DATA_WIDTH_A)
        .READ_RESET_VALUE_A("0"),            // String
        .READ_LATENCY_A(1),                  // DECIMAL
        .WRITE_MODE_A("write_first"),        // String
        .RST_MODE_A("SYNC"),                 // String
        
        // Port B module parameters  
        .WRITE_DATA_WIDTH_B(WIDTH_A*CHUNK_SIZE*NUM_CORES_A), // DECIMAL, varying based on the matrix size
        .READ_DATA_WIDTH_B(WIDTH_A*CHUNK_SIZE*NUM_CORES_A), // DECIMAL, varying based on the matrix size
        .BYTE_WRITE_WIDTH_B(WIDTH_A*CHUNK_SIZE*NUM_CORES_A),              // DECIMAL, how many bytes in WRITE_DATA_WIDTH_A
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
        .ena(in_a_ena),
        .wea(in_a_wea),
        .addra(in_a_addra),
        .dina(in_a_dina),
        .douta(),
        
        // Port B module ports
        .clkb(clk),
        .rstb(~rst_n),
        .enb(in_a_enb),
        .web(0),
        .addrb(in_a_addrb),
        .dinb(0),
        .doutb(in_a_doutb)
    );

    // *** Input B BRAM **********************************************************
    // xpm_memory_tdpram: True Dual Port RAM
    // Xilinx Parameterized Macro, version 2018.3
    reg in_b_enb;
    reg [ADDR_WIDTH_B-1:0] in_b_addrb; // Same as in_b_addra
    wire [WIDTH_B*CHUNK_SIZE*NUM_CORES_B-1:0] in_b_doutb;

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
        .BYTE_WRITE_WIDTH_A(WIDTH_B*CHUNK_SIZE*NUM_CORES_B),              // DECIMAL, how many bytes in WRITE_DATA_WIDTH_A, use $clog2 maybe?
        .ADDR_WIDTH_A(ADDR_WIDTH_B),                   // DECIMAL, clog2(MEMORY_SIZE/WRITE_DATA_WIDTH_A)
        .READ_RESET_VALUE_A("0"),            // String
        .READ_LATENCY_A(1),                  // DECIMAL
        .WRITE_MODE_A("write_first"),        // String
        .RST_MODE_A("SYNC"),                 // String
        
        // Port B module parameters  
        .WRITE_DATA_WIDTH_B(WIDTH_B*CHUNK_SIZE*NUM_CORES_B), // DECIMAL, data width: 64-bit
        .READ_DATA_WIDTH_B(WIDTH_B*CHUNK_SIZE*NUM_CORES_B), // DECIMAL, data width: 64-bit
        .BYTE_WRITE_WIDTH_B(WIDTH_B*CHUNK_SIZE*NUM_CORES_B),              // DECIMAL
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
        .ena(in_b_ena),
        .wea(in_b_wea),
        .addra(in_b_addra),
        .dina(in_b_dina),
        .douta(),
        
        // Port B module ports
        .clkb(clk),
        .rstb(~rst_n),
        .enb(in_b_enb),
        .web(0),
        .addrb(in_b_addrb),
        .dinb(0),
        .doutb(in_b_doutb)
    );

    // *** Toplevel ***********************************************************
    wire systolic_finish_top;
    wire accumulator_done_top;
    reg accumulator_done_top_d; // Delayed version of accumulator_done_top
    wire accumulator_done_top_rising; // Rising edge signal
    assign accumulator_done_top_rising = ~accumulator_done_top_d & accumulator_done_top;
    
    wire [(WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A*NUM_CORES_B)-1:0] out_core;
    reg internal_rst_n;
    reg internal_reset_acc;
    // Toggle start based on done variable
    wire top_start;
    assign top_start = (start && !done);

    matmul_module #(.WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH), .BLOCK_SIZE(BLOCK_SIZE), .CHUNK_SIZE(CHUNK_SIZE), .INNER_DIMENSION(INNER_DIMENSION), .NUM_CORES(NUM_CORES)) 
    matmul_module_inst (
        .clk(clk), .en(top_start), .rst_n(internal_rst_n), .reset_acc(internal_reset_acc),
        .input_n(in_b_doutb), .input_w(in_a_doutb),
        .accumulator_done(accumulator_done_top), .systolic_finish(systolic_finish_top),
        .out_top(out_core)
    );

    // *** Main Controller **********************************************************
    
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
            accumulator_done_top_d <=0;
            flag <=0;
            in_a_enb <=0;
            in_b_enb <=0;
            in_a_addrb <=0;
            in_b_addrb <=0;
            out_bram <=0;
        end
        else begin
            accumulator_done_top_d <= accumulator_done_top; // Assigninig the delayed version 
            counter_acc_done <= 0; // Assign this to zero every clock cycle
            
            // Port B Controller
            if (start || ((in_b_wea == 8'hFF) && (in_a_wea == 8'hFF))) begin
                in_b_enb <=1;
                in_a_enb <=1;
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
                if (counter == ((INNER_DIMENSION/BLOCK_SIZE) - 1)) begin
                    counter <=0;
                end
                else begin
                    counter <= counter + 1;
                end
                // Address controller (input matrix will be the stationary input)
                in_a_addrb <= counter + (INNER_DIMENSION/BLOCK_SIZE)*counter_row;
                in_b_addrb <= counter + (INNER_DIMENSION/BLOCK_SIZE)*counter_col;
            end

            // Column/Row Update
            if (accumulator_done_top_rising) begin
                // counter_row indicates the i-th input matrix (I) row
                // counter_col indicates the i-th weight matrix (W) row

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

    // Assign out_valid port when first accumulator_done_top is 1
    assign out_valid = counter_acc_done;
    // Done assigning based on flag
    assign done = (flag == MAX_FLAG);


endmodule


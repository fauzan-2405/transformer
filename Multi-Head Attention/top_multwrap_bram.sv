// top_multwrap_bram
// This top module wraps multi_matmul_wrapper + bram for testing purposes

module top_multwrap_bram #(
    parameter TOTAL_INPUT_W = 2,
    parameter TOTAL_MODULES = 4
) (
    import linear_proj_pkg::*;
    input logic clk, rst_n,
    input logic en_module,

    input logic in_mat_ena,
    input logic in_mat_wea,
    input [ADDR_WIDTH_A-1:0] in_mat_wr_addra,
    input [WIDTH_A*CHUNK_SIZE*NUM_CORES_A-1:0] in_mat_dina,

    input logic in_mat_enb,
    input logic in_mat_web,
    input [ADDR_WIDTH_A-1:0] in_mat_wr_addrb,
    input [WIDTH_A*CHUNK_SIZE*NUM_CORES_A-1:0] in_mat_dinb,

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
        .addra(in_a_addra),
        .dina(in_a_dina),
        .douta(),
        
        // Port B module ports
        .clkb(clk),
        .rstb(~rst_n),
        .enb(in_mat_enb),
        .web(in_mat_web),
        .addrb(in_a_addrb),
        .dinb(0),
        .doutb(in_a_doutb)
    );


    
    
    


endmodule
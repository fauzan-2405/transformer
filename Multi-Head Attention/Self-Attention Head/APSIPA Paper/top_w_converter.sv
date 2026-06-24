// top_w_converter.sv
// Used as a top module for converter that does not use the r2b_converter

module top_w_converter #(
    // Matrix Parameters
    parameter A_OUTER_DIMENSION = 16,
    parameter INNER_DIMENSION   = 10,
    parameter B_OUTER_DIMENSION = 12,

    // Elements Parameters 
    parameter WIDTH_A       = 16,
    parameter FRAC_WIDTH_A  = 8,
    parameter WIDTH_B       = 16,
    parameter FRAC_WIDTH_B  = 8,
    parameter WIDTH_OUT     = 16,
    parameter FRAC_WIDTH_OUT= 8,
    parameter BLOCK_SIZE    = 2,
    parameter CHUNK_SIZE    = BLOCK_SIZE * BLOCK_SIZE,
    parameter NUM_CORES_A   = 2,
    parameter NUM_CORES_B   = 2,
    parameter WIDTH_IN_A    = WIDTH_A * CHUNK_SIZE * NUM_CORES_A,
    parameter WIDTH_IN_B    = WIDTH_B * CHUNK_SIZE * NUM_CORES_B,
    parameter WIDTH_OUT_C   = WIDTH_OUT * CHUNK_SIZE * NUM_CORES_A * NUM_CORES_B
) (
    input wire              aclk,
    input wire              aresetn,

    // *** AXIS Slave 0 port ***
    output wire                 s_axis_0_tready,
    input wire [WIDTH_IN_A-1:0] s_axis_0_tdata, // Input Data
    input wire                  s_axis_0_tvalid,
    input wire                  s_axis_0_tlast,
    // *** AXIS Slave 1 port ***
    output wire                 s_axis_1_tready,
    input wire [WIDTH_IN_B-1:0] s_axis_1_tdata, // Weight Data
    input wire                  s_axis_1_tvalid,
    input wire                  s_axis_1_tlast,

    // *** Custom IP port (optional) ***
    
    // *** AXIS master port ***
    input wire                  m_axis_tready,
    output wire [WIDTH_OUT_C-1:0]  m_axis_tdata, // Output Data
    output wire                 m_axis_tvalid,
    output wire                 m_axis_tlast
);
    localparam int NUM_A_ELEMENTS = ((A_OUTER_DIMENSION/BLOCK_SIZE)*(INNER_DIMENSION/BLOCK_SIZE))/(NUM_CORES_A); // Total elements of Input if we converted the inputs based on the NUM_CORES, in tb_multihead_attention.sv
    localparam int NUM_B_ELEMENTS = ((B_OUTER_DIMENSION/BLOCK_SIZE)*(INNER_DIMENSION/BLOCK_SIZE))/(NUM_CORES_B);

    localparam int ROW_SIZE_MAT_C = A_OUTER_DIMENSION / (BLOCK_SIZE * NUM_CORES_A);  
    localparam int COL_SIZE_MAT_C = B_OUTER_DIMENSION / (BLOCK_SIZE * NUM_CORES_B); 
    localparam int MAX_FLAG = (ROW_SIZE_MAT_C * COL_SIZE_MAT_C);

    // ========================================= INPUT BRAM =========================================
    localparam MEMORY_SIZE_A = INNER_DIMENSION*A_OUTER_DIMENSION*WIDTH_A;
    localparam DATA_WIDTH_A  = WIDTH_A*CHUNK_SIZE*NUM_CORES_A;
    localparam int ADDR_WIDTH_A = $clog2(MEMORY_SIZE_A/DATA_WIDTH_A);

    logic in_mat_en;
    logic in_mat_wea;
    logic [ADDR_WIDTH_A-1:0] in_mat_addra, in_mat_addrb;
    logic [DATA_WIDTH_A-1:0] in_mat_doutb;
    
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
        .WRITE_DATA_WIDTH_A(DATA_WIDTH_A), // DECIMAL, varying based on the matrix size
        .READ_DATA_WIDTH_A(DATA_WIDTH_A),  // DECIMAL, varying based on the matrix size
        .BYTE_WRITE_WIDTH_A(DATA_WIDTH_A), // DECIMAL, how many bytes in WRITE_DATA_WIDTH_A, use $clog2 maybe?
        .ADDR_WIDTH_A(ADDR_WIDTH_A),         // DECIMAL, clog2(MEMORY_SIZE_A/WRITE_DATA_WIDTH_A)
        .READ_RESET_VALUE_A("0"),            // String
        .READ_LATENCY_A(1),                  // DECIMAL
        .WRITE_MODE_A("write_first"),        // String
        .RST_MODE_A("SYNC"),                 // String
        
        // Port B module parameters  
        .WRITE_DATA_WIDTH_B(DATA_WIDTH_A), // DECIMAL, varying based on the matrix size
        .READ_DATA_WIDTH_B(DATA_WIDTH_A),  // DECIMAL, varying based on the matrix size
        .BYTE_WRITE_WIDTH_B(DATA_WIDTH_A), // DECIMAL, how many bytes in WRITE_DATA_WIDTH_A
        .ADDR_WIDTH_B(ADDR_WIDTH_A),         // DECIMAL, clog2(MEMORY_SIZE/WRITE_DATA_WIDTH_A)
        .READ_RESET_VALUE_B("0"),            // String
        .READ_LATENCY_B(1),                  // DECIMAL
        .WRITE_MODE_B("write_first"),        // String
        .RST_MODE_B("SYNC")                  // String
    )
    xpm_memory_tdpram_in_mat
    (        
        // Port A module ports
        .clka(aclk),
        .rsta(~aresetn),
        .ena(in_mat_en),
        .wea(in_mat_wea),
        .addra(in_mat_addra), 
        .dina(s_axis_0_tdata),
        .douta(),
        
        // Port B module ports
        .clkb(aclk),
        .rstb(~aresetn),
        .enb(in_mat_en),
        .web(1'b0), 
        .addrb(in_mat_addrb), 
        .dinb(1'b0),
        .doutb(in_mat_doutb)
    );


    // ========================================= WEIGHT BRAM =========================================
    localparam MEMORY_SIZE_B = INNER_DIMENSION*B_OUTER_DIMENSION*WIDTH_B;
    localparam DATA_WIDTH_B  = WIDTH_B*CHUNK_SIZE*NUM_CORES_B;
    localparam int ADDR_WIDTH_B = $clog2(MEMORY_SIZE_B/DATA_WIDTH_B);

    logic we_mat_en;
    logic we_mat_wea;
    logic [ADDR_WIDTH_A-1:0] we_mat_addra, we_mat_addrb;
    logic [DATA_WIDTH_A-1:0] we_mat_doutb;

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
        .WRITE_DATA_WIDTH_A(DATA_WIDTH_B), // DECIMAL, varying based on the matrix size
        .READ_DATA_WIDTH_A(DATA_WIDTH_B),  // DECIMAL, varying based on the matrix size
        .BYTE_WRITE_WIDTH_A(DATA_WIDTH_B), // DECIMAL, how many bytes in WRITE_DATA_WIDTH_A, use $clog2 maybe?
        .ADDR_WIDTH_A(ADDR_WIDTH_B),         // DECIMAL, clog2(MEMORY_SIZE_A/WRITE_DATA_WIDTH_A)
        .READ_RESET_VALUE_A("0"),            // String
        .READ_LATENCY_A(1),                  // DECIMAL
        .WRITE_MODE_A("write_first"),        // String
        .RST_MODE_A("SYNC"),                 // String
        
        // Port B module parameters  
        .WRITE_DATA_WIDTH_B(DATA_WIDTH_B), // DECIMAL, varying based on the matrix size
        .READ_DATA_WIDTH_B(DATA_WIDTH_B),  // DECIMAL, varying based on the matrix size
        .BYTE_WRITE_WIDTH_B(DATA_WIDTH_B), // DECIMAL, how many bytes in WRITE_DATA_WIDTH_A
        .ADDR_WIDTH_B(ADDR_WIDTH_B),         // DECIMAL, clog2(MEMORY_SIZE/WRITE_DATA_WIDTH_A)
        .READ_RESET_VALUE_B("0"),            // String
        .READ_LATENCY_B(1),                  // DECIMAL
        .WRITE_MODE_B("write_first"),        // String
        .RST_MODE_B("SYNC")                  // String
    )
    xpm_memory_tdpram_we_mat
    (        
        // Port A module ports
        .clka(aclk),
        .rsta(~aresetn),
        .ena(we_mat_en),
        .wea(we_mat_wea),
        .addra(we_mat_addra), 
        .dina(s_axis_1_tdata),
        .douta(),
        
        // Port B module ports
        .clkb(aclk),
        .rstb(~aresetn),
        .enb(we_mat_en),
        .web(1'b0), 
        .addrb(we_mat_addrb), 
        .dinb(1'b0),
        .doutb(we_mat_doutb)
    );
  
endmodule
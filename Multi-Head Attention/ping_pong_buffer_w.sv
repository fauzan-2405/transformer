// ping_pong_buffer_w.sv
// Used to bridge linear projection results with Qn x KnT matmul in self-head attention (or other things)
// The input consists NUM_CORES_A * NUM_CORES_B * TOTAL_MODULES blocks
// This used as the WEST input

module ping_pong_buffer_w #(
    parameter WIDTH             = 16,
    parameter NUM_CORES_A       = 2,
    parameter NUM_CORES_B       = 1,
    parameter TOTAL_MODULES     = 4,
    parameter COL_X             = 16, // COL SIZE of matrix X (producer), we calculate it using C_COL_MAT_SIZE formula!!
    parameter TOTAL_INPUT_W     = 2,

    localparam CHUNK_SIZE       = top_pkg::TOP_CHUNK_SIZE,
    localparam BLOCK_SIZE       = top_pkg::TOP_BLOCK_SIZE,
    localparam MODULE_WIDTH     = WIDTH*CHUNK_SIZE*NUM_CORES_A*NUM_CORES_B,
    localparam IN_WIDTH         = MODULE_WIDTH * TOTAL_MODULES,
    localparam TOTAL_DEPTH      = COL_X * TOTAL_INPUT_W,
    localparam MEMORY_SIZE      = TOTAL_DEPTH * MODULE_WIDTH,
    localparam int ADDR_WIDTH   = $clog2(TOTAL_DEPTH)
) (
    input logic clk, rst_n,
    input logic [$clog2(TOTAL_MODULES)-1:0] slicing_idx,

    // Bank 0 Interface
    input logic                     bank0_ena, bank0_enb,
    input logic                     bank0_wea, bank0_web,
    input logic [ADDR_WIDTH-1:0]    bank0_addra, bank0_addrb,
    input logic [IN_WIDTH-1:0]      bank0_din [TOTAL_INPUT_W],
    output logic [MODULE_WIDTH-1:0] bank0_douta, bank0_doutb,


    // Bank 1 Interface
    input logic                     bank1_ena, bank1_enb,
    input logic                     bank1_wea, bank1_web,
    input logic [ADDR_WIDTH-1:0]    bank1_addra, bank1_addrb,
    input logic [IN_WIDTH-1:0]      bank1_din [TOTAL_INPUT_W],
    output logic [MODULE_WIDTH-1:0] bank1_douta, bank1_doutb
);
    // ************************************ Controller ************************************
    // MSB-first slicing function
    function automatic [MODULE_WIDTH-1:0] extract_module (
        input [IN_WIDTH-1:0] bus,
        input int idx
    );
        extract_module = bus[IN_WIDTH - (idx+1)*MODULE_WIDTH +: MODULE_WIDTH];
    endfunction

    // ************************************ BANK 0 ************************************
    xpm_memory_tdpram
    #(
        // Common module parameters
        .MEMORY_SIZE(MEMORY_SIZE),           // DECIMAL, 
        .MEMORY_PRIMITIVE("auto"),           // String
        .CLOCKING_MODE("common_clock"),      // String, "common_clock"
        .MEMORY_INIT_FILE(),                 // String
        .MEMORY_INIT_PARAM("0"),             // String      
        .USE_MEM_INIT(1),                    // DECIMAL
        
        // Port A module parameters
        .WRITE_DATA_WIDTH_A(MODULE_WIDTH), // DECIMAL, 
        .READ_DATA_WIDTH_A(MODULE_WIDTH),  // DECIMAL, 
        .BYTE_WRITE_WIDTH_A($clog2(MODULE_WIDTH)), // DECIMAL, how many bytes in WRITE_DATA_WIDTH_A, use $clog2 maybe?
        .ADDR_WIDTH_A(ADDR_WIDTH),         // DECIMAL, clog2(MEMORY_SIZE/WRITE_DATA_WIDTH_A)
        .READ_RESET_VALUE_A("0"),            // String
        .READ_LATENCY_A(1),                  // DECIMAL
        .WRITE_MODE_A("write_first"),        // String
        .RST_MODE_A("SYNC"),                 // String
        
        // Port B module parameters  
        .WRITE_DATA_WIDTH_B(MODULE_WIDTH), // DECIMAL, 
        .READ_DATA_WIDTH_B(MODULE_WIDTH),  // DECIMAL,
        .BYTE_WRITE_WIDTH_B($clog2(MODULE_WIDTH)), // DECIMAL
        .ADDR_WIDTH_BADDR_WIDTH(ADDR_WIDTH),         // DECIMAL, clog2(MEMORY_SIZE/WRITE_DATA_WIDTH_A)
        .READ_RESET_VALUE_B("0"),            // String
        .READ_LATENCY_B(1),                  // DECIMAL
        .WRITE_MODE_B("write_first"),        // String
        .RST_MODE_B("SYNC")                  // String
    )
    bank0_w
    (
        // Port A module ports
        .clka(clk),
        .rsta(~rst_n),
        .ena(bank0_ena), 
        .wea(bank0_wea),
        .addra(bank0_addra), 
        .dina(extract_module(bank0_din[0], slicing_idx)),
        .douta(bank0_douta),
        
        // Port B module ports
        .clkb(clk),
        .rstb(~rst_n),
        .enb(bank0_enb),
        .web(bank0_wea), 
        .addrb(bank0_addrb),
        .dinb(extract_module(bank0_din[1], slicing_idx)),
        .doutb(bank0_doutb) 
    );

    // ************************************ Bank 1 ************************************
    xpm_memory_tdpram
    #(
        // Common module parameters
        .MEMORY_SIZE(MEMORY_SIZE),           // DECIMAL, 
        .MEMORY_PRIMITIVE("auto"),           // String
        .CLOCKING_MODE("common_clock"),      // String, "common_clock"
        .MEMORY_INIT_FILE(),                 // String
        .MEMORY_INIT_PARAM("0"),             // String      
        .USE_MEM_INIT(1),                    // DECIMAL
        
        // Port A module parameters
        .WRITE_DATA_WIDTH_A(MODULE_WIDTH), // DECIMAL, data width: 64-bit
        .READ_DATA_WIDTH_A(MODULE_WIDTH),  // DECIMAL, data width: 64-bit
        .BYTE_WRITE_WIDTH_A($clog2(MODULE_WIDTH)), // DECIMAL, how many bytes in WRITE_DATA_WIDTH_A, use $clog2 maybe?
        .ADDR_WIDTH_A(ADDR_WIDTH),         // DECIMAL, clog2(MEMORY_SIZE/WRITE_DATA_WIDTH_A)
        .READ_RESET_VALUE_A("0"),            // String
        .READ_LATENCY_A(1),                  // DECIMAL
        .WRITE_MODE_A("write_first"),        // String
        .RST_MODE_A("SYNC"),                 // String
        
        // Port B module parameters  
        .WRITE_DATA_WIDTH_B(MODULE_WIDTH), // DECIMAL, data width: 64-bit
        .READ_DATA_WIDTH_B(MODULE_WIDTH),  // DECIMAL, data width: 64-bit
        .BYTE_WRITE_WIDTH_B($clog2(MODULE_WIDTH)), // DECIMAL
        .ADDR_WIDTH_BADDR_WIDTH(),         // DECIMAL, clog2(MEMORY_SIZE/WRITE_DATA_WIDTH_A)
        .READ_RESET_VALUE_B("0"),            // String
        .READ_LATENCY_B(1),                  // DECIMAL
        .WRITE_MODE_B("write_first"),        // String
        .RST_MODE_B("SYNC")                  // String
    )
    bank1_w
    (
        // Port A module ports
        .clka(clk),
        .rsta(~rst_n),
        .ena(bank1_ena), 
        .wea(bank1_wea),
        .addra(bank1_addra), 
        .dina(extract_module(bank1_din[0], slicing_idx)),
        .douta(bank1_douta),
        
        // Port B module ports
        .clkb(clk),
        .rstb(~rst_n),
        .enb(bank1_enb),
        .web(bank1_web), 
        .addrb(bank1_addrb),
        .dinb(extract_module(bank1_din[1], slicing_idx)),
        .doutb(bank1_doutb) 
    );



endmodule
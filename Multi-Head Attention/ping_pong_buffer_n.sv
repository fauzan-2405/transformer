// ping_pong_buffer_n.sv
// Used to bridge linear projection results with Qn x KnT matmul in self-head attention (or other things)
// The input consists NUM_CORES_A * NUM_CORES_B * TOTAL_MODULES blocks
// This used as the NORTH input

module ping_pong_buffer_n #(
    parameter WIDTH             = 16,
    parameter NUM_CORES_A       = 2, // DO NOT FORGET to swap NUM_CORES_A with NUM_CORES_B (TOTAL_MODULES) in this
    parameter TOTAL_MODULES     = 1, // buffer because this is used to transpose the matrix
    parameter NUM_CORES_B       = 4,
    parameter COL_X             = 16, // COL SIZE of matrix X (producer), we calculate it using C_COL_MAT_SIZE formula!!
    parameter COL_Y             = 16, // COL SIZE of matrix y (consumer) 
    parameter TOTAL_INPUT_W     = 2,

    localparam CHUNK_SIZE       = top_pkg::TOP_CHUNK_SIZE,
    localparam BLOCK_SIZE       = top_pkg::TOP_BLOCK_SIZE,
    localparam SLICE_WIDTH      = WIDTH*CHUNK_SIZE*NUM_CORES_B,
    localparam MODULE_WIDTH     = SLICE_WIDTH*TOTAL_INPUT_W,
    localparam IN_WIDTH         = WIDTH*CHUNK_SIZE*TOTAL_MODULES*NUM_CORES_A,
    localparam TOTAL_DEPTH      = COL_X * TOTAL_INPUT_W,    // ************** PLEASE REVISE THIS **************
    localparam MEMORY_SIZE      = TOTAL_DEPTH * MODULE_WIDTH,
    localparam int ADDR_WIDTH   = $clog2(TOTAL_DEPTH)
) (
    input logic clk, rst_n,
    input logic [$clog2(TOTAL_MODULES)-1:0] slicing_idx; 

    // Bank 0 Interface
    input logic                     bank0_ena, bank0_enb,
    input logic                     bank0_wea, bank0_web,
    input logic [ADDR_WIDTH-1:0]    bank0_addra, bank0_addrb,
    input logic [IN_WIDTH-1:0]      bank0_din [TOTAL_INPUT_W],

    // Bank 1 Interface
    input logic                     bank1_ena, bank1_enb,
    input logic                     bank1_web, bank1_web,
    input logic [ADDR_WIDTH-1:0]    bank1_addra, bank1_addrb,
    input logic [IN_WIDTH-1:0]      bank1_din [TOTAL_INPUT_W],

    // Debug
    output logic                active_bank_wr,
    output logic                active_bank_rd
);
    // ************************************ Controller ************************************
    // MSB-first slicing function
    function automatic [MODULE_WIDTH-1:0] extract_module (
        input logic [IN_WIDTH-1:0] bus [TOTAL_INPUT_W],
        input int idx
    );
        logic [MODULE_WIDTH-1:0] tmp;
        int pos = MODULE_WIDTH;

        for (int b = 0; b < TOTAL_INPUT_W; b++) begin
            pos -= SLICE_WIDTH;
            tmp[pos +: SLICE_WIDTH] =
                bus[b][IN_WIDTH - (idx+1)*SLICE_WIDTH +: SLICE_WIDTH];
        end

        extract_module = tmp;
    endfunction


    // ************************************ Write BRAM ************************************
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
    bank_0
    (
        // Port A module ports
        .clka(clk),
        .rsta(~rst_n),
        .ena(bank0_ena), 
        .wea(),
        .addra(), 
        .dina(extract_module(wr_data[0], slicing_idx)),
        .douta(),
        
        // Port B module ports
        .clkb(clk),
        .rstb(~rst_n),
        .enb(),
        .web('0), 
        .addrb(),
        .dinb(extract_module(wr_data[1], slicing_idx)),
        .doutb() // For now, we only use port B to read
    );

    // ************************************ Read BRAM ************************************
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
    xpm_memory_tdpram_inst
    (
        // Port A module ports
        .clka(clk),
        .rsta(~rst_n),
        .ena(1'b0), 
        .wea(),
        .addra(), 
        .dina(),
        .douta(),
        
        // Port B module ports
        .clkb(clk),
        .rstb(~rst_n),
        .enb(),
        .web('0), 
        .addrb(),
        .dinb(),
        .doutb() // For now, we only use port B to read
    );



endmodule
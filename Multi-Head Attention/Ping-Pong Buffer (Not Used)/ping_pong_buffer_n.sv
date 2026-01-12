// ping_pong_buffer_n.sv
// Used to bridge linear projection results with Qn x KnT matmul in self-head attention (or other things)
// The input consists NUM_CORES_A * NUM_CORES_B * TOTAL_MODULES blocks
// This used as the NORTH input
// TO DO change the TDPRAM into SPRAM

module ping_pong_buffer_n #(
    parameter WIDTH             = 16,
    parameter NUM_CORES_A       = 2, // DO NOT FORGET to swap NUM_CORES_A with NUM_CORES_B (TOTAL_MODULES) in this
    parameter TOTAL_MODULES     = 3, // buffer because this is used to transpose the matrix
    parameter NUM_CORES_B       = 1,
    parameter COL_X             = 16, // COL SIZE of matrix X (producer), we calculate it using C_COL_MAT_SIZE formula!!
    parameter TOTAL_INPUT_W     = 2,

    localparam CHUNK_SIZE       = top_pkg::TOP_CHUNK_SIZE,
    localparam BLOCK_SIZE       = top_pkg::TOP_BLOCK_SIZE,
    parameter SLICE_WIDTH      = WIDTH*CHUNK_SIZE*NUM_CORES_B,
    parameter MODULE_WIDTH     = SLICE_WIDTH*TOTAL_INPUT_W,
    parameter IN_WIDTH         = N_SLICE_WIDTH * N_NUM_CORES_A * N_TOTAL_MODULES,
    parameter TOTAL_DEPTH      = COL_X,    // ************** PLEASE REVISE THIS **************
    parameter MEMORY_SIZE      = TOTAL_DEPTH * MODULE_WIDTH,
    parameter int ADDR_WIDTH   = $clog2(TOTAL_DEPTH)
) (
    input logic clk, rst_n,
    input logic [$clog2(TOTAL_MODULES)-1:0] slicing_idx,

    // Bank 0 Interface
    input logic                     bank0_ena,
    input logic                     bank0_wea,
    input logic [ADDR_WIDTH-1:0]    bank0_addra,
    input logic [IN_WIDTH-1:0]      bank0_din [TOTAL_INPUT_W],
    output logic [MODULE_WIDTH-1:0] bank0_dout,

    // Bank 1 Interface
    input logic                     bank1_ena,
    input logic                     bank1_wea,
    input logic [ADDR_WIDTH-1:0]    bank1_addra,
    input logic [IN_WIDTH-1:0]      bank1_din [TOTAL_INPUT_W],
    output logic [MODULE_WIDTH-1:0] bank1_dout
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


    // ************************************ BANK 0 ************************************
    xpm_memory_spram
    #(
        .MEMORY_SIZE(MEMORY_SIZE),
        .MEMORY_PRIMITIVE("auto"),
        .MEMORY_INIT_FILE(),
        .MEMORY_INIT_PARAM("0"),
        .USE_MEM_INIT(1),

        .WRITE_DATA_WIDTH_A(MODULE_WIDTH),
        .READ_DATA_WIDTH_A(MODULE_WIDTH),
        .BYTE_WRITE_WIDTH_A(MODULE_WIDTH),
        .ADDR_WIDTH_A(ADDR_WIDTH),

        .READ_LATENCY_A(1),
        .WRITE_MODE_A("write_first"),
        .READ_RESET_VALUE_A("0"),
        .RST_MODE_A("SYNC")
    )
    bank0_n
    (
        .clka(clk),
        .rsta(~rst_n),

        .ena(bank0_ena),
        .wea(bank0_wea),
        .addra(bank0_addra),

        .dina(extract_module(bank0_din, slicing_idx)),
        .douta(bank0_dout)
    );


    // ************************************ BANK 1 ************************************
    xpm_memory_spram
    #(
        .MEMORY_SIZE(MEMORY_SIZE),
        .MEMORY_PRIMITIVE("auto"),
        .MEMORY_INIT_FILE(),
        .MEMORY_INIT_PARAM("0"),
        .USE_MEM_INIT(1),

        .WRITE_DATA_WIDTH_A(MODULE_WIDTH),
        .READ_DATA_WIDTH_A(MODULE_WIDTH),
        .BYTE_WRITE_WIDTH_A(MODULE_WIDTH),
        .ADDR_WIDTH_A(ADDR_WIDTH),

        .READ_LATENCY_A(1),
        .WRITE_MODE_A("write_first"),
        .READ_RESET_VALUE_A("0"),
        .RST_MODE_A("SYNC")
    )
    bank1_n
    (
        .clka(clk),
        .rsta(~rst_n),

        .ena(bank1_ena),
        .wea(bank1_wea),          
        .addra(bank1_addra),

        .dina(extract_module(bank1_din, slicing_idx)),
        .douta(bank1_dout)
    );

endmodule
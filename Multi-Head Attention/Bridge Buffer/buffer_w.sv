// buffer_w.sv
// Used to bridge linear projection results with Qn x KnT matmul in self-head attention (or other things)
// The input consists NUM_CORES_A * NUM_CORES_B * TOTAL_MODULES blocks
// This used as the WEST input

module buffer_w #(
    parameter WIDTH             = 16,
    parameter NUM_CORES_A       = 2,
    parameter NUM_CORES_B       = 1,
    parameter TOTAL_MODULES     = 4,
    parameter ROW_X             = 10,
    parameter COL_X             = 16, 
    parameter TOTAL_INPUT_W     = 2,

    localparam CHUNK_SIZE       = top_pkg::TOP_CHUNK_SIZE,
    localparam BLOCK_SIZE       = top_pkg::TOP_BLOCK_SIZE,
    parameter SLICE_WIDTH      = WIDTH*CHUNK_SIZE*NUM_CORES_A,
    parameter MODULE_WIDTH     = SLICE_WIDTH*TOTAL_INPUT_W,
    parameter IN_WIDTH         = SLICE_WIDTH * NUM_CORES_B * TOTAL_MODULES,
    parameter TOTAL_DEPTH      = ROW_X * COL_X,     // Can be reduced even further
    parameter MEMORY_SIZE      = TOTAL_DEPTH * MODULE_WIDTH,
    parameter int ADDR_WIDTH   = $clog2(TOTAL_DEPTH)
) (
    input logic clk, rst_n,
    input logic [$clog2(TOTAL_MODULES)-1:0] slicing_idx,

    // Bank 0 Interface
    input logic                     bank0_ena,
    input logic                     bank0_enb,
    input logic                     bank0_wea,
    input logic [ADDR_WIDTH-1:0]    bank0_addra,
    input logic [ADDR_WIDTH-1:0]    bank0_addrb,
    input logic [IN_WIDTH-1:0]      bank0_din [TOTAL_INPUT_W],
    output logic [MODULE_WIDTH-1:0] bank0_dout
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
    xpm_memory_tdpram #(
        .MEMORY_SIZE            (MEMORY_SIZE),
        .MEMORY_PRIMITIVE       ("auto"),
        .MEMORY_INIT_FILE       (),
        .MEMORY_INIT_PARAM      ("0"),
        .USE_MEM_INIT           (1),

        // Port A (WRITE)
        .WRITE_DATA_WIDTH_A     (MODULE_WIDTH),
        .READ_DATA_WIDTH_A      (MODULE_WIDTH),
        .BYTE_WRITE_WIDTH_A     (MODULE_WIDTH),
        .ADDR_WIDTH_A           (ADDR_WIDTH),

        // Port B (READ)
        .WRITE_DATA_WIDTH_B     (MODULE_WIDTH),
        .READ_DATA_WIDTH_B      (MODULE_WIDTH),
        .BYTE_WRITE_WIDTH_B     (MODULE_WIDTH),
        .ADDR_WIDTH_B           (ADDR_WIDTH),

        .READ_LATENCY_A         (1),
        .READ_LATENCY_B         (1),

        .WRITE_MODE_A           ("write_first"),
        .WRITE_MODE_B           ("read_first"),

        .READ_RESET_VALUE_A     ("0"),
        .READ_RESET_VALUE_B     ("0"),

        .RST_MODE_A             ("SYNC"),
        .RST_MODE_B             ("SYNC")
    ) bank0_n
    (
        // -------- Port A : Write --------
        .clka   (clk),
        .rsta   (~rst_n),
        .ena    (bank0_ena),
        .wea    (bank0_wea),
        .addra  (bank0_addra),
        .dina   (extract_module(bank0_din, slicing_idx)),
        .douta  (),

        // -------- Port B : Read --------
        .clkb   (clk),
        .rstb   (~rst_n),
        .enb    (bank0_enb),
        .web    (1'b0),
        .addrb  (bank0_addrb),
        .dinb   ('0),
        .doutb  (bank0_dout)
    );



endmodule
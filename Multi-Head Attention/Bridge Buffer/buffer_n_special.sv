// buffer_n_special.sv
// Special NORTH buffer with intra-block swap (BLOCK_SIZE=2)
// Same structure as buffer_n, but different extraction logic
// Used to contains Vn matrix before multiplicated by QKT

module buffer_n_special #(
    parameter WIDTH             = 16,
    parameter NUM_CORES_A       = 2,
    parameter NUM_CORES_B       = 1,
    parameter COL_X             = 10,
    parameter ROW_X             = 16,
    parameter TOTAL_INPUT_W     = 2,

    localparam CHUNK_SIZE       = top_pkg::TOP_CHUNK_SIZE, // should be 4
    localparam BLOCK_SIZE       = top_pkg::TOP_BLOCK_SIZE, // should be 2

    parameter SLICE_WIDTH       = WIDTH * CHUNK_SIZE,
    parameter IN_WIDTH          = SLICE_WIDTH * NUM_CORES_A * NUM_CORES_B,
    parameter MODULE_WIDTH      = WIDTH * CHUNK_SIZE * NUM_CORES_B,

    parameter TOTAL_DEPTH       = ROW_X * COL_X,                        
    parameter MEMORY_SIZE       = TOTAL_DEPTH * MODULE_WIDTH,
    parameter int ADDR_WIDTH    = $clog2(TOTAL_DEPTH)
)(
    input logic clk, rst_n,
    input logic [$clog2(NUM_CORES_A):0] slicing_idx,

    // Bank a Interface
    input logic                     bank0_ena,
    input logic                     bank0_wea,
    input logic [ADDR_WIDTH-1:0]    bank0_addra,

    input logic                     bank0_enb,
    input logic                     bank0_web,
    input logic [ADDR_WIDTH-1:0]    bank0_addrb,

    input logic [IN_WIDTH-1:0]      bank0_din [TOTAL_INPUT_W],
    output logic [MODULE_WIDTH-1:0] bank0_dout
);

    // ============================================================
    // Special Extraction Function
    // ============================================================

    function automatic [MODULE_WIDTH-1:0] extract_module_special (
        input logic [IN_WIDTH-1:0] bus,
        input int core_a_idx
    );
        logic [MODULE_WIDTH-1:0] tmp;
        logic [WIDTH-1:0] e0, e1, e2, e3;

        int out_offset;
        out_offset = 0;

        for (int b = 0; b < NUM_CORES_B; b++) begin

            int base_idx;
            base_idx = (b * NUM_CORES_A + core_a_idx) * CHUNK_SIZE * WIDTH;

            e0 = bus[base_idx + 0*WIDTH +: WIDTH];
            e1 = bus[base_idx + 1*WIDTH +: WIDTH];
            e2 = bus[base_idx + 2*WIDTH +: WIDTH];
            e3 = bus[base_idx + 3*WIDTH +: WIDTH];

            // swap (1 <-> 2)
            tmp[out_offset + 0*WIDTH +: WIDTH] = e0;
            tmp[out_offset + 1*WIDTH +: WIDTH] = e2;
            tmp[out_offset + 2*WIDTH +: WIDTH] = e1;
            tmp[out_offset + 3*WIDTH +: WIDTH] = e3;

            out_offset += CHUNK_SIZE * WIDTH;
        end

        return tmp;
    endfunction


    // ============================================================
    // BANK 0 (TDPRAM)
    // ============================================================

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
    ) bank0_n (
        // -------- Port A --------
        .clka   (clk),
        .rsta   (~rst_n),
        .ena    (bank0_ena),
        .wea    (bank0_wea),
        .addra  (bank0_addra),
        .dina   (extract_module_special(bank0_din[0], slicing_idx)),
        .douta  (),

        // -------- Port B --------
        .clkb   (clk),
        .rstb   (~rst_n),
        .enb    (bank0_enb),
        .web    (bank0_web),
        .addrb  (bank0_addrb),
        .dinb   (extract_module_special(bank0_din[1], slicing_idx)),
        .doutb  (bank0_dout)
    );

endmodule
// north_buffer.sv
// NORTH buffer for Kn^T (weight-stationary)
// - Entire matrix stored
// - Written once, read many times

module north_buffer #(
    parameter WIDTH             = 16,
    parameter NUM_CORES_A       = 2,
    parameter TOTAL_MODULES     = 3,
    parameter NUM_CORES_B       = 1,
    parameter COL_X             = 16,
    parameter TOTAL_INPUT_W     = 2,

    localparam CHUNK_SIZE       = top_pkg::TOP_CHUNK_SIZE,
    localparam BLOCK_SIZE       = top_pkg::TOP_BLOCK_SIZE,

    parameter SLICE_WIDTH       = WIDTH * CHUNK_SIZE * NUM_CORES_B,
    parameter MODULE_WIDTH      = SLICE_WIDTH * TOTAL_INPUT_W,
    parameter IN_WIDTH          = SLICE_WIDTH * NUM_CORES_A * TOTAL_MODULES,
    parameter TOTAL_DEPTH       = COL_X,
    parameter MEMORY_SIZE       = TOTAL_DEPTH * MODULE_WIDTH,
    parameter int ADDR_WIDTH    = $clog2(TOTAL_DEPTH)
) (
    input  logic clk,
    input  logic rst_n,
    input  logic [$clog2(TOTAL_MODULES)-1:0] n_slicing_idx,

    // =========================
    // WRITE PORT (LP → NORTH)
    // =========================
    input  logic                  n_wr_en,
    input  logic [ADDR_WIDTH-1:0] n_wr_addr,
    input  logic [IN_WIDTH-1:0]   n_wr_din [TOTAL_INPUT_W],

    // =========================
    // READ PORT (SA ← NORTH)
    // =========================
    input  logic                  n_rd_en,
    input  logic [ADDR_WIDTH-1:0] n_rd_addr,
    output logic [MODULE_WIDTH-1:0] n_rd_dout
);

    // ------------------------------------------------------------------
    // Slice extractor (MSB-first, correct for Kn^T)
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

    // ------------------------------------------------------------------
    // True Dual-Port RAM (NORTH)
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
    ) north_tdpram (
        // -------- Port A : Write --------
        .clka   (clk),
        .rsta   (~rst_n),
        .ena    (n_wr_en),
        .wea    (n_wr_en),
        .addra  (n_wr_addr),
        .dina   (extract_module(n_wr_din, n_slicing_idx)),
        .douta  (),

        // -------- Port B : Read --------
        .clkb   (clk),
        .rstb   (~rst_n),
        .enb    (n_rd_en),
        .web    (1'b0),
        .addrb  (n_rd_addr),
        .dinb   ('0),
        .doutb  (n_rd_dout)
    );

endmodule

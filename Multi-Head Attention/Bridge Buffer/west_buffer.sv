// west_buffer.sv
// WEST buffer for Qn (weight-stationary compatible)
// Supports simultaneous write (LP) + read (SA)

module west_buffer #(
    parameter WIDTH             = 16,
    parameter NUM_CORES_A       = 2,
    parameter NUM_CORES_B       = 1,
    parameter TOTAL_MODULES     = 4,
    parameter COL_X             = 16,
    parameter TOTAL_INPUT_W     = 2,

    localparam CHUNK_SIZE       = top_pkg::TOP_CHUNK_SIZE,
    localparam BLOCK_SIZE       = top_pkg::TOP_BLOCK_SIZE,

    localparam MODULE_WIDTH     = WIDTH * CHUNK_SIZE * NUM_CORES_A * NUM_CORES_B,
    localparam IN_WIDTH         = MODULE_WIDTH * TOTAL_MODULES,
    localparam TOTAL_DEPTH      = COL_X * TOTAL_INPUT_W,
    localparam MEMORY_SIZE      = TOTAL_DEPTH * MODULE_WIDTH,
    localparam int ADDR_WIDTH   = $clog2(TOTAL_DEPTH)
) (
    input  logic clk,
    input  logic rst_n,
    input  logic [$clog2(TOTAL_MODULES)-1:0] w_slicing_idx,

    // =========================
    // WEST BANK (TDPRAM)
    // =========================
    input  logic                     w_ena,
    input  logic                     w_enb,
    input  logic                     w_wea,
    input  logic                     w_web,
    input  logic [ADDR_WIDTH-1:0]    w_addra,
    input  logic [ADDR_WIDTH-1:0]    w_addrb,
    input  logic [IN_WIDTH-1:0]      w_din [TOTAL_INPUT_W],
    output logic [MODULE_WIDTH-1:0]  w_douta,
    output logic [MODULE_WIDTH-1:0]  w_doutb
);

    // ------------------------------------------------------------------
    // Slice extractor (MSB-first, TOTAL_INPUT_W aware)
    function automatic [MODULE_WIDTH-1:0] extract_module (
        input logic [IN_WIDTH-1:0] bus [TOTAL_INPUT_W],
        input int idx
    );
        logic [MODULE_WIDTH-1:0] tmp;
        int pos;

        pos = MODULE_WIDTH;
        for (int w = 0; w < TOTAL_INPUT_W; w++) begin
            pos -= MODULE_WIDTH / TOTAL_INPUT_W;
            tmp[pos +: (MODULE_WIDTH / TOTAL_INPUT_W)] =
                bus[w][IN_WIDTH - (idx+1)*(MODULE_WIDTH / TOTAL_INPUT_W) +:
                       (MODULE_WIDTH / TOTAL_INPUT_W)];
        end

        extract_module = tmp;
    endfunction

    // ------------------------------------------------------------------
    // True Dual-Port RAM (WEST)
    xpm_memory_tdpram #(
        .MEMORY_SIZE           (MEMORY_SIZE),
        .MEMORY_PRIMITIVE      ("auto"),
        .CLOCKING_MODE         ("common_clock"),
        .MEMORY_INIT_FILE      (),
        .MEMORY_INIT_PARAM     ("0"),
        .USE_MEM_INIT          (1),

        // Port A
        .WRITE_DATA_WIDTH_A    (MODULE_WIDTH),
        .READ_DATA_WIDTH_A     (MODULE_WIDTH),
        .BYTE_WRITE_WIDTH_A    (MODULE_WIDTH),
        .ADDR_WIDTH_A          (ADDR_WIDTH),
        .READ_LATENCY_A        (1),
        .WRITE_MODE_A          ("write_first"),
        .READ_RESET_VALUE_A    ("0"),
        .RST_MODE_A            ("SYNC"),

        // Port B
        .WRITE_DATA_WIDTH_B    (MODULE_WIDTH),
        .READ_DATA_WIDTH_B     (MODULE_WIDTH),
        .BYTE_WRITE_WIDTH_B    (MODULE_WIDTH),
        .ADDR_WIDTH_B          (ADDR_WIDTH),
        .READ_LATENCY_B        (1),
        .WRITE_MODE_B          ("write_first"),
        .READ_RESET_VALUE_B    ("0"),
        .RST_MODE_B            ("SYNC")
    ) west_tdpram (
        // -------- Port A --------
        .clka   (clk),
        .rsta   (~rst_n),
        .ena    (w_ena),
        .wea    (w_wea),
        .addra  (w_addra),
        .dina   (extract_module(w_din, w_slicing_idx)),
        .douta  (w_douta),

        // -------- Port B --------
        .clkb   (clk),
        .rstb   (~rst_n),
        .enb    (w_enb),
        .web    (w_web),
        .addrb  (w_addrb),
        .dinb   (extract_module(w_din, w_slicing_idx)),
        .doutb  (w_doutb)
    );

endmodule

// -------------------------------------------------------------
// Ping-Pong BRAM Buffer
// Stores output of (X × W) before feeding into next matmul stage
// Supports:
//   * TOTAL_INPUT_W parallel inputs (usually 2)
//   * TOTAL_MODULES slices per input (MSB-first)
//   * True Dual Port BRAM writes (Input0 on PortA, Input1 on PortB)
//   * Ping-pong double-buffering to avoid overflow
// -------------------------------------------------------------

module ping_pong_bram_buffer #(
    parameter WIDTH              = 16,
    parameter CHUNK_SIZE         = 4,
    parameter NUM_CORES_A        = 2,
    parameter NUM_CORES_B        = 1,
    parameter TOTAL_MODULES      = 4,
    parameter TOTAL_INPUT_W      = 2,       // usually 2
    parameter COL_X              = 256,     // number of columns of the X output

    // derived
    parameter MODULE_WIDTH       = WIDTH * CHUNK_SIZE * NUM_CORES_A * NUM_CORES_B,
    parameter IN_WIDTH           = MODULE_WIDTH * TOTAL_MODULES,
    parameter TOTAL_ADDR         = COL_X * TOTAL_INPUT_W  // full addr space per bank
) (
    input  logic                       clk,
    input  logic                       rst_n,

    // Input valid from top_linear_projection
    input  logic                       wr_valid,
    input  logic [IN_WIDTH-1:0]        wr_data [TOTAL_INPUT_W],

    // Output interface for next matmul
    input  logic                       rd_en,
    input  logic [$clog2(TOTAL_ADDR)-1:0] rd_addr,
    output logic [MODULE_WIDTH-1:0]    rd_data,

    // Status
    output logic                       bank0_valid,
    output logic                       bank1_valid,
    output logic                       active_bank  // bank currently being written
);

    // ---------------------------------------------------------
    // Internal registers
    // ---------------------------------------------------------
    logic [0:0] curr_bank;   // 0 or 1
    logic [$clog2(COL_X)-1:0] wr_idx;

    assign active_bank = curr_bank;

    // Valid flags
    logic bank_valid [1:0];

    assign bank0_valid = bank_valid[0];
    assign bank1_valid = bank_valid[1];

    // ---------------------------------------------------------
    // BRAM Declaration (Ping-Pong: 2 banks)
    // We pack both banks into a single large TDPRAM instance:
    //   addr[MSB] selects bank (0 or 1)
    //   addr[LSBs] index inside bank
    // ---------------------------------------------------------

    localparam ADDR_BITS = $clog2(TOTAL_ADDR);
    localparam BANK_ADDR_BITS = $clog2(TOTAL_ADDR);

    // Single TDPRAM with 2×TOTAL_ADDR rows:
    // addr = {bank_bit, internal_addr}
    localparam TOTAL_DEPTH = 2 * TOTAL_ADDR;

    logic [MODULE_WIDTH-1:0] bram_dout_a, bram_dout_b;

    // ---------------------------------------------------------
    // Combine addresses
    // ---------------------------------------------------------
    logic [$clog2(TOTAL_DEPTH)-1:0] portA_addr, portB_addr, portRd_addr;

    // Write address calculation:
    //   Input 0 → address = wr_idx
    //   Input 1 → address = wr_idx + COL_X
    logic [$clog2(TOTAL_ADDR)-1:0] wr_addr_in0;
    logic [$clog2(TOTAL_ADDR)-1:0] wr_addr_in1;

    assign wr_addr_in0 = wr_idx;
    assign wr_addr_in1 = wr_idx + COL_X;

    assign portA_addr = {curr_bank, wr_addr_in0};
    assign portB_addr = {curr_bank, wr_addr_in1};
    assign portRd_addr = {~curr_bank, rd_addr};  
    // downstream always reads the *other* bank

    // ---------------------------------------------------------
    // BRAM Instance
    // True Dual Port, 2×TOTAL_ADDR deep
    // ---------------------------------------------------------

    xpm_memory_tdpram #(
        .ADDR_WIDTH_A($clog2(TOTAL_DEPTH)),
        .ADDR_WIDTH_B($clog2(TOTAL_DEPTH)),
        .READ_DATA_WIDTH_A(MODULE_WIDTH),
        .WRITE_DATA_WIDTH_A(MODULE_WIDTH),
        .READ_DATA_WIDTH_B(MODULE_WIDTH),
        .WRITE_DATA_WIDTH_B(MODULE_WIDTH),
        .BYTE_WRITE_WIDTH_A(MODULE_WIDTH),
        .BYTE_WRITE_WIDTH_B(MODULE_WIDTH),
        .MEMORY_SIZE(TOTAL_DEPTH * MODULE_WIDTH),
        .MEMORY_INIT_FILE("none"),
        .MEMORY_INIT_PARAM("0"),
        .READ_LATENCY_A(1),
        .READ_LATENCY_B(1),
        .CLOCKING_MODE("common_clock"),
        .WRITE_MODE_A("write_first"),
        .WRITE_MODE_B("write_first")
    ) bram_pingpong (
        .clka(clk),
        .clkb(clk),
        .rsta(~rst_n),
        .rstb(~rst_n),

        // Write Input 0 → Port A
        .ena(wr_valid),
        .wea(wr_valid),
        .addra(portA_addr),
        .dina(extract_module(wr_data[0], META_IDX)),
        .douta(bram_dout_a),

        // Write Input 1 → Port B
        .enb(wr_valid),
        .web(wr_valid),
        .addrb(portB_addr),
        .dinb(extract_module(wr_data[1], META_IDX)),
        .doutb(bram_dout_b)
    );

    // ---------------------------------------------------------
    // MSB-first slicing function
    // ---------------------------------------------------------
    function automatic [MODULE_WIDTH-1:0] extract_module (
        input [IN_WIDTH-1:0] bus,
        input int idx
    );
        extract_module = bus[IN_WIDTH - (idx+1)*MODULE_WIDTH +: MODULE_WIDTH];
    endfunction

    // ---------------------------------------------------------
    // Write index and bank switching logic
    // ---------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            curr_bank     <= 0;
            wr_idx        <= 0;
            bank_valid[0] <= 0;
            bank_valid[1] <= 0;
        end else begin
            if (wr_valid) begin
                if (wr_idx == COL_X-1) begin
                    // Mark bank as valid
                    bank_valid[curr_bank] <= 1'b1;

                    // Switch bank
                    curr_bank <= ~curr_bank;

                    // Clear next bank valid flag (it will be rewritten)
                    bank_valid[~curr_bank] <= 1'b0;

                    wr_idx <= 0;
                end else begin
                    wr_idx <= wr_idx + 1;
                end
            end
        end
    end

    // ---------------------------------------------------------
    // Output read data (Port A or B? We choose B)
    // ---------------------------------------------------------
    assign rd_data = bram_dout_b;

endmodule

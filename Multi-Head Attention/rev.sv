// ======================================================================
//  ping_pong_bram_buffer.sv
//  BRAM-based ping-pong buffer for streaming multi-module matmul outputs
//
//  - INPUT FORMAT:
//      wr_data[TOTAL_INPUT_W] each packed as:
//          { module[TOTAL_MODULES-1], ..., module[0] }
//
//  - STORED IN BRAM AS:
//      input_index 0 →   addr 0            ... COL_X-1
//      input_index 1 →   addr COL_X        ... 2*COL_X-1
//
//  - Each BRAM entry stores one module result:
//        MODULE_WIDTH = WIDTH*CHUNK_SIZE*NUM_CORES_A*NUM_CORES_B
//
// ======================================================================

module ping_pong_bram_buffer #(
    parameter WIDTH             = 16,
    parameter CHUNK_SIZE        = 4,
    parameter NUM_CORES_A       = 2,
    parameter NUM_CORES_B       = 1,
    parameter TOTAL_MODULES     = 4,
    parameter TOTAL_INPUT_W     = 2,

    // From your confirmation:
    // COL_X == COL_SIZE_MAT_C (number of writes per input matrix)
    parameter COL_X             = 32,  

    localparam MODULE_WIDTH     = WIDTH * CHUNK_SIZE * NUM_CORES_A * NUM_CORES_B,
    localparam IN_WIDTH         = MODULE_WIDTH * TOTAL_MODULES,
    localparam TOTAL_DEPTH      = COL_X * TOTAL_INPUT_W
)(
    input  logic clk,
    input  logic rst_n,

    // ---------------- WR side ----------------
    input  logic                 wr_valid,
    input  logic [IN_WIDTH-1:0]  wr_data [TOTAL_INPUT_W],
    output logic                 wr_ready,

    // ---------------- RD side ----------------
    input  logic                 rd_ready,
    output logic                 rd_valid,
    output logic [MODULE_WIDTH-1:0] rd_data,
    output logic [$clog2(TOTAL_DEPTH)-1:0] rd_addr
);

    // ------------------------------------------------------------------
    //  Ping-pong state
    // ------------------------------------------------------------------
    logic ping_is_write;
    logic [$clog2(TOTAL_DEPTH)-1:0] wr_addr;
    logic [$clog2(TOTAL_DEPTH)-1:0] rd_addr_int;

    assign rd_addr = rd_addr_int;

    // ==================================================================
    //  Generate two BRAMs: BRAM0 and BRAM1
    // ==================================================================
    logic [MODULE_WIDTH-1:0] dout0, dout1;

    // BRAM 0
    xpm_memory_sdpram #(
        .ADDR_WIDTH_A  ($clog2(TOTAL_DEPTH)),
        .ADDR_WIDTH_B  ($clog2(TOTAL_DEPTH)),
        .READ_DATA_WIDTH_B(MODULE_WIDTH),
        .WRITE_DATA_WIDTH_A(MODULE_WIDTH),
        .MEMORY_SIZE(TOTAL_DEPTH * MODULE_WIDTH),
        .WRITE_MODE_B("no_change")
    ) bram0 (
        .clka(clk), .addra(wr_addr), .dina(/* filled below */), .wea(/* filled below */),
        .clkb(clk), .addrb(rd_addr_int), .doutb(dout0),
        .ena(1), .enb(1)
    );

    // BRAM 1
    xpm_memory_sdpram #(
        .ADDR_WIDTH_A  ($clog2(TOTAL_DEPTH)),
        .ADDR_WIDTH_B  ($clog2(TOTAL_DEPTH)),
        .READ_DATA_WIDTH_B(MODULE_WIDTH),
        .WRITE_DATA_WIDTH_A(MODULE_WIDTH),
        .MEMORY_SIZE(TOTAL_DEPTH * MODULE_WIDTH),
        .WRITE_MODE_B("no_change")
    ) bram1 (
        .clka(clk), .addra(wr_addr), .dina(/* filled below */), .wea(/* filled below */),
        .clkb(clk), .addrb(rd_addr_int), .doutb(dout1),
        .ena(1), .enb(1)
    );

    // ------------------------------------------------------------------
    //  Select which BRAM is write / read
    // ------------------------------------------------------------------
    wire writing_to_bram0 =  ping_is_write;
    wire writing_to_bram1 = ~ping_is_write;

    logic bram_we;
    logic [MODULE_WIDTH-1:0] bram_din;

    assign bram_we = wr_valid && wr_ready;

    // Pick correct BRAM input
    assign bram0.wea  = writing_to_bram0 ? bram_we : 1'b0;
    assign bram1.wea  = writing_to_bram1 ? bram_we : 1'b0;
    assign bram0.dina = writing_to_bram0 ? bram_din : '0;
    assign bram1.dina = writing_to_bram1 ? bram_din : '0;

    // RD side mux
    assign rd_data = ping_is_write ? dout1 : dout0;

    // ------------------------------------------------------------------
    //  WRITE LOGIC — Slice wr_data into TOTAL_MODULES blocks
    // ------------------------------------------------------------------
    integer inp, mod_i;
    always_comb begin
        bram_din = '0;
        // not used here, because each BRAM write writes only 1 module
    end

    // Write address generation & slicing
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_addr <= 0;
            ping_is_write <= 0;
        end else begin
            if (wr_valid && wr_ready) begin

                // Determine which input index we are writing (0 or 1)
                // and which module slice
                int which_input  = wr_addr / COL_X;     // 0 or 1
                int module_index = wr_addr % COL_X;     // 0..(COL_X-1)

                // ---- Extract MODULE_WIDTH slice from wr_data ----
                bram_din <= wr_data[which_input][(module_index+1)*MODULE_WIDTH - 1 : (module_index)*MODULE_WIDTH ];

                // Increment write address
                wr_addr <= wr_addr + 1;

                // When full buffer written → flip ping-pong
                if (wr_addr == TOTAL_DEPTH-1) begin
                    wr_addr <= 0;
                    ping_is_write <= ~ping_is_write;
                end
            end
        end
    end

    assign wr_ready = !(wr_addr == TOTAL_DEPTH);

    // ------------------------------------------------------------------
    // READ SIDE
    // ------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_addr_int <= 0;
            rd_valid <= 0;
        end else begin
            if (rd_ready) begin
                rd_valid <= 1;
                rd_addr_int <= rd_addr_int + 1;

                if (rd_addr_int == TOTAL_DEPTH-1)
                    rd_addr_int <= 0;
            end
        end
    end

endmodule

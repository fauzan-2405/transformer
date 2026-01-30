// top_b2r_converter.sv
// This is used to wrap b2r_converter after sending the output data
// This module will buffer the row data, then send it per TILE_SIZE to softmax module

module top_b2r_converter $(
    parameter WIDTH         = 16,
    parameter FRAC_WIDTH    = 8,
    parameter ROW           = 256,  // Resulting row, in decimal
    parameter COL           = 64,   // Resulting col, in decimal
    parameter BLOCK_SIZE    = 2,
    parameter CHUNK_SIZE    = 4,
    parameter NUM_CORES_H   = 2,
    parameter NUM_CORES_V   = 2,
    parameter TILE_SIZE     = 8
) (
    input logic clk,
    input logic rst_n,           
    input logic en_b2r,
    input logic in_valid,
    input logic [WIDTH*CHUNK_SIZE*NUM_CORES_H*NUM_CORES_V-1:0] in_data,

    output logic out_valid,
    output logic [TILE_SIZE*WIDTH-1:0] out_b2r_top
);
    // ************************** LOCALPARAMS **************************
    localparam ROW_DEPTH            = ROW;                 // number of rows
    localparam TILES_PER_ROW        = COL / TILE_SIZE;
    localparam TILE_DEPTH           = ROW * TILES_PER_ROW;

    localparam WRITE_DATA_WIDTH_A   = WIDTH * COL;
    localparam READ_DATA_WIDTH_A    = WRITE_DATA_WIDTH_A;   // not needed actually
    localparam BYTE_WRITE_WIDTH_A   = WRITE_DATA_WIDTH_A;
    localparam ADDR_WIDTH_A         = $clog2(ROW_DEPTH);

    localparam WRITE_DATA_WIDTH_B   = TILE_SIZE * WIDTH;    // not needed actually
    localparam READ_DATA_WIDTH_B    = WRITE_DATA_WIDTH_B;
    localparam BYTE_WRITE_WIDTH_B   = WRITE_DATA_WIDTH_B;
    localparam ADDR_WIDTH_B         = $clog2(TILE_DEPTH);

    localparam MEMORY_SIZE          = ROW_DEPTH * WRITE_DATA_WIDTH_A;

    // ************************** B2R CONVERTER **************************
    logic [WIDTH*COL-1:0] out_b2r_module;
    logic out_ready_b2r;

    b2r_converter #(
        .WIDTH(WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH),
        .ROW(ROW),             // Resulting row
        .COL(COL),             // Resulting col
        .BLOCK_SIZE(BLOCK_SIZE),
        .CHUNK_SIZE(CHUNK_SIZE),
        .NUM_CORES_H(NUM_CORES_H),
        .NUM_CORES_V(NUM_CORES_V)
    ) converter_b2r (
        .clk(clk),
        .rst_n(rst_n),
        .en(en_b2r),
        .in_valid(in_data),
        .slice_done(),
        .output_ready(out_ready_b2r),
        .slice_last(),
        .buffer_done(),
        .out_data(out_b2r_module)
    );

    // ************************** BRAM BUFFER **************************
    logic ena, wea,
    logic [ADDR_WIDTH_A-1:0] addra,
    logic enb,
    logic [ADDR_WIDTH_B-1:0] addrb,

    xpm_memory_tdpram #(
        .MEMORY_SIZE            (MEMORY_SIZE),
        .MEMORY_PRIMITIVE       ("auto"),
        .MEMORY_INIT_FILE       (),
        .MEMORY_INIT_PARAM      ("0"),
        .USE_MEM_INIT           (1),

        // Port A (WRITE)
        .WRITE_DATA_WIDTH_A     (WRITE_DATA_WIDTH_A),
        .READ_DATA_WIDTH_A      (READ_DATA_WIDTH_A),
        .BYTE_WRITE_WIDTH_A     (BYTE_WRITE_WIDTH_A),
        .ADDR_WIDTH_A           (ADDR_WIDTH_A),

        // Port B (READ)
        .WRITE_DATA_WIDTH_B     (WRITE_DATA_WIDTH_B),
        .READ_DATA_WIDTH_B      (READ_DATA_WIDTH_B),
        .BYTE_WRITE_WIDTH_B     (READ_DATA_WIDTH_B),
        .ADDR_WIDTH_B           (ADDR_WIDTH_B),

        .READ_LATENCY_A         (1),
        .READ_LATENCY_B         (1),

        .WRITE_MODE_A           ("write_first"),
        .WRITE_MODE_B           ("read_first"),

        .READ_RESET_VALUE_A     ("0"),
        .READ_RESET_VALUE_B     ("0"),

        .RST_MODE_A             ("SYNC"),
        .RST_MODE_B             ("SYNC")
    ) b2r_wrapper_bram
    (
        // -------- Port A : Write --------
        .clka   (clk),
        .rsta   (~rst_n),
        .ena    (ena),
        .wea    (wea),
        .addra  (addra),
        .dina   (out_b2r_module),
        .douta  (),

        // -------- Port B : Read --------
        .clkb   (clk),
        .rstb   (~rst_n),
        .enb    (enb),
        .web    (1'b0),
        .addrb  (addrb),
        .dinb   ('0),
        .doutb  (out_b2r_top)
    );


    // ************************** Controller **************************
    logic [$clog2(ROW)-1:0] row_rd_idx;
    logic [$clog2(TILES_PER_ROW)-1:0] tile_idx;

    assign ena  = en_b2r;
    assign enb  = en_b2r && (addra != 0);
    assign wea  = out_ready_b2r;

    assign addrb = row_rd_idx * TILES_PER_ROW + tile_idx;

    always @(posedge clk) begin
        if (!rst_n) begin
            addra   <= '0;

            row_rd_idx  <= '0;
            tile_idx    <= '0;
            out_valid   <= 0;

            out_b2r_top <= '0;
        end else begin
            out_valid   <= enb;
            if (wea) begin
                addra   <= addra + 1;
            end

            if (enb) begin
                if (tile_idx == TILES_PER_ROW-1) begin
                    tile_idx  <= '0;
                    row_rd_idx <= row_rd_idx + 1'b1;
                end else begin
                    tile_idx <= tile_idx + 1'b1;
                end
            end
        end
    end
endmodule
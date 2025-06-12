// r2b_converter_w.v
// Row to block converter for WEIGHT matrix
// Reorders row-major input into vertical BLOCK_SIZE × CHUNK_SIZE chunks (2x4 = 4 elements)

module r2b_converter_w #(
    parameter WIDTH         = 16,
    parameter FRAC_WIDTH    = 8,
    parameter ROW           = 256,   // fixed
    parameter COL           = 64,    // fixed
    parameter BLOCK_SIZE    = 2,     // rows per vertical block
    parameter CHUNK_SIZE    = 4,     // columns per vertical block
    parameter NUM_CORES     = 1,
    parameter RAM_DEPTH     = ROW,
    parameter RAM_DATA_WIDTH= WIDTH * COL,
    parameter OUTPUT_WIDTH  = WIDTH * BLOCK_SIZE * (CHUNK_SIZE / 2)
) (
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     en,
    input  wire [WIDTH*COL-1:0]     in_n2r_buffer,
    output reg  [OUTPUT_WIDTH-1:0] out_n2r_buffer,
    output wire                     slice_last,
    output wire                     buffer_done,
    output reg                     output_ready
);

    // FSM States
    localparam STATE_IDLE      = 2'd0;
    localparam STATE_FILL      = 2'd1;
    localparam STATE_SLICE     = 2'd2;
    localparam STATE_DONE      = 2'd3;
    integer j;

    reg [1:0] state_reg, state_next;

    // Memory
    wire                        ram_we;
    reg [$clog2(ROW)-1:0]       ram_write_addr;
    reg [$clog2(ROW)-1:0]       ram_read_addr0, ram_read_addr1;
    reg [RAM_DATA_WIDTH-1:0]    ram_din;
    reg [RAM_DATA_WIDTH-1:0]    ram_din_d;
    wire [RAM_DATA_WIDTH-1:0]   ram_dout0, ram_dout1;

    // Row counter for fill
    reg [$clog2(ROW):0] row_counter;

    // Output slice indexing
    localparam TOTAL_BLOCKS = ROW / BLOCK_SIZE;
    localparam COL_GROUPS   = COL / BLOCK_SIZE;

    reg [$clog2(TOTAL_BLOCKS):0] block_row_index;  // for vertical groups (rows)
    reg [$clog2(TOTAL_BLOCKS):0] block_row_index_d;
    reg [$clog2(COL_GROUPS):0]   block_col_index;  // for vertical groups (columns)
    reg [$clog2(COL_GROUPS):0]   block_col_index_d; 

    wire [RAM_DATA_WIDTH-1:0] row0_data, row1_data;
    reg slice_ready;

    // FSM
    always @(posedge clk) begin
        if (!rst_n)
            state_reg <= STATE_IDLE;
        else
            state_reg <= state_next;
    end

    always @(*) begin
        case (state_reg)
            STATE_IDLE:  state_next = en ? STATE_FILL : STATE_IDLE;
            STATE_FILL:  state_next = ((ram_write_addr == ROW - 1) && ( row_counter == ROW - 1)) ? STATE_SLICE : STATE_FILL;
            STATE_SLICE: state_next = ((block_row_index_d == TOTAL_BLOCKS - 1) && (block_col_index_d == COL_GROUPS - 1)) ? STATE_DONE : STATE_SLICE;
            STATE_DONE:  state_next = (!rst_n) ? STATE_IDLE : STATE_DONE;
            default:     state_next = STATE_IDLE;
        endcase
    end

    // RAM Write
    always @(posedge clk) begin
        ram_din <= in_n2r_buffer;
        if (state_reg == STATE_FILL) begin
            ram_write_addr <= row_counter;
            //ram_din < in_n2r_buffer;
            ram_din_d <= ram_din;
        end
    end

    // Row Counter (during FILL)
    always @(posedge clk) begin
        if (!rst_n) begin
            row_counter <= 0;
        end else if (state_reg == STATE_FILL) begin
            if (row_counter < ROW - 1)
                row_counter <= row_counter + 1;
        end
    end

    // Slice control logic
    always @(posedge clk) begin
        output_ready <= (slice_ready && state_reg == STATE_SLICE);
        if (!rst_n) begin
            block_row_index <= 0;
            block_col_index <= 0;
            slice_ready     <= 0;
        end else if (state_reg == STATE_SLICE) begin
            slice_ready <= 1;

            // Prepare for next block
            if (block_row_index == TOTAL_BLOCKS - 1) begin
                block_row_index <= 0;
                if (block_col_index == COL_GROUPS -1) begin
                    block_col_index <= 0;
                end else begin
                    block_col_index <= block_col_index + 1;
                end
            end else begin
                block_row_index <= block_row_index + 1;
            end

        end else begin
            slice_ready <= 0;
        end 
    end

    // Output vertical block (2 rows × 4 columns)
    always @(posedge clk) begin
        block_col_index_d <= block_col_index;
        block_row_index_d <= block_row_index;
        if (state_reg == STATE_SLICE) begin
            for (j = 0; j < BLOCK_SIZE; j = j + 1) begin
                out_n2r_buffer[(2*(BLOCK_SIZE - 1 - j)+0)*WIDTH +: WIDTH] <= ram_dout1[(RAM_DATA_WIDTH - 1 - (block_col_index_d*BLOCK_SIZE + j)*WIDTH) -: WIDTH];
                out_n2r_buffer[(2*(BLOCK_SIZE - 1 - j)+1)*WIDTH +: WIDTH] <= ram_dout0[(RAM_DATA_WIDTH - 1 - (block_col_index_d*BLOCK_SIZE + j)*WIDTH) -: WIDTH];
            end
        end
    end

    // Assign read addresses (row pair)
    always @(*) begin
        if (state_reg == STATE_SLICE) begin
            ram_read_addr0 = block_row_index * BLOCK_SIZE + 0;
            ram_read_addr1 = block_row_index * BLOCK_SIZE + 1;
        end
    end

    assign ram_we = (state_reg == STATE_FILL && en);
    //assign ram_din = in_n2r_buffer;
    //assign ram_write_addr = row_counter;
    //assign slice_ready = (state_reg == STATE_SLICE);
    //assign output_ready = slice_ready;
    assign slice_last   = slice_ready && (state_reg == STATE_DONE);
    assign buffer_done  = (state_reg == STATE_DONE);

    // RAM Instance (dual read ports emulated via ping-pong if needed)
    ram_1w2r #(
        .DATA_WIDTH(RAM_DATA_WIDTH),
        .DEPTH(RAM_DEPTH)
    ) weight_buffer_ram (
        .clk(clk),
        .we(ram_we),
        .write_addr(ram_write_addr),
        .read_addr0(ram_read_addr0),
        .read_addr1(ram_read_addr1),
        .din(ram_din_d),
        .dout0(ram_dout0),
        .dout1(ram_dout1)
    );

endmodule

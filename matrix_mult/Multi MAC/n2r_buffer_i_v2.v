// n2r_buffer_i.v
// Normal to Ready buffer for INPUT matrix
// Outputs reshaped 2xN (vertical) blocks per clock after filling SLICE_ROWS.

module n2r_buffer_i #(
    parameter WIDTH       = 16,
    parameter FRAC_WIDTH  = 8,
    parameter BLOCK_SIZE  = 2, 
    parameter CHUNK_SIZE  = 4,
    parameter ROW         = 2754, 
    parameter COL         = 256,
    parameter NUM_CORES   = (COL == 2754) ? 9 :
                            (COL == 256)  ? 8 :
                            (COL == 200)  ? 5 :
                            (COL == 64)   ? 4 : 2
) (
    input  wire                          clk,
    input  wire                          rst_n,
    input  wire                          en,
    input  wire [WIDTH*COL-1:0]          in_n2r_buffer,
    output wire                          slice_done,
    output wire                          output_ready,
    output wire                          buffer_done,
    output reg  [WIDTH*CHUNK_SIZE*NUM_CORES-1:0] out_n2r_buffer
);
    localparam SLICE_ROWS       = BLOCK_SIZE * NUM_CORES;
    localparam CHUNKS_PER_ROW   = COL/BLOCK_SIZE;
    localparam ROW_DIV_CORES    = ROW / SLICE_ROWS;
    localparam OUTPUT_WIDTH     = WIDTH * CHUNK_SIZE * NUM_CORES;
    localparam RAM_DEPTH        = ROW;
    localparam RAM_DATA_WIDTH   = WIDTH * COL;

    localparam STATE_IDLE       = 2'd0;
    localparam STATE_FILL       = 2'd1;
    localparam STATE_SLICE     = 2'd2;
    localparam STATE_DONE       = 2'd3;
    integer i;

    // State Machine
    reg [1:0] state_reg, state_next;

    // RAM control
    reg  [$clog2(RAM_DEPTH)-1:0] ram_write_addr;
    wire [$clog2(RAM_DEPTH)-1:0] ram_read_addr0, ram_read_addr1;
    reg  [RAM_DATA_WIDTH-1:0] ram_din;
    reg  [RAM_DATA_WIDTH-1:0] ram_din_d;
    wire [RAM_DATA_WIDTH-1:0] ram_dout0, ram_dout1;
    wire ram_we;

    // Counters
    reg [$clog2(ROW):0] row_counter;
    reg [$clog2(ROW_DIV_CORES):0] slice_row_index;
    reg [$clog2(CHUNKS_PER_ROW):0] slice_col_index;

    // Output valid
    reg slice_valid;

    // FSM state transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state_reg <= STATE_IDLE;
        else
            state_reg <= state_next;
    end

    always @(*) begin
        case (state_reg)
            STATE_IDLE:     state_next = en ? STATE_FILL : STATE_IDLE;
            STATE_FILL:     state_next = (row_counter == ROW - 1) ? STATE_SLICE : STATE_FILL; 
            STATE_SLICE:   state_next = ((slice_row_index == ROW_DIV_CORES - 1) && (slice_col_index == CHUNKS_PER_ROW - 1)) ? STATE_DONE : STATE_SLICE;
            STATE_DONE:     state_next = (!rst_n) ? STATE_IDLE : STATE_DONE;
            default:        state_next = STATE_IDLE;
        endcase
    end

    // RAM Write
    always @(posedge clk) begin
        ram_din <= in_n2r_buffer;
        if (!rst_n) begin
            row_counter <= 0;
            ram_write_addr <= 0;
            ram_din <=0;
        end else if (state_reg == STATE_FILL) begin
            ram_write_addr <= row_counter;
            ram_din_d <= ram_din;
            if (row_counter < ROW - 1) begin
                row_counter <= row_counter + 1;
            end
        end
    end

    // Slice control logic
    always @(posedge clk) begin
        if (!rst_n) begin
            slice_row_index <= 0;
            slice_col_index <= 0;
            slice_valid     <= 0;
            output_ready    <= 0;
        end else if (state_reg == STATE_SLICE) begin
            slice_valid     <= 1;
            output_ready    <= 1;

            // Advance column first, then row
            if (slice_col_index == CHUNKS_PER_ROW - 1) begin
                slice_col_index <= 0;
                if (slice_row_index == ROW_DIV_CORES - 1) begin
                    slice_row_index <= 0;
                end else begin
                    slice_row_index <= slice_row_index + 1;
                end
            end else begin
                slice_col_index <= slice_col_index + 1;
            end
        end else begin
            slice_ready  <= 0;
            output_ready <= 0;
        end
    end

    // Output
    always @(posedge clk) begin
        if (state_reg == STATE_SLICE) begin
            for (i = 0; i < SLICE_ROWS; i = i + 1) begin
                out_n2r_buffer[(SLICE_ROWS - 1 - i)*WIDTH +: WIDTH] <= ram_dout0[(RAM_DATA_WIDTH - 1 - WIDTH * (slice_col_index * BLOCK_SIZE + i)) -: WIDTH];
            end
        end
    end

    // Assign read addresses
    always @(*) begin
        if (state_reg == STATE_SLICE) begin
            ram_read_addr0 = slice_row_index * SLICE_ROWS + 0;
            ram_read_addr1 = slice_row_index * SLICE_ROWS + 1;
        end
    end

    assign ram_we = (state_reg == STATE_FILL && en);

    // Dual-read RAM
    ram_1w2r #(
        .DATA_WIDTH(RAM_DATA_WIDTH),
        .DEPTH(RAM_DEPTH)
    ) buffer_ram (
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
// n2r_buffer.v
// Normal to Ready buffer
// Used for changing the shape of the matrix from the normal version (row by row) to the ready to be inputted to the matrix multiplication module

module n2r_buffer_v2 #(
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
    output reg  [WIDTH*CHUNK_SIZE*NUM_CORES-1:0] out_n2r_buffer
);
    // Local parameters
    localparam SLICE_ROWS       = BLOCK_SIZE * NUM_CORES; // 
    localparam CHUNKS_PER_ROW   = COL/BLOCK_SIZE;
    localparam OUTPUT_WIDTH     = WIDTH * CHUNK_SIZE * NUM_CORES;
    localparam RAM_DEPTH        = ROW;
    localparam RAM_DATA_WIDTH   = WIDTH * COL;
    localparam STATE_IDLE       = 3'd0;
    localparam STATE_FILL       = 3'd1;
    localparam STATE_SLICE_RD   = 3'd2;
    localparam STATE_OUTPUT     = 3'd3;
    integer i;

    // State Machine
    reg [2:0] state_reg, state_next;

    // Counters
    reg [$clog2(ROW)-1:0] counter;      // Write index
    reg [$clog2(ROW)-1:0] counter_row;  // Current slice row base
    reg [$clog2(CHUNKS_PER_ROW)-1:0] counter_out;
    reg [$clog2(SLICE_ROWS)-1:0] slice_load_counter;

    // RAM Interface
    reg ram_we;
    reg [$clog2(RAM_DEPTH)-1:0] ram_write_addr, ram_read_addr;
    reg [RAM_DATA_WIDTH-1:0] ram_din;
    wire [RAM_DATA_WIDTH-1:0] ram_dout;

    // Slice row buffer
    reg [RAM_DATA_WIDTH-1:0] slice_row [0:SLICE_ROWS-1];
    reg slice_ready;

    // FSM state register
    always @(posedge clk) begin
        if (!rst_n) begin
            state_reg <= STATE_IDLE;
        end
        else begin
            state_reg <= state_next;
        end
    end

    // FSM next state logic
    always @(*) begin
        case(state_reg)
        STATE_IDLE:
            begin
                state_next = en ? STATE_FILL : STATE_IDLE;
            end

            STATE_FILL:
            begin
                state_next = (counter >= ROW) ? STATE_SLICE_RD : STATE_FILL;
            end

            STATE_SLICE_RD:
            begin
                state_next = (slice_load_counter >= SLICE_ROWS - 1) ? STATE_OUTPUT : STATE_SLICE_RD;
            end

            STATE_OUTPUT:
            begin
                state_next = (counter_out == CHUNKS_PER_ROW - 1) ? STATE_SLICE_RD : STATE_OUTPUT;
            end

            default:
            begin
                state_next = STATE_IDLE;
            end
        endcase
    end

    // RAM write logic during STATE_FILL
    always @(posedge clk) begin
        ram_we <= 0;
        if (state_reg == STATE_FILL && en) begin
            ram_we          <= 1;
            ram_write_addr  <= counter;
            ram_din         <= in_n2r_buffer;
        end
    end

    // Slice read logic
    always @(posedge clk) begin
        if (!rst_n) begin
            counter         <= 0;
            counter_row     <= 0;
            counter_out     <= 0;
            slice_load_counter <= 0;
            slice_ready     <= 0;
        end else begin
            case (state_reg)
                STATE_FILL: 
                begin
                    if (en && counter < ROW) begin
                        counter <= counter + 1;
                    end
                end

                STATE_SLICE_RD: 
                begin
                    ram_read_addr <= counter_row + slice_load_counter;
                    slice_row[slice_load_counter] <= ram_dout;

                    if (slice_load_counter == SLICE_ROWS - 1) begin
                        slice_ready <= 1;
                        slice_load_counter <= 0;
                    end else begin
                        slice_load_counter <= slice_load_counter + 1;
                    end
                end

                STATE_OUTPUT:
                begin
                    if (slice_ready) begin
                        for (i = 0; i < SLICE_ROWS; i = i+1) begin
                            out_n2r_buffer[(SLICE_ROWS - 1 - i)*32 +: 32] <= slice_row[i][(RAM_DATA_WIDTH - 1 - 32*counter_out) -: 32];
                        end

                        if (counter_out == CHUNKS_PER_ROW - 1) begin
                            counter_out <= 0;
                            counter_row <= counter_row + SLICE_ROWS;
                            slice_ready <= 0;
                        end else begin
                            counter_out <= counter_out + 1;
                        end
                    end
                end
            endcase
        end
    end

    assign slice_done = (state_reg == STATE_OUTPUT) && (counter_out == CHUNKS_PER_ROW - 1);

    // Instantiate BRAM
    ram_1w1r #(
        .DATA_WIDTH(RAM_DATA_WIDTH),
        .DEPTH(RAM_DEPTH)
    ) temp_buffer_ram (
        .clk(clk),
        .we(ram_we),
        .write_addr(ram_write_addr),
        .read_addr(ram_read_addr),
        .din(ram_din),
        .dout(ram_dout)
    );

endmodule
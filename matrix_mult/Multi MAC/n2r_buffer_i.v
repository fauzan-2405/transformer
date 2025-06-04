// n2r_buffer.v
// Normal to Ready buffer for input
// Used for changing the shape of the input matrix from the normal version (row by row) to the ready to be inputted to the matrix multiplication module (block per block)

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
    // Local parameters
    localparam SLICE_ROWS       = BLOCK_SIZE * NUM_CORES; // 
    localparam CHUNKS_PER_ROW   = COL/BLOCK_SIZE;
    localparam ROW_DIV_CORES    = ROW/(NUM_CORES*BLOCK_SIZE);
    localparam OUTPUT_WIDTH     = WIDTH * CHUNK_SIZE * NUM_CORES;
    localparam RAM_DEPTH        = ROW;
    localparam RAM_DATA_WIDTH   = WIDTH * COL;
    localparam STATE_IDLE       = 3'd0;
    localparam STATE_FILL       = 3'd1;
    localparam STATE_SLICE_RD   = 3'd2;
    localparam STATE_OUTPUT     = 3'd3;
    localparam STATE_DONE       = 3'd4;
    integer i;

    // State Machine
    reg [2:0] state_reg, state_next;

    // Counters & Flag
    reg [$clog2(ROW)-1:0] counter;      // Write index
    reg [$clog2(ROW)-1:0] counter_row;  // Current slice row base
    reg [$clog2(ROW)-1:0] counter_row_index; // Current row based on the ROW / NUM_CORES
    reg [$clog2(CHUNKS_PER_ROW)-1:0] counter_out;
    reg [$clog2(CHUNKS_PER_ROW)-1:0] counter_out_d;
    reg [$clog2(ROW)-1:0] slice_load_counter;
    reg [$clog2(ROW)-1:0] slice_load_counter_d;
    wire all_slice_done;

    // RAM Interface
    reg ram_we;
    reg [$clog2(ROW)-1:0] ram_write_addr;
    wire [$clog2(ROW)-1:0] ram_read_addr;
    reg [RAM_DATA_WIDTH-1:0] ram_din;
    wire [RAM_DATA_WIDTH-1:0] ram_dout;

    // Slice row buffer
    reg [RAM_DATA_WIDTH-1:0] slice_row [0:SLICE_ROWS-1];
    reg slice_ready;
    reg slice_ready_d;

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
                state_next = ((counter >= ROW - 1) && (ram_write_addr >= ROW - 1)) ? STATE_SLICE_RD : STATE_FILL;
            end

            STATE_SLICE_RD:
            begin
                state_next = ((ram_read_addr  >= SLICE_ROWS - 1) && (slice_load_counter_d >= SLICE_ROWS - 1)) ? STATE_OUTPUT : STATE_SLICE_RD;
            end

            STATE_OUTPUT:
            begin
                // state_next = ((counter_out == CHUNKS_PER_ROW - 1) && (counter_out_d == CHUNKS_PER_ROW - 1)) ? STATE_SLICE_RD : STATE_OUTPUT;
                if ((counter_out == CHUNKS_PER_ROW - 1) && (counter_out_d == CHUNKS_PER_ROW - 1)) begin
                    if (all_slice_done) begin
                        state_next = STATE_DONE;
                    end else begin
                        state_next = STATE_SLICE_RD;
                    end
                end 
                else begin
                    state_next = STATE_OUTPUT;
                end
            end

            STATE_DONE:
            begin
                state_next = (!rst_n) ? STATE_IDLE : STATE_DONE;
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
        if (state_reg == STATE_FILL) begin
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
            counter_row_index <= 0;
        end else begin
            counter_out_d <= counter_out;
            slice_load_counter_d <= slice_load_counter;
            slice_ready_d <= slice_ready;

            case (state_reg)
                STATE_FILL: 
                begin
                    if (en && counter < ROW) begin
                        if (counter == ROW - 1) begin
                            counter <= counter;
                        end else begin
                            counter <= counter + 1;
                        end
                    end
                end

                STATE_SLICE_RD: 
                begin
                    //ram_read_addr <= counter_row + slice_load_counter;
                    slice_row[slice_load_counter_d] <= ram_dout;

                    if (slice_load_counter == SLICE_ROWS - 1) begin
                        if ((slice_load_counter_d + (counter_row_index * SLICE_ROWS)) == ram_read_addr ) begin
                            slice_ready <= 1;
                            slice_load_counter <= 0;

                            if (counter_row_index == ROW_DIV_CORES) begin'
                                counter_row_index <= counter_row_index;
                            end else begin
                                counter_row_index <= counter_row_index + 1;
                            end
                        end else begin
                            slice_load_counter <= slice_load_counter;
                        end
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
                            if (counter_out == counter_out_d) begin
                                counter_out <= 0;
                                counter_row <= counter_row + SLICE_ROWS;
                                slice_ready <= 0;
                            end
                            else begin
                                counter_out <= counter_out;
                            end
                        end else begin
                            counter_out <= counter_out + 1;
                        end
                    end
                end
            endcase
        end
    end

    assign ram_read_addr = (state_reg == STATE_SLICE_RD) ? (counter_row + slice_load_counter) : 0;
    assign all_slice_done = (counter_row_index == ROW_DIV_CORES);
    assign slice_done = (state_reg == STATE_OUTPUT) && (counter_out_d == CHUNKS_PER_ROW - 1);
    assign buffer_done = (all_slice_done & slice_done);
    assign output_ready = (slice_ready_d & slice_ready);

    // Instantiate BRAM
    ram_1w1r #(
        .DATA_WIDTH(RAM_DATA_WIDTH),
        .DEPTH(RAM_DEPTH),
        .ROW(ROW)
    ) temp_buffer_ram (
        .clk(clk),
        .we(ram_we),
        .write_addr(ram_write_addr),
        .read_addr(ram_read_addr),
        .din(ram_din),
        .dout(ram_dout)
    );

endmodule
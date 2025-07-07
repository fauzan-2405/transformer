// vertical_converter.v
// Row to block converter for input and output
// Used for changing the shape of the input matrix from the normal version (row by row) to the ready to be inputted to the matrix multiplication module (block per block)

module vertical_converter #(
    parameter WIDTH       = 16,
    parameter FRAC_WIDTH  = 8,
    parameter BLOCK_SIZE  = 2, 
    parameter CHUNK_SIZE  = 4,
    parameter ROW         = 2754, 
    parameter COL         = 256,
    parameter NUM_CORES_H = 2,  // Horizontal
    parameter NUM_CORES_V = 2   // Vertical
) (
    input  wire                          clk,
    input  wire                          rst_n,
    input  wire                          en,
    input  wire                          in_valid,
    input  wire [WIDTH*COL-1:0]          in_data,
    output wire                          slice_done,
    output wire                          output_ready,
    output wire                          slice_last,
    output wire                          buffer_done,
    output reg  [WIDTH*CHUNK_SIZE*NUM_CORES_V-1:0] out_data
);
    // Local parameters
    localparam SLICE_ROWS       = BLOCK_SIZE * NUM_CORES_V; 
    localparam CHUNKS_PER_ROW   = COL/(BLOCK_SIZE * NUM_CORES_H);
    localparam ROW_DIV          = ROW/(SLICE_ROWS);
    localparam RAM_DEPTH        = ROW;
    localparam RAM_DATA_WIDTH   = WIDTH * COL;
    integer i;

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
    //reg [RAM_DATA_WIDTH-1:0] ram_din_d;
    wire [RAM_DATA_WIDTH-1:0] ram_dout;

    // Slice row buffer
    reg [RAM_DATA_WIDTH-1:0] slice_row [0:SLICE_ROWS-1];
    reg slice_ready;
    reg slice_ready_d;

    // RAM write logic during STATE_FILL
    always @(posedge clk) begin
        ram_we <= 0;
        if (en) begin
            ram_din         <= in_data;
            if (in_valid) begin
                ram_we          <= 1;
                ram_write_addr  <= counter;
            end
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
            if (en) begin
                counter_out_d <= counter_out;
                slice_load_counter_d <= slice_load_counter;
                slice_ready_d <= slice_ready;

                if (en && in_valid && counter < ROW) begin
                    if (counter == ROW - 1) begin
                        counter <= counter;
                    end else begin
                        counter <= counter + 1;
                    end
                end

                //ram_read_addr <= counter_row + slice_load_counter;
                slice_row[slice_load_counter_d] <= ram_dout;

                if (slice_load_counter == SLICE_ROWS - 1) begin
                    if ((slice_load_counter_d + (counter_row_index * SLICE_ROWS)) == ram_read_addr ) begin
                        slice_ready <= 1;
                        slice_load_counter <= 0;

                        if (counter_row_index == ROW_DIV) begin
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

                if (slice_ready) begin
                    for (i = 0; i < SLICE_ROWS; i = i+1) begin
                        out_data[(SLICE_ROWS - 1 - i)*32 +: 32] <= slice_row[i][(RAM_DATA_WIDTH - 1 - 32*counter_out) -: 32];
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
        end
    end

    assign ram_read_addr = (counter_row + slice_load_counter);
    assign all_slice_done = (counter_row_index == ROW_DIV);
    assign slice_done =(counter_out_d == CHUNKS_PER_ROW - 1);
    assign slice_last = (all_slice_done & slice_done);
    assign output_ready = (slice_ready_d & slice_ready);
    assign buffer_done = slice_last;

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
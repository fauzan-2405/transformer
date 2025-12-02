// b2r_converter.v VERSIONN TWOOO
// Used to convert block-per-block input into row-per-row (normal matrix ordering)
// WIDTH*CHUNK_SIZE*NUM_CORES = COL_OPERATION (in this computation)

module b2r_converter #(
    parameter WIDTH         = 16,
    parameter FRAC_WIDTH    = 8,
    parameter ROW           = 256,
    parameter COL           = 64,
    parameter BLOCK_SIZE    = 2,
    parameter CHUNK_SIZE    = 4,
    parameter NUM_CORES_H   = 2,
    parameter NUM_CORES_V   = 2
)(
    input                          clk,
    input                          rst_n,           
    input                          en,
    input                          in_valid,
    input  [WIDTH*CHUNK_SIZE*NUM_CORES_H*NUM_CORES_V-1:0] in_data,

    output wire                    slice_done,
    output wire                    output_ready,
    output wire                    slice_last,
    output wire                    buffer_done,
    output reg [WIDTH*COL-1:0]     out_data
);
    // Local parameters
    localparam TOTAL_INPUT_ROW_REAL  = ROW/(BLOCK_SIZE*NUM_CORES_V) * COL/(BLOCK_SIZE*NUM_CORES_H); // Total rows in core mode
    localparam TOTAL_INPUT_COL_REAL  = CHUNK_SIZE * NUM_CORES_H * NUM_CORES_V;                      // Total cols in core mode

    localparam SLICE_ROWS       = COL/(BLOCK_SIZE*NUM_CORES_H);                     // Indicates how many input rows (in core mode) that needed to produce one output
    localparam CHUNKS_PER_ROW   = TOTAL_INPUT_COL_REAL/(BLOCK_SIZE*NUM_CORES_H);    // Indicates how many chunks within one core in one input row (in core mode),
    localparam ROW_DIV          = TOTAL_INPUT_ROW_REAL/(SLICE_ROWS);                // Indicates how many iterations in rows based on the SLICE_ROWS
    localparam RAM_DEPTH        = TOTAL_INPUT_ROW_REAL;
    localparam RAM_DATA_WIDTH   = WIDTH * TOTAL_INPUT_COL_REAL;
    localparam BLOCKS_PER_V_CORE = CHUNK_SIZE / BLOCK_SIZE;
    localparam OUTPUTS_PER_SLICE = NUM_CORES_V * BLOCKS_PER_V_CORE;
    
    localparam STATE_IDLE       = 3'd0;
    localparam STATE_FILL       = 3'd1;
    localparam STATE_SLICE_RD   = 3'd2;
    localparam STATE_OUTPUT     = 3'd3;
    localparam STATE_DONE       = 3'd4;
    integer i;

    // State Machine
    reg [2:0] state_reg, state_next;

    // Counters & Flag
    reg [$clog2(TOTAL_INPUT_ROW_REAL)-1:0] counter;      // Write index
    reg [$clog2(TOTAL_INPUT_ROW_REAL)-1:0] counter_row;  // Current slice row base
    reg [$clog2(TOTAL_INPUT_ROW_REAL)-1:0] counter_row_index; // Current row based on the ROW / NUM_CORES
    reg [$clog2(CHUNKS_PER_ROW)-1:0] counter_out;
    reg [$clog2(CHUNKS_PER_ROW)-1:0] counter_out_d;
    reg [$clog2(TOTAL_INPUT_ROW_REAL)-1:0] slice_load_counter;
    reg [$clog2(TOTAL_INPUT_ROW_REAL)-1:0] slice_load_counter_d;
    wire all_slice_done;

    // RAM Interface
    reg ram_we;
    reg [$clog2(TOTAL_INPUT_ROW_REAL)-1:0] ram_write_addr;
    //reg [$clog2(TOTAL_INPUT_ROW_REAL)-1:0] ram_read_addr;
    wire [$clog2(TOTAL_INPUT_ROW_REAL)-1:0] ram_read_addr;
    reg [RAM_DATA_WIDTH-1:0] ram_din;
    reg [RAM_DATA_WIDTH-1:0] ram_din_d;
    wire [RAM_DATA_WIDTH-1:0] ram_dout;

    // Slice row buffer
    reg [RAM_DATA_WIDTH-1:0] slice_row [0:SLICE_ROWS-1];
    reg slice_ready;
    reg slice_ready_d;

    // Integer variable for output
    // row_idx : row index when iterating slice_rows
    // core_h : 
    // elem_idx indicates elements that we want to access based on the BLOCK_SIZE
    integer nv_idx, block_id;
    integer row_idx, nh_idx;
    integer elem_idx;     
    integer base_col_idx;
    integer out_base;
    integer elem_offset;
    integer mem_pos, out_pos;

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
                state_next = ((counter >= TOTAL_INPUT_ROW_REAL - 1) && (ram_write_addr >= TOTAL_INPUT_ROW_REAL - 1)) ? STATE_SLICE_RD : STATE_FILL;
            end

            STATE_SLICE_RD:
            begin
                //state_next = ((ram_read_addr  >= SLICE_ROWS - 1) && (slice_load_counter_d >= SLICE_ROWS - 1)) ? STATE_OUTPUT : STATE_SLICE_RD;
                //state_next = (ram_read_addr  == SLICE_ROWS + counter_row - slice_load_counter) ? STATE_OUTPUT : STATE_SLICE_RD;
                state_next = ((ram_read_addr  == SLICE_ROWS + counter_row - slice_load_counter) && (slice_load_counter_d >= SLICE_ROWS - 1)) ? STATE_OUTPUT : STATE_SLICE_RD;
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
        if (en) begin
            ram_din         <= in_data;
            if (state_reg == STATE_FILL && in_valid) begin
                ram_we          <= 1;
                ram_write_addr  <= counter;
                //ram_din         <= in_data;
                ram_din_d       <= ram_din;
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

                case (state_reg)
                    STATE_FILL: 
                    begin
                        if (en && in_valid && counter < TOTAL_INPUT_ROW_REAL) begin
                            if (counter == TOTAL_INPUT_ROW_REAL - 1) begin
                                counter <= counter;
                            end else begin
                                counter <= counter + 1;
                            end
                        end
                    end

                    STATE_SLICE_RD: 
                    begin
                        //ram_read_addr <= counter_row + slice_load_counter;
                        slice_row[slice_load_counter] <= ram_dout;

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
                    end

                    STATE_OUTPUT:
                    begin
                        if (slice_ready) begin
                            // Calculate indices
                            nv_idx = counter_out / BLOCKS_PER_V_CORE;
                            block_id = counter_out % BLOCKS_PER_V_CORE;
                            for (row_idx = 0; row_idx < SLICE_ROWS; row_idx = row_idx + 1) begin
                                for (nh_idx = 0; nh_idx < NUM_CORES_H; nh_idx = nh_idx + 1) begin
                                    // Calculate memory addresses
                                    base_col_idx = (nh_idx * CHUNK_SIZE * NUM_CORES_V) + (nv_idx * CHUNK_SIZE) + (block_id * BLOCK_SIZE);
                                    
                                    // Calculate output position
                                    out_base = (row_idx * NUM_CORES_H * BLOCK_SIZE + nh_idx * BLOCK_SIZE) * WIDTH;
                                    
                                    // Copy BLOCK_SIZE elements
                                    for (elem_offset = 0; elem_offset < BLOCK_SIZE; elem_offset = elem_offset + 1) begin
                                        mem_pos = (base_col_idx + elem_offset) * WIDTH;
                                        out_pos = out_base + elem_offset * WIDTH;
                                        
                                        out_data[out_pos +: WIDTH] <= slice_row[row_idx][mem_pos +: WIDTH];
                                    end
                                    
                                    
                                end
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
    end

    assign ram_read_addr = (state_reg == STATE_SLICE_RD) ? (counter_row + slice_load_counter) : 0;
    assign all_slice_done = (counter_row_index == ROW_DIV);
    assign slice_done = (state_reg == STATE_OUTPUT) && (counter_out_d == CHUNKS_PER_ROW - 1);
    assign slice_last = (all_slice_done & slice_done);
    assign output_ready = (slice_ready_d & slice_ready);
    assign buffer_done = slice_last || (state_reg == STATE_DONE);

    // Instantiate BRAM
    ram_1w1r #(
        .DATA_WIDTH(RAM_DATA_WIDTH),
        .DEPTH(RAM_DEPTH)
    ) temp_buffer_ram (
        .clk(clk),
        .we(ram_we),
        .write_addr(ram_write_addr),
        .read_addr(ram_read_addr),
        .din(ram_din_d),
        .dout(ram_dout)
    );

endmodule


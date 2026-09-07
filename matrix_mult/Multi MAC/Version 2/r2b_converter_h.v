module r2b_converter_h #(
    parameter WIDTH         = 16,
    parameter FRAC_WIDTH    = 8,
    parameter ROW           = 256,   
    parameter COL           = 64,    
    parameter BLOCK_SIZE    = 2,     // Vertical block size (rows)
    parameter CHUNK_SIZE    = 4,     // Elements per core (must be BLOCK_SIZE²)
    parameter NUM_CORES_H   = 1      // Horizontal cores per chunk
) (
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     en,
    input  wire                     in_valid,
    input  wire [WIDTH*COL-1:0]     in_data,
    output reg  [WIDTH*CHUNK_SIZE*NUM_CORES_H-1:0] out_data,
    output reg                      slice_done,
    //output wire                     slice_last,
    output wire                     buffer_done,
    output reg                      output_ready
);

    // Derived parameters
    localparam RAM_DEPTH        = ROW;
    localparam RAM_DATA_WIDTH   = WIDTH * COL;
    localparam SLICE_ROWS       = BLOCK_SIZE;                         
    localparam COLS_PER_CORE    = CHUNK_SIZE / BLOCK_SIZE;             // Columns per core per row
    localparam CHUNKS_PER_ROW   = COL / (BLOCK_SIZE * NUM_CORES_H);    
    localparam ROW_DIV          = ROW / SLICE_ROWS;                   
    localparam TOTAL_BLOCKS     = ROW / BLOCK_SIZE;                    // Total vertical blocks
    localparam COL_GROUPS       = CHUNKS_PER_ROW;                      // Total horizontal chunks
    localparam CHUNK_WIDTH      = BLOCK_SIZE * NUM_CORES_H;            // Columns per chunk
    
    // States
    localparam STATE_IDLE       = 3'd0;
    localparam STATE_FILL       = 3'd1;
    localparam STATE_PROCESS    = 3'd2;
    localparam STATE_DONE       = 3'd3;
    
    // Control registers
    reg [2:0] state_reg, state_next;
    reg [$clog2(ROW)-1:0] ram_write_addr;
    reg [$clog2(ROW)-1:0] ram_write_addr_d;
    reg [$clog2(TOTAL_BLOCKS)-1:0] block_row_index;
    reg [$clog2(TOTAL_BLOCKS)-1:0] block_row_index_d;
    reg [$clog2(COL_GROUPS)-1:0] block_col_index;
    reg [$clog2(COL_GROUPS)-1:0] block_col_index_d;
    reg [$clog2(ROW)-1:0] row_counter;
    reg out_ready;

    // RAM signals
    wire ram_we;
    reg [RAM_DATA_WIDTH-1:0] ram_din;
    reg [$clog2(RAM_DEPTH)-1:0] ram_read_addr0, ram_read_addr1;
    wire [RAM_DATA_WIDTH-1:0] ram_dout0, ram_dout1;
    
    // Integers
    integer base_col, core, col, col_idx, row, out_idx;

    // FSM
    always @(posedge clk) begin
        if (!rst_n) state_reg <= STATE_IDLE;
        else state_reg <= state_next;
    end

    always @(*) begin
        case (state_reg)
            STATE_IDLE:  state_next = en ? STATE_FILL : STATE_IDLE;
            STATE_FILL:  state_next = ((row_counter == ROW) && (ram_write_addr_d == ROW - 1)) ? STATE_PROCESS : STATE_FILL;
            STATE_PROCESS: begin
                if ((block_row_index_d == TOTAL_BLOCKS-1) && 
                    (block_col_index_d == COL_GROUPS-1)) 
                    state_next = STATE_DONE;
                else 
                    state_next = STATE_PROCESS;
            end
            STATE_DONE:  state_next = STATE_IDLE;
            default:     state_next = STATE_IDLE;
        endcase
    end

    // Row counter for fill
    always @(posedge clk) begin
        if (!rst_n) row_counter <= 0;
        else if (state_reg == STATE_FILL && in_valid)
            row_counter <= (row_counter == ROW) ? 0 : row_counter + 1;
    end

    // RAM write
    assign ram_we = (state_reg == STATE_FILL) || in_valid;
    always @(posedge clk) begin
        ram_din <= in_data;
        ram_write_addr_d <= ram_write_addr;
        if (ram_we) ram_write_addr <= row_counter;
    end

    // Block processing counters
    always @(posedge clk) begin
        if (!rst_n) begin
            block_row_index <= 0;
            block_col_index <= 0;
            block_col_index_d <= 0;
        end
        else if (state_reg == STATE_PROCESS) begin
            block_col_index_d <= block_col_index;
            block_row_index_d <= block_row_index;
            if (block_row_index == TOTAL_BLOCKS-1) begin
                block_row_index <= 0;
                block_col_index <= (block_col_index == COL_GROUPS-1) ? 0 : block_col_index + 1;
                //block_col_index_d <= block_col_index;
            end
            else begin
                block_row_index <= block_row_index + 1;
            end
        end
    end

    // RAM read addresses
    always @(*) begin
        if (state_reg == STATE_PROCESS) begin
            ram_read_addr0 <= block_row_index * BLOCK_SIZE;
            ram_read_addr1 <= block_row_index * BLOCK_SIZE + 1;
        end
    end

    // Output generation
    always @(posedge clk) begin
        if (!rst_n) begin
            base_col <= 0;
            core <= 0; 
            col <= 0;
            col_idx <= 0; 
            row <= 0; 
            out_idx <= 0;
        end
        else if (state_reg == STATE_PROCESS) begin
            // base_col = block_col_index * CHUNK_WIDTH
            base_col = (COL_GROUPS - 1 - block_col_index_d) * CHUNK_WIDTH;
            for (core = 0; core < NUM_CORES_H; core = core+1) begin
                for (col = 0; col < COLS_PER_CORE; col=col+1) begin
                    col_idx = base_col + core * COLS_PER_CORE + col;
                    for (row = 0; row < BLOCK_SIZE; row=row+1) begin
                        out_idx = (core * CHUNK_SIZE) + (col * BLOCK_SIZE) + row;
                        if (row == 0) begin
                            out_data[out_idx*WIDTH +: WIDTH] <= ram_dout1[col_idx*WIDTH +: WIDTH];
                        end else begin
                            out_data[out_idx*WIDTH +: WIDTH] <= ram_dout0[col_idx*WIDTH +: WIDTH];
                        end
                    end
                end
            end
        end
    end

    // Control signals
    always @(posedge clk) begin
        if (!rst_n) begin
            out_ready <= 0;
            output_ready <= 0;
            slice_done <= 0;
        end
        else begin
            out_ready <= (state_reg == STATE_PROCESS);
            output_ready <= out_ready && ~buffer_done;
            slice_done <= (state_reg == STATE_PROCESS) && 
                         (block_row_index_d == TOTAL_BLOCKS-1);
        end
    end

    //assign slice_last = (block_col_index == COL_GROUPS-1) && slice_done;
    assign buffer_done = (state_reg == STATE_DONE);

    // 1w2r RAM instantiation
    ram_1w2r #(
        .DATA_WIDTH(RAM_DATA_WIDTH),
        .DEPTH(RAM_DEPTH)
    ) weight_buffer_ram (
        .clk(clk),
        .we(ram_we),
        .write_addr(ram_write_addr),
        .read_addr0(ram_read_addr0),
        .read_addr1(ram_read_addr1),
        .din(ram_din),
        .dout0(ram_dout0),
        .dout1(ram_dout1)
    );

endmodule

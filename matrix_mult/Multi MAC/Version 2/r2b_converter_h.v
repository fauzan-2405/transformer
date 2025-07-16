// r2b_converter_h.v
// Generic row-to-block converter (horizontal traversal)
// Supports arbitrary ROW, COL, NUM_CORES_H

module r2b_converter_h #(
    parameter WIDTH         = 16,
    parameter FRAC_WIDTH    = 8,
    parameter ROW           = 256,   
    parameter COL           = 64,    
    parameter BLOCK_SIZE    = 2,     // Rows per block
    parameter CHUNK_SIZE    = 4,     // Columns per chunk
    parameter NUM_CORES_H   = 1      // Number of horizontal cores
) (
    input  wire                           clk,
    input  wire                           rst_n,
    input  wire                           en,
    input  wire                           in_valid,
    input  wire [WIDTH*COL-1:0]           in_n2r_buffer,
    output wire [WIDTH*BLOCK_SIZE*CHUNK_SIZE*NUM_CORES_H-1:0] out_n2r_buffer,
    output wire                           slice_last,
    output wire                           buffer_done,
    output wire                           output_ready
);

    // Local parameters
    localparam SLICE_ROWS       = BLOCK_SIZE;               // Rows per slice
    localparam CHUNKS_PER_SLICE = COL / CHUNK_SIZE;         // Chunks per slice
    localparam TOTAL_SLICES     = ROW / BLOCK_SIZE;         // Total vertical slices
    localparam RAM_DEPTH        = ROW;
    localparam RAM_DATA_WIDTH   = WIDTH * COL;
    localparam OUTPUT_WIDTH     = WIDTH * BLOCK_SIZE * CHUNK_SIZE * NUM_CORES_H;
    
    // FSM States
    localparam STATE_IDLE       = 3'd0;
    localparam STATE_FILL       = 3'd1;
    localparam STATE_SLICE_RD = 3'd2;
    localparam STATE_OUTPUT     = 3'd3;
    localparam STATE_DONE       = 3'd4;
    
    // State registers
    reg [2:0] state_reg, state_next;
    
    // RAM signals
    reg ram_we;
    reg [$clog2(RAM_DEPTH)-1:0] ram_write_addr;
    reg [$clog2(RAM_DEPTH)-1:0] ram_read_addr;
    reg [RAM_DATA_WIDTH-1:0] ram_din;
    wire [RAM_DATA_WIDTH-1:0] ram_dout;
    
    // Counters
    reg [$clog2(ROW)-1:0] row_counter;
    reg [$clog2(SLICE_ROWS)-1:0] slice_load_counter;
    reg [$clog2(TOTAL_SLICES)-1:0] slice_counter;
    reg [$clog2(CHUNKS_PER_SLICE)-1:0] chunk_counter;
    
    // Buffers
    reg [RAM_DATA_WIDTH-1:0] slice_buffer [0:SLICE_ROWS-1];
    reg slice_ready;
    wire all_slices_done;
    
    // Assign outputs
    assign output_ready = (state_reg == STATE_OUTPUT);
    assign buffer_done  = (state_reg == STATE_DONE);
    assign slice_last   = all_slices_done && (chunk_counter == CHUNKS_PER_SLICE - 1);
    assign all_slices_done = (slice_counter == TOTAL_SLICES - 1);
    
    // Output generation
    generate
        genvar r, c, core;
        for (r = 0; r < BLOCK_SIZE; r = r + 1) begin: row_out
            for (core = 0; core < NUM_CORES_H; core = core + 1) begin: core_out
                for (c = 0; c < CHUNK_SIZE; c = c + 1) begin: col_out
                    localparam out_idx = (
                        r * (NUM_CORES_H * CHUNK_SIZE) + 
                        core * CHUNK_SIZE + c
                    ) * WIDTH;
                    
                    localparam in_idx = (
                        (chunk_counter * NUM_CORES_H + core) * CHUNK_SIZE + c
                    ) * WIDTH;
                    
                    assign out_n2r_buffer[out_idx +: WIDTH] = 
                        slice_buffer[r][in_idx +: WIDTH];
                end
            end
        end
    endgenerate

    // FSM state register
    always @(posedge clk) begin
        if (!rst_n) state_reg <= STATE_IDLE;
        else state_reg <= state_next;
    end

    // FSM next state logic
    always @(*) begin
        state_next = state_reg;
        case (state_reg)
            STATE_IDLE: 
                if (en) state_next = STATE_FILL;
            
            STATE_FILL: 
                if (row_counter == ROW - 1 && in_valid) 
                    state_next = STATE_SLICE_RD;
            
            STATE_SLICE_RD: 
                if (slice_load_counter == SLICE_ROWS - 1) 
                    state_next = STATE_OUTPUT;
            
            STATE_OUTPUT: 
                if (chunk_counter == CHUNKS_PER_SLICE - 1) begin
                    if (all_slices_done) state_next = STATE_DONE;
                    else state_next = STATE_SLICE_RD;
                end
            
            STATE_DONE: 
                if (!en) state_next = STATE_IDLE;
        endcase
    end

    // RAM write logic
    always @(posedge clk) begin
        if (!rst_n) begin
            row_counter <= 0;
            ram_we <= 0;
        end else if (state_reg == STATE_FILL && in_valid) begin
            ram_din <= in_n2r_buffer;
            ram_we <= 1;
            ram_write_addr <= row_counter;
            
            if (row_counter < ROW - 1)
                row_counter <= row_counter + 1;
            else
                row_counter <= 0;
        end else begin
            ram_we <= 0;
        end
    end

    // Slice loading logic
    always @(posedge clk) begin
        if (!rst_n) begin
            slice_load_counter <= 0;
            slice_counter <= 0;
            slice_ready <= 0;
        end else begin
            case (state_reg)
                STATE_SLICE_RD: begin
                    ram_read_addr <= slice_counter * SLICE_ROWS + slice_load_counter;
                    slice_buffer[slice_load_counter] <= ram_dout;
                    
                    if (slice_load_counter < SLICE_ROWS - 1) begin
                        slice_load_counter <= slice_load_counter + 1;
                    end else begin
                        slice_load_counter <= 0;
                        slice_ready <= 1;
                    end
                end
                
                STATE_OUTPUT: begin
                    if (slice_ready) begin
                        if (chunk_counter < CHUNKS_PER_SLICE - 1) begin
                            chunk_counter <= chunk_counter + 1;
                        end else begin
                            chunk_counter <= 0;
                            slice_ready <= 0;
                            slice_counter <= slice_counter + 1;
                        end
                    end
                end
                
                default: begin
                    slice_ready <= 0;
                end
            endcase
        end
    end

    // RAM instantiation
    ram_1w1r #(
        .DATA_WIDTH(RAM_DATA_WIDTH),
        .DEPTH(RAM_DEPTH)
    ) weight_buffer_ram (
        .clk(clk),
        .we(ram_we),
        .write_addr(ram_write_addr),
        .read_addr(ram_read_addr),
        .din(ram_din),
        .dout(ram_dout)
    );

endmodule
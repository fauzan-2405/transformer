// b2r_converter.v
// Used to convert the block-per-block output into row-per-row (normal matrix) output

module b2r_converter #(
    parameter WIDTH         = 16,
    parameter FRAC_WIDTH    = 8,
    parameter ROW           = 256,
    parameter COL           = 64,
    parameter BLOCK_SIZE    = 2,
    parameter CHUNK_SIZE    = 4,
    parameter NUM_CORES     = 2
)(
    input                          clk,
    input                          rst,
    input                          start,
    input                          top_valid,
    input  [WIDTH*BLOCK_SIZE*NUM_CORES-1:0] top_data,
    input                          row_ready,

    output reg                     row_valid,
    output reg [WIDTH*COL-1:0]     row_data,
    output reg                     done
);

    // FSM states
    typedef enum reg [1:0] {
        IDLE  = 2'd0,
        WRITE = 2'd1,
        READ  = 2'd2,
        DONE  = 2'd3
    } state_t;

    state_t state, next_state;

    localparam TOTAL_ELEM = ROW * COL;
    localparam ELEM_PER_INPUT = BLOCK_SIZE * NUM_CORES;

    // Write and read pointers
    reg [$clog2(TOTAL_ELEM):0] write_ptr;
    reg [$clog2(ROW):0]        read_row;

    // BRAM storage
    reg [WIDTH-1:0] bram [0:TOTAL_ELEM-1];

    // Flattened top_data unpacking
    integer i;
    always @(posedge clk) begin
        if (top_valid && state == WRITE) begin
            for (i = 0; i < ELEM_PER_INPUT; i = i + 1) begin
                if (write_ptr + i < TOTAL_ELEM) begin
                    bram[write_ptr + i] <= top_data[(i+1)*WIDTH-1 -: WIDTH];
                end
            end
        end
    end

    // FSM
    always @(posedge clk or posedge rst) begin
        if (rst)
            state <= IDLE;
        else
            state <= next_state;
    end

    always @(*) begin
        case (state)
            IDLE:  next_state = start ? WRITE : IDLE;
            WRITE: next_state = (write_ptr >= COL) ? READ : WRITE;
            READ:  next_state = (read_row >= ROW) ? DONE : READ;
            DONE:  next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Write pointer update
    always @(posedge clk) begin
        if (rst || state == IDLE)
            write_ptr <= 0;
        else if (top_valid && state == WRITE)
            write_ptr <= write_ptr + ELEM_PER_INPUT;
    end

    // Read logic
    always @(posedge clk) begin
        if (rst || state == IDLE) begin
            row_valid <= 0;
            read_row <= 0;
            row_data <= 0;
        end else if (state == READ) begin
            if (row_ready) begin
                row_valid <= 1;
                for (i = 0; i < COL; i = i + 1) begin
                    row_data[(i+1)*WIDTH-1 -: WIDTH] <= bram[read_row * COL + i];
                end
                read_row <= read_row + 1;
            end else begin
                row_valid <= 0;
            end
        end else begin
            row_valid <= 0;
        end
    end

    // Done signal
    always @(posedge clk) begin
        if (rst)
            done <= 0;
        else if (state == DONE)
            done <= 1;
        else
            done <= 0;
    end

endmodule

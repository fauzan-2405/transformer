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
    // Localparameters
    localparam STATE_IDLE      = 2'd0;
    localparam STATE_WRITE     = 2'd1;
    localparam STATE_READ      = 2'd2;
    localparam STATE_DONE      = 2'd3;

    // FSM states
    reg [1:0] state_reg, state_next;

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
        if (top_valid && state_reg == STATE_WRITE) begin
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
            state_reg <= STATE_IDLE;
        else
            state_reg <= state_next;
    end

    always @(*) begin
        case (state_reg)
            STATE_IDLE:  state_next = start ? STATE_WRITE : STATE_IDLE;
            STATE_WRITE: state_next = (write_ptr >= COL) ? STATE_READ : STATE_WRITE;
            STATE_READ:  state_next = (read_row >= ROW) ? STATE_DONE : STATE_READ;
            STATE_DONE:  state_next = STATE_IDLE;
            default: state_next = STATE_IDLE;
        endcase
    end

    // Write pointer update
    always @(posedge clk) begin
        if (rst || state_reg == STATE_IDLE)
            write_ptr <= 0;
        else if (top_valid && state_reg == STATE_WRITE)
            write_ptr <= write_ptr + ELEM_PER_INPUT;
    end

    // Read logic
    always @(posedge clk) begin
        if (rst || state_reg == STATE_IDLE) begin
            row_valid <= 0;
            read_row <= 0;
            row_data <= 0;
        end else if (state_reg == STATE_READ) begin
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
        else if (state_reg == STATE_DONE)
            done <= 1;
        else
            done <= 0;
    end

endmodule

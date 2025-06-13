// b2r_converter.v
// Used to convert block-per-block input into row-per-row (normal matrix ordering)

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
    input                          rst_n,           
    input                          start,
    input                          in_valid,
    input  [WIDTH*CHUNK_SIZE*NUM_CORES-1:0] in_data,

    output reg                     out_valid,
    output reg [WIDTH*COL-1:0]     out_data,
    output reg                     done
);
    // FSM
    localparam STATE_IDLE      = 2'd0;
    localparam STATE_WRITE     = 2'd1;
    localparam STATE_READ      = 2'd2;
    localparam STATE_DONE      = 2'd3;

    reg [1:0] state_reg, state_next;

    localparam TOTAL_ELEM = ROW * COL;
    localparam ELEM_PER_INPUT = BLOCK_SIZE * NUM_CORES;

    reg [$clog2(TOTAL_ELEM):0] write_ptr;
    reg [$clog2(ROW):0]        read_row;

    reg [WIDTH-1:0] bram [0:TOTAL_ELEM-1];

    integer i;

    // BRAM Write
    always @(posedge clk) begin
        if (in_valid && state_reg == STATE_WRITE) begin
            for (i = 0; i < ELEM_PER_INPUT; i = i + 1) begin
                if (write_ptr + i < TOTAL_ELEM) begin
                    bram[write_ptr + i] <= in_data[(i+1)*WIDTH-1 -: WIDTH]; // This seems wrong
                end
            end
        end
    end

    always @(posedge clk) begin
        if (!rst_n)
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

    always @(posedge clk) begin
        if (!rst_n)
            write_ptr <= 0;
        else if (in_valid && state_reg == STATE_WRITE)
            write_ptr <= write_ptr + ELEM_PER_INPUT;
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            out_valid <= 0;
            read_row <= 0;
            out_data <= 0;
        end else if (state_reg == STATE_READ) begin
            if (row_ready) begin
                out_valid <= 1;
                for (i = 0; i < COL; i = i + 1) begin
                    out_data[(i+1)*WIDTH-1 -: WIDTH] <= bram[read_row * COL + i];
                end
                read_row <= read_row + 1;
            end else begin
                out_valid <= 0;
            end
        end else begin
            out_valid <= 0;
        end
    end

    always @(posedge clk) begin
        if (!rst_n)
            done <= 0;
        else if (state_reg == STATE_DONE)
            done <= 1;
        else
            done <= 0;
    end

endmodule

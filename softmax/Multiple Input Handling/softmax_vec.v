
module softmax_vec #(
    parameter WIDTH          = 32,
    parameter FRAC_WIDTH     = 16,
    parameter TOTAL_ELEMENTS = 64,   // set small for sim; can be 2754 in HW
    parameter TILE_SIZE      = 8,
    parameter USE_AMULT      = 0     // passed to exp_vec
)(
    input  wire                          clk,
    input  wire                          rst_n,
    input  wire                          start,

    // Input tile stream, MS chunk = element 0
    input  wire [TILE_SIZE*WIDTH-1:0]    X_tile_in,
    input  wire                          tile_in_valid,

    // Output tile stream, MS chunk = element 0
    output reg  [TILE_SIZE*WIDTH-1:0]    Y_tile_out,
    output reg                           tile_out_valid,

    output reg                           done
);
    // Function to do log2
    function integer clog2;
        input integer value;
        integer i;
        begin
            clog2 = 0;
            for (i = value-1; i>0; i = i >> 1)
            clog2 = clog2 + 1;
        end
    endfunction

    // Local Parameters
    localparam [WIDTH-1:0] LN2_Q    = 32'h0000B172; // ~0.693147 in Q16.16
    localparam ADDRW                = clog2(TOTAL_ELEMENTS);
    localparam SUM_WIDTH            = WIDTH +16; // sum_exp width size
    localparam RAM_DATA_WIDTH       = WIDTH * TILE_SIZE;
    localparam RAM_DEPTH            = TOTAL_ELEMENTS / TILE_SIZE;

    // FSM States
    localparam S_IDLE       = 3'd0;
    localparam S_LOAD       = 3'd1; // Pass 0: Store tiles and track max
    localparam S_PASS_1     = 3'd2; // Pass 1: Calculate exp(Xi-max_value), read exp outputs to accumulate sum_exp
    localparam S_LN         = 3'd3; // range reduction to calculate ln
    localparam S_PASS_2     = 3'd4; // Calculate exp(X_i - max_value - sum_exp) and stream the output
    localparam S_DONE       = 3'd5;

    reg [2:0] state_reg, state_next;

    // Counters and registers
    reg [ADDRW:0] wr_count;
    reg [ADDRW:0] rd_count1, rd_count2;
    reg signed [WIDTH-1:0] max_val;
    reg signed [SUM_WIDTH-1:0] sum_exp;
    reg [TILE_SIZE*WIDTH-1:0] exp_in_flat;      // Input data from RAM to exp_vec()
    wire [TILE_SIZE*WIDTH-1:0] exp_out_flat;    // Output data from exp_vec()

    integer i;

    // RAM
    // Maybe add the TDPRAM in here?
    ram_1w2r #(
        .DATA_WIDTH(RAM_DATA_WIDTH),
        .DEPTH(RAM_DEPTH)
    ) temp_buffer_ram (
        .clk(clk),
        .we(tile_in_valid),
        .write_addr(),
        .read_addr0(),
        .read_addr1(),
        .din(X_tile_in),
        .dout0(), // should be to EXP_0
        .dout1()  // should be to EXP_1
    );
    
    // exp_vec unit
    exp_vec #(
        .WIDTH(WIDTH), .FRAC(FRAC_WIDTH), .TILE_SIZE(TILE_SIZE), .USE_AMULT(USE_AMULT)
    ) EXP_0 (
        X_flat(), .Y_flat()
    );

    exp_vec #(
        .WIDTH(WIDTH), .FRAC(FRAC_WIDTH), .TILE_SIZE(TILE_SIZE), .USE_AMULT(USE_AMULT)
    ) EXP_1 (
        X_flat(), .Y_flat()
    )

    

endmodule

// softmax_vec.v
// if TOTAL_ELEMENTS % TILE_SIZE != 0 then we will assume the last tile that contains last elements will be padded to zero
//

module softmax_vec #(
    parameter WIDTH          = 32,
    parameter FRAC_WIDTH     = 16,
    parameter TOTAL_ELEMENTS = 1024,   // set small for sim; can be 2754 in HW
    parameter TILE_SIZE      = 16,
    parameter USE_AMULT      = 0     // passed to exp_vec
)(
    input  wire                          clk,
    input  wire                          rst_n,
    input  wire                          en,

    // Input tile stream, MS chunk = element 0
    input  wire [TILE_SIZE*WIDTH-1:0]    X_tile_in,
    input  wire                          tile_in_valid,

    // Output tile stream, MS chunk = element 0
    output reg  [TILE_SIZE*WIDTH-1:0]    Y_tile_out,
    output reg                           tile_out_valid,

    output reg                           done
);
    // Function to slice the x_flat
    function signed [WIDTH-1:0] slice_flat;
        input [WIDTH*TILE_SIZE-1:0] x_flat;
        input integer idx;
        begin
            slice_flat = x_flat[(TILE_SIZE-1-idx)*WIDTH +: WIDTH];
        end
    endfunction

    // Local Parameters
    localparam [WIDTH-1:0] LN2_Q    = 32'h0000B172; // ~0.693147 in Q16.16
    localparam ADDRE                = $clog2(TOTAL_ELEMENTS);               // to count elements
    localparam ADDRS                = $clog2((TOTAL_ELEMENTS+2)/2);         // to count how many sum operations have done
    localparam COUNT_SUM            = (TOTAL_ELEMENTS % TILE_SIZE) == 0 ? TOTAL_ELEMENTS/TILE_SIZE : ((TOTAL_ELEMENTS/TILE_SIZE) + 1);
    localparam SUM_WIDTH            = WIDTH + $clog2(TOTAL_ELEMENTS + 1); // sum_exp width size
    localparam RAM_DATA_WIDTH       = WIDTH * TILE_SIZE;
    localparam RAM_DEPTH            = (TOTAL_ELEMENTS + TILE_SIZE - 1) / TILE_SIZE;
    localparam ADDRW                = $clog2(RAM_DEPTH);                     // to count words (tiles)

    // FSM States
    localparam S_IDLE       = 3'd0;
    localparam S_LOAD       = 3'd1; // Pass 0: Store tiles and track max
    localparam S_PASS_1     = 3'd2; // Pass 1A: Calculate exp(Xi-max_value), pass it to exp, and calculate sum_exp
    localparam S_LN         = 3'd3; // range reduction to calculate ln
    localparam S_PASS_2     = 3'd4; // Calculate exp(X_i - max_value - sum_exp) and stream the output
    localparam S_DONE       = 3'd5;

    reg [2:0] state_reg, state_next, state_reg_d;
    integer i;

    // Counters and registers
    reg [ADDRE:0] e_loaded;                     // How many elements loaded into RAM
    reg [ADDRE:0] e_read;                       // How many elements consumed in pass1 (for sum)
    reg [ADDRE:0] e_accumulated;                // optional tracker while accumulating

    reg signed [WIDTH-1:0] max_val;             // Max value of Xi (Xi max)

    // ----------------- RAM ----------------
    reg [ADDRW-1:0] ram_read_addr0, ram_read_addr1;
    reg [ADDRW-1:0] ram_write_addr;
    wire [RAM_DATA_WIDTH-1:0] ram_dout0;
    wire [RAM_DATA_WIDTH-1:0] ram_dout1;

    ram_1w2r #(
        .DATA_WIDTH(RAM_DATA_WIDTH),
        .DEPTH(RAM_DEPTH)
    ) temp_buffer_ram (
        .clk(clk),
        .we(tile_in_valid && (state_reg == S_LOAD)),
        .write_addr(ram_write_addr),
        .read_addr0(ram_read_addr0),
        .read_addr1(ram_read_addr1),
        .din(X_tile_in),
        .dout0(ram_dout0),
        .dout1(ram_dout1)
    );

    // ----------------- EXP FUNCTION UNIT ----------------
    // Registers used to pack-unpack
    reg [RAM_DATA_WIDTH-1:0] exp_in_flat0;              // Input data from RAM to exp_vec(): Flattened Xi - max_value
    reg [RAM_DATA_WIDTH-1:0] exp_in_flat1;
    wire [RAM_DATA_WIDTH-1:0] exp_out_flat0;            // Output data from exp_vec()
    wire [RAM_DATA_WIDTH-1:0] exp_out_flat1;
    reg signed [WIDTH-1:0] exp_out_nflat0 [0:TILE_SIZE-1];      // Unflattened exp(xi-max_value) result
    reg signed [WIDTH-1:0] exp_out_nflat1 [0:TILE_SIZE-1];

    // exp function unit to calculate exp(xi-max_value)
    exp_vec #(
        .WIDTH(WIDTH), .FRAC(FRAC_WIDTH), .TILE_SIZE(TILE_SIZE), .USE_AMULT(USE_AMULT)
    ) EXP_0 (
        .X_flat(exp_in_flat0), .Y_flat(exp_out_flat0)
    );

    exp_vec #(
        .WIDTH(WIDTH), .FRAC(FRAC_WIDTH), .TILE_SIZE(TILE_SIZE), .USE_AMULT(USE_AMULT)
    ) EXP_1 (
        .X_flat(exp_in_flat1), .Y_flat(exp_out_flat1)
    );

    // Unpack exp outputs (exp_out_flat) into arrays (exp_out_nflat)
    integer ui;
    always @* begin
        for (ui = 0; ui < TILE_SIZE; ui = ui+1) begin
            exp_out_nflat0[ui] = exp_out_flat0[(TILE_SIZE-1-ui)*WIDTH +: WIDTH];
            exp_out_nflat1[ui] = exp_out_flat1[(TILE_SIZE-1-ui)*WIDTH +: WIDTH];
        end
    end

    // ----------------- SUM_EXP CALCULATIONS ----------------
    reg [SUM_WIDTH-1:0] sum_exp;
    reg [ADDRS-1:0] e_count_sum;
    reg minus, minus_d;

    // Sum-of-elements within a tile
    integer si;
    reg [SUM_WIDTH-1:0] acc0, acc1;
    always @(*) begin
        if (state_reg_d == S_PASS_1) begin
            acc0 = {SUM_WIDTH{1'b0}};
            acc1 = {SUM_WIDTH{1'b0}};
            for (si =0; si < TILE_SIZE; si = si+1) begin
                acc0 = acc0 + {{(SUM_WIDTH-WIDTH){exp_out_nflat0[si][WIDTH-1]}}, exp_out_nflat0[si]};
                acc1 = acc1 + {{(SUM_WIDTH-WIDTH){exp_out_nflat1[si][WIDTH-1]}}, exp_out_nflat1[si]};
            end
        end
    end

    // ----------------- LNU UNIT ----------------
    // Range reduction regs => ln(sum_exp) = ln(m) + k*ln(2)
    wire signed [WIDTH-1:0] ln_sum_out;

    lnu_range_adapter_1to8 #(.WIDTH(WIDTH), .FRAC(FRAC_WIDTH), .SUM_WIDTH(SUM_WIDTH))
        LNU (.x_sum_exp(sum_exp), .y_ln_out(ln_sum_out));

    // ----------------- PASS 2 SUPPORT ----------------
    reg out_phase, out_phase_d;
    reg [ADDRE-1:0] e_streamed;
    integer remain, take_even, take_odd, valid_count;

    // ----------------- FSM NEXT STATE ----------------
    always @(*) begin
        state_next = state_reg;
        case (state_reg)
            S_IDLE: begin
                //state_next = (en && start) ? S_LOAD : S_IDLE;
                state_next = (en) ? S_LOAD : S_IDLE;
            end

            S_LOAD: // Pass 0: Store tiles and track max
            begin
                state_next = (e_loaded == TOTAL_ELEMENTS) ? S_PASS_1 : S_LOAD;
            end

            S_PASS_1: // Pass 1: Read from the RAM, calculate the exp, and sum exp
            begin
                state_next = (e_count_sum == COUNT_SUM) ? S_LN : S_PASS_1;
            end

            S_LN: // LN: Calculate the ln(sum_exp)
            begin
                state_next = S_PASS_2;
            end

            S_PASS_2:
            begin
                state_next = (remain == 0) ? S_DONE : S_PASS_2;
            end

            S_DONE:
            begin
                state_next = (!rst_n) ? S_IDLE: S_DONE;
            end
        endcase

    end

    // ----------------- FSM SEQUENTIAL ----------------
    always @(posedge clk) begin
        if (!rst_n) begin
            state_reg       <= S_IDLE;
            state_reg_d     <= S_IDLE;
            e_loaded        <= {ADDRE{1'b0}};
            e_read          <= {ADDRE{1'b0}};
            e_accumulated   <= {ADDRE{1'b0}};

            ram_write_addr  <= {ADDRW{1'b0}};
            ram_read_addr0  <= {ADDRW{1'b0}}; // even
            ram_read_addr1  <= (RAM_DEPTH>1) ? {{(ADDRW-1){1'b0}},1'b1} : {ADDRW{1'b0}}; // odd 1

            max_val         <= 32'sh8000_0000; // Very negative
            minus           <= 0;
            minus_d         <= 0;
            e_count_sum     <= {ADDRS{1'b0}};
            sum_exp         <= {SUM_WIDTH{1'b0}};

            tile_out_valid  <= 0;
            out_phase       <= 0;
            out_phase_d     <= 0;
            done            <= 0;

            e_streamed      <= {ADDRE{1'b0}};
            take_even       <= 0;
            take_odd        <= 0;
            valid_count     <= 0;

            Y_tile_out      <= {RAM_DATA_WIDTH{1'b0}};

            exp_in_flat0    <= {RAM_DATA_WIDTH{1'b0}};
            exp_in_flat1    <= {RAM_DATA_WIDTH{1'b0}};
        end else if (en) begin
            state_reg   <= state_next;
            state_reg_d <= state_reg;
            out_phase_d <= out_phase;
            minus_d     <= minus;

            // Case for state_next
            case (state_next)
                S_PASS_1: begin
                    // RAM read addresses before moving on to S_PASS_1
                    ram_read_addr0     <= {ADDRW{1'b0}}; // 0
                    ram_read_addr1     <= (RAM_DEPTH>1) ? {{(ADDRW-1){1'b0}},1'b1} : {ADDRW{1'b0}};
                    valid_count = (TOTAL_ELEMENTS > e_read) ? (TOTAL_ELEMENTS - e_read) : 0;
                    // Split accross even and odd
                    if (valid_count >= 2*TILE_SIZE) begin
                        take_even = TILE_SIZE;
                        take_odd  = TILE_SIZE;
                    end else if (valid_count > TILE_SIZE) begin
                        take_even = TILE_SIZE;
                        take_odd  = valid_count - TILE_SIZE;
                    end else begin
                        take_even = valid_count;
                        take_odd  = 0;
                    end

                    // advance read counters/addresses
                    e_read <= e_read + take_even + take_odd;

                    // Bump even/odd tile addresses if we actually consumed a full tile from each
                    if (take_even == TILE_SIZE)
                        if (ram_read_addr0 + 2 <= (TOTAL_ELEMENTS / TILE_SIZE)) ram_read_addr0 <= ram_read_addr0 + 2; // next even
                    if (take_odd == TILE_SIZE)
                        if (ram_read_addr1 + 2 < (TOTAL_ELEMENTS / TILE_SIZE)) ram_read_addr1  <= ram_read_addr1  + 2; // next odd

                    minus        <= (ram_read_addr1 == ram_read_addr0+1);
                end

                S_PASS_2: begin
                    remain = (TOTAL_ELEMENTS > e_streamed) ? (TOTAL_ELEMENTS - e_streamed) : 0;

                    // Decide how many to take from each side this "fetch"
                    if (remain >= 2*TILE_SIZE) begin
                        take_even <= TILE_SIZE;
                        take_odd  <= TILE_SIZE;
                    end else if (remain > TILE_SIZE) begin
                        take_even <= TILE_SIZE;
                        take_odd  <= remain - TILE_SIZE;
                    end else begin
                        take_even <= remain;
                        take_odd  <= remain;
                    end

                    if (take_even == TILE_SIZE)
                        if (ram_read_addr0 + 2 <= (TOTAL_ELEMENTS / TILE_SIZE)) ram_read_addr0 <= ram_read_addr0 + 2; // next even
                    if (take_odd == TILE_SIZE)
                        if (ram_read_addr1 + 2 < (TOTAL_ELEMENTS / TILE_SIZE)) ram_read_addr1  <= ram_read_addr1  + 2; // next odd\

                    // Emit per-tile stream:
                    if (out_phase == 0) begin
                        e_streamed      <= e_streamed + take_even;
                        if (state_reg_d == S_PASS_2) begin
                            Y_tile_out      <= exp_out_flat1;
                            tile_out_valid  <= 1'b1;
                        end
                        out_phase       <= (take_even != 0) ? 1'b1 : 1'b0; // if odd valid then emit it next
                    end else begin
                        e_streamed      <= e_streamed + take_odd;
                        if (state_reg_d == S_PASS_2)begin
                            Y_tile_out      <= exp_out_flat0;
                            tile_out_valid  <= 1'b1;
                        end
                        out_phase       <= 1'b0;
                    end
                end
            endcase

            // Case for state_reg
            case (state_reg)
                S_LOAD: begin       // Pass 0: Store tiles and track max
                    // Write tile into RAM while looking for the max_value
                    if (tile_in_valid && (e_loaded < TOTAL_ELEMENTS)) begin
                        for (i = 0; i < TILE_SIZE; i = i+1) begin
                            if ((e_loaded + i) < TOTAL_ELEMENTS) begin
                                // Element i of this tile
                                if (slice_flat(X_tile_in, i) > max_val) begin
                                    max_val <= slice_flat(X_tile_in, i);
                                end
                            end
                        end
                        // Increment element and write address
                        e_loaded       <= e_loaded + ((e_loaded + TILE_SIZE <= TOTAL_ELEMENTS) ? TILE_SIZE
                                                     : (TOTAL_ELEMENTS - e_loaded));
                        ram_write_addr <= ram_write_addr + 1;
                    end
                end

                S_PASS_1: begin    // Pass 1: Calculate the exp and sum_exp
                    // Pack into exp_in_flat
                    for (i = 0; i < TILE_SIZE; i=i+1) begin
                        exp_in_flat0[(TILE_SIZE-1-i)*WIDTH +: WIDTH] <= slice_flat(ram_dout0, i) - max_val;
                        exp_in_flat1[(TILE_SIZE-1-i)*WIDTH +: WIDTH] <= slice_flat(ram_dout1, i) - max_val;
                    end
                end

                S_LN: begin         // LN: Calculate the natural logarithmic
                    e_streamed   <= {ADDRE+1{1'b0}};
                    out_phase    <= 1'b0;
                    tile_out_valid <= 1'b0;
                end

                S_PASS_2: begin     // Pass_2: Calculate each exp(Xi - max_value -ln(sum_exp))
                    for (i = 0; i < TILE_SIZE; i = i+1) begin
                        exp_in_flat0[(TILE_SIZE-1-i)*WIDTH +: WIDTH] <= slice_flat(ram_dout0, i) - max_val - ln_sum_out;
                        exp_in_flat1[(TILE_SIZE-1-i)*WIDTH +: WIDTH] <= slice_flat(ram_dout1, i) - max_val - ln_sum_out;
                    end
                    if (state_next == S_DONE) begin
                        tile_out_valid  <= 0;
                        done            <= 1;
                    end
                end

                S_DONE: begin
                end
            endcase

            // Case for state_reg_d
            case (state_reg_d)
                S_PASS_1: begin
                    if (e_count_sum < COUNT_SUM) begin
                       if (minus_d) begin
                            sum_exp <= sum_exp + acc0 + acc1;
                            e_count_sum <= e_count_sum + 2;
                        end else begin
                            sum_exp <= sum_exp + acc0;
                            e_count_sum <= e_count_sum + 1;
                        end
                    end
                end
            endcase
        end
    end
endmodule

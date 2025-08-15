
module softmax_vec #(
    parameter WIDTH          = 32,
    parameter FRAC           = 16,
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
    // ============================================
    // Local helpers
    // ============================================
    function integer clog2;
        input integer value;
        integer i;
        begin
            clog2 = 0;
            for (i = value-1; i > 0; i = i >> 1)
                clog2 = clog2 + 1;
        end
    endfunction

    // ln(2) in Q(FRAC)
    localparam [WIDTH-1:0] LN2_Q = 32'h0000B172; // ~0.693147 in Q16.16

    localparam ADDRW = clog2(TOTAL_ELEMENTS);

    // ============================================
    // Simple RAM for X (inferred BRAM)
    // ============================================
    reg signed [WIDTH-1:0] ram_x [0:TOTAL_ELEMENTS-1];

    // ============================================
    // FSM states
    // ============================================
    localparam S_IDLE     = 3'd0;
    localparam S_LOAD     = 3'd1;  // Pass 0: store tiles, track max
    localparam S_PASS1_A  = 3'd2;  // Pass 1: form Xi-max (drive exp_vec)
    localparam S_PASS1_B  = 3'd3;  // Pass 1: read exp outputs, accumulate sum
    localparam S_LN       = 3'd4;  // Range reduction + lnu_scalar
    localparam S_PASS2_A  = 3'd5;  // Pass 2: form Xi-max-ln_sum (drive exp_vec)
    localparam S_PASS2_B  = 3'd6;  // Pass 2: read exp outputs, stream out
    localparam S_DONE     = 3'd7;

    reg [2:0] state, state_n;

    // ============================================
    // Counters / pointers
    // ============================================
    reg [ADDRW:0] wr_count;
    reg [ADDRW:0] rd_count1;
    reg [ADDRW:0] rd_count2;

    // ============================================
    // Max tracker and sum accumulator
    // ============================================
    reg  signed [WIDTH-1:0] max_val;
    localparam SUMW = WIDTH + 16;
    reg  signed [SUMW-1:0]  sum_exp_acc;

    // ============================================
    // Tile buffers
    // ============================================
    integer i;
    reg signed [WIDTH-1:0] Xnorm_buf [0:TILE_SIZE-1]; // drives exp_vec
    reg signed [WIDTH-1:0] EXP_buf   [0:TILE_SIZE-1]; // captures exp_vec out

    // Flatten pack/unpack wiring
    reg  [TILE_SIZE*WIDTH-1:0] exp_in_flat;
    wire [TILE_SIZE*WIDTH-1:0] exp_out_flat;

    // Pack Xnorm_buf -> exp_in_flat
    always @* begin
        for (i = 0; i < TILE_SIZE; i = i + 1) begin
            integer msb, lsb;
            msb = (TILE_SIZE-1-i)*WIDTH + (WIDTH-1);
            lsb = (TILE_SIZE-1-i)*WIDTH;
            exp_in_flat[msb:lsb] = Xnorm_buf[i];
        end
    end

    // Unpack exp_out_flat -> EXP_buf
    always @* begin
        for (i = 0; i < TILE_SIZE; i = i + 1) begin
            integer msb, lsb;
            msb = (TILE_SIZE-1-i)*WIDTH + (WIDTH-1);
            lsb = (TILE_SIZE-1-i)*WIDTH;
            EXP_buf[i] = exp_out_flat[msb:lsb];
        end
    end

    // ============================================
    // Shared EXP unit (combinational)
    // ============================================
    exp_vec #(
        .WIDTH(WIDTH),
        .FRAC(FRAC),
        .TILE_SIZE(TILE_SIZE),
        .USE_AMULT(USE_AMULT)
    ) EXP_TILE (
        .X_flat(exp_in_flat),
        .Y_flat(exp_out_flat)
    );

    // ============================================
    // LNU scalar (combinational, expects [1,2))
    // ============================================
    wire signed [WIDTH-1:0] ln_m;
    reg  signed [WIDTH-1:0] m_norm;
    reg  signed [WIDTH-1:0] ln_sum;
    reg  [15:0]             k_shift;

    lnu_scalar #(
        .WIDTH(WIDTH),
        .FRAC(FRAC)
    ) LNU_I (
        .x_in(m_norm),
        .y_out(ln_m)
    );

    // ============================================
    // Helpers
    // ============================================
    // Slice element i from flattened vector (MS chunk = element 0)
    function [WIDTH-1:0] slice_flat;
        input [TILE_SIZE*WIDTH-1:0] vec;
        input integer idx;
        integer msb, lsb;
        begin
            msb = (TILE_SIZE-1-idx)*WIDTH + (WIDTH-1);
            lsb = (TILE_SIZE-1-idx)*WIDTH;
            slice_flat = vec[msb:lsb];
        end
    endfunction

    // Find MSB index (unsigned); returns -1 if zero
    function integer msb_index;
        input [WIDTH-1:0] u;
        integer k;
        begin
            msb_index = -1;
            for (k = WIDTH-1; k >= 0; k = k - 1)
                if (u[k]) begin
                    msb_index = k;
                    k = -1; // break
                end
        end
    endfunction

    // ============================================
    // FSM sequential
    // ============================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= S_IDLE;
            wr_count     <= {ADDRW+1{1'b0}};
            rd_count1    <= {ADDRW+1{1'b0}};
            rd_count2    <= {ADDRW+1{1'b0}};
            max_val      <= 32'sh8000_0000; // very negative
            sum_exp_acc  <= {SUMW{1'b0}};
            tile_out_valid <= 1'b0;
            done         <= 1'b0;
            ln_sum       <= {WIDTH{1'b0}};
            m_norm       <= {WIDTH{1'b0}};
            k_shift      <= 16'd0;
            // Clear Xnorm_buf
            for (i = 0; i < TILE_SIZE; i = i + 1) begin
                Xnorm_buf[i] <= {WIDTH{1'b0}};
            end
        end else begin
            state <= state_n;

            case (state)
                // ---------------------------
                S_IDLE: begin
                    tile_out_valid <= 1'b0;
                    done           <= 1'b0;
                    if (start) begin
                        wr_count    <= {ADDRW+1{1'b0}};
                        rd_count1   <= {ADDRW+1{1'b0}};
                        rd_count2   <= {ADDRW+1{1'b0}};
                        max_val     <= 32'sh8000_0000;
                        sum_exp_acc <= {SUMW{1'b0}};
                    end
                end

                // ---------------------------
                // PASS 0: load tiles and track max
                S_LOAD: begin
                    if (tile_in_valid) begin
                        for (i = 0; i < TILE_SIZE; i = i + 1) begin
                            integer addr0;
                            reg signed [WIDTH-1:0] xi;
                            addr0 = wr_count + i;
                            if (addr0 < TOTAL_ELEMENTS) begin
                                xi = slice_flat(X_tile_in, i);
                                ram_x[addr0] <= xi;
                                if (xi > max_val) max_val <= xi;
                            end
                        end
                        wr_count <= wr_count + TILE_SIZE[ADDRW:0];
                    end
                end

                // ---------------------------
                // PASS 1A: drive exp_vec with (Xi - max_val)
                S_PASS1_A: begin
                    for (i = 0; i < TILE_SIZE; i = i + 1) begin
                        integer addr1;
                        addr1 = rd_count1 + i;
                        if (addr1 < TOTAL_ELEMENTS) begin
                            Xnorm_buf[i] <= ram_x[addr1] - max_val;
                        end else begin
                            Xnorm_buf[i] <= {WIDTH{1'b0}};
                        end
                    end
                end

                // PASS 1B: read exp outputs, accumulate sum
                S_PASS1_B: begin
                    for (i = 0; i < TILE_SIZE; i = i + 1) begin
                        integer addr1b;
                        addr1b = rd_count1 + i;
                        if (addr1b < TOTAL_ELEMENTS) begin
                            // widen sign for accumulation
                            sum_exp_acc <= sum_exp_acc
                                + {{(SUMW-WIDTH){EXP_buf[i][WIDTH-1]}}, EXP_buf[i]};
                        end
                    end
                    rd_count1 <= rd_count1 + TILE_SIZE[ADDRW:0];
                end

                // ---------------------------
                // LN: range reduce sum_exp_acc to [1,2), compute ln_sum
                S_LN: begin
                    reg [WIDTH-1:0] sum_clip_u;
                    integer pos, ktmp;
                    // Truncate to WIDTH (sum is non-negative in softmax)
                    sum_clip_u = sum_exp_acc[WIDTH-1:0];

                    // Handle zero (pathological) to avoid ln(0)
                    if (sum_clip_u == {WIDTH{1'b0}}) begin
                        m_norm  <= 32'h00010000; // 1.0 in Q16.16
                        k_shift <= 16'd0;
                        ln_sum  <= 32'h80000000; // -inf approx (very negative)
                    end else begin
                        pos   = msb_index(sum_clip_u);
                        ktmp  = pos - FRAC; // normalize to [1,2)
                        if (ktmp >= 0)
                            m_norm <= $signed(sum_clip_u) >>> ktmp;
                        else
                            m_norm <= $signed(sum_clip_u) <<< (-ktmp);
                        k_shift <= ktmp[15:0];

                        // ln_sum = ln(m_norm) + k * ln(2)
                        // Careful to register after lnu combinationally settles
                        ln_sum <= ln_m + $signed({{(WIDTH-16){k_shift[15]}}, k_shift}) * $signed(LN2_Q);
                    end
                end

                // ---------------------------
                // PASS 2A: drive exp_vec with (Xi - max - ln_sum)
                S_PASS2_A: begin
                    for (i = 0; i < TILE_SIZE; i = i + 1) begin
                        integer addr2;
                        addr2 = rd_count2 + i;
                        if (addr2 < TOTAL_ELEMENTS)
                            Xnorm_buf[i] <= ram_x[addr2] - max_val - ln_sum;
                        else
                            Xnorm_buf[i] <= {WIDTH{1'b0}};
                    end
                    tile_out_valid <= 1'b0;
                end

                // PASS 2B: read exp outputs and stream the tile
                S_PASS2_B: begin
                    reg [TILE_SIZE*WIDTH-1:0] y_pack;
                    // Pack EXP_buf into Y_tile_out
                    y_pack = {TILE_SIZE*WIDTH{1'b0}};
                    for (i = 0; i < TILE_SIZE; i = i + 1) begin
                        integer msb, lsb;
                        msb = (TILE_SIZE-1-i)*WIDTH + (WIDTH-1);
                        lsb = (TILE_SIZE-1-i)*WIDTH;
                        y_pack[msb:lsb] = EXP_buf[i];
                    end
                    Y_tile_out    <= y_pack;
                    tile_out_valid <= 1'b1;
                    rd_count2     <= rd_count2 + TILE_SIZE[ADDRW:0];
                end

                // ---------------------------
                S_DONE: begin
                    tile_out_valid <= 1'b0;
                    done           <= 1'b1;
                end

            endcase
        end
    end

    // ============================================
    // FSM next-state
    // ============================================
    always @* begin
        state_n = state;
        case (state)
            S_IDLE: begin
                if (start) state_n = S_LOAD;
            end

            S_LOAD: begin
                if (wr_count >= TOTAL_ELEMENTS) state_n = S_PASS1_A;
                else                             state_n = S_LOAD;
            end

            // Pass1 two-cycle per tile
            S_PASS1_A: begin
                state_n = S_PASS1_B;
            end
            S_PASS1_B: begin
                if (rd_count1 >= TOTAL_ELEMENTS) state_n = S_LN;
                else                             state_n = S_PASS1_A;
            end

            S_LN: begin
                state_n = S_PASS2_A;
            end

            // Pass2 two-cycle per tile
            S_PASS2_A: begin
                state_n = S_PASS2_B;
            end
            S_PASS2_B: begin
                if (rd_count2 >= TOTAL_ELEMENTS) state_n = S_DONE;
                else                             state_n = S_PASS2_A;
            end

            S_DONE: begin
                state_n = S_IDLE;
            end

            default: state_n = S_IDLE;
        endcase
    end

endmodule

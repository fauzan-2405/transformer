// softmax_vec.v 

module softmax_vec #(
    parameter WIDTH          = 32,
    parameter FRAC_WIDTH     = 16,
    parameter TOTAL_ELEMENTS = 64,   // set small for sim; can be 2754 in HW
    parameter TILE_SIZE      = 8,
    parameter USE_AMULT      = 0     // passed to exp_vec
)(
    input  wire                          clk,
    input  wire                          rst_n,
    input  wire                          en, 
    input  wire                          start,

    // Input tile stream, MS chunk = element 0
    input  wire [TILE_SIZE*WIDTH-1:0]    X_tile_in,
    input  wire                          tile_in_valid,

    // Output tile stream, MS chunk = element 0
    output reg  [TILE_SIZE*WIDTH-1:0]    Y_tile_out,
    output reg                           tile_out_valid,

    output reg                           done
);
    // Function to slice the x_flat
    function [WIDTH-1:0] slice_flat;
        input [WIDTH*TILE_SIZE-1:0] x_flat;
        input integer idx;
        integer msb,lsb;
        begin
            msb = (TILE_SIZE-1-idx)*WIDTH + (WIDTH-1);
            lsb = (TILE_SIZE-1-idx)*WIDTH;
            slice_flat = x_flat[msb:lsb];
        end
    endfunction

    // Local Parameters
    localparam [WIDTH-1:0] LN2_Q    = 32'h0000B172; // ~0.693147 in Q16.16
    localparam ADDRE                = $clog2(TOTAL_ELEMENTS);               // to count elements
    localparam SUM_WIDTH            = WIDTH + $clog2(TOTAL_ELEMENTS + 1); // sum_exp width size
    localparam RAM_DATA_WIDTH       = WIDTH * TILE_SIZE;
    localparam RAM_DEPTH            = TOTAL_ELEMENTS / TILE_SIZE;
    localparam ADDRW                = $clog2(RAM_DEPTH);                     // to count words (tiles)

    // FSM States
    localparam S_IDLE       = 3'd0;
    localparam S_LOAD       = 3'd1; // Pass 0: Store tiles and track max
    localparam S_PASS_1     = 3'd2; // Pass 1A: Calculate exp(Xi-max_value), pass it to exp, and calculate sum_exp
    localparam S_LN         = 3'd3; // range reduction to calculate ln
    localparam S_PASS_2     = 3'd4; // Calculate exp(X_i - max_value - sum_exp) and stream the output
    localparam S_DONE       = 3'd5;

    reg [2:0] state_reg, state_next;
 
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
    reg signed [WIDTH-1:0] X_norm_0 [0:TILE_SIZE-1];            // Unflattened xi - max_value
    reg signed [WIDTH-1:0] X_norm_1 [0:TILE_SIZE-1];
    reg [RAM_DATA_WIDTH-1:0] exp_in_flat0;              // Input data from RAM to exp_vec(): Flattened Xi - max_value
    reg [RAM_DATA_WIDTH-1:0] exp_in_flat1;    
    reg [RAM_DATA_WIDTH-1:0] xi_min_maxvalue [0:RAM_DEPTH-1];     // Registers to hold flattened xi - max_value
    wire [RAM_DATA_WIDTH-1:0] exp_out_flat0;            // Output data from exp_vec()
    wire [RAM_DATA_WIDTH-1:0] exp_out_flat1;
    reg signed [WIDTH-1:0] exp_out_nflat0 [0:TILE_SIZE-1];      // Unflattened exp(xi-max_value) result
    reg signed [WIDTH-1:0] exp_out_nflat1 [0:TILE_SIZE-1];

    // exp function unit to calculate exp(xi-max_value)
    exp_vec #(
        .WIDTH(WIDTH), .FRAC(FRAC_WIDTH), .TILE_SIZE(TILE_SIZE), .USE_AMULT(USE_AMULT)
    ) EXP_0 (
        X_flat(exp_in_flat0), .Y_flat(exp_out_flat0)
    );

    exp_vec #(
        .WIDTH(WIDTH), .FRAC(FRAC_WIDTH), .TILE_SIZE(TILE_SIZE), .USE_AMULT(USE_AMULT)
    ) EXP_1 (
        X_flat(exp_in_flat1), .Y_flat(exp_out_flat1)
    );

    // Unpack exp outputs (exp_out_flat) into arrays (exp_out_nflat)
    genvar ui;
    generate
        for (ui = 0; ui < TILE_SIZE; ui = ui+1) begin
            localparam integer MSB = (TILE_SIZE-1-ui)*WIDTH + (WIDTH-1);
            localparam integer LSB = (TILE_SIZE-1-ui)*WIDTH;
            assign exp_out_nflat0[ui] = exp_out_flat0[MSB:LSB];
            assign exp_out_nflat1[ui] = exp_out_flat1[MSB:LSB];
        end
    endgenerate

    // ----------------- SUM_EXP CALCULATIONS ----------------
    reg [SUM_WIDTH-1:0] sum_exp;
    reg [SUM_WIDTH-1:0] sum_tile0;
    reg [SUM_WIDTH-1:0] sum_tile1;

    // Sum-of-elements within a tile
    integer si;
    reg [SUM_WIDTH-1:0] acc0, acc1;
    always @(*) begin
        acc0 = {SUM_WIDTH{1'b0}};
        acc1 = {SUM_WIDTH{1'b0}};
        for (si =0; si < TILE_SIZE; si = si+1) begin
            acc0 = acc0 + {{(SUM_WIDTH-WIDTH){exp_out_nflat0[si][WIDTH-1]}}, exp_out_nflat0[si]};
            acc1 = acc1 + {{(SUM_WIDTH-WIDTH){exp_out_nflat1[si][WIDTH-1]}}, exp_out_nflat1[si]};
        end
    end

    assign sum_tile0 = acc0;
    assign sum_tile1 = acc1;

    // ----------------- LNU UNIT ----------------
    // Range reduction regs => ln(sum_exp) = ln(m) + k*ln(2)  
    reg signed [WIDTH-1:0] ln_sum_out;

    lnu_range_adapter_1to8 #(.WIDTH(WIDTH), .FRAC(FRAC_WIDTH))
        LNU (.x_sum_exp(sum_exp), .y_ln_out(ln_sum_out));

    // ----------------- FSM NEXT STATE ----------------
    always @(*) begin
        state_next = state_reg;
        case (state_reg) 
            S_IDLE: begin
                state_next = (en && start) ? S_LOAD : S_IDLE;
            end

            S_LOAD: // Pass 0: Store tiles and track max
            begin
                state_next = (e_loaded >= TOTAL_ELEMENTS) ? S_PASS_1: S_LOAD;
            end

            S_PASS_1: // Pass 1: Read from the RAM, calculate the exp, and sum exp
            begin
                state_next = (e_read >= TOTAL_ELEMENTS) ? S_LN : S_PASS_1;
            end

            S_LN: // LN: Calculate the ln(sum_exp)
            begin
                state_next = S_PASS_2;
            end

            S_PASS_2:
            begin
                state_next
            end
        endcase

    end

    // ----------------- FSM SEQUENTIAL ----------------
    integer i;
    integer msb, lsb;

    always @(posedge clk) begin
        if (!rst_n) begin
            state_reg       <= S_IDLE;
            e_loaded        <= {ADDRE{1'b0}};
            e_read          <= {ADDRE{1'b0}};
            e_accumulated   <= {ADDRE{1'b0}};

            ram_read_addr0  <= {ADDRW{1'b0}};
            ram_read_addr1  <= {ADDRW{1'b0}}; // even
            ram_write_addr  <= (RAM_DEPTH>1) ? {{(ADDRW-1){1'b0}},1'b1} : {ADDRW{1'b0}}; // odd 1

            max_val         <= 32'sh8000_0000; // Very negative
            sum_exp         <= {SUM_WIDTH{1'b0}};

            tile_out_valid  <= 0;
            done            <= 0;

            ln_sum_out      <= {WIDTH(1'b0)}; 

            exp_in_flat0    <= {RAM_DATA_WIDTH(1'b0)};
            exp_in_flat1    <= {RAM_DATA_WIDTH(1'b0)};
            for (i = 0; i < TILE_SIZE; i = i + 1) begin
                X_norm_0[i] <= {WIDTH{1'b0}};
                X_norm_1[i] <= {WIDTH{1'b0}};
            end
        end else if (en) begin
            state_reg <= state_next;
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

                    // Reset all before S_PASS_1
                    if (e_loaded >= TOTAL_ELEMENTS) begin
                        e_read             <= {ADDRE+1{1'b0}};
                        ram_read_addr0     <= {ADDRW{1'b0}}; // 0
                        ram_read_addr1     <= (RAM_DEPTH>1) ? {{(ADDRW-1){1'b0}},1'b1} : {ADDRW{1'b0}};
                        sum_exp            <= {SUM_WIDTH{1'b0}};
                    end
                end

                S_PASS_1: begin    // Pass 1: Calculate the exp and sum_exp
                    // Calculate each xi-max_value
                    for (i=0; i < TILE_SIZE; i = i +1) begin
                        X_norm_0[i] <= slice_flat(ram_dout0, i) - max_val;
                        X_norm_1[i] <= slice_flat(ram_dout1, i) - max_val;
                    end

                    // Pack into exp_in_flat
                    for (i = 0; i < TILE_SIZE; i=i+1) begin
                        msb = (TILE_SIZE-1-i)*WIDTH + (WIDTH-1);
                        lsb = (TILE_SIZE-1-i)*WIDTH;
                        exp_in_flat0[msb:lsb] <= X_norm_0[i];
                        exp_in_flat1[msb:lsb] <= X_norm_1[i];
                    end

                    // Read exp outputs and accumulate sum
                    begin: ACCUMULATE
                        integer valid_count, take_even, take_odd, k; // valid count = how many elements left to process in total
                        valid_count = (TOTAL_ELEMENTS > e_read) ? (TOTAL_ELEMENTS - e_read) : 0;
                        // Split accross even and odd
                        if (valid_count >= 2*TILE_SIZE) begin
                            take_even = TILE_SIZE;
                            take_odd  = TILE_SIZE;
                        end else if (valid_count >) TILE_SIZE begin
                            take_even = TILE_SIZE;
                            take_odd  = valid_count - TILE_SIZE;
                        end else begin
                            take_even = valid_count;
                            take_odd  = 0;
                        end

                        // Add even first
                        for (k=0; k < take_even; k = k+1) begin
                            sum_exp <= sum_exp + {{(SUM_WIDTH-WIDTH){exp_out_nflat0[k][WIDTH-1]}}, exp_out_nflat0[k]};
                        end
                        // then odd
                        for (k = 0; k < take_odd; k = k + 1) begin
                            sum_exp <= sum_exp + {{(SUM_WIDTH-WIDTH){exp_out_nflat1[k][WIDTH-1]}}, exp_out_nflat1[k]};
                        end

                        // advance read counters/addresses
                        e_read <= e_read + take_even + take_odd;

                        // Bump even/odd tile addresses if we actually consumed a full tile from each
                        if (take_even == TILE_SIZE)
                            ram_read_addr0 <= ram_read_addr0 + 2; // next even
                        if (take_odd == TILE_SIZE)
                            ram_read_addr1  <= ram_read_addr1  + 2; // next odd
                    end
                end

                S_LN: begin         // LN: Calculate the natural logarithmic
                    // For now, there is nothing to write on this because it purely combinational
                end

                S_PASS_2: begin     // Pass_2: Calculate each exp(Xi - max_value -)
                end


            endcase
        end


    end

    

endmodule

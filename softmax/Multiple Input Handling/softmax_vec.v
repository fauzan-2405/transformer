
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
    // Function to do log2 
    /*
    function integer clog2;
        input integer value;
        integer i;
        begin
            clog2 = 0;
            for (i = value-1; i>0; i = i >> 1)
            clog2 = clog2 + 1;
        end
    endfunction */

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
    localparam SUM_WIDTH            = WIDTH +16; // sum_exp width size
    localparam RAM_DATA_WIDTH       = WIDTH * TILE_SIZE;
    localparam RAM_DEPTH            = TOTAL_ELEMENTS / TILE_SIZE;
    localparam ADDRW                = $clog2(RAM_DEPTH)                     // to count words (tiles)

    // FSM States
    localparam S_IDLE       = 3'd0;
    localparam S_LOAD       = 3'd1; // Pass 0: Store tiles and track max
    localparam S_PASS_1A    = 3'd2; // Pass 1A: Calculate exp(Xi-max_value) 
    localparam S_PASS_1B    = 3'd3; // Pass 1B: Read exp outputs to accumulate sum_exp
    localparam S_LN         = 3'd4; // range reduction to calculate ln
    localparam S_PASS_2     = 3'd5; // Calculate exp(X_i - max_value - sum_exp) and stream the output
    localparam S_DONE       = 3'd6;

    reg [2:0] state_reg, state_next;

    // Counters and registers
    reg [ADDRE-1:0] e_count;                    // For counting the total of element that has been processed in S_LOAD
    reg signed [WIDTH-1:0] xi;                  // Each of the element (Xi)
    reg signed [WIDTH-1:0] max_val;             // Max value of Xi (Xi max)
    // Registers used to pack-unpack
    reg signed [WIDTH-1:0] X_norm_0 [0:TILE_SIZE-1];
    reg signed [WIDTH-1:0] X_norm_1 [0:TILE_SIZE-1];
    reg signed [SUM_WIDTH-1:0] sum_exp;
    reg [RAM_DATA_WIDTH-1:0] exp_in_flat0;      // Input data from RAM to exp_vec(): Flattened Xi - max_value
    reg [RAM_DATA_WIDTH-1:0] exp_in_flat1;    
    reg [RAM_DATA_WIDTH-1:0] xi_min_maxvalue [0:RAM_DEPTH-1];     // Registers to hold flattened xi - max_value
    wire [RAM_DATA_WIDTH-1:0] exp_out_flat0;    // Output data from exp_vec()
    wire [RAM_DATA_WIDTH-1:0] exp_out_flat1;

    // Integer for counting
    integer i, j;
    // Integer for msb n lsb
    integer msb, lsb;

    // ----------------- RAM ----------------
    reg [ADDRW-1:0] ram_read_addr0, ram_read_addr1;
    reg [ADDRW-1:0] ram_write_addr;
    reg [RAM_DATA_WIDTH-1:0] ram_dout0;
    reg [RAM_DATA_WIDTH-1:0] ram_dout1;
    ram_1w2r #(
        .DATA_WIDTH(RAM_DATA_WIDTH),
        .DEPTH(RAM_DEPTH)
    ) temp_buffer_ram (
        .clk(clk),
        .we(tile_in_valid),
        .write_addr(ram_write_addr),
        .read_addr0(ram_read_addr0),
        .read_addr1(ram_read_addr1),
        .din(X_tile_in),
        .dout0(ram_dout0), 
        .dout1(ram_dout1)  
    );
    
    // ----------------- EXP FUNCTION UNIT ----------------
    // Pack X_norm_0 and 1 to exp_in_flat0 and exp_in_flat1
    // and assign exp_in_flat0 & 1 to xi_min_maxvalue 
    always @(*) begin
        for (i=0; i < TILE_SIZE; i = i+1) begin
            msb = (TILE_SIZE-1-i)*WIDTH + (WIDTH-1);
            lsb = (TILE_SIZE-1-i)*WIDTH;
            exp_in_flat0 = X_norm_0[msb:lsb];
            exp_in_flat1 = X_norm_1[msb:lsb];
        end
        for (j=0; j < RAM_DEPTH/2; j = j+1) begin
            xi_min_maxvalue[j*2]    = exp_in_flat0[i]; // Even addresses
            xi_min_maxvalue[j*2+1]  = exp_in_flat1[i]; // Odd addresses
        end
    end

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

    // ----------------- LNU UNIT ----------------
    // Range reduction regs => ln(sum_exp) = ln(m) + k*ln(2)
    wire signed [WIDTH-1:0] ln_m;
    reg signed [WIDTH-1:0] m_norm;    
    reg signed [WIDTH-1:0] ln_sum;
    reg signed [15:0]      k_shift;

    lnu_scalar #(
        .WIDTH(WIDTH), .FRAC(FRAC_WIDTH)
    ) LNU_0 (
        x_in(), .y_out()
    );

    // ----------------- FSM NEXT STATE ----------------
    always @(*) begin
        case (state_reg) 
            S_IDLE: begin
                state_next = (en && start) ? S_LOAD : STATE_IDLE;
            end

            S_LOAD: // Pass 0: Store tiles and track max
            begin
                state_next = (e_count >= TOTAL_ELEMENTS) ? S_PASS_1A: S_LOAD;
            end

            S_PASS_1A: // Pass 1A: Read from the RAM and calculate the exp
            begin
                state_next = ((ram_read_addr0 >= RAM_DEPTH -1) && (ram_read_addr1 >= RAM_DEPTH)) ? S_PASS_1B : S_PASS_1A;
            end

            S_PASS_1B: // Pass 1B: Read from the 
        endcase

    end

    // ----------------- FSM SEQUENTIAL ----------------
    always @(posedge clk) begin
        if (!rst_n) begin
            state_reg       <= S_IDLE;
            e_count         <= {ADDRE{1'b0}};
            ram_read_addr0  <= {ADDRW{1'b0}};
            ram_read_addr1  <= {ADDRW{1'b0}};
            ram_write_addr  <= {ADDRW{1'b0}};
            max_val         <= 32'sh8000_0000; // Very negative
            sum_exp         <= {SUM_WIDTH{1'b0}};
            tile_out_valid  <= 0;
            done            <= 0;
            ln_sum          <= {WIDTH(1'b0)};
            m_norm          <= {WIDTH(1'b0)};
            k_shift         <= 16'd0;
            exp_in_flat0    <= {WIDTH*TILE_SIZE-1(1'b0)};
            exp_in_flat1    <= {WIDTH*TILE_SIZE-1(1'b0)};
            for (i = 0; i < TILE_SIZE; i = i + 1) begin
                X_norm_0[i] <= {WIDTH{1'b0}};
                X_norm_1[i] <= {WIDTH{1'b0}};
            end
        end else if (en) begin
            state_reg <= state_next;
            case (state_reg)
                S_IDLE: begin
                    tile_out_valid  <= 0;
                    done            <= 0;
                    if (start) begin
                        e_count     <= {ADDRE{1'b0}};
                        ram_read_addr0  <= {ADDRW{1'b0}};
                        ram_read_addr1  <= 1; // 1 because we want the RAM to access different addres than ram_read_addr0
                        ram_write_addr  <= {ADDRW{1'b0}};
                        max_val     <= 32'sh8000_0000; // Very negative
                        sum_exp     <= {SUM_WIDTH{1'b0}};
                    end
                end

                S_LOAD: begin       // Pass 0: Store tiles and track max 
                    if (tile_in_valid) begin
                        for (i = 0; i < TILE_SIZE; i = i+1) begin
                            if (e_count < TOTAL_ELEMENTS) begin
                                xi      <= slice_flat(X_tile_in, i)
                                if (xi > max_val) max_val <= xi;
                            end
                            e_count <= e_count + i;
                        end
                        ram_write_addr <= ram_write_addr + 1;
                    end
                end

                S_PASS_1A: begin    // Pass 1A: Read from the RAM and calculate the exp
                    for (j=0; j < RAM_DEPTH/2; j = j + 1) begin
                        if (ram_read_addr0 < RAM_DEPTH -1) && (ram_read_addr1 < RAM_DEPTH) begin
                            ram_read_addr0 <= ram_read_addr0 + (j*2); // Even address
                            ram_read_addr1 <= ram_read_addr1 + (j*2 + 1); // Odd address
                            for (i=0; i < TILE_SIZE; i = i +1) begin
                                X_norm_0[i] <= slice_flat(ram_dout0, i) - max_val;
                                X_norm_1[i] <= slice_flat(ram_dout1, i) - max_val;
                            end
                        end else begin
                            ram_read_addr0  <= {ADDRW{1'b0}};
                            ram_read_addr1  <= 1; // 1 because we want the RAM to access different addres than ram_read_addr0
                        end
                    end 
                end

                S_PASS_1B: 


            endcase
        end


    end

    

endmodule

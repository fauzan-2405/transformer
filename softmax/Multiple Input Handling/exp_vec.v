// Vectorized exp() with shared LUTs and per-lane index
// Y_i = exp(X_i) ≈ (A(seg_i) * X_i) >> FRAC + C(seg_i)
// Where seg_i is selected from |X_i| and sign
//
// Parameters:
//   WIDTH     : total bit width (Q16.16 default is 32)
//   FRAC      : fractional bits (default 16)
//   TILE_SIZE : number of parallel lanes
//   USE_AMULT : 0 = use exact multiply (X*A), 1 = use approximate amult (shift-add)
//   AMULT_SHIFT : width of SHIFT_VAL provided to amult (bits pulled from A's frac)
//
// Notes:
// - LUT_A and LUT_C are implemented once via functions (shared definition).
// - Each lane computes its own index (tiny logic).
// - Flattened I/O: MS chunk is element 0 (matches your earlier convention).

module exp_vec #(
    parameter integer WIDTH       = 32,
    parameter integer FRAC        = 16,
    parameter integer TILE_SIZE   = 4,
    parameter integer USE_AMULT   = 0,   // 0: exact multiply, 1: approximate shift-add
    parameter integer AMULT_SHIFT = 16   // how many bits from A frac to use for amult SHIFT_VAL
)(
    input  wire signed [TILE_SIZE*WIDTH-1:0] X_flat,
    output wire signed [TILE_SIZE*WIDTH-1:0] Y_flat
);
    // Unpack flattened vector into arrays for readability
    wire signed [WIDTH-1:0] X [0:TILE_SIZE-1];
    reg  signed [WIDTH-1:0] Y [0:TILE_SIZE-1];

    genvar gi;
    generate
        for (gi = 0; gi < TILE_SIZE; gi = gi + 1) begin : UNPACK
            // MS chunk is first element (index 0)
            localparam integer MSB = (TILE_SIZE-1-gi)*WIDTH + (WIDTH-1);
            localparam integer LSB = (TILE_SIZE-1-gi)*WIDTH;
            assign X[gi] = X_flat[MSB:LSB];
        end
    endgenerate

    // ----------------------------
    // Index logic (per lane)
    //   absX = |X|
    //   Ytemp = absX << 2       (divide range into 0.25 bins)
    //   If Ytemp[31:21] nonzero => saturate index to 31
    //   Else index = Ytemp[22:16]
    // Then apply sign fold: if X is negative => add 32 to select the second half of LUT
    // ----------------------------
    function automatic [6:0] index_sel_soft;
        input signed [WIDTH-1:0] x_in;
        reg [WIDTH-1:0] absX;
        reg [WIDTH-1:0] Ytemp;
        reg sel_lut_saturate;
        reg [6:0] base_idx;
    begin
        absX = x_in[WIDTH-1] ? (~x_in + 1'b1) : x_in;
        Ytemp = absX << 2; // *4 to get 0.25 steps
        sel_lut_saturate = |Ytemp[31:21]; // any of bits 31..21 set?
        base_idx = sel_lut_saturate ? 7'd31 : {2'b00, Ytemp[22:16]}; // 7 bits, but upper 2 are zero here
        // fold sign: negative selects 32..63
        index_sel_soft = x_in[WIDTH-1] ? (base_idx + 7'd32) : base_idx;
    end
    endfunction

    // ----------------------------
    // LUT functions (shared definition)
    // ----------------------------
    function automatic signed [WIDTH-1:0] lutA;
        input [6:0] aidx;
        begin
            case (aidx)
                7'd0: lutA = 32'h0001228C;
                7'd1: lutA = 32'h00017512; 
                7'd2: lutA = 32'h0001DF09; 
                7'd3: lutA = 32'h00026717; 
                7'd4: lutA = 32'h000315CB; 
                7'd5: lutA = 32'h0003F61D; 
                7'd6: lutA = 32'h00051626; 
                7'd7: lutA = 32'h000687FE; 
                7'd8: lutA = 32'h000862E1; 
                7'd9: lutA = 32'h000AC4A6; 
                7'd10: lutA = 32'h000DD39B; 
                7'd11: lutA = 32'h0011C0F2; 
                7'd12: lutA = 32'h0016CBD3; 
                7'd13: lutA = 32'h001D4559; 
                7'd14: lutA = 32'h002595A6; 
                7'd15: lutA = 32'h00304271; 
                7'd16: lutA = 32'h003DF76B; 
                7'd17: lutA = 32'h004F9108; 
                7'd18: lutA = 32'h00662A5A;
                7'd19: lutA = 32'h00832EDB;
                7'd20: lutA = 32'h00A8713D;
                7'd21: lutA = 32'h00D848C4;
                7'd22: lutA = 32'h0115B6E7;
                7'd23: lutA = 32'h016497AA;
                7'd24: lutA = 32'h01C9DFAE;  
                7'd25: lutA = 32'h024BEBEA;  
                7'd26: lutA = 32'h02F2E7FC;
                7'd27: lutA = 32'h03C95199;
                7'd28: lutA = 32'h04DCA141;
                7'd29: lutA = 32'h063E22EC;
                7'd30: lutA = 32'h08040C3B;
                7'd31: lutA = 32'h0A4AE1AA;
                // neg range (32..63)
                7'd32: lutA = 32'h0000E248;
                7'd33: lutA = 32'h0000B03A;
                7'd34: lutA = 32'h0000893F;
                7'd35: lutA = 32'h00006AE3;
                7'd36: lutA = 32'h0000533E;
                7'd37: lutA = 32'h000040D5;
                7'd38: lutA = 32'h0000327D;
                7'd39: lutA = 32'h00002752;
                7'd40: lutA = 32'h00001EA0;
                7'd41: lutA = 32'h000017DA;
                7'd42: lutA = 32'h00001293;
                7'd43: lutA = 32'h00000E77;
                7'd44: lutA = 32'h00000B44;
                7'd45: lutA = 32'h000008C6;
                7'd46: lutA = 32'h000006D5;
                7'd47: lutA = 32'h00000552;
                7'd48: lutA = 32'h00000425;
                7'd49: lutA = 32'h0000033A;
                7'd50: lutA = 32'h00000284;
                7'd51: lutA = 32'h000001F5;
                7'd52: lutA = 32'h00000186;
                7'd53: lutA = 32'h00000130;
                7'd54: lutA = 32'h000000ED;
                7'd55: lutA = 32'h000000B8;
                7'd56: lutA = 32'h00000090;
                7'd57: lutA = 32'h00000070;
                7'd58: lutA = 32'h00000057;
                7'd59: lutA = 32'h00000044;
                7'd60: lutA = 32'h00000035;
                7'd61: lutA = 32'h00000029;
                7'd62: lutA = 32'h00000020;
                7'd63: lutA = 32'h00000019;
                default: lutA = {WIDTH{1'b0}};
            endcase
        end
    endfunction

    function automatic signed [WIDTH-1:0] lutC;
        input [6:0] cidx;
        begin
            case (cidx)
                7'd0:  lutC = 32'h0000FE8A;
                7'd1:  lutC = 32'h0000E991;
                7'd2:  lutC = 32'h0000B426;
                7'd3:  lutC = 32'h00004D8A;
                7'd4:  lutC = 32'hFFFF9E1D;
                7'd5:  lutC = 32'hFFFE84C9;
                7'd6:  lutC = 32'hFFFCD38A;
                7'd7:  lutC = 32'hFFFA4AC9;
                7'd8:  lutC = 32'hFFF6930A; 
                7'd9:  lutC = 32'hFFF13489; 
                7'd10: lutC = 32'hFFE98BE6; 
                7'd11: lutC = 32'hFFDEBB0E; 
                7'd12: lutC = 32'hFFCF9512; 
                7'd13: lutC = 32'hFFBA8343; 
                7'd14: lutC = 32'hFF9D6165; 
                7'd15: lutC = 32'hFF754E1B; 
                7'd16: lutC = 32'hFF3E6BAD; 
                7'd17: lutC = 32'hFEF38C29; 
                7'd18: lutC = 32'hFE8DC242;
                7'd19: lutC = 32'hFE03CE1E;
                7'd20: lutC = 32'hFD495AB4;
                7'd21: lutC = 32'hFC4DFC79;
                7'd22: lutC = 32'hFAFBDD9B;
                7'd23: lutC = 32'hF935FDA1;
                7'd24: lutC = 32'hF6D5E22D;
                7'd25: lutC = 32'hF3A88BE1;
                7'd26: lutC = 32'hEF6A7469;
                7'd27: lutC = 32'hE9C24843;
                7'd28: lutC = 32'hE239F6D9;
                7'd29: lutC = 32'hD8359409;
                7'd30: lutC = 32'hCAE75D17;
                7'd31: lutC = 32'hB93FFD33;
                // neg range (32..63)
                7'd32: lutC = 32'h0000FECE;
                7'd33: lutC = 32'h0000F280;
                7'd34: lutC = 32'h0000DF2B;
                7'd35: lutC = 32'h0000C887;
                7'd36: lutC = 32'h0000B0FB;
                7'd37: lutC = 32'h00009A0A;
                7'd38: lutC = 32'h00008497;
                7'd39: lutC = 32'h00007117;
                7'd40: lutC = 32'h00005FBB;
                7'd41: lutC = 32'h00005085;
                7'd42: lutC = 32'h0000435A;
                7'd43: lutC = 32'h00003812;
                7'd44: lutC = 32'h00002E7C;
                7'd45: lutC = 32'h00002665;
                7'd46: lutC = 32'h00001F9C;
                7'd47: lutC = 32'h000019F3;
                7'd48: lutC = 32'h0000153F;
                7'd49: lutC = 32'h0000115A;
                7'd50: lutC = 32'h00000E24;
                7'd51: lutC = 32'h00000B81;
                7'd52: lutC = 32'h00000957;
                7'd53: lutC = 32'h00000792;
                7'd54: lutC = 32'h00000621;
                7'd55: lutC = 32'h000004F4;
                7'd56: lutC = 32'h000003FF;
                7'd57: lutC = 32'h00000339;
                7'd58: lutC = 32'h00000298;
                7'd59: lutC = 32'h00000216;
                7'd60: lutC = 32'h000001AD;
                7'd61: lutC = 32'h00000159;
                7'd62: lutC = 32'h00000114;
                7'd63: lutC = 32'h000000DD;
                default: lutC = {WIDTH{1'b0}};
            endcase
        end
    endfunction

    // ----------------------------
    // Optional approximate multiplier instance (generate)
    // ----------------------------
    // Local function to pick SHIFT_VAL bits from A's fractional part
    function automatic [AMULT_SHIFT-1:0] pick_shift_val;
        input signed [WIDTH-1:0] Acoef;
        integer top, bot;
        begin
            //Take AMULT_SHIFT bits from the top of the fractional field of A
            top = FRAC-1;
            bot = FRAC-AMULT_SHIFT;
            if (bot < 0) begin
                // guard in case AMULT_SHIFT > FRAC
                pick_shift_val = {{(AMULT_SHIFT){1'b0}}};
            end else begin
                pick_shift_val = Acoef[top:bot];
            end
        end
    endfunction

    // ----------------------------
    // Per-lane datapath (purely combinational here)
    // ----------------------------
    generate
        for (genvar i = 0; i < TILE_SIZE; i = i + 1) begin : PER_LANE
            wire [6:0] sel_i;
            wire signed [WIDTH-1:0] A_i, C_i;
            wire signed [(2*WIDTH)-1:0] P_full;
            wire signed [WIDTH-1:0] mult_exact;
            wire [AMULT_SHIFT-1:0] shift_val_i;
            wire signed [WIDTH-1:0] mult_approx;

            assign sel_i = index_sel_soft(X[i]);
            assign A_i   = lutA(sel_i);
            assign C_i   = lutC(sel_i);

            // Exact multiply path
            assign P_full     = X[i] * A_i;
            assign mult_exact = P_full[(FRAC+WIDTH-1):FRAC]; // >> FRAC

            // Approximate multiply path (optional)
            generate
                if (USE_AMULT != 0) begin : USE_AMULT_G
                    assign shift_val_i = pick_shift_val(A_i);
                    amult #(
                        .WIDTH(WIDTH),
                        .SHIFT(AMULT_SHIFT)
                    ) AMULT_I (
                        // .CLK(), // combinational version as in your code
                        .DAT_IN(X[i]),
                        .SHIFT_VAL(shift_val_i),
                        .DAT_OUT(mult_approx)
                    );
                end else begin : NO_AMULT_G
                    assign mult_approx = {WIDTH{1'b0}}; // unused
                end
            endgenerate

            // Select multiply result and add C
            wire signed [WIDTH-1:0] Y_i = (USE_AMULT != 0) ? (mult_approx + C_i)
                                                           : (mult_exact  + C_i);

            // Register-less combinational output for now; we can pipeline later
            always @* begin
                Y[i] = Y_i;
            end

            // Pack back into Y_flat (MS chunk = element 0)
            localparam integer OMSB = (TILE_SIZE-1-i)*WIDTH + (WIDTH-1);
            localparam integer OLSB = (TILE_SIZE-1-i)*WIDTH;
            assign Y_flat[OMSB:OLSB] = Y[i];
        end
    endgenerate

endmodule

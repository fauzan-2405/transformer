// softmax_lut.v
// Used to store LUT values 
// The input ranges from -8 to +8
// Output is in Q8.8 fixed-point format: [S][7 INT][8 FRAC]

module softmax_lut #(
    parameter WIDTH = 16,
    parameter FRAC_WIDTH = 8,
    parameter INT_WIDTH = 8
) (
    input  wire signed [INT_WIDTH-1:0] in,      // Range: -8 to +8
    output reg  [WIDTH-1:0] e_i_val             // Q8.8 format
);
    always @(*) begin
        case (in)
            -8: e_i_val = 16'b0_00000000_00000000; // e^-8 ≈ 0
            -7: e_i_val = 16'b0_00000000_00000000; // e^-7 ≈ 0
            -6: e_i_val = 16'b0_00000000_00000001; // e^-6 ≈ 0.002 → 1
            -5: e_i_val = 16'b0_00000000_00000010; // e^-5 ≈ 0.0067 → 2
            -4: e_i_val = 16'b0_00000000_00000101; // e^-4 ≈ 0.0183 → 5
            -3: e_i_val = 16'b0_00000000_00001101; // e^-3 ≈ 0.0497 → 13
            -2: e_i_val = 16'b0_00000000_00100011; // e^-2 ≈ 0.135 → 35
            -1: e_i_val = 16'b0_00000000_01011110; // e^-1 ≈ 0.367 → 94
             0: e_i_val = 16'b0_00000001_00000000; // e^0 = 1.0 → 256
             1: e_i_val = 16'b0_00000010_10111000; // e^1 ≈ 2.718 → 696
             2: e_i_val = 16'b0_00000111_01100011; // e^2 ≈ 7.389 → 1891
             3: e_i_val = 16'b0_00010100_00010010; // e^3 ≈ 20.085 → 5138
             4: e_i_val = 16'b0_00110110_10001001; // e^4 ≈ 54.598 → 13977
             5: e_i_val = 16'b0_10010100_11111001; // e^5 ≈ 148.413 → 37993
             6: e_i_val = 16'b1_11111111_11111111; // e^6 ≈ 403.428 → 103278 → clipped
             7: e_i_val = 16'b1_11111111_11111111; // e^7 ≈ 1096.633 → 280744 → clipped
             8: e_i_val = 16'b1_11111111_11111111; // e^8 ≈ 2980.958 → 763749 → clipped
            default: e_i_val = 16'b0_00000000_00000000; // Default to 0
        endcase
    end
endmodule

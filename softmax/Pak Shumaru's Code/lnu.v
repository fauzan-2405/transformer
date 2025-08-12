// ln_pwl_q16_16.v
// ln(x) approximated by piecewise linear (Q16.16), 28 segments, interval 0.25

module lnu (
    input  wire signed [31:0] x_in,      // Q16.16 input
    output reg  signed [31:0] ln_out     // Q16.16 output
);
    reg [4:0] index;
    reg signed [31:0] a, b;
    reg signed [31:0] a_lut [0:27];
    reg signed [31:0] b_lut [0:27];

    wire signed [63:0]  mult_result;
    reg [31:0] Ytemp; 
    
    initial begin
    a_lut[0] = 32'h0000E480;
    a_lut[1] = 32'h0000BAB3;
    a_lut[2] = 32'h00009DDA;
    a_lut[3] = 32'h000088BC;
    a_lut[4] = 32'h0000789C;
    a_lut[5] = 32'h00006BE4;
    a_lut[6] = 32'h00006199;
    a_lut[7] = 32'h0000591A;
    a_lut[8] = 32'h000051F7;
    a_lut[9] = 32'h00004BE3;
    a_lut[10] = 32'h000046A6;
    a_lut[11] = 32'h00004216;
    a_lut[12] = 32'h00003E14;
    a_lut[13] = 32'h00003A88;
    a_lut[14] = 32'h0000375D;
    a_lut[15] = 32'h00003486;
    a_lut[16] = 32'h000031F6;
    a_lut[17] = 32'h00002FA3;
    a_lut[18] = 32'h00002D85;
    a_lut[19] = 32'h00002B95;
    a_lut[20] = 32'h000029CD;
    a_lut[21] = 32'h00002829;
    a_lut[22] = 32'h000026A5;
    a_lut[23] = 32'h0000253E;
    a_lut[24] = 32'h000023EF;
    a_lut[25] = 32'h000022B7;
    a_lut[26] = 32'h00002194;
    a_lut[27] = 32'h00002083;

    b_lut[0] = 32'hFFFF1B80;
    b_lut[1] = 32'hFFFF4FC1;
    b_lut[2] = 32'hFFFF7B06;
    b_lut[3] = 32'hFFFF9FF9;
    b_lut[4] = 32'hFFFFC03A;
    b_lut[5] = 32'hFFFFDCD9;
    b_lut[6] = 32'hFFFFF694;
    b_lut[7] = 32'h00000DF2;
    b_lut[8] = 32'h0000235B;
    b_lut[9] = 32'h0000371B;
    b_lut[10] = 32'h00004970;
    b_lut[11] = 32'h00005A8B;
    b_lut[12] = 32'h00006A93;
    b_lut[13] = 32'h000079A8;
    b_lut[14] = 32'h000087E7;
    b_lut[15] = 32'h00009565;
    b_lut[16] = 32'h0000A236;
    b_lut[17] = 32'h0000AE6A;
    b_lut[18] = 32'h0000BA10;
    b_lut[19] = 32'h0000C534;
    b_lut[20] = 32'h0000CFE1;
    b_lut[21] = 32'h0000DA21;
    b_lut[22] = 32'h0000E3FB;
    b_lut[23] = 32'h0000ED78;
    b_lut[24] = 32'h0000F69E;
    b_lut[25] = 32'h0000FF74;
    b_lut[26] = 32'h000107FD;
    b_lut[27] = 32'h00011040;
    end

    always @(*) begin
        // index = floor((x_in - 1.0) / 0.25)
        if (x_in < 32'h00010000)
            index = 0;
        else if (x_in >= 32'h00080000)
            index = 27;
        else begin
            Ytemp = (x_in - 32'h00010000) << 2; // divide by 0.25 = shift 14 bits
            index = Ytemp[20:16];
            end
        
        a = a_lut[index];
        b = b_lut[index];
    end

    assign mult_result = a * x_in;

    always @(*) begin
        ln_out = (mult_result >> 16) + b;
    end

endmodule
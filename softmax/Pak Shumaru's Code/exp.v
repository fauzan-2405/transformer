// exp.v
// Used to find the exponent (e^x) value

module exp #( 
    parameter WIDTH = 32,
    parameter FRAC_BIT = 16,
    parameter POINT = 40,
    parameter SHIFT = 8
    
)(  //input CLK, // penambahan untuk critical path
    //input wire rst, // penambahan untuk critical path
    input wire signed [WIDTH-1:0] X,
    output wire signed [WIDTH-1:0] Y
);
         
   
    wire signed [((WIDTH*2))-1:0] temp;
    wire signed [WIDTH-1:0] Ytemp;
    wire [6:0] SEL_LUT,SEL_soft;
    wire signed [WIDTH-1:0] output_lUT_A;
    wire signed [WIDTH-1:0] output_lUT_C;
    reg [WIDTH-1:0] lUT_C_cs;
    wire [WIDTH-1:0] A, C;
    wire signed [WIDTH-1:0] Ymul_temp;
    wire signed [WIDTH-1:0] Yadd_temp, absX;
    wire Xneg;
        
    assign absX = X[WIDTH-1] ? ((~X)+32'd1) : X;
    assign Xneg = X[WIDTH-1];
    
    //comparator paralel
    index #(
        .WIDTH(WIDTH)
    ) Index_LUT_Soft (
        .absX(absX),
        .Y(SEL_LUT)
    );    
    assign SEL_soft = Xneg ? (SEL_LUT+7'd32) : SEL_LUT; 

    // LUT parameter A dan C
    LUT_A_Soft #(
        .WIDTH(WIDTH)    
    ) lut_a(
        .x(SEL_soft),
        .A(output_lUT_A)
    );
    LUT_C_Soft #(
        .WIDTH(WIDTH)    
    ) lut_c(
        .x(SEL_soft),
        .C(output_lUT_C)
    );
    
    // Approximate multiplication
    /*
    amult #(
        .WIDTH(WIDTH)
    ) softmax_mult_A (
        .CLK(CLK),
        .DAT_IN(X),
        .SHIFT_VAL(output_lUT_A[FRAC_BIT-1:FRAC_BIT-SHIFT]),
        .DAT_OUT(Ymul_temp)
    ); */

    assign temp = X * output_lUT_A;
    assign Y = temp[(WIDTH+FRAC_BIT-1):FRAC_BIT] + output_lUT_C;
     
endmodule
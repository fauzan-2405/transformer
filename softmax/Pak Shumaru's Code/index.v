// index.v
// It takes the absolute value of your fixed-point input 𝑥 
// and maps it into a 7-bit segment index used to fetch slope/intercept 
// parameters from LUT_A_Soft and LUT_C_Soft.

module index #(
    parameter WIDTH = 32
) (
    input wire [(WIDTH-1):0] absX,
    output reg [6:0] Y
    );

    reg [(WIDTH-1):0] Ytemp;
    reg sel_lut;
    
    always @(*) begin
        Ytemp = absX <<< 2;
        sel_lut = Ytemp[31]|Ytemp[30]|Ytemp[29]|Ytemp[28]|Ytemp[27]|Ytemp[26]|Ytemp[25]|Ytemp[24]| Ytemp[23] | Ytemp[22] | Ytemp[21]; // untuk > 32 index maka bit ke 21 akan 1
        Y = sel_lut ? 7'd31: Ytemp[22:16];
    end
       
endmodule

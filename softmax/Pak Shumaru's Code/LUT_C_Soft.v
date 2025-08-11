// LUT_C_Soft.v
// LUT for C in Ax + C

module LUT_C_Soft #(
    parameter WIDTH = 32,
    parameter ADDR_WIDTH = 5
) (
    input wire [6:0] x,        
    output reg signed [WIDTH-1:0] C   
    );

    // LUT for sigmoid function values
    reg [(WIDTH-1):0] lut_c [0:(1<<ADDR_WIDTH)-1];
    always @(*) begin
     case (x)
        7'd0: C = 32'h0000FE8A;  //0-0.25
        7'd1: C = 32'h0000E991;  //0.25 - 0.5
        7'd2: C = 32'h0000B426; //0.5 - 0.75
        7'd3: C = 32'h00004D8A; //0.75 - 1
        7'd4: C = 32'hFFFF9E1D; //1-1.25
        7'd5: C = 32'hFFFE84C9; //1.25-1.5
        7'd6: C = 32'hFFFCD38A; //1.5-1.75
        7'd7: C = 32'hFFFA4AC9; //1.75-2
        7'd8: C = 32'hFFF6930A; 
        7'd9: C = 32'hFFF13489; 
        7'd10: C = 32'hFFE98BE6; 
        7'd11: C = 32'hFFDEBB0E; 
        7'd12: C = 32'hFFCF9512; 
        7'd13: C = 32'hFFBA8343; 
        7'd14: C = 32'hFF9D6165; 
        7'd15: C = 32'hFF754E1B; 
        7'd16: C = 32'hFF3E6BAD; 
        7'd17: C = 32'hFEF38C29; 
        7'd18: C = 32'hFE8DC242;
        7'd19: C = 32'hFE03CE1E;
        7'd20: C = 32'hFD495AB4;
        7'd21: C = 32'hFC4DFC79;
        7'd22: C = 32'hFAFBDD9B;
        7'd23: C = 32'hF935FDA1;
        7'd24: C = 32'hF6D5E22D;
        7'd25: C = 32'hF3A88BE1;
        7'd26: C = 32'hEF6A7469;
        7'd27: C = 32'hE9C24843;
        7'd28: C = 32'hE239F6D9;
        7'd29: C = 32'hD8359409;
        7'd30: C = 32'hCAE75D17;
        7'd31: C = 32'hB93FFD33;  
        // lut -1 - -A
        7'd32: C = 32'h0000FECE;
        7'd33: C = 32'h0000F280;
        7'd34: C = 32'h0000DF2B;
        7'd35: C = 32'h0000C887;
        7'd36: C = 32'h0000B0FB;
        7'd37: C = 32'h00009A0A;
        7'd38: C = 32'h00008497;
        7'd39: C = 32'h00007117;
        7'd40: C = 32'h00005FBB;
        7'd41: C = 32'h00005085;
        7'd42: C = 32'h0000435A;
        7'd43: C = 32'h00003812;
        7'd44: C = 32'h00002E7C;
        7'd45: C = 32'h00002665;
        7'd46: C = 32'h00001F9C;
        7'd47: C = 32'h000019F3;
        7'd48: C = 32'h0000153F;
        7'd49: C = 32'h0000115A;
        7'd50: C = 32'h00000E24;
        7'd51: C = 32'h00000B81;
        7'd52: C = 32'h00000957;
        7'd53: C = 32'h00000792;
        7'd54: C = 32'h00000621;
        7'd55: C = 32'h000004F4;
        7'd56: C = 32'h000003FF;
        7'd57: C = 32'h00000339;
        7'd58: C = 32'h00000298;
        7'd59: C = 32'h00000216;
        7'd60: C = 32'h000001AD;
        7'd61: C = 32'h00000159;
        7'd62: C = 32'h00000114;
        7'd63: C = 32'h000000DD;
        default: C = 32'h0;
        endcase
    end
endmodule
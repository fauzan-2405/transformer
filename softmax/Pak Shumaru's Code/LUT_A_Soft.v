// LUT_A_Soft.v
// LUT for A in Ax + C

module LUT_A_Soft #(
    parameter WIDTH = 32,
    parameter ADDR_WIDTH = 5
) (
    input wire [6:0] x,        
    output reg signed [(WIDTH-1):0] A    
    );

    // LUT for sigmoid function values menggunakan reg
    reg [(WIDTH-1):0] lut_a [0:(1<<ADDR_WIDTH)-1];
    always @(*) begin
     case (x)
        7'd0: A  = 32'h0001228C;
        7'd1: A  = 32'h00017512; 
        7'd2: A  = 32'h0001DF09; 
        7'd3: A  = 32'h00026717; 
        7'd4: A  = 32'h000315CB; 
        7'd5: A  = 32'h0003F61D; 
        7'd6: A  = 32'h00051626; 
        7'd7: A  = 32'h000687FE; 
        7'd8: A  = 32'h000862E1; 
        7'd9: A  = 32'h000AC4A6; 
        7'd10: A  = 32'h000DD39B; 
        7'd11: A  = 32'h0011C0F2; 
        7'd12: A  = 32'h0016CBD3; 
        7'd13: A  = 32'h001D4559; 
        7'd14: A  = 32'h002595A6; 
        7'd15: A  = 32'h00304271; 
        7'd16: A  = 32'h003DF76B; 
        7'd17: A  = 32'h004F9108; 
        7'd18: A  = 32'h00662A5A;
        7'd19: A  = 32'h00832EDB;
        7'd20: A  = 32'h00A8713D;
        7'd21: A  = 32'h00D848C4;
        7'd22: A  = 32'h0115B6E7;
        7'd23: A  = 32'h016497AA;
        7'd24: A  = 32'h01C9DFAE;  
        7'd25: A  = 32'h024BEBEA;  
        7'd26: A  = 32'h02F2E7FC;
        7'd27: A  = 32'h03C95199;
        7'd28: A  = 32'h04DCA141;
        7'd29: A  = 32'h063E22EC;
        7'd30: A  = 32'h08040C3B;
        7'd31: A  = 32'h0A4AE1AA;
        // lut -1 - -A
        7'd32: A  = 32'h0000E248;
        7'd33: A  = 32'h0000B03A;
        7'd34: A  = 32'h0000893F;
        7'd35: A  = 32'h00006AE3;
        7'd36: A  = 32'h0000533E;
        7'd37: A  = 32'h000040D5;
        7'd38: A  = 32'h0000327D;
        7'd39: A  = 32'h00002752;
        7'd40: A  = 32'h00001EA0;
        7'd41: A  = 32'h000017DA;
        7'd42: A  = 32'h00001293;
        7'd43: A  = 32'h00000E77;
        7'd44: A  = 32'h00000B44;
        7'd45: A  = 32'h000008C6;
        7'd46: A  = 32'h000006D5;
        7'd47: A  = 32'h00000552;
        7'd48: A  = 32'h00000425;
        7'd49: A  = 32'h0000033A;
        7'd50: A  = 32'h00000284;
        7'd51: A  = 32'h000001F5;
        7'd52: A  = 32'h00000186;
        7'd53: A  = 32'h00000130;
        7'd54: A  = 32'h000000ED;
        7'd55: A  = 32'h000000B8;
        7'd56: A  = 32'h00000090;
        7'd57: A  = 32'h00000070;
        7'd58: A  = 32'h00000057;
        7'd59: A  = 32'h00000044;
        7'd60: A  = 32'h00000035;
        7'd61: A  = 32'h00000029;
        7'd62: A  = 32'h00000020;
        7'd63: A  = 32'h00000019;
        default: A = 32'h0;
           
        endcase
    end

endmodule
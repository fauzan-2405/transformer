
module amult #(
//Approximate Multiplier
    parameter WIDTH = 32,
    parameter SHIFT = 8
)(  //input wire CLK,
    input wire signed [WIDTH-1:0] DAT_IN,
    input wire [SHIFT-1:0] SHIFT_VAL,
    output wire [WIDTH-1:0] DAT_OUT
);
    localparam CONST_ZERO = {WIDTH{1'b0}};

    wire [WIDTH-1:0] shift_reg [0:SHIFT-1];
//    reg [WIDTH-1:0] shift_regP [0:SHIFT-1];
//    reg  [WIDTH-1:0] DAT_OUTtemp;
    wire [WIDTH-1:0] DAT_OUT1, DAT_OUT2, DAT_OUT3;

//    assign shift_reg[0] = SHIFT_VAL[11] ? (DAT_IN >>> 1) : 0;
//    assign shift_reg[1] = SHIFT_VAL[10] ? (DAT_IN >>> 2) : 0;
//    assign shift_reg[2] = SHIFT_VAL[9] ? (DAT_IN >>> 3) : 0;
//    assign shift_reg[3] = SHIFT_VAL[8] ? (DAT_IN >>> 4) : 0;
//    assign shift_reg[4] = SHIFT_VAL[7] ? (DAT_IN >>> 5) : 0;
//    assign shift_reg[5] = SHIFT_VAL[6] ? (DAT_IN >>> 6) : 0;
//    assign shift_reg[6] = SHIFT_VAL[5] ? (DAT_IN >>> 7) : 0;
//    assign shift_reg[7] = SHIFT_VAL[4] ? (DAT_IN >>> 8) : 0;
//    assign shift_reg[8] = SHIFT_VAL[3] ? (DAT_IN >>> 9) : 0;
//    assign shift_reg[9] = SHIFT_VAL[2] ? (DAT_IN >>> 10) : 0;
//    assign shift_reg[10] = SHIFT_VAL[1] ? (DAT_IN >>> 11) : 0;
//    assign shift_reg[11] = SHIFT_VAL[0] ? (DAT_IN >>> 12) : 0;

 //    shift barrel 8
//    assign shift_reg[0] = SHIFT_VAL[7] ? (DAT_IN >>> 1) : 0;
//    assign shift_reg[1] = SHIFT_VAL[6] ? (DAT_IN >>> 2) : 0;
//    assign shift_reg[2] = SHIFT_VAL[5] ? (DAT_IN >>> 3) : 0;
//    assign shift_reg[3] = SHIFT_VAL[4] ? (DAT_IN >>> 4) : 0;
//    assign shift_reg[4] = SHIFT_VAL[3] ? (DAT_IN >>> 5) : 0;
//    assign shift_reg[5] = SHIFT_VAL[2] ? (DAT_IN >>> 6) : 0;
//    assign shift_reg[6] = SHIFT_VAL[1] ? (DAT_IN >>> 7) : 0;
//    assign shift_reg[7] = SHIFT_VAL[0] ? (DAT_IN >>> 8) : 0;
//    //    shift barrel 10
//    assign shift_reg[0] = SHIFT_VAL[9] ? (DAT_IN >>> 1) : 0;
//    assign shift_reg[1] = SHIFT_VAL[8] ? (DAT_IN >>> 2) : 0;
//    assign shift_reg[2] = SHIFT_VAL[7] ? (DAT_IN >>> 3) : 0;
//    assign shift_reg[3] = SHIFT_VAL[6] ? (DAT_IN >>> 4) : 0;
//    assign shift_reg[4] = SHIFT_VAL[5] ? (DAT_IN >>> 5) : 0;
//    assign shift_reg[5] = SHIFT_VAL[4] ? (DAT_IN >>> 6) : 0;
//    assign shift_reg[6] = SHIFT_VAL[3] ? (DAT_IN >>> 7) : 0;
//    assign shift_reg[7] = SHIFT_VAL[2] ? (DAT_IN >>> 8) : 0;
//    assign shift_reg[8] = SHIFT_VAL[1] ? (DAT_IN >>> 9) : 0;
//    assign shift_reg[9] = SHIFT_VAL[0] ? (DAT_IN >>> 10) : 0;
//    shift barrel 12
//    assign shift_reg[0] = SHIFT_VAL[11] ? (DAT_IN >>> 1) : 0;
//    assign shift_reg[1] = SHIFT_VAL[10] ? (DAT_IN >>> 2) : 0;
//    assign shift_reg[2] = SHIFT_VAL[9] ? (DAT_IN >>> 3) : 0;
//    assign shift_reg[3] = SHIFT_VAL[8] ? (DAT_IN >>> 4) : 0;
//    assign shift_reg[4] = SHIFT_VAL[7] ? (DAT_IN >>> 5) : 0;
//    assign shift_reg[5] = SHIFT_VAL[6] ? (DAT_IN >>> 6) : 0;
//    assign shift_reg[6] = SHIFT_VAL[5] ? (DAT_IN >>> 7) : 0;
//    assign shift_reg[7] = SHIFT_VAL[4] ? (DAT_IN >>> 8) : 0;
//    assign shift_reg[8] = SHIFT_VAL[3] ? (DAT_IN >>> 9) : 0;
//    assign shift_reg[9] = SHIFT_VAL[2] ? (DAT_IN >>> 10) : 0;
//    assign shift_reg[10] = SHIFT_VAL[1] ? (DAT_IN >>> 11) : 0;
//    assign shift_reg[11] = SHIFT_VAL[0] ? (DAT_IN >>> 12) : 0;
// shift barrel 14 bit    
//    assign shift_reg[0] = SHIFT_VAL[13] ? (DAT_IN >>> 1) : 0;
//    assign shift_reg[1] = SHIFT_VAL[12] ? (DAT_IN >>> 2) : 0;
//    assign shift_reg[2] = SHIFT_VAL[11] ? (DAT_IN >>> 3) : 0;
//    assign shift_reg[3] = SHIFT_VAL[10] ? (DAT_IN >>> 4) : 0;
//    assign shift_reg[4] = SHIFT_VAL[9] ? (DAT_IN >>> 5) : 0;
//    assign shift_reg[5] = SHIFT_VAL[8] ? (DAT_IN >>> 6) : 0;
//    assign shift_reg[6] = SHIFT_VAL[7] ? (DAT_IN >>> 7) : 0;
//    assign shift_reg[7] = SHIFT_VAL[6] ? (DAT_IN >>> 8) : 0;
//    assign shift_reg[8] = SHIFT_VAL[5] ? (DAT_IN >>> 9) : 0;
//    assign shift_reg[9] = SHIFT_VAL[4] ? (DAT_IN >>> 10) : 0;
//    assign shift_reg[10] = SHIFT_VAL[3] ? (DAT_IN >>> 11) : 0;
//    assign shift_reg[11] = SHIFT_VAL[2] ? (DAT_IN >>> 12) : 0;
//    assign shift_reg[12] = SHIFT_VAL[1] ? (DAT_IN >>> 13) : 0;
//    assign shift_reg[13] = SHIFT_VAL[0] ? (DAT_IN >>> 14) : 0;
// shift barrel 16 bit    
    assign shift_reg[0] = SHIFT_VAL[15] ? (DAT_IN >>> 1) : 0;
    assign shift_reg[1] = SHIFT_VAL[14] ? (DAT_IN >>> 2) : 0;
    assign shift_reg[2] = SHIFT_VAL[13] ? (DAT_IN >>> 3) : 0;
    assign shift_reg[3] = SHIFT_VAL[12] ? (DAT_IN >>> 4) : 0;
    assign shift_reg[4] = SHIFT_VAL[11] ? (DAT_IN >>> 5) : 0;
    assign shift_reg[5] = SHIFT_VAL[10] ? (DAT_IN >>> 6) : 0;
    assign shift_reg[6] = SHIFT_VAL[9] ? (DAT_IN >>> 7) : 0;
    assign shift_reg[7] = SHIFT_VAL[8] ? (DAT_IN >>> 8) : 0;
    assign shift_reg[8] = SHIFT_VAL[7] ? (DAT_IN >>> 9) : 0;
    assign shift_reg[9] = SHIFT_VAL[6] ? (DAT_IN >>> 10) : 0;
    assign shift_reg[10] = SHIFT_VAL[5] ? (DAT_IN >>> 11) : 0;
    assign shift_reg[11] = SHIFT_VAL[4] ? (DAT_IN >>> 12) : 0;
    assign shift_reg[12] = SHIFT_VAL[3] ? (DAT_IN >>> 13) : 0;
    assign shift_reg[13] = SHIFT_VAL[2] ? (DAT_IN >>> 14) : 0;
    assign shift_reg[14] = SHIFT_VAL[1] ? (DAT_IN >>> 15) : 0;
    assign shift_reg[15] = SHIFT_VAL[0] ? (DAT_IN >>> 16) : 0;


    //=====pipeline adder pada shift barrel===========
//    always @(posedge CLK) begin
//               shift_regP[0] <= shift_reg[0];
//                shift_regP[1] <=  shift_reg[1];
//                shift_regP[2] <= shift_reg[2];
//                shift_regP[3]<= shift_reg[3];
//                shift_regP[4] <= shift_reg[4];
//                shift_regP[5] <=  shift_reg[5];
//                shift_regP[6] <= shift_reg[6];
//                shift_regP[7]<= shift_reg[7];
//                shift_regP[8]<= shift_reg[8];
//                shift_regP[9]<= shift_reg[9];
//                shift_regP[10]<= shift_reg[10];
//                shift_regP[11]<= shift_reg[11];


//    end
   assign DAT_OUT = shift_reg[0]+shift_reg[1]+shift_reg[2]+shift_reg[3]+shift_reg[4]+shift_reg[5]+shift_reg[6]+shift_reg[7];
//                       + shift_reg[8]+ shift_reg[9]+ shift_reg[10]+ shift_reg[11]+shift_reg[12]+shift_reg[13]
//                    +shift_reg[14]+shift_reg[15]; 
    //=====pipeline adder pada shift barrel===========
//    always @(posedge CLK) begin
//               shift_regP[0] <= shift_reg[0];
//                shift_regP[1] <=  shift_reg[1];
//                shift_regP[2] <= shift_reg[2];
//                shift_regP[3]<= shift_reg[3];
//                shift_regP[4] <= shift_reg[4];
//                shift_regP[5] <=  shift_reg[5];
//                shift_regP[6] <= shift_reg[6];
//                shift_regP[7]<= shift_reg[7];
//                shift_regP[8]<= shift_reg[8];
//                shift_regP[9]<= shift_reg[9];
//                shift_regP[10]<= shift_reg[10];
//                shift_regP[11]<= shift_reg[11];


//    end
//   assign DAT_OUT = shift_reg[0]+shift_reg[1]+shift_reg[2]+shift_reg[3]+shift_reg[4]+shift_reg[5]+shift_reg[6]+shift_reg[7]+ shift_reg[8]+ shift_reg[9]+ shift_reg[10]+ shift_reg[11]; 
   assign DAT_OUT1 = shift_reg[0]+shift_reg[1]+shift_reg[2]+shift_reg[3]+shift_reg[4]; //+shift_reg[2]; //+shift_reg[3]; //+shift_reg[4]+shift_reg[5];
   assign DAT_OUT2 = shift_reg[5]+shift_reg[6]+shift_reg[7]+shift_reg[8]+shift_reg[9]; //+ shift_reg[8]; //+ shift_reg[9]; //+ shift_reg[10]+ shift_reg[11];
   assign DAT_OUT3 = shift_reg[10]+shift_reg[11]+shift_reg[12]+shift_reg[13]+shift_reg[14]+shift_reg[15]; //+ shift_reg[10]+ shift_reg[11];
   assign DAT_OUT = DAT_OUT1+DAT_OUT2+DAT_OUT3;
   

endmodule
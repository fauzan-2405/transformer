// control_data.v
// This is used to control data from RAM

module data_control #(
    parameter WIDTH = 16, // Bit size for each element
    parameter FACTOR = 2754
) (
    input clk, rst_n,
    input counter,
    input [WIDTH*WIDTH-1:0] data,
    output reg [WIDTH-1:0] out00, out01, out02, out03,
                           out10, out11, out12, out13,
                           out20, out21, out22, out23,
                           out30, out31, out32, out33
);
    always @(posedge done_accum) begin
        if (counter == 16) begin
            // Akses row selanjutnya
        end 
        else begin
            counter <= counter+1
        end
    end

    assign out00 = data[(WIDTH*WIDTH-1)-(WIDTH*0):WIDTH*WIDTH-(WIDTH*0)-WIDTH]; // out00 = [255:240]
    assign out01 = data[(WIDTH*WIDTH-1)-(WIDTH*1):WIDTH*WIDTH-(WIDTH*1)-WIDTH]; // out01 = [239:224]
    assign out02 = data[(WIDTH*WIDTH-1)-(WIDTH*2):WIDTH*WIDTH-(WIDTH*2)-WIDTH]; // out02 = [223:208]
    assign out03 = data[(WIDTH*WIDTH-1)-(WIDTH*3):WIDTH*WIDTH-(WIDTH*3)-WIDTH]; // out03 = [207:192]

    assign out10 = data[(WIDTH*WIDTH-1)-(WIDTH*4):WIDTH*WIDTH-(WIDTH*4)-WIDTH]; // out10 = [191:176]
    assign out11 = data[(WIDTH*WIDTH-1)-(WIDTH*5):WIDTH*WIDTH-(WIDTH*5)-WIDTH]; // out11 = [175:160]
    assign out12 = data[(WIDTH*WIDTH-1)-(WIDTH*6):WIDTH*WIDTH-(WIDTH*6)-WIDTH]; // out12 = [159:144]
    assign out13 = data[(WIDTH*WIDTH-1)-(WIDTH*7):WIDTH*WIDTH-(WIDTH*7)-WIDTH]; // out13 = [143:128]

    assign out20 = data[(WIDTH*WIDTH-1)-(WIDTH*8):WIDTH*WIDTH-(WIDTH*8)-WIDTH]; // out20 = [127:112]
    assign out21 = data[(WIDTH*WIDTH-1)-(WIDTH*9):WIDTH*WIDTH-(WIDTH*9)-WIDTH]; // out21 = [111:96]
    assign out22 = data[(WIDTH*WIDTH-1)-(WIDTH*10):WIDTH*WIDTH-(WIDTH*10)-WIDTH]; // out22 = [95:80]
    assign out23 = data[(WIDTH*WIDTH-1)-(WIDTH*11):WIDTH*WIDTH-(WIDTH*11)-WIDTH]; // out23 = [79:64]

    assign out30 = data[(WIDTH*WIDTH-1)-(WIDTH*12):WIDTH*WIDTH-(WIDTH*12)-WIDTH]; // out30 = [63:48]
    assign out31 = data[(WIDTH*WIDTH-1)-(WIDTH*13):WIDTH*WIDTH-(WIDTH*13)-WIDTH]; // out31 = [47:32]
    assign out32 = data[(WIDTH*WIDTH-1)-(WIDTH*14):WIDTH*WIDTH-(WIDTH*14)-WIDTH]; // out32 = [31:16]
    assign out33 = data[(WIDTH*WIDTH-1)-(WIDTH*15):WIDTH*WIDTH-(WIDTH*15)-WIDTH]; // out33 = [15:0]

endmodule

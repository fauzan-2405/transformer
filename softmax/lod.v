// lod.v
// This module is used for detecting the leading one (Leading One Detection)

module lod (
    input  wire [31:0] num,
    output reg  [4:0]  pos
);
    integer i;
    always @(*) begin
        pos = 5'd0;
        for (i = 31; i >= 0; i = i - 1) begin
            if (num[i] == 1'b1) begin
                pos = i[4:0];
                i = -1; // force exit in pure Verilog
            end
        end
    end
endmodule


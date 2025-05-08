`timescale 1ns / 1ps

module tb_lod;

    reg  [31:0] num;
    wire [4:0]  pos;

    // Instantiate the LOD module
    lod uut (
        .num(num),
        .pos(pos)
    );

    initial begin
        $display("Time\t\tInput\t\t\tLeading One Position");
        $monitor("%0t\t%b\t%0d", $time, num, pos);

        num = 32'b00000000000000000000000000000000; #10;
        num = 32'b00000000000000000000000000000001; #10;
        num = 32'b00000000000000000000000100000000; #10;
        num = 32'b00000000100000000000000000000000; #10;
        num = 32'b11111111111111111111111111111111; #10;
        num = 32'b00001000000000000000000000000000; #10;

        $finish;
    end

endmodule

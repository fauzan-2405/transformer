`timescale 1ns / 1ps

module tb_max_finder;

    parameter DATA_WIDTH = 16;
    parameter INPUT_SIZE = 8;

    reg clk, rst, start;
    reg [DATA_WIDTH-1:0] x [0:INPUT_SIZE-1];
    wire [DATA_WIDTH-1:0] max_val;
    wire done;

    // Instantiate the max_finder module
    max_finder #(
        .DATA_WIDTH(DATA_WIDTH),
        .INPUT_SIZE(INPUT_SIZE)
    ) uut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .x(x),
        .max_val(max_val),
        .done(done)
    );

    // Clock generation
    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst = 1;
        start = 0;
        #10;

        rst = 0;
        // Initialize input array
        x[0] = 16'd12;
        x[1] = 16'd7;
        x[2] = 16'd23;
        x[3] = 16'd15;
        x[4] = 16'd4;
        x[5] = 16'd16;
        x[6] = 16'd5;
        x[7] = 16'd8;

        #10 start = 1;
        #10 start = 0;

        wait(done);

        #10;
        $display("Maximum value = %0d", max_val);
        $finish;
    end

endmodule

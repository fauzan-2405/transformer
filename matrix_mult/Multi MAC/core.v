// core.v
// Used to combine all
`include "mac.v"
`include "mux2_1.v"
`include "control_mux2_1.v"

module core #(
    parameter WIDTH = 16,
    parameter FRAC_WIDTH = 8,
    parameter BLOCK_SIZE = 2, // The size of systolic array dimension (N x N)
    parameter CHUNK_SIZE = 4,
    parameter INNER_DIMENSION = 64 // The same number of rows in one matrix and same number of columns in the other matrix
) (
    input clk, en, rst_n, reset_acc,
    input [(WIDTH*CHUNK_SIZE)-1:0] input_w,
    input [(WIDTH*CHUNK_SIZE)-1:0] input_n,
	
	output accumulator_done, systolic_finish,
	output [(WIDTH*CHUNK_SIZE)-1:0] out
);
    // Wire for mux output
    wire [WIDTH-1:0] out_mux0_n, out_mux1_n;
    wire [WIDTH-1:0] out_mux0_w, out_mux2_w;

    // Wire for control_mux output
    wire [BLOCK_SIZE-1:0] mux_reset_west;
    wire [BLOCK_SIZE-1:0] mux_reset_north;

    // Control mux
    control_mux2_1 control_mux_west (.clk(clk), .en(en), .rst_n(rst_n), .mux_reset(mux_reset_west));
    control_mux2_1 control_mux_north (.clk(clk), .en(en), .rst_n(rst_n), .mux_reset(mux_reset_north));

    // Mux (West)
    mux2_1 #(.WIDTH(WIDTH)) mux0_W (
        .clk(clk), .en(en), .rst_n(mux_reset_west[BLOCK_SIZE-1]),
        .input_0(input_w[(WIDTH*CHUNK_SIZE-1)-WIDTH*0:(WIDTH*CHUNK_SIZE-1)-WIDTH*(0+1)+1]), //[63:48]
        .input_1(input_w[(WIDTH*CHUNK_SIZE-1)-WIDTH*1:(WIDTH*CHUNK_SIZE-1)-WIDTH*(1+1)+1]), //[47:32]
        .out(out_mux0_w)
    );

    mux2_1 #(.WIDTH(WIDTH)) mux1_W (
        .clk(clk), .en(en), .rst_n(mux_reset_west[BLOCK_SIZE-2]),
        .input_0(input_w[(WIDTH*CHUNK_SIZE-1)-WIDTH*2:(WIDTH*CHUNK_SIZE-1)-WIDTH*(2+1)+1]), 
        .input_1(input_w[(WIDTH*CHUNK_SIZE-1)-WIDTH*3:(WIDTH*CHUNK_SIZE-1)-WIDTH*(3+1)+1]), 
        .out(out_mux2_w)
    );

    // Mux North
    mux2_1 #(.WIDTH(WIDTH)) mux0_N (
        .clk(clk), .en(en), .rst_n(mux_reset_west[BLOCK_SIZE-1]),
        .input_0(input_n[(WIDTH*CHUNK_SIZE-1)-WIDTH*0:(WIDTH*CHUNK_SIZE-1)-WIDTH*(0+1)+1]), //[63:48]
        .input_1(input_n[(WIDTH*CHUNK_SIZE-1)-WIDTH*1:(WIDTH*CHUNK_SIZE-1)-WIDTH*(1+1)+1]), //[47:32]
        .out(out_mux0_n)
    );

    mux2_1 #(.WIDTH(WIDTH)) mux1_N (
        .clk(clk), .en(en), .rst_n(mux_reset_west[BLOCK_SIZE-2]),
        .input_0(input_n[(WIDTH*CHUNK_SIZE-1)-WIDTH*2:(WIDTH*CHUNK_SIZE-1)-WIDTH*(2+1)+1]), 
        .input_1(input_n[(WIDTH*CHUNK_SIZE-1)-WIDTH*3:(WIDTH*CHUNK_SIZE-1)-WIDTH*(3+1)+1]), 
        .out(out_mux1_n)
    );

    // MAC
    mac #(.WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH), .BLOCK_SIZE(BLOCK_SIZE), .INNER_DIMENSION(INNER_DIMENSION), .CHUNK_SIZE(CHUNK_SIZE)) mac_0 (
        .clk(clk), .en(en), .rst_n(rst_n), .reset_acc(reset_acc), .in_north0(out_mux0_n), .in_north1(out_mux1_n), .in_west0(out_mux0_w), .in_west2(out_mux2_w),
        .accumulator_done(accumulator_done), .systolic_finish(systolic_finish), .out(out)
    );

endmodule
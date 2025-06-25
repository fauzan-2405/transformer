// core_v2.v
// Used to combine all
//`include "mac_v2.v"
//`include "mux2_1.v"
//`include "control_mux2_1.v"

module core_v2 #(
    parameter WIDTH_A = 16,
    parameter FRAC_WIDTH_A = 8,
    parameter WIDTH_B = 16,
    parameter FRAC_WIDTH_B = 8,
    parameter WIDTH_OUT = 16,
    parameter FRAC_WIDTH_OUT = 8,
    parameter BLOCK_SIZE = 2, 
    parameter CHUNK_SIZE = 4,
    parameter INNER_DIMENSION = 64 
) (
    input clk, en, rst_n, reset_acc,
    input [(WIDTH_A*CHUNK_SIZE)-1:0] input_w,
    input [(WIDTH_B*CHUNK_SIZE)-1:0] input_n,
	
	output accumulator_done, systolic_finish,
	output [(WIDTH_OUT*CHUNK_SIZE)-1:0] out
);
    // Wire for mux output
    wire [WIDTH_B-1:0] out_mux0_n, out_mux1_n;
    wire [WIDTH_A-1:0] out_mux0_w, out_mux2_w;

    // Wire for control_mux output
    wire [BLOCK_SIZE-1:0] mux_reset_west;
    wire [BLOCK_SIZE-1:0] mux_reset_north;

    // Control mux
    control_mux2_1 control_mux_west (.clk(clk), .en(en), .rst_n(rst_n), .mux_reset(mux_reset_west));
    control_mux2_1 control_mux_north (.clk(clk), .en(en), .rst_n(rst_n), .mux_reset(mux_reset_north));

    // Mux (West)
    mux2_1 #(.WIDTH(WIDTH_A)) mux0_W (
        .clk(clk), .en(en), .rst_n(mux_reset_west[BLOCK_SIZE-1]),
        .input_0(input_w[(WIDTH_A*CHUNK_SIZE-1)-WIDTH_A*0:(WIDTH_A*CHUNK_SIZE-1)-WIDTH_A*(0+1)+1]), //[63:48]
        .input_1(input_w[(WIDTH_A*CHUNK_SIZE-1)-WIDTH_A*1:(WIDTH_A*CHUNK_SIZE-1)-WIDTH_A*(1+1)+1]), //[47:32]
        .out(out_mux0_w)
    );

    mux2_1 #(.WIDTH(WIDTH_A)) mux1_W (
        .clk(clk), .en(en), .rst_n(mux_reset_west[BLOCK_SIZE-2]),
        .input_0(input_w[(WIDTH_A*CHUNK_SIZE-1)-WIDTH_A*2:(WIDTH_A*CHUNK_SIZE-1)-WIDTH_A*(2+1)+1]), 
        .input_1(input_w[(WIDTH_A*CHUNK_SIZE-1)-WIDTH_A*3:(WIDTH_A*CHUNK_SIZE-1)-WIDTH_A*(3+1)+1]), 
        .out(out_mux2_w)
    );

    // Mux North
    mux2_1 #(.WIDTH(WIDTH_B)) mux0_N (
        .clk(clk), .en(en), .rst_n(mux_reset_west[BLOCK_SIZE-1]),
        .input_0(input_n[(WIDTH_B*CHUNK_SIZE-1)-WIDTH_B*0:(WIDTH_B*CHUNK_SIZE-1)-WIDTH_B*(0+1)+1]), //[63:48]
        .input_1(input_n[(WIDTH_B*CHUNK_SIZE-1)-WIDTH_B*1:(WIDTH_B*CHUNK_SIZE-1)-WIDTH_B*(1+1)+1]), //[47:32]
        .out(out_mux0_n)
    );

    mux2_1 #(.WIDTH(WIDTH_B)) mux1_N (
        .clk(clk), .en(en), .rst_n(mux_reset_west[BLOCK_SIZE-2]),
        .input_0(input_n[(WIDTH_B*CHUNK_SIZE-1)-WIDTH_B*2:(WIDTH_B*CHUNK_SIZE-1)-WIDTH_B*(2+1)+1]), 
        .input_1(input_n[(WIDTH_B*CHUNK_SIZE-1)-WIDTH_B*3:(WIDTH_B*CHUNK_SIZE-1)-WIDTH_B*(3+1)+1]), 
        .out(out_mux1_n)
    );

    // MAC
    mac_v2 #(.BLOCK_SIZE(BLOCK_SIZE), .INNER_DIMENSION(INNER_DIMENSION), .CHUNK_SIZE(CHUNK_SIZE), .WIDTH_A(WIDTH_A), .FRAC_WIDTH_A(FRAC_WIDTH_A), .WIDTH_B(WIDTH_B), .FRAC_WIDTH_B(FRAC_WIDTH_B), .WIDTH_OUT(WIDTH_OUT), .FRAC_WIDTH_OUT(FRAC_WIDTH_OUT)) 
        mac_0 (
        .clk(clk), .en(en), .rst_n(rst_n), .reset_acc(reset_acc), .in_north0(out_mux0_n), .in_north1(out_mux1_n), .in_west0(out_mux0_w), .in_west2(out_mux2_w),
        .accumulator_done(accumulator_done), .systolic_finish(systolic_finish), .out(out)
    );

endmodule
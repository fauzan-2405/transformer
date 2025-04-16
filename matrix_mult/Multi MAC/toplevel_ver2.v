// toplevel_ver2.v
// This toplevel module does not use buffer and will be used in top_v2.v
//`include "core.v"
//`include "buffer.v"

module toplevel_ver2 #(
    parameter WIDTH = 16,
    parameter FRAC_WIDTH = 8,
    parameter BLOCK_SIZE = 2, // The size of systolic array dimension (N x N)
    parameter CHUNK_SIZE = 4,
    parameter INNER_DIMENSION = 64, // The same number of rows in one matrix and same number of columns in the other matrix
    parameter NUM_CORES = 2
) (
    input clk, en, rst_n, reset_acc,
    input [(WIDTH*CHUNK_SIZE)-1:0] input_n,
    input [(WIDTH*CHUNK_SIZE*NUM_CORES)-1:0] input_w,
	
	output accumulator_done, systolic_finish,
	output [(WIDTH*CHUNK_SIZE*NUM_CORES)-1:0] out_top
);
    // Wire declaration
    wire [NUM_CORES-1:0] acc_done_array;
    wire [NUM_CORES-1:0] systolic_finish_array;
    wire [(WIDTH*CHUNK_SIZE)-1:0] input_w_array [0:NUM_CORES-1];

    genvar i;
    generate
        for (i = 0; i < NUM_CORES; i = i + 1) begin
            assign input_w_array[i] = input_w[(i+1)*(WIDTH * CHUNK_SIZE) - 1 -: (WIDTH * CHUNK_SIZE)];
        end
    endgenerate
    
	// Core generation
	generate
		case (NUM_CORES)
			17: for (i = 0; i < 17; i = i +1) begin
				core #(.WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH), .BLOCK_SIZE(BLOCK_SIZE), .CHUNK_SIZE(CHUNK_SIZE), .INNER_DIMENSION(INNER_DIMENSION)) core_17 (
					.clk(clk), .en(en), .rst_n(rst_n), .reset_acc(reset_acc),
                    .input_w(input_w_array[i]), .input_n(input_n),
                    .accumulator_done(acc_done_array[i]), .systolic_finish(systolic_finish_array[i]),
                    .out(out_top[(i+1)*(WIDTH*CHUNK_SIZE)-1 -: (WIDTH*CHUNK_SIZE)])
				);
				  end
			8:  for (i = 0; i < 8; i = i +1) begin
				core #(.WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH), .BLOCK_SIZE(BLOCK_SIZE), .CHUNK_SIZE(CHUNK_SIZE), .INNER_DIMENSION(INNER_DIMENSION)) core_8 (
					.clk(clk), .en(en), .rst_n(rst_n), .reset_acc(reset_acc),
                    .input_w(input_w_array[i]), .input_n(input_n),
                    .accumulator_done(acc_done_array[i]), .systolic_finish(systolic_finish_array[i]),
                    .out(out_top[(i+1)*(WIDTH*CHUNK_SIZE)-1 -: (WIDTH*CHUNK_SIZE)])		
				);
				  end
			5:  for (i = 0; i < 5; i = i +1) begin
				core #(.WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH), .BLOCK_SIZE(BLOCK_SIZE), .CHUNK_SIZE(CHUNK_SIZE), .INNER_DIMENSION(INNER_DIMENSION)) core_5 (
					.clk(clk), .en(en), .rst_n(rst_n), .reset_acc(reset_acc),
                    .input_w(input_w_array[i]), .input_n(input_n),
                    .accumulator_done(acc_done_array[i]), .systolic_finish(systolic_finish_array[i]),
                    .out(out_top[(i+1)*(WIDTH*CHUNK_SIZE)-1 -: (WIDTH*CHUNK_SIZE)])					
				);
				  end
			4:   for (i = 0; i < 4; i = i +1) begin
				core #(.WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH), .BLOCK_SIZE(BLOCK_SIZE), .CHUNK_SIZE(CHUNK_SIZE), .INNER_DIMENSION(INNER_DIMENSION)) core_4 (
					.clk(clk), .en(en), .rst_n(rst_n), .reset_acc(reset_acc),
                    .input_w(input_w_array[i]), .input_n(input_n),
                    .accumulator_done(acc_done_array[i]), .systolic_finish(systolic_finish_array[i]),
                    .out(out_top[(i+1)*(WIDTH*CHUNK_SIZE)-1 -: (WIDTH*CHUNK_SIZE)])				
				);
				  end
            default: for (i = 0; i < 2; i = i +1) begin
                core #(.WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH), .BLOCK_SIZE(BLOCK_SIZE), .CHUNK_SIZE(CHUNK_SIZE), .INNER_DIMENSION(INNER_DIMENSION)) core_4 (
					.clk(clk), .en(en), .rst_n(rst_n), .reset_acc(reset_acc),
                    .input_w(input_w_array[i]), .input_n(input_n),
                    .accumulator_done(acc_done_array[i]), .systolic_finish(systolic_finish_array[i]),
                    .out(out_top[(i+1)*(WIDTH*CHUNK_SIZE)-1 -: (WIDTH*CHUNK_SIZE)])				
				);
                  end
		endcase
	endgenerate
	
    assign accumulator_done = &acc_done_array[NUM_CORES-1:0];
    assign systolic_finish  = &systolic_finish_array[NUM_CORES-1:0];

endmodule
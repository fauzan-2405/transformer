// toplevel.v
// This toplevel uses buffer for its output, so the output will be 64-bit
// For the one who does not use buffer (the output will be 64-bit x NUM_CORES), see toplevel_v2.v

//`include "core.v"
//`include "buffer.v"

module toplevel #(
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
	output [(WIDTH*CHUNK_SIZE)-1:0] out_top
);
    // Wire declaration
    wire [NUM_CORES-1:0] acc_done_array;
    wire [NUM_CORES-1:0] systolic_finish_array;
    wire [(WIDTH*CHUNK_SIZE)-1:0] input_w_array [0:NUM_CORES-1];
    //wire [(WIDTH*CHUNK_SIZE)-1:0] output_n_array [0:NUM_CORES-1];
    wire [(WIDTH*CHUNK_SIZE*NUM_CORES)-1:0] out_core;

    genvar i;
    generate
        for (i = 0; i < NUM_CORES; i = i + 1) begin
            assign input_w_array[i] = input_w[(i+1)*(WIDTH * CHUNK_SIZE) - 1 -: (WIDTH * CHUNK_SIZE)];
        end
    endgenerate
    
	// Core generation
	generate
        for (i = 0; i < NUM_CORES; i = i +1) begin
            core #(.WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH), .BLOCK_SIZE(BLOCK_SIZE), .CHUNK_SIZE(CHUNK_SIZE), .INNER_DIMENSION(INNER_DIMENSION)) core_inst (
                .clk(clk), .en(en), .rst_n(rst_n), .reset_acc(reset_acc),
                .input_w(input_w_array[i]), .input_n(input_n),
                .accumulator_done(acc_done_array[i]), .systolic_finish(systolic_finish_array[i]),
                .out(out_core[(i+1)*(WIDTH*CHUNK_SIZE)-1 -: (WIDTH*CHUNK_SIZE)])				
            );
        end
	endgenerate

    assign accumulator_done = &acc_done_array[NUM_CORES-1:0];
    assign systolic_finish  = &systolic_finish_array[NUM_CORES-1:0];

    // Buffer instance and output handling
    buffer #(.NUM_CORES(NUM_CORES), .CHUNK_SIZE(CHUNK_SIZE), .WIDTH(WIDTH)) buffer_inst (
        .clk(clk), .rst_n(rst_n), .start(accumulator_done), 
        .in(out_core), .output_buffer(out_top)
    );
	

endmodule
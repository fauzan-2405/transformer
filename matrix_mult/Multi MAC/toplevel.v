// core.v
// Used to combine all
`include "core.v"

module toplevel #(
    parameter WIDTH = 16,
    parameter FRAC_WIDTH = 8,
    parameter BLOCK_SIZE = 2, // The size of systolic array dimension (N x N)
    parameter CHUNK_SIZE = 4,
    parameter INNER_DIMENSION = 64, // The same number of rows in one matrix and same number of columns in the other matrix
    // Matrix A and B parameters
    parameter ROW_SIZE_MAT_A = 16,
    parameter COL_SIZE_MAT_B = 10,
    // Matrix C parameter
    parameter ROW_SIZE_MAT_C = ROW_SIZE_MAT_A / BLOCK_SIZE,
    parameter COL_SIZE_MAT_C = COL_SIZE_MAT_B / BLOCK_SIZE,
) (
    input clk, en, rst_n, reset_acc,
    input [(WIDTH*CHUNK_SIZE)-1:0] input_w,
    input [(WIDTH*CHUNK_SIZE*17)-1:0] input_n,
	
	output accumulator_done, systolic_finish,
	output [(WIDTH*CHUNK_SIZE)-1:0] out
);
    // Wire declaration
    localparam integer NUM_CORES = (INNER_DIMENSION == 2754) ? 17 :
                               (INNER_DIMENSION == 256)  ? 8 :
                               (INNER_DIMENSION == 200)  ? 5 :
                               (INNER_DIMENSION == 64)   ? 4 : 0;

    wire [NUM_CORES-1:0] acc_done_array;
    wire [NUM_CORES-1:0] systolic_finish_array;
    wire [(WIDTH*CHUNK_SIZE)-1:0] input_n_array [0:NUM_CORES-1];
    wire [(WIDTH*CHUNK_SIZE)-1:0] output_n_array [0:NUM_CORES-1];
    genvar i;
    generate
        for (i = 0; i < NUM_CORES; i = i + 1) begin
            assign input_n_array[i] = input_n[(i+1)*(WIDTH * CHUNK_SIZE) - 1 -: (WIDTH * CHUNK_SIZE)];
        end
    endgenerate
    
	// Core generation
    genvar i;
	generate
		case (NUM_CORES)
			17: for (i = 0; i < 17; i++) begin
				core #(.WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH), .BLOCK_SIZE(BLOCK_SIZE), .CHUNK_SIZE(CHUNK_SIZE), .INNER_DIMENSION(INNER_DIMENSION)) core_31 (
					.clk(clk), .en(en), .rst_n(rst_n), .reset_acc(reset_acc),
                    .input_w(input_w), .input_n(input_n_array[i]),
                    .accumulator_done(accumulator_done), .systolic_finish(systolic_finish),
                    .out(output_n_array[i])
				);
				  end
			8:  for (i = 0; i < 8; i++) begin
				core #(.WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH), .BLOCK_SIZE(BLOCK_SIZE), .CHUNK_SIZE(CHUNK_SIZE), .INNER_DIMENSION(INNER_DIMENSION)) core_16 (
					.clk(clk), .en(en), .rst_n(rst_n), .reset_acc(reset_acc),
                    .input_w(input_w), .input_n(input_n_array[i]),
                    .accumulator_done(accumulator_done), .systolic_finish(systolic_finish),
                    .out(output_n_array[i])					
				);
				  end
			5:  for (i = 0; i < 5; i++) begin
				core #(.WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH), .BLOCK_SIZE(BLOCK_SIZE), .CHUNK_SIZE(CHUNK_SIZE), .INNER_DIMENSION(INNER_DIMENSION)) core_10 (
					.clk(clk), .en(en), .rst_n(rst_n), .reset_acc(reset_acc),
                    .input_w(input_w), .input_n(input_n_array[i]),
                    .accumulator_done(accumulator_done), .systolic_finish(systolic_finish),
                    .out(output_n_array[i])					
				);
				  end
			4:   for (i = 0; i < 4; i++) begin
				core #(.WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH), .BLOCK_SIZE(BLOCK_SIZE), .CHUNK_SIZE(CHUNK_SIZE), .INNER_DIMENSION(INNER_DIMENSION)) core_8 (
					.clk(clk), .en(en), .rst_n(rst_n), .reset_acc(reset_acc),
                    .input_w(input_w), .input_n(input_n_array[i]),
                    .accumulator_done(accumulator_done), .systolic_finish(systolic_finish),
                    .out(output_n_array[i])					
				);
				  end
		endcase
	endgenerate

    assign accumulator_done = &acc_done_array[NUM_CORES-1:0];
    assign systolic_finish  = &systolic_finish_array[NUM_CORES-1:0];
	

endmodule
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
    parameter ROW_SIZE_MAT_A = 16;
    parameter COL_SIZE_MAT_B = 10;
    // Matrix C parameter
    parameter ROW_SIZE_MAT_C = ROW_SIZE_MAT_A / BLOCK_SIZE;
    parameter COL_SIZE_MAT_C = COL_SIZE_MAT_B / BLOCK_SIZE;
) (
    input clk, en, rst_n, reset_acc,
    input [(WIDTH*CHUNK_SIZE)-1:0] input_w,
    input [(WIDTH*CHUNK_SIZE)-1:0] input_n,
	
	output accumulator_done, systolic_finish,
	output [(WIDTH*CHUNK_SIZE)-1:0] out
);
    // Wire declaration
    wire accumulator_done, systolic_finish;

	// Core generation
	genvar i;
	generate
		case (INNER_DIMENSION)
			2754: for (i = 0; i < 33; i++) begin
				core #(.WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH), .BLOCK_SIZE(BLOCK_SIZE), .CHUNK_SIZE(CHUNK_SIZE), .INNER_DIMENSION(INNER_DIMENSION)) core_31 (
					.clk(clk), .en(en), .rst_n(rst_n), .(reset_acc),
                    .input_w(), .input_n(),
                    .accumulator_done(accumulator_done), .systolic_finish(systolic_finish),
                    .out()
				);
				  end
			256:  for (i = 0; i < 16; i++) begin
				core #(.WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH), .BLOCK_SIZE(BLOCK_SIZE), .CHUNK_SIZE(CHUNK_SIZE), .INNER_DIMENSION(INNER_DIMENSION)) core_16 (
					
				);
				  end
			200:  for (i = 0; i < 10; i++) begin
				core #(.WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH), .BLOCK_SIZE(BLOCK_SIZE), .CHUNK_SIZE(CHUNK_SIZE), .INNER_DIMENSION(INNER_DIMENSION)) core_10 (
					
				);
				  end
			16:   for (i = 0; i < 8; i++) begin
				core #(.WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH), .BLOCK_SIZE(BLOCK_SIZE), .CHUNK_SIZE(CHUNK_SIZE), .INNER_DIMENSION(INNER_DIMENSION)) core_8 (
					
				);
				  end
		endcase
	endgenerate

    // ** Controller ******************
    // Start at enable
    always @(posedge clk) begin
        if (en) begin
            if (systolic_finish == 1) begin
                rst_n <= 0;
            end else begin 
                rst_n <= 1;
            end
        end
    end
    // Reset accumulator ever
    always @(posedge systolic_finish) begin
        if (accumulator_done == 1) begin
            reset_acc <= 0;
        end else begin
            reset_acc <= 1;
        end
    end

    // We decided to be input stationary (input A)
    always @(posedge systolic_finish) begin
        counter_A <= counter + (INNER_DIMENSION/BLOCK_SIZE)*counter_row;
        counter_B <= counter + (INNER_DIMENSION/BLOCK_SIZE)*counter_col;
    end

    always @(posedge systolic_finish) begin
        if (counter == ((INNER_DIMENSION/BLOCK_SIZE) - 1)) begin
            counter <=0;
        end
        else begin
            counter <= counter + 1;
        end
    end

    // Check if we already at the end of the MAT C column
    always @(posedge accumulator_done) begin 
        if (counter_col == (COL_SIZE_MAT_C - 1)) begin
            counter_col <= 0;
            counter_row <= counter_row + 1;
        end else begin
            counter_col <= counter_col + 1;
        end
    end

	

endmodule
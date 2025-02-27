// accumulator.v
// Used to accumulate the result from 2X2 systolic array

module accumulator #(
    parameter WIDTH = 16,
    parameter FRAC_WIDTH = 8,
    parameter BLOCK_SIZE = 2, // The size of systolic array dimension (N x N)
    parameter CHUNK_SIZE = 4,
    parameter INNER_DIMENSION = 64 // The same number of rows in one matrix and same number of columns in the other matrix
) (
    input clk, rst_n,
    input [WIDTH*CHUNK_SIZE-1:0] in, // This is a input from systolic output
    input systolic_done,

    output reg accumulator_done,
    output reg [WIDTH*CHUNK_SIZE-1:0] out
);
    reg [WIDTH-1:0] update_value[CHUNK_SIZE-1:0]; // The number of element we want to update the value
	// Dont initialize these parameters if you want to do accumulator or mac simulation on testbench
    reg [6:0] counter = 7'b1111_111; // To count the iteration to produce one block of output based on the dimension of systolic output
	
    always @(posedge systolic_done) begin
        if (!rst_n) begin
            accumulator_done <= 0;
            counter <= 0;
			update_value[0] <= 'h0000;
			update_value[1] <= 'h0000;
			update_value[2] <= 'h0000;
			update_value[3] <= 'h0000;
            out <= {WIDTH*CHUNK_SIZE{1'b0}}; // Reset all to 0
        end
        else begin
			//if (counter == 1) begin
            if (counter == (INNER_DIMENSION/BLOCK_SIZE)) begin
                accumulator_done <= 1;
				// Concatenate all update_value registers for the output
                out[(WIDTH*1)-1:WIDTH*0] <= update_value[3];
                out[(WIDTH*2)-1:WIDTH*1] <= update_value[2];
                out[(WIDTH*3)-1:WIDTH*2] <= update_value[1];
                out[(WIDTH*4)-1:WIDTH*3] <= update_value[0];
				counter <= 0;
            end
            else begin
                accumulator_done <= 0;
                counter <= counter + 1;
            end
		// Accumulate the input values
		update_value[0] <= update_value[0] + in[(WIDTH*CHUNK_SIZE-1)-WIDTH*0:(WIDTH*CHUNK_SIZE-1)-WIDTH*(0+1)+1]; // in[(64-1)-0:(64-1)-16*1+1]= [63:48]
        update_value[1] <= update_value[1] + in[(WIDTH*CHUNK_SIZE-1)-WIDTH*1:(WIDTH*CHUNK_SIZE-1)-WIDTH*(1+1)+1];
        update_value[2] <= update_value[2] + in[(WIDTH*CHUNK_SIZE-1)-WIDTH*2:(WIDTH*CHUNK_SIZE-1)-WIDTH*(2+1)+1];
        update_value[3] <= update_value[3] + in[(WIDTH*CHUNK_SIZE-1)-WIDTH*3:(WIDTH*CHUNK_SIZE-1)-WIDTH*(3+1)+1];

        end		
    end
endmodule

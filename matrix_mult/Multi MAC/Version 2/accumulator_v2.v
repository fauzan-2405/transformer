// accumulator_v2.v
// Used to accumulate the result from 2X2 systolic array

module accumulator_v2 #(
    parameter WIDTH_OUT = 16,
    parameter FRAC_WIDTH_OUT = 8,
    parameter BLOCK_SIZE = 2, // The size of systolic array dimension (N x N)
    parameter CHUNK_SIZE = 4,
    parameter INNER_DIMENSION = 64 // The same number of rows in one matrix and same number of columns in the other matrix
) (
    input clk, rst_n,
    input [WIDTH_OUT*CHUNK_SIZE-1:0] in, // This is a input from systolic output
    input systolic_done,

    output reg accumulator_done,
    output reg [WIDTH_OUT*CHUNK_SIZE-1:0] out_accum
);
    reg [WIDTH_OUT-1:0] update_value[CHUNK_SIZE-1:0]; // The number of element we want to update the value
	// Dont initialize these parameters if you want to do accumulator or mac simulation on testbench
    reg [6:0] counter = 7'b1111_111; // To count the iteration to produce one block of output based on the dimension of systolic output
	
    always @(posedge systolic_done) begin
        if (!rst_n) begin
            accumulator_done <= 0;
            counter <= 0;
			update_value[0] <= {WIDTH_OUT{1'b0}};
			update_value[1] <= {WIDTH_OUT{1'b0}};
			update_value[2] <= {WIDTH_OUT{1'b0}};
			update_value[3] <= {WIDTH_OUT{1'b0}};
            out_accum <= {WIDTH_OUT*CHUNK_SIZE{1'b0}}; // Reset all to 0
        end
        else begin
			//if (counter == 1) begin
            if (counter == (INNER_DIMENSION/BLOCK_SIZE) ) begin
                accumulator_done <= 1;
                // Concatenate all update_value registers for the output
                out_accum[(WIDTH_OUT*1)-1:WIDTH_OUT*0] <= update_value[3];
                out_accum[(WIDTH_OUT*2)-1:WIDTH_OUT*1] <= update_value[2];
                out_accum[(WIDTH_OUT*3)-1:WIDTH_OUT*2] <= update_value[1];
                out_accum[(WIDTH_OUT*4)-1:WIDTH_OUT*3] <= update_value[0];
                counter <= 0;
            end
            else begin
                accumulator_done <= 0;
                counter <= counter + 1;
            end
        // Accumulate the input values
        update_value[0] <= update_value[0] + in[(WIDTH_OUT*CHUNK_SIZE-1)-WIDTH_OUT*0:(WIDTH_OUT*CHUNK_SIZE-1)-WIDTH_OUT*(0+1)+1]; // in[(64-1)-0:(64-1)-16*1+1]= [63:48]
        update_value[1] <= update_value[1] + in[(WIDTH_OUT*CHUNK_SIZE-1)-WIDTH_OUT*1:(WIDTH_OUT*CHUNK_SIZE-1)-WIDTH_OUT*(1+1)+1];
        update_value[2] <= update_value[2] + in[(WIDTH_OUT*CHUNK_SIZE-1)-WIDTH_OUT*2:(WIDTH_OUT*CHUNK_SIZE-1)-WIDTH_OUT*(2+1)+1];
        update_value[3] <= update_value[3] + in[(WIDTH_OUT*CHUNK_SIZE-1)-WIDTH_OUT*3:(WIDTH_OUT*CHUNK_SIZE-1)-WIDTH_OUT*(3+1)+1];

        end
    end
endmodule

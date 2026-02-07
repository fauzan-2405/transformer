// accumulator_v3.v, the module's name is still accumulator_v2 for easier implementation
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
    // Accumulator sizing
    localparam integer ACC_EXTRA_BITS   = $clog2(INNER_DIMENSION/BLOCK_SIZE) + 2;
    localparam integer ACC_WIDTH        = WIDTH_OUT + ACC_EXTRA_BITS;

    reg [ACC_WIDTH-1:0] update_value[CHUNK_SIZE-1:0]; // The number of element we want to update the value
        // Dont initialize these parameters if you want to do accumulator or mac simulation on testbench
    reg [6:0] counter = 7'b1111_111; // To count the iteration to produce one block of output based on the dimension of systolic output
    //reg [6:0] counter;

    //always @(posedge systolic_done) begin
    always @(posedge clk) begin
        if (!rst_n) begin
            accumulator_done <= 0;
            counter <= 0;
            update_value[0] <= {ACC_WIDTH{1'b0}};
            update_value[1] <= {ACC_WIDTH{1'b0}};
            update_value[2] <= {ACC_WIDTH{1'b0}};
            update_value[3] <= {ACC_WIDTH{1'b0}};
            out_accum <= {WIDTH_OUT*CHUNK_SIZE{1'b0}}; // Reset all to 0
            //out_accum <= 0;
        end
        //else begin
        else if (systolic_done) begin
            //if (counter == 1) begin
            //if (systolic_done) begin // Comment this if this breaks
            if (counter == (INNER_DIMENSION/BLOCK_SIZE)) begin
                accumulator_done <= 1;
                // Concatenate all update_value registers for the output
                out_accum[(WIDTH_OUT*1)-1:WIDTH_OUT*0] <= sat(update_value[3]);
                out_accum[(WIDTH_OUT*2)-1:WIDTH_OUT*1] <= sat(update_value[2]);
                out_accum[(WIDTH_OUT*3)-1:WIDTH_OUT*2] <= sat(update_value[1]);
                out_accum[(WIDTH_OUT*4)-1:WIDTH_OUT*3] <= sat(update_value[0]);
                counter <= 0;
            end
            else begin
                accumulator_done <= 0;
                counter <= counter + 1;
            end
            // Accumulate the input values
            update_value[0] <= update_value[0] + {{(ACC_WIDTH-WIDTH_OUT){in[(WIDTH_OUT*CHUNK_SIZE-1)-WIDTH_OUT*0]}}, in[(WIDTH_OUT*CHUNK_SIZE-1)-WIDTH_OUT*0 : (WIDTH_OUT*CHUNK_SIZE-1)-WIDTH_OUT*(0+1)+1]};
            update_value[1] <= update_value[1] + {{(ACC_WIDTH-WIDTH_OUT){in[(WIDTH_OUT*CHUNK_SIZE-1)-WIDTH_OUT*1]}}, in[(WIDTH_OUT*CHUNK_SIZE-1)-WIDTH_OUT*1 : (WIDTH_OUT*CHUNK_SIZE-1)-WIDTH_OUT*(1+1)+1]};
            update_value[2] <= update_value[2] + {{(ACC_WIDTH-WIDTH_OUT){in[(WIDTH_OUT*CHUNK_SIZE-1)-WIDTH_OUT*2]}}, in[(WIDTH_OUT*CHUNK_SIZE-1)-WIDTH_OUT*2 : (WIDTH_OUT*CHUNK_SIZE-1)-WIDTH_OUT*(2+1)+1]};
            update_value[3] <= update_value[3] + {{(ACC_WIDTH-WIDTH_OUT){in[(WIDTH_OUT*CHUNK_SIZE-1)-WIDTH_OUT*3]}}, in[(WIDTH_OUT*CHUNK_SIZE-1)-WIDTH_OUT*3 : (WIDTH_OUT*CHUNK_SIZE-1)-WIDTH_OUT*(3+1)+1]};
        end
    end

    // Local function wrapper for saturation
    function automatic signed [WIDTH_OUT-1:0] sat;
        input signed [ACC_WIDTH-1:0] val;
        signed [ACC_WIDTH-1:0] max_v, min_v;
    begin
        max_v = $signed({{(ACC_WIDTH-WIDTH_OUT){1'b0}},
                        {1'b0,{(WIDTH_OUT-1){1'b1}}}});

        min_v = $signed({{(ACC_WIDTH-WIDTH_OUT){1'b1}},
                        {1'b1,{(WIDTH_OUT-1){1'b0}}}});

        if (val > max_v)
            sat = {1'b0,{(WIDTH_OUT-1){1'b1}}};
        else if (val < min_v)
            sat = {1'b1,{(WIDTH_OUT-1){1'b0}}};
        else
            sat = val[WIDTH_OUT-1:0];
    end
    endfunction

endmodule

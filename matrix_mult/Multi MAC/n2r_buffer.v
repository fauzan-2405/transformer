// n2r_buffer.v
// Normal to Ready buffer
// Used for changing the shape of the matrix from the normal version (row by row) to the ready to be inputted to the matrix multiplication module

module n2r_buffer #(
    parameter WIDTH = 16,
    parameter FRAC_WIDTH = 8,
    parameter BLOCK_SIZE = 2, 
    parameter CHUNK_SIZE = 4,
    parameter ROW = 4, 
    parameter COL = 6,
    parameter NUM_CORES = (COL == 2754) ? 9 :
                               (COL == 256)  ? 8 :
                               (COL == 200)  ? 5 :
                               (COL == 64)   ? 4 : 2
) (
    input clk, rst_n, en,
    input [WIDTH*COL] in_n2r_buffer,
    output reg [WIDTH*CHUNK_SIZE*NUM_CORES-1:0] out_n2r_buffer
);
    reg [7:0] counter; // Row counter
    reg [7:0] counter_block; // Block counter to start slicing the input
    reg [(WIDTH*COL)-1:0] temp_buffer [0:BLOCK_SIZE*NUM_CORES-1];

    integer i, j;

    always @(posedge clk) begin
        if (!rst_n) begin
            counter <= 0;
            counter_block <= BLOCK_SIZE*NUM_CORES-1;
        end
        else begin
            if (en) begin
                // Do the slicing when the counter is equal to the number of the block that we want to be outputted
                if (counter == counter_block) begin
                    // Update the counter_block value
                    counter_block <= counter_block*2 + 1;

                    // Slicing the buffer 
                    for (j = 0; j < COL/BLOCK_SIZE; j = j + 1) begin // Col
                        for (i = 0; i < BLOCK_SIZE*NUM_CORES; i = i + 1) begin // Row
                            out_n2r_buffer[(BLOCK_SIZE*NUM_CORES-1-i)*32 +: 32] <= temp_buffer[i][((WIDTH*COL-1)-(32*j)) -: 32];
                        end
                    end
                end
                
                else begin
                    temp_buffer[counter] <= in_n2r_buffer;
                    counter <= counter + 1;
                end
            end
        end
    end


endmodule
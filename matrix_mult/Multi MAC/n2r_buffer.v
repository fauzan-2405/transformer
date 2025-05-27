// n2r_buffer.v
// Normal to Ready buffer
// Used for changing the shape of the matrix from the normal version (row by row) to the ready to be inputted to the matrix multiplication module
/* TODO
    1. Solve the out_buffer[j], the j variable is not correct
*/

module n2r_buffer (
    parameter WIDTH = 16,
    parameter FRAC_WIDTH = 8,
    parameter BLOCK_SIZE = 2, 
    parameter CHUNK_SIZE = 4,
    parameter ROW = 2754, 
    parameter COL = 256,
    parameter NUM_CORES = (COL == 2754) ? 9 :
                               (COL == 256)  ? 8 :
                               (COL == 200)  ? 5 :
                               (COL == 64)   ? 4 : 2
) (
    input clk, rst_n, en,
    input [WIDTH*COL] in_n2r_buffer,
    output slice_done, // To inform if the output sending is done or not
    output reg [WIDTH*CHUNK_SIZE*NUM_CORES-1:0] out_n2r_buffer
);
    reg [7:0] counter; // Row counter for temp_buffer
    reg [7:0] counter_row; // Row counter per NUM_CORES
    reg [7:0] counter_block; // Block counter to start slicing the input
    reg [7:0] counter_out; // Output counter

    reg [(WIDTH*COL)-1:0] temp_buffer [0:BLOCK_SIZE*NUM_CORES-1];
    reg [WIDTH*CHUNK_SIZE*NUM_CORES-1:0] out_buffer [0:(COL/BLOCK_SIZE)]

    integer i, j;

    reg [2:0] state_reg, state_next;

    // State Machine
    always @(posedge clk) begin
        if (!rst_n) begin
            state_reg <= 0;
            counter <= 0;
            counter_out <= 0;
            counter_block <= BLOCK_SIZE*NUM_CORES-1;
            counter_row < = 0;
        end else begin
            state_reg <= state_next;

            // Inserting the input to the temporary buffer
            temp_buffer[counter] <= in_n2r_buffer;
            if (counter < ROW) begin
                counter = counter + 1;
            end

            // Sending the output on state 2
            if (state_reg == 2) begin
                out_n2r_buffer <= out_buffer[counter_out];
                if (counter_out < COL/BLOCK_SIZE) begin
                    counter_out <= counter_out + 1;
                end else begin
                    counter_out <= 0;
                end
            end
        end
    end

    always @(*) begin
        state_next = state_reg;
        case (state_reg)
            0: // Begin state 0
            begin
                if (en & ~slice_done) begin
                    state_next = 1;
                end
            end
            1: // State 1: Increment the counter and insert the input to the temp_buffer
            begin
                if (counter >= counter_block) begin
                    state_next = 2;
                end
                else if ((counter == ROW-1) & (counter_block == ROW-1)) begin
                    state_next = 0;
                end
            end
            2: // State 2: Slice the temp_buffer to the out buffer and send the output
            begin
                if (counter_out == COL/BLOCK_SIZE) begin
                    state_next = 1;
                    counter_row = counter_row + BLOCK_SIZE*NUM_CORES
                end
                else begin
                    // Update the counter_block
                    counter_block = counter_block*2 + 1;

                    for (j = 0; j < COL/BLOCK_SIZE; j = j + 1) begin // Col
                        for (i = 0; i < BLOCK_SIZE*NUM_CORES; i = i + 1) begin // Row
                            out_buffer[j][(BLOCK_SIZE*NUM_CORES-1-i)*32 +: 32] <= temp_buffer[counter_row+i][((WIDTH*COL-1)-(32*j)) -: 32];
                        end
                    end
                end
            end
        endcase
    end

    assign slice_done = (counter_out == COL/BLOCK_SIZE);

    /*
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
    */


endmodule
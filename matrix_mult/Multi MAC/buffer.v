// buffer.v
// Used as a buffer from the toplevel output

module buffer #(
    parameter NUM_CORES = 4,
    parameter CHUNK_SIZE = 4,
    parameter WIDTH = 16
) (
    input clk, rst_n, start,
    input [(WIDTH*CHUNK_SIZE*NUM_CORES)-1:0] in,
    output reg [(WIDTH*CHUNK_SIZE)-1:0] output_buffer
);
    wire [(WIDTH*CHUNK_SIZE)-1:0] out_n [0:NUM_CORES-1];
    reg [5:0] counter;
    // [4:0] IDLE = 5'b11111;  // Define IDLE state as all 1s
    
    genvar i;
    generate
        for (i=0; i<NUM_CORES; i = i +1) begin
            assign out_n[i] = in[(i+1)*(WIDTH*CHUNK_SIZE)-1 -: (WIDTH*CHUNK_SIZE)];
        end
    endgenerate

    always @(posedge clk) begin
        if (!rst_n) begin
            counter <= 0; // Assign all bits to 1
            output_buffer <= 0;
        end
        else if (start) begin
            output_buffer <= out_n[counter];
            if (counter == 0) begin
                counter <= counter + 1;
            end
            else if (counter <= NUM_CORES - 1) begin
                counter <= counter;
            end
            else begin
                counter <= counter + 1;
            end
        end
    end
    
endmodule
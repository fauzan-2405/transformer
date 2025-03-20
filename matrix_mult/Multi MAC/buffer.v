// buffer.v
// Used as a buffer from the toplevel output

module buffer #(
    parameter NUM_CORES = 4,
    parameter CHUNK_SIZE = 4,
    parameter WIDTH = 16
) (
    input clk, en,
    input [(WIDTH*CHUNK_SIZE*NUM_CORES)-1:0] in,
    output reg [(WIDTH*CHUNK_SIZE)-1:0] output_buffer
);
    wire [(WIDTH*CHUNK_SIZE)-1:0] out_n [0:NUM_CORES-1];
    reg [$clog2(NUM_CORES)-1:0] counter = 0;
    
    genvar i;
    generate
        for (i=0; i<NUM_CORES; i = i +1) begin
            assign out_n[i] = in[(i+1)*(WIDTH*CHUNK_SIZE)-1 -: (WIDTH*CHUNK_SIZE)];
        end
    endgenerate

    always @(posedge clk) begin
        if (en) begin
            out <= out_n[counter];
            counter <= counter+1;
            if (counter == NUM_CORES-1) begin
                counter <= 0;
            end
        end
        else begin
            counter <= 0;
        end
    end
    
endmodule
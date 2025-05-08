// max_finder.v
// Used for finding the maximum value

module max_finder #(
    parameter DATA_WIDTH = 16,
    parameter INPUT_SIZE = 8
)(
    input  wire                   clk,
    input  wire                   rst,
    input  wire                   start,
    input  wire [DATA_WIDTH-1:0] x [0:INPUT_SIZE-1],
    output reg  [DATA_WIDTH-1:0] max_val,
    output reg                   done
);

    reg [3:0] index;
    reg [DATA_WIDTH-1:0] temp_max;
    reg processing;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            index     <= 0;
            temp_max  <= 0;
            max_val   <= 0;
            done      <= 0;
            processing <= 0;
        end else begin
            if (start && !processing) begin
                temp_max  <= x[0];
                index     <= 1;
                done      <= 0;
                processing <= 1;
            end else if (processing) begin
                if (index < INPUT_SIZE) begin
                    if (x[index] > temp_max)
                        temp_max <= x[index];
                    index <= index + 1;
                end else begin
                    max_val   <= temp_max;
                    done      <= 1;
                    processing <= 0;
                end
            end
        end
    end
endmodule

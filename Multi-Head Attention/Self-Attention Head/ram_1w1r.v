// ram_1w1r.v
// Simplified version to write and read simultaenously

module ram_1w1r #(
    parameter DATA_WIDTH = 4096,
    parameter DEPTH = 64
) (
    input clk,
    input we,
    input [$clog2(DEPTH)-1:0] write_addr,
    input [$clog2(DEPTH)-1:0] read_addr,
    input [DATA_WIDTH-1:0] din,
    output reg [DATA_WIDTH-1:0] dout
);
    (* ram_style = "block" *) // Force inference of BRAM in Vivado
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    always @(posedge clk) begin
        if (we) begin
            mem[write_addr] <= din;
        end
        dout <= mem[read_addr];
    end

endmodule
module ram_1w2r #(
    parameter DATA_WIDTH = 1024,
    parameter DEPTH      = 256
)(
    input  wire clk,
    input  wire we,
    input  wire [$clog2(DEPTH)-1:0] write_addr,
    input  wire [$clog2(DEPTH)-1:0] read_addr0,
    input  wire [$clog2(DEPTH)-1:0] read_addr1,
    input  wire [DATA_WIDTH-1:0]    din,
    output reg  [DATA_WIDTH-1:0]    dout0,
    output reg  [DATA_WIDTH-1:0]    dout1
);

    (* ram_style = "block" *)
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    always @(posedge clk) begin
        if (we) begin
            mem[write_addr] <= din;
        end
        dout0 <= mem[read_addr0];
        dout1 <= mem[read_addr1];
    end
endmodule

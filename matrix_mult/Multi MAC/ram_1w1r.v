// ram_1w1r.v
// Simplified version to write and read simultaenously

module ram_1w1r #(
    parameter DATA_WIDTH = 4096,
    parameter DEPTH = 64
) (
    input clk,
    input rst_n,
    input we,
    input [clog2_safe(DEPTH)-1:0] write_addr,
    input [clog2_safe(DEPTH)-1:0] read_addr,
    input [DATA_WIDTH-1:0] din,
    output reg [DATA_WIDTH-1:0] dout
);
    function automatic int clog2_safe
        input integer value;
        begin
            if (value <= 1) begin
                return 1;
            end else begin
                return $clog2(value);
            end
        end
    endfunction

    (* ram_style = "block" *) // Force inference of BRAM in Vivado
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    integer i;

    always @(posedge clk) begin
        if (!rst_n) begin
            for (i = 0; i < DEPTH; i = i + 1) begin
                mem[i] <= 0;
            end
        end
        else if (we) begin
            mem[write_addr] <= din;
        end
        dout <= mem[read_addr];
    end

endmodule
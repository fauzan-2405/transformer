// control_unit.v
// Used to control mux to stream input

module control_unit (
    input clk, rst_n,
    output wire [3:0] mux_reset
);
    reg [7:0] counter; // For controlling reset

    assign mux_reset = counter[7:4];

    always @(posedge clk) begin
        if (rst_n) begin // Active
			if (counter == 8'b0000_1111) begin
				counter <= 8'b0000_1111;
			end
            counter <= (counter >> 1)|(counter << 7);
        end
        else begin // Not Active
			 counter <= 8'b1000_0111; 
			// This is not used because there's a bug when first
			// mux is not defined. It is because the reset is already 1 so the variable "select" on mux
			// (see mux.v) is not yet defined
            //counter <= 8'b0000_1111; 
        end
    end


endmodule
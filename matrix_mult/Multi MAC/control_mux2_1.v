// control_mux2_1.v
// Used to control mux to stream input

module control_mux2_1 (
    input clk, rst_n, en,
    output wire [1:0] mux_reset
);
    //reg [3:0] counter = 4'b10_01; // For controlling reset
	reg [3:0] counter;
	assign mux_reset = counter[3:2];

    always @(posedge clk) begin
        if (rst_n) begin // Active
			if (counter == 4'b00_11) begin
				counter <= 4'b00_11;
			end else begin
				if (en) begin
					counter <= (counter >> 1)|(counter << 3);
				end
			end
        end
        else begin // Not Active
			 counter <= 4'b10_01; 
        end
    end


endmodule
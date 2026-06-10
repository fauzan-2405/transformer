module delay_register #(
    parameter WIDTH = 8,  // Width of the data signal
    parameter DELAY = 4   // X cycles of delay
)(
    input  wire             clk,
    input  wire             rst_n, // Active-low synchronous reset
    input  wire [WIDTH-1:0] data_in,
    output wire [WIDTH-1:0] data_out
);

    // Guard against a 0-cycle delay request
    if (DELAY == 0) begin
        assign data_out = data_in;
    end else begin
        // Create an array of registers (the pipeline pipeline)
        reg [WIDTH-1:0] pipe [0:DELAY-1];
        integer i;

        always @(posedge clk) begin
            if (!rst_n) begin
                // Reset all stages in the pipeline
                for (i = 0; i < DELAY; i = i + 1) begin
                    pipe[i] <= {WIDTH{1'b0}};
                end
            end else begin
                // Shift the data through the pipeline
                pipe[0] <= data_in; // First stage takes the input
                for (i = 1; i < DELAY; i = i + 1) begin
                    pipe[i] <= pipe[i-1]; // Subsequent stages shift
                end
            end
        end

        // The output is the last stage of the pipeline
        assign data_out = pipe[DELAY-1];
    end

endmodule
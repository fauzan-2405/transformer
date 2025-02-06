module tb_saturate;

    // Testbench signals
    reg clk;
    reg rst_n;
    reg [31:0] in;  // 2*WIDTH = 32 bits for the input
    wire [15:0] out;  // 16-bit output

    // Instantiate the saturate module
    saturate #(
        .WIDTH(16),
        .FRAC_WIDTH(8)
    ) saturate_inst (
        .clk(clk),
        .rst_n(rst_n),
        .in(in),
        .out(out)
    );

    // Clock generation
    always begin
        #5 clk = ~clk;  // 10ns clock period
    end

    // Initial block to initialize signals and apply test cases
    initial begin
        // Initialize signals
        clk = 0;
        rst_n = 0;
        in = 32'b0;

        // Set up VCD dump file
        $dumpfile("tb_saturate.vcd");  // VCD output file
        $dumpvars(0, tb_saturate);      // Dump all variables in the testbench

        // Apply reset
        #10 rst_n = 1;
        
        // Test Case 1: Positive value within range (16.75)
        in = 16'b00010000_11000000;  // 16.75
        #10;
        $display("Test Case 1: in = %b, out = %b", in, out);
        
        // Test Case 2: Negative value within range (-128)
        in = 16'b10000000_00000000;  // -128
        #10;
        $display("Test Case 2: in = %b, out = %b", in, out);

        // Test Case 3: Overflow positive (127.99609375)
        in = 16'b01111111_11111111;  // 127.99609375 (max positive value for Q8.8)
        #10;
        $display("Test Case 3: in = %b, out = %b", in, out);

        // Test Case 4: Overflow negative (-128.0)
        in = 16'b10000001_00000000;  // -128.0 (underflow, should clip to -128)
        #10;
        $display("Test Case 4: in = %b, out = %b", in, out);

        // Test Case 5: Negative value out of range (-129)
        in = 16'b10000010_00000000;  // -129 (should clip to -128)
        #10;
        $display("Test Case 5: in = %b, out = %b", in, out);
        
        // Test Case 6: Positive value just below overflow (126.5)
        in = 16'b01111111_11000000;  // 126.5
        #10;
        $display("Test Case 6: in = %b, out = %b", in, out);

        // End simulation
        $finish;
    end

endmodule

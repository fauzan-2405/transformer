`timescale 1ns/1ps

module tb_rshift;

    // ===========================================================
    // Parameters (match your module!)
    // ===========================================================
    localparam WIDTH_OUT      = 16;
    localparam CHUNK_SIZE     = 4;
    localparam NUM_CORES_A    = 4;
    localparam NUM_CORES_B    = 1;
    localparam TOTAL_MODULES  = 2;
    localparam TOTAL_INPUT_W  = 2;

    localparam ELEMENTS_PER_VEC =
            CHUNK_SIZE * NUM_CORES_A * NUM_CORES_B * TOTAL_MODULES;

    localparam VECTOR_BITS = WIDTH_OUT * ELEMENTS_PER_VEC;

    // ===========================================================
    // DUT I/O signals
    // ===========================================================
    logic clk;
    logic rst_n;

    logic [VECTOR_BITS-1:0] in_4bit_rshift [TOTAL_INPUT_W];
    logic [VECTOR_BITS-1:0] out_shifted    [TOTAL_INPUT_W];
    logic out_valid;

    // ===========================================================
    // Instantiate DUT
    // ===========================================================
    rshift #(
        .WIDTH_OUT(WIDTH_OUT),
        .CHUNK_SIZE(CHUNK_SIZE),
        .TOTAL_MODULES(TOTAL_MODULES),
        .TOTAL_INPUT_W(TOTAL_INPUT_W),
        .NUM_CORES_A(NUM_CORES_A),
        .NUM_CORES_B(NUM_CORES_B)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .in_4bit_rshift(in_4bit_rshift),
        .out_shifted(out_shifted),
        .out_valid(out_valid)
    );

    // ===========================================================
    // Clock generation
    // ===========================================================
    initial clk = 0;
    always #5 clk = ~clk;   // 100 MHz clock

    // ===========================================================
    // Task: Apply reset
    // ===========================================================
    task apply_reset;
        begin
            rst_n = 0;
            repeat(3) @(posedge clk);
            rst_n = 1;
        end
    endtask

    // ===========================================================
    // Golden reference computation
    // ===========================================================
    function automatic [VECTOR_BITS-1:0]
        golden_shift(input [VECTOR_BITS-1:0] vec);

        logic signed [WIDTH_OUT-1:0] element;
        logic signed [WIDTH_OUT-1:0] shifted;
        integer e;

        begin
            golden_shift = '0;

            for (e = 0; e < ELEMENTS_PER_VEC; e++) begin
                int high = VECTOR_BITS - e*WIDTH_OUT - 1;
                int low  = VECTOR_BITS - (e+1)*WIDTH_OUT;

                element = vec[high:low];
                shifted = element >>> 4;

                golden_shift[high:low] = shifted;
            end
        end
    endfunction

    // ===========================================================
    // Test sequence
    // ===========================================================
    integer i, w;

    initial begin
        $display("=== TB START ===");

        // Initialize inputs
        for (w = 0; w < TOTAL_INPUT_W; w++)
            in_4bit_rshift[w] = '0;

        // Apply reset
        apply_reset();

        // -------------------------------------------------------
        // Test 1: Random stimuli
        // -------------------------------------------------------
        for (i = 0; i < 10; i++) begin
            @(posedge clk);

            // Random input vectors
            for (w = 0; w < TOTAL_INPUT_W; w++)
                in_4bit_rshift[w] = $urandom;

            @(posedge clk);

            if (out_valid) begin
                for (w = 0; w < TOTAL_INPUT_W; w++) begin
                    if (out_shifted[w] !== golden_shift(in_4bit_rshift[w])) begin
                        $display("ERROR at cycle %0d, W=%0d", i, w);
                        $display("DUT:    %h", out_shifted[w]);
                        $display("GOLDEN: %h", golden_shift(in_4bit_rshift[w]));
                        $fatal("Mismatch detected!");
                    end else begin
                        $display("PASS at cycle %0d, W=%0d", i, w);
                    end
                end
            end
        end

        $display("=== TB FINISHED SUCCESSFULLY ===");
        $finish;
    end

endmodule

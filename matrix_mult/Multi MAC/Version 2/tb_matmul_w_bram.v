`timescale 1ns / 1ps

module tb_matmul_w_bram;

    // Parameters
    parameter WIDTH_A = 8; 
    parameter WIDTH_B = 8; 
    parameter WIDTH_OUT = 16;

    parameter FRAC_WIDTH_A = 4; 
    parameter FRAC_WIDTH_B = 4; 
    parameter FRAC_WIDTH_OUT = 8;

    parameter INNER_DIMENSION = 6; 
    parameter A_OUTER_DIMENSION = 12; 
    parameter B_OUTER_DIMENSION = 8; 

    parameter BLOCK_SIZE = 2;
    parameter CHUNK_SIZE = 4;

    //parameter NUM_CORES_A = 2;
    //parameter NUM_CORES_B = 2;

    // Derived parameters
    parameter DATA_WIDTH_A = WIDTH_A * CHUNK_SIZE * NUM_CORES_A;
    parameter DATA_WIDTH_B = WIDTH_B * CHUNK_SIZE * NUM_CORES_B;
    parameter DATA_WIDTH_OUT = WIDTH_OUT * CHUNK_SIZE * NUM_CORES_A * NUM_CORES_B;

    parameter ADDR_WIDTH_A = $clog2((INNER_DIMENSION * A_OUTER_DIMENSION) / (CHUNK_SIZE * NUM_CORES_A));
    parameter ADDR_WIDTH_B = $clog2((INNER_DIMENSION * B_OUTER_DIMENSION) / (CHUNK_SIZE * NUM_CORES_B));
    parameter NUM_WORDS_A = 1 << ADDR_WIDTH_A;
    parameter NUM_WORDS_B = 1 << ADDR_WIDTH_B;

    // DUT Inputs
    reg clk = 0, rst_n = 0, start = 0;
    reg in_b_ena = 0, in_b_wea = 0;
    reg in_a_ena = 0, in_a_wea = 0;
    reg [ADDR_WIDTH_B-1:0] in_b_addra = 0;
    reg [ADDR_WIDTH_A-1:0] in_a_addra = 0;
    reg [DATA_WIDTH_B-1:0] in_b_dina = 0;
    reg [DATA_WIDTH_A-1:0] in_a_dina = 0;

    // DUT Outputs
    wire done, out_valid;
    wire [DATA_WIDTH_OUT-1:0] out_bram;

    // Clock generation
    always #5 clk = ~clk;

    // Input memory
    reg [DATA_WIDTH_A-1:0] mem_A [0:NUM_WORDS_A-1];
    reg [DATA_WIDTH_B-1:0] mem_B [0:NUM_WORDS_B-1];

    // Output logging
    integer output_file;
    integer output_count = 0;

    // Instantiate the DUT
    matmul_w_bram #(
        .WIDTH_A(WIDTH_A), .FRAC_WIDTH_A(FRAC_WIDTH_A),
        .WIDTH_B(WIDTH_B), .FRAC_WIDTH_B(FRAC_WIDTH_B),
        .WIDTH_OUT(WIDTH_OUT), .FRAC_WIDTH_OUT(FRAC_WIDTH_OUT),
        .INNER_DIMENSION(INNER_DIMENSION),
        .A_OUTER_DIMENSION(A_OUTER_DIMENSION),
        .B_OUTER_DIMENSION(B_OUTER_DIMENSION),
        .BLOCK_SIZE(BLOCK_SIZE),
        .CHUNK_SIZE(CHUNK_SIZE),
        .NUM_CORES_A(NUM_CORES_A),
        .NUM_CORES_B(NUM_CORES_B)
    ) dut (
        .clk(clk), .rst_n(rst_n), .start(start),
        .in_b_ena(in_b_ena), .in_b_wea(in_b_wea), .in_b_addra(in_b_addra), .in_b_dina(in_b_dina),
        .in_a_ena(in_a_ena), .in_a_wea(in_a_wea), .in_a_addra(in_a_addra), .in_a_dina(in_a_dina),
        .done(done), .out_valid(out_valid), .out_bram(out_bram)
    );

    // Simulation procedure
    initial begin
        $display("Starting simulation...");

        // Load input memory (binary)
        $readmemb("mem_A_core.mem", mem_A);
        $readmemb("mem_B_core.mem", mem_B);

        // Reset sequence
        #20 rst_n = 1;

        // Write A BRAM
        in_a_ena = 1;
        in_a_wea = 1;
        for (int i = 0; i < NUM_WORDS_A; i++) begin
            @(posedge clk);
            in_a_addra <= i;
            in_a_dina <= mem_A[i];
        end
        in_a_ena = 0;
        in_a_wea = 0;

        // Write B BRAM
        in_b_ena = 1;
        in_b_wea = 1;
        for (int i = 0; i < NUM_WORDS_B; i++) begin
            @(posedge clk);
            in_b_addra <= i;
            in_b_dina <= mem_B[i];
        end
        in_b_ena = 0;
        in_b_wea = 0;

        // Start operation
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        // Open output file
        output_file = $fopen("mem_C_result.mem", "w");

        // Wait for and capture outputs
        while (!done) begin
            @(posedge clk);
            if (out_valid) begin
                $fdisplay(output_file, "%b", out_bram);
                output_count++;
            end
        end

        $fclose(output_file);
        $display("✅ Done! Captured %0d outputs in mem_C_result.mem", output_count);
        $stop;
    end

endmodule

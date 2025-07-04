`timescale 1ns / 1ps

module tb_matmul_w_bram;

    // Parameters from user
    parameter WIDTH_A = 8; 
    parameter WIDTH_B = 8; 
    parameter WIDTH_OUT = 12;

    parameter FRAC_WIDTH_A = 4; 
    parameter FRAC_WIDTH_B = 2; 
    parameter FRAC_WIDTH_OUT = 4;

    parameter INNER_DIMENSION = 4; 
    parameter A_OUTER_DIMENSION = 4; 
    parameter B_OUTER_DIMENSION = 6; 

    parameter BLOCK_SIZE = 2;
    parameter CHUNK_SIZE = 4;

    parameter NUM_CORES_A = 2;
    parameter NUM_CORES_B = 3;

    // Derived parameters
    parameter DATA_WIDTH_A = WIDTH_A * CHUNK_SIZE * NUM_CORES_A;
    parameter DATA_WIDTH_B = WIDTH_B * CHUNK_SIZE * NUM_CORES_B;
    parameter DATA_WIDTH_OUT = WIDTH_OUT * CHUNK_SIZE * NUM_CORES_A * NUM_CORES_B;

    parameter NUM_WORDS_A = (A_OUTER_DIMENSION * INNER_DIMENSION) / (CHUNK_SIZE * NUM_CORES_A);
    parameter NUM_WORDS_B = (INNER_DIMENSION * B_OUTER_DIMENSION) / (CHUNK_SIZE * NUM_CORES_B);

    parameter ADDR_WIDTH_A = $clog2(NUM_WORDS_A);
    parameter ADDR_WIDTH_B = $clog2(NUM_WORDS_B);

    // DUT signals
    reg clk = 0, rst_n = 0;
    reg start = 0;

    reg in_a_ena = 0, in_a_wea = 0;
    reg in_b_ena = 0, in_b_wea = 0;

    reg [ADDR_WIDTH_A-1:0] in_a_addra = 0;
    reg [ADDR_WIDTH_B-1:0] in_b_addra = 0;

    reg [DATA_WIDTH_A-1:0] in_a_dina = 0;
    reg [DATA_WIDTH_B-1:0] in_b_dina = 0;

    wire done, out_valid;
    wire [DATA_WIDTH_OUT-1:0] out_bram;

    // Clock generation
    always #5 clk = ~clk;

    // Input memory files (binary)
    reg [DATA_WIDTH_A-1:0] mem_A [0:NUM_WORDS_A-1];
    reg [DATA_WIDTH_B-1:0] mem_B [0:NUM_WORDS_B-1];

    // Output logging
    integer output_file;
    integer output_count = 0;

    // Instantiate DUT
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
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .in_b_ena(in_b_ena), .in_b_wea(in_b_wea),
        .in_b_addra(in_b_addra), .in_b_dina(in_b_dina),
        .in_a_ena(in_a_ena), .in_a_wea(in_a_wea),
        .in_a_addra(in_a_addra), .in_a_dina(in_a_dina),
        .done(done), .out_valid(out_valid),
        .out_bram(out_bram)
    );

    // Stimulus
    integer i;

    initial begin
        $display("Starting parallel BRAM initialization testbench...");
        $readmemb("mem_A_core.mem", mem_A);
        $readmemb("mem_B_core.mem", mem_B);

        // Reset sequence
        #55 rst_n = 1;
        #10;

        // Enable write ports
        start = 1;
        in_a_ena = 1;
        in_b_ena = 1;
        in_a_wea = 1;
        in_b_wea = 1;
        //#10 start = 1;

        // Write data in parallel to BRAM A and B
        for (i = 0; i < NUM_WORDS_A || i < NUM_WORDS_B; i = i + 1) begin
            @(posedge clk);
            
            if (i < NUM_WORDS_A) begin
                in_a_addra <= i;
                in_a_dina  <= mem_A[i];
            end else begin
                in_a_wea   <= 0;
            end

            if (i < NUM_WORDS_B) begin
                in_b_addra <= i;
                in_b_dina  <= mem_B[i];
            end else begin
                in_b_wea   <= 0;
            end
        end

        // Disable after writes are done
        @(posedge clk);
        in_a_wea = 0;
        in_b_wea = 0;
        in_a_ena = 0;
        in_b_ena = 0;

        // Open result file
        output_file = $fopen("mem_C_result.mem", "w");

        // Wait for computation to complete
        while (!done) begin
            @(posedge clk);
            if (out_valid) begin
                $fdisplay(output_file, "%b", out_bram);
                output_count= output_count + 1;
            end
        end

        $fclose(output_file);
        $display("✅ Finished. Output saved to mem_C_result.mem (%0d lines)", output_count);
        //$stop;
    end

endmodule

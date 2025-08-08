`timescale 1ns / 1ps

module tb_r2b_converter_h;

    // Parameters (can be changed to test different configurations)
    parameter WIDTH        = 16;
    parameter FRAC_WIDTH  = 8;
    parameter ROW         = 12;
    parameter COL         = 6;
    parameter BLOCK_SIZE  = 2;
    parameter CHUNK_SIZE  = 4;
    parameter NUM_CORES_H = 3;
    
    localparam DATA_WIDTH   = WIDTH * COL;
    localparam OUT_WIDTH    = WIDTH * CHUNK_SIZE * NUM_CORES_H;

    // Clock and reset
    reg clk = 0;
    reg rst_n = 0;
    reg en = 0;
    reg in_valid = 0;

    // DUT interfaces
    reg  [DATA_WIDTH-1:0] in_data;
    wire [OUT_WIDTH-1:0]  out_data;
    wire slice_last, output_ready, buffer_done;

    // Instantiate the DUT
    r2b_converter_h #(
        .WIDTH(WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH),
        .ROW(ROW),
        .COL(COL),
        .BLOCK_SIZE(BLOCK_SIZE),
        .CHUNK_SIZE(CHUNK_SIZE),
        .NUM_CORES_H(NUM_CORES_H)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .in_valid(in_valid),
        .in_data(in_data),
        .out_data(out_data),
        //.slice_last(slice_last),
        .buffer_done(buffer_done),
        .output_ready(output_ready)
    );

    // Clock generation
    always #5 clk = ~clk;

    // Test stimulus
    integer i, j;
    reg [WIDTH-1:0] q_val;
    reg [WIDTH*COL-1:0] temp_row;

    initial begin
        // Initialize
        //$display("Starting testbench for r2b_converter_h");
        //$display("Configuration: ROW=%0d, COL=%0d, BLOCK_SIZE=%0d, CHUNK_SIZE=%0d, NUM_CORES_H=%0d",
        //         ROW, COL, BLOCK_SIZE, CHUNK_SIZE, NUM_CORES_H);
        
        // Reset sequence
        rst_n = 0;
        #15 rst_n = 1;
        #30 en = 1;
        #30 in_valid = 1;

        // Feed input rows with values from 0.0 to (ROW*COL-1).0 in Q8.8 format
        for (i = 0; i < ROW; i = i + 1) begin
            temp_row = 0;
            //$write("Input Row %0d: ", i);
            for (j = 0; j < COL; j = j + 1) begin
                q_val = (i * COL + j) * (1 << FRAC_WIDTH); // Q8.8 format
                temp_row = (temp_row << WIDTH) | q_val;
                //$write("%0d.%02d ", q_val >> FRAC_WIDTH, 
                       //((q_val & ((1 << FRAC_WIDTH)-1)) * 100 / (1 << FRAC_WIDTH));
            end
            in_data = temp_row;
            $display("");
            #10;
        end

        // Stop feeding input
        in_valid = 0;

        // Wait for processing to complete
        /*wait(buffer_done);
        #100;
        
        $display("Testbench completed");
        $finish;
        */
    end

    // Output monitor
    integer out_count = 0;
    always @(posedge clk) begin
        if (output_ready) begin
            $display("\nOutput Block %0d:", out_count);
            out_count = out_count + 1;
            
            // Print each value in the output block
            /*
            for (i = 0; i < BLOCK_SIZE; i = i + 1) begin
                $write("  Row %0d: ", i);
                for (j = 0; j < CHUNK_SIZE * NUM_CORES_H; j = j + 1) begin
                    automatic integer idx = (i * CHUNK_SIZE * NUM_CORES_H + j) * WIDTH;
                    automatic logic [WIDTH-1:0] val = out_n2r_buffer[idx +: WIDTH];
                    $write("%0d.%02d ", val >> FRAC_WIDTH, 
                           ((val & ((1 << FRAC_WIDTH)-1)) * 100 / (1 << FRAC_WIDTH)));
                end
                $display("");
            end 
            */
        end
        
        if (slice_last) begin
            $display("Last slice detected");
        end
    end

endmodule

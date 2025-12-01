// 4bit_rshift.sv
// Used to do arithmetic right shift 4 bit

module 4bit_rshift #(
    parameter WIDTH_A = 16,
    parameter FRAC_WIDTH_A = 8,
    parameter WIDTH_B = 16,
    parameter FRAC_WIDTH_B = 8,
    parameter WIDTH_OUT = 16,
    parameter FRAC_WIDTH_OUT = 8,
    parameter BLOCK_SIZE = 2, 
    parameter CHUNK_SIZE = 4,
    parameter TOTAL_MODULES = 2,
    parameter TOTAL_INPUT_W = 2,
    parameter NUM_CORES_B = 1,
    parameter NUM_CORES_A = 4
) (
    input logic clk, rst_n,
    input logic [(WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A*NUM_CORES_B*TOTAL_MODULES)-1:0] in_4bit_rshift [TOTAL_INPUT_W],

    output logic [(WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A*NUM_CORES_B*TOTAL_MODULES)-1:0] out_shifted   [TOTAL_INPUT_W] 
);

    // Local helper constants
    localparam int ELEMENTS_PER_VEC = CHUNK_SIZE * NUM_CORES_A * NUM_CORES_B * TOTAL_MODULES;
    localparam int VECTOR_BITS = WIDTH_OUT * ELEMENTS_PER_VEC;

    logic [(WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A*NUM_CORES_B*TOTAL_MODULES)-1:0] next_shifted [TOTAL_INPUT_W];

    integer w, e;
    always_comb begin
        for (w = 0; w < TOTAL_INPUT_W; w++) begin
            next_shifted[w] = '0;  // start cleared
        end

        for (w = 0; w < TOTAL_INPUT_W; w++) begin
            for (e = 0; e < ELEMENTS_PER_VEC; e++) begin
                // Big-endian slice positions
                int high = VECTOR_BITS - e*WIDTH_OUT - 1;
                int low  = VECTOR_BITS - (e+1)*WIDTH_OUT;

                logic signed [WIDTH_OUT-1:0] tmp_elem;
                logic signed [WIDTH_OUT-1:0] shifted;

                tmp_elem = in_4bit_shift[w][high:low];
                shifted  = tmp_elem >>> 4;

                next_shifted[w][high:low] = shifted;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst_n) begin
            for (w = 0; w < TOTAL_INPUT_W; w++)
                out_shifted[w] <= '0;
        end else begin
            for (w = 0; w < TOTAL_INPUT_W; w++)
                out_shifted[w] <= next_shifted[w];
        end
    end
endmodule
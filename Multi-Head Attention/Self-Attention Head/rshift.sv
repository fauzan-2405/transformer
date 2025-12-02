// rshift.sv
// Used to arithmetic right shift

module rshift #(
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
    input  logic clk,
    input  logic rst_n, 
    input  logic in_valid,
    input  logic [(WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A*NUM_CORES_B*TOTAL_MODULES)-1:0]
            in_4bit_rshift [TOTAL_INPUT_W],

    output logic [(WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A*NUM_CORES_B*TOTAL_MODULES)-1:0]
            out_shifted   [TOTAL_INPUT_W],

    output logic out_valid
);

    localparam int ELEMENTS_PER_VEC = CHUNK_SIZE * NUM_CORES_A * NUM_CORES_B * TOTAL_MODULES;
    localparam int VECTOR_BITS      = WIDTH_OUT * ELEMENTS_PER_VEC;

    logic [(WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A*NUM_CORES_B*TOTAL_MODULES)-1:0]
          next_shifted [TOTAL_INPUT_W];

    always_comb begin
        for (integer w_i = 0; w_i < TOTAL_INPUT_W; w_i++) begin
            // Arithmetic shift behavior
            for (integer e_i = 0; e_i < ELEMENTS_PER_VEC; e_i++) begin
                int high = VECTOR_BITS - e_i*WIDTH_OUT - 1;

                logic signed [WIDTH_OUT-1:0] tmp_elem;
                logic signed [WIDTH_OUT-1:0] shifted;

                tmp_elem = in_4bit_rshift[w_i][high -: WIDTH_OUT];
                shifted  = tmp_elem >>> 4;

                next_shifted[w_i][high -: WIDTH_OUT] = shifted;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            // active-low reset
            for (integer w_j = 0; w_j < TOTAL_INPUT_W; w_j++) begin
                out_shifted[w_j] <= '0;
            end

            out_valid <= 1'b0;

        end else begin
            // register new data
            for (integer w_k = 0; w_k < TOTAL_INPUT_W; w_k++) begin
                out_shifted[w_k] <= next_shifted[w_k];
            end

            out_valid   <= in_valid;        
        end
    end

endmodule

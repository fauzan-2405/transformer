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
    input  logic clk,
    input  logic rst_n, 
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

    integer w, e;
    always_comb begin
        for (w = 0; w < TOTAL_INPUT_W; w++)
            next_shifted[w] = '0;

        for (w = 0; w < TOTAL_INPUT_W; w++) begin
            for (e = 0; e < ELEMENTS_PER_VEC; e++) begin
                int high = VECTOR_BITS - e*WIDTH_OUT - 1;
                int low  = VECTOR_BITS - (e+1)*WIDTH_OUT;

                logic signed [WIDTH_OUT-1:0] tmp_elem;
                logic signed [WIDTH_OUT-1:0] shifted;

                tmp_elem = in_4bit_rshift[w][high:low];
                shifted  = tmp_elem >>> 4;

                next_shifted[w][high:low] = shifted;
            end
        end
    end

    logic valid_d;   
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            // active-low reset
            for (w = 0; w < TOTAL_INPUT_W; w++)
                out_shifted[w] <= '0;

            valid_d   <= 1'b0;
            out_valid <= 1'b0;

        end else begin
            // register new data
            for (w = 0; w < TOTAL_INPUT_W; w++)
                out_shifted[w] <= next_shifted[w];

            valid_d   <= 1'b1;        
            out_valid <= valid_d;     
        end
    end

endmodule

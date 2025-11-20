// multi_matmul.v
// Used to wrap multi matmul module
// IMPORTANT: Make sure to edit the core_a and core_b configs!

module multi_matmul #(
    parameter WIDTH_A = 16,
    parameter FRAC_WIDTH_A = 8,
    parameter WIDTH_B = 16,
    parameter FRAC_WIDTH_B = 8,
    parameter WIDTH_OUT = 16,
    parameter FRAC_WIDTH_OUT = 8,
    parameter BLOCK_SIZE = 2, 
    parameter CHUNK_SIZE = 4,
    parameter INNER_DIMENSION = 64,
    parameter TOTAL_MODULES = 2,
    parameter NUM_CORES_B = 1,
    parameter NUM_CORES_A = 4
) (
    input clk, rst_n, en, reset_acc,
    input [(WIDTH_A*CHUNK_SIZE*NUM_CORES_A)-1:0] input_w, // shared accross modules
    input [(WIDTH_B*CHUNK_SIZE*NUM_CORES_B*TOTAL_MODULES)-1:0] input_n,

    output acc_done_modules, systolic_finish_modules,
    output [(WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A*NUM_CORES_B*TOTAL_MODULES)-1:0] out_multi_matmul
);
    // Local wires
    wire [TOTAL_MODULES-1:0] acc_done_array, systolic_finish_array;
    
    genvar i;
    generate
        for (i = 0; i < TOTAL_MODULES; i = i + 1) begin: GEN_MATMUL

            // Slice the input_n
            localparam N_SLICE_WIDTH = WIDTH_B * CHUNK_SIZE * NUM_CORES_B;
            wire [N_SLICE_WIDTH-1:0] input_n_slice;
            assign input_n_slice = input_n[(i+1)*N_SLICE_WIDTH-1 -: N_SLICE_WIDTH];

            // Slice the output
            localparam OUT_SLICE_WIDTH = WIDTH_OUT * CHUNK_SIZE * NUM_CORES_A * NUM_CORES_B;
            wire [OUT_SLICE_WIDTH-1:0] out_slice;
            assign out_multi_matmul[(i+1)*OUT_SLICE_WIDTH-1 -: OUT_SLICE_WIDTH] = out_slice;

            matmul_module #(
                .BLOCK_SIZE(BLOCK_SIZE),
                .INNER_DIMENSION(INNER_DIMENSION),
                .CHUNK_SIZE(CHUNK_SIZE),
                .WIDTH_A(WIDTH_A),
                .FRAC_WIDTH_A(FRAC_WIDTH_A),
                .WIDTH_B(WIDTH_B),
                .FRAC_WIDTH_B(FRAC_WIDTH_B),
                .WIDTH_OUT(WIDTH_OUT),
                .FRAC_WIDTH_OUT(FRAC_WIDTH_OUT),
                .NUM_CORES_A(NUM_CORES_A),
                .NUM_CORES_B(NUM_CORES_B)
            ) matmul_module_inst (
                .clk(clk), .en(en), .rst_n(rst_n), .reset_acc(reset_acc),
                .input_w(input_w), .input_n(input_n_slice), // The first one is the MSB
                .accumulator_done(acc_done_array[i]), .systolic_finish(systolic_finish_array[i]),
                .out_top(out_slice) // The first one is the MSB
            );
        end
    endgenerate

    assign acc_done_modules = &acc_done_array;
    assign systolic_finish_modules  = &systolic_finish_array;

endmodule
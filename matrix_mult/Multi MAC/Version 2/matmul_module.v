// matmul_module.v
// For the one who uses buffer (the output will be 64-bi), see toplevel.v
// This module is also the updated version of the original toplevel_v2 on Multi MAC folder
// just with some parameters adjustments

//`include "core_v2.v"

module matmul_module #(
    parameter WIDTH_A = 16,
    parameter FRAC_WIDTH_A = 8,
    parameter WIDTH_B = 16,
    parameter FRAC_WIDTH_B = 8,
    parameter WIDTH_OUT = 16,
    parameter FRAC_WIDTH_OUT = 8,
    parameter BLOCK_SIZE = 2, 
    parameter CHUNK_SIZE = 4,
    parameter INNER_DIMENSION = 64,
    parameter NUM_CORES_B = 1,
    parameter NUM_CORES_A = 2
) (
    input clk, en, rst_n, reset_acc,
    input [(WIDTH_B*CHUNK_SIZE*NUM_CORES_B)-1:0] input_n,
    input [(WIDTH_A*CHUNK_SIZE*NUM_CORES_A)-1:0] input_w,

    output accumulator_done, systolic_finish,
    output [(WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A*NUM_CORES_B)-1:0] out_top
);

    // Internal arrays
    wire [WIDTH_A*CHUNK_SIZE-1:0] input_w_array [0:NUM_CORES_A-1];
    wire [WIDTH_B*CHUNK_SIZE-1:0] input_n_array [0:NUM_CORES_B-1]; 

    wire [NUM_CORES_A*NUM_CORES_B-1:0] acc_done_array;
    wire [NUM_CORES_A*NUM_CORES_B-1:0] systolic_finish_array;

    genvar i, j;

    // Flatten input_w to array
    generate
        for (i = 0; i < NUM_CORES_A; i = i + 1) begin : WIRE_W
            assign input_w_array[i] = input_w[(i+1)*(WIDTH_A * CHUNK_SIZE) - 1 -: (WIDTH_A * CHUNK_SIZE)];
        end
    endgenerate

    // Dynamically wire input_n_array based on NUM_CORES_B
    generate
        for (i = 0; i < NUM_CORES_B; i = i + 1) begin : WIRE_N
            if (NUM_CORES_B == 1) begin
                assign input_n_array[i] = input_n;
            end else begin
                assign input_n_array[i] = input_n[(i+1)*(WIDTH_B * CHUNK_SIZE) - 1 -: (WIDTH_B * CHUNK_SIZE)];
            end
        end
    endgenerate

    // Instantiate core_v2 instances
    generate
        for (j = 0; j < NUM_CORES_B; j = j + 1) begin
            for (i = 0; i < NUM_CORES_A; i = i + 1) begin
                localparam INDEX = j * NUM_CORES_A + i;
                core_v2 #(
                    .BLOCK_SIZE(BLOCK_SIZE),
                    .INNER_DIMENSION(INNER_DIMENSION),
                    .CHUNK_SIZE(CHUNK_SIZE),
                    .WIDTH_A(WIDTH_A),
                    .FRAC_WIDTH_A(FRAC_WIDTH_A),
                    .WIDTH_B(WIDTH_B),
                    .FRAC_WIDTH_B(FRAC_WIDTH_B),
                    .WIDTH_OUT(WIDTH_OUT),
                    .FRAC_WIDTH_OUT(FRAC_WIDTH_OUT)
                ) core_inst (
                    .clk(clk),
                    .en(en),
                    .rst_n(rst_n),
                    .reset_acc(reset_acc),
                    .input_w(input_w_array[i]),
                    .input_n(input_n_array[j]),
                    .accumulator_done(acc_done_array[INDEX]),
                    .systolic_finish(systolic_finish_array[INDEX]),
                    .out(out_top[(j * NUM_CORES_A + i + 1)*(WIDTH_OUT * CHUNK_SIZE) - 1 -: (WIDTH_OUT * CHUNK_SIZE)])
                    //.out(out_top[(j * NUM_CORES_A + i + 1)*(WIDTH_OUT * BLOCK_SIZE) - 1 -: (WIDTH_OUT * BLOCK_SIZE)])
                );
            end
        end
    endgenerate

    assign accumulator_done = &acc_done_array;
    assign systolic_finish  = &systolic_finish_array;

endmodule

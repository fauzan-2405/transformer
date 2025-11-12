// multi_matmul_wrapper.v
// Wraps TOTAL_INPUT_W instances of multi_matmul
// Each of it shared the same input_n but with a different input_w and output

module multi_matmul_wrapper #(
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
    parameter TOTAL_INPUT_W = 2,
    parameter NUM_CORES_B = 1,
    parameter NUM_CORES_A = 4
) (
    input logic clk, rst_n, en, reset_acc,
    input logic [(WIDTH_A*CHUNK_SIZE*NUM_CORES_A)-1:0] input_w [TOTAL_INPUT_W],
    input logic [(WIDTH_B*CHUNK_SIZE*NUM_CORES_B*TOTAL_MODULES)-1:0] input_n,

    output logic acc_done_wrap, systolic_finish_wrap,
    output logic [(WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A*NUM_CORES_B*TOTAL_MODULES)-1:0] out_multi_matmul [TOTAL_INPUT_W]
);
    // Local wires
    logic [TOTAL_INPUT_W-1:0] acc_done_array, systolic_finish_array;

    genvar i;
    generate
        for (i = 0; i < TOTAL_INPUT_W; i++) begin: GEN_WRAPPER
            multi_matmul #(
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
                .NUM_CORES_B(NUM_CORES_B),
                .TOTAL_MODULES(TOTAL_MODULES)
            ) multi_matmul_inst (
                .clk(clk),
                .rst_n(rst_n),
                .en(en),
                .reset_acc(reset_acc),
                .input_w(input_w[i]),               // per-instance west input
                .input_n(input_n),                  // shared north input
                .out_multi_matmul(out_multi_matmul[i]), // per-instance output
                .acc_done_modules(acc_done_array[i]),
                .systolic_finish_modules(systolic_finish_array[i])
            );
        end
    endgenerate

    assign acc_done_wrap = &acc_done_array;
    assign systolic_finish_wrap  = &systolic_finish_array;

    always @(posedge clk) begin
        if (~rst_n) begin
            // Output
            for (int i = 0; i < TOTAL_INPUT_W; i = i +1) begin
                out_multi_matmul[i] <= '0;
            end
        end
    end



endmodule
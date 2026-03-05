// top_r2b_circular_fifo.sv
// Used to stall outputs from top_r2b_converter_v
// There is a mismatch between the input data dimension (TOTAL_TILE_SOFTMAX)
// with the total amount of fifo unit (NUM_BANKS_FIFO) to adjust the circular definition
// NUM_BANKS_FIFO < TOTAL_TILE_SOFTMAX

module top_r2b_circular_fifo #(
    parameter WIDTH             = 16,
    parameter CHUNK_SIZE        = 4,
    parameter NUM_CORES_V       = 2,
    parameter TOTAL_TILE_SOFTMAX = 8,   // number of outputs per unit
    parameter TILE_SIZE_SOFTMAX  = 4,
    parameter TOTAL_OUTPUTS_PER_TILE = 2,
    parameter NUM_BANKS_FIFO    = 2,
    parameter RD_DATA_COUNT_WIDTH = 4,
    parameter FIFO_WRITE_DEPTH = 16,

    localparam UNIT_WIDTH = WIDTH * CHUNK_SIZE * NUM_CORES_V
)(
    input logic clk,
    input logic rst_n [NUM_BANKS_FIFO],
    input logic                  fifo_wr_en [TOTAL_TILE_SOFTMAX],
    input logic [UNIT_WIDTH-1:0] in_data [TOTAL_INPUT_W_Qn_KnT][TOTAL_TILE_SOFTMAX],
    input logic [$clog2(TOTAL_TILE_SOFTMAX)-1:0] fifo_idx [NUM_BANKS_FIFO], // Determines the fifo unit that used in circular fashion
    input logic                  fifo_rd_en [TOTAL_TILE_SOFTMAX],
    input logic [RD_DATA_COUNT_WIDTH-1:0] rd_data_count [NUM_BANKS_FIFO],

    output logic                    fifo_full [NUM_BANKS_FIFO],
    output logic                    fifo_underflow [NUM_BANKS_FIFO],
    output logic                    fifo_empty [NUM_BANKS_FIFO],
    output logic [UNIT_WIDTH-1:0]   out_data [TOTAL_INPUT_W_Qn_KnT][NUM_BANKS_FIFO]
);
    //localparam FIFO_READ_DEPTH = TOTAL_OUTPUTS_PER_TILE * UNIT_WIDTH/UNIT_WIDTH;
    //  FIFO Bank
    logic [UNIT_WIDTH-1:0] fifo_dout [NUM_BANKS_FIFO];

    genvar i, j;
    generate
        for (j = 0; j < TOTAL_INPUT_W_Qn_KnT; j++) begin : GEN_FIFO_BANK
            for (i = 0; i < NUM_BANKS_FIFO; i++) begin
                xpm_fifo_sync #(
                    .FIFO_MEMORY_TYPE("distributed"),
                    .FIFO_WRITE_DEPTH(FIFO_WRITE_DEPTH),
                    .WRITE_DATA_WIDTH(UNIT_WIDTH),
                    .READ_DATA_WIDTH(UNIT_WIDTH),
                    .RD_DATA_COUNT_WIDTH(RD_DATA_COUNT_WIDTH),
                    .FIFO_READ_LATENCY(1)
                ) fifo_inst (
                    .rst(~rst_n[i]),
                    .wr_clk(clk),
                    .wr_en(fifo_wr_en[i]),
                    .din(in_data[j][fifo_idx[i]]),
                    .full(fifo_full[i]),
                    .rd_data_count(rd_data_count[i]),
                    .rd_en(fifo_rd_en[i]),
                    .dout(out_data[j][i]),
                    .underflow(fifo_underflow[i]),
                    .empty(fifo_empty[i])
                );
            end
        end
    endgenerate

endmodule

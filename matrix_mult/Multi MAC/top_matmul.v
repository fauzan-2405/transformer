// top_matmul.v
// Used to wrap (r2b_converter_i + r2b_converter_w) -> top_v2 -> b2r_converter

module top_matmul #(
    parameter WIDTH                     = 16,
    parameter FRAC_WIDTH                = 8,
    parameter BLOCK_SIZE                = 2, 
    parameter CHUNK_SIZE                = 4,
    parameter I_OUTER_DIMENSION         = 12, 
    parameter W_OUTER_DIMENSION         = 6,
    parameter INNER_DIMENSION           = 6,
    parameter NUM_CORES = (I_OUTER_DIMENSION == 2754) ? 9 :
                        (I_OUTER_DIMENSION == 256)  ? 8 :
                        (I_OUTER_DIMENSION == 200)  ? 5 :
                        (I_OUTER_DIMENSION == 64)   ? 4 : 2
) (
    input wire clk, rst_n,
    input wire en_top_matmul,
    // *** Port for input_converter ***
    input wire input_i_valid,
    input wire [WIDTH*INNER_DIMENSION-1:0] input_i,
    // *** Port for weight_converter ***
    input wire input_w_valid,
    input wire [WIDTH*W_OUTER_DIMENSION-1:0] input_w,
    // *** Port for output_converter ***
    output wire out_matmul_ready,
    output wire out_matmul_last,
    output wire out_matmul_done,
    output wire  [WIDTH*W_OUTER_DIMENSION-1:0] out_matmul_data 
);
    // Local Parameters
    localparam ADDR_WIDTH_I = $clog2((INNER_DIMENSION*I_OUTER_DIMENSION*WIDTH)/(WIDTH*CHUNK_SIZE*NUM_CORES));
    localparam ADDR_WIDTH_W = $clog2((INNER_DIMENSION*W_OUTER_DIMENSION*WIDTH)/(WIDTH*CHUNK_SIZE));

    // Internal Signals
    wire [WIDTH*CHUNK_SIZE*NUM_CORES-1:0] input_block_data;
    wire input_block_valid, input_block_done, input_block_last;

    wire [WIDTH*CHUNK_SIZE-1:0] weight_block_data;
    wire weight_block_valid, weight_block_done, weight_block_last;

    wire [WIDTH*CHUNK_SIZE*NUM_CORES-1:0] output_block_data;
    wire top_ready, top_done;

    // Internal BRAM control signals
    reg [ADDR_WIDTH_I-1:0] in_addra;
    reg [ADDR_WIDTH_W-1:0] wb_addra;
    reg in_ena, wb_ena;
    reg [7:0] in_wea, wb_wea;

    // FSM Control
    reg started;
    wire all_data_ready = input_block_done && weight_block_done;

    // Input matrix converter
    r2b_converter_i #(
        .WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH), .BLOCK_SIZE(BLOCK_SIZE),
        .CHUNK_SIZE(CHUNK_SIZE), .ROW(I_OUTER_DIMENSION), .COL(INNER_DIMENSION), 
        .NUM_CORES(NUM_CORES)
    ) input_converter (
        .clk(clk), .rst_n(rst_n),
        .en(en_top_matmul),
        .in_valid(input_i_valid),
        .in_n2r_buffer(input_i),
        .slice_done(),  // optional
        .output_ready(input_block_valid),
        .slice_last(input_block_last),
        .buffer_done(input_block_done),
        .out_n2r_buffer(input_block_data)
    );

    // Weight matrix converter
    r2b_converter_w #(
        .WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH), .BLOCK_SIZE(BLOCK_SIZE),
        .CHUNK_SIZE(CHUNK_SIZE), .ROW(INNER_DIMENSION), .COL(W_OUTER_DIMENSION),
        .NUM_CORES(1)  // Single weight block per core
    ) weight_converter (
        .clk(clk), .rst_n(rst_n),
        .en(en_top_matmul),
        .in_valid(input_w_valid),
        .in_n2r_buffer(input_w),
        .out_n2r_buffer(weight_block_data),
        .slice_last(weight_block_last),
        .buffer_done(weight_block_done),
        .output_ready(weight_block_valid)
    );

    // top_v2 instance (computation core)
    top_v2 #(
        .WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH), .BLOCK_SIZE(BLOCK_SIZE),
        .CHUNK_SIZE(CHUNK_SIZE), .INNER_DIMENSION(INNER_DIMENSION),
        .I_OUTER_DIMENSION(I_OUTER_DIMENSION), .W_OUTER_DIMENSION(W_OUTER_DIMENSION),
        .NUM_CORES(NUM_CORES), .ADDR_WIDTH_I(ADDR_WIDTH_I), .ADDR_WIDTH_W(ADDR_WIDTH_W)
    ) matmul_core (
        .clk(clk), .rst_n(rst_n),
        .start(started),

        .wb_ena(wb_ena),
        .wb_wea(wb_wea),
        .wb_addra(wb_addra),
        .wb_dina(weight_block_data),

        .in_ena(in_ena),
        .in_wea(in_wea),
        .in_addra(in_addra),
        .in_dina(input_block_data),

        .out_bram(output_block_data),
        .top_ready(top_ready),
        .done(top_done)
    );

    // Output converter
    b2r_converter #(
        .WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH),
        .ROW(I_OUTER_DIMENSION), .COL(W_OUTER_DIMENSION), .BLOCK_SIZE(BLOCK_SIZE), .CHUNK_SIZE(CHUNK_SIZE),
        .NUM_CORES(NUM_CORES)
    ) output_converter (
        .clk(clk), .rst_n(rst_n),
        .en(en_top_matmul),
        .in_valid(top_ready),
        .in_data(output_block_data),
        .slice_done(),   // optional
        .output_ready(out_matmul_ready),
        .slice_last(out_matmul_last),
        .buffer_done(out_matmul_done),
        .out_data(out_matmul_data)
    );

    // FSM for BRAM write and start trigger
    reg [ADDR_WIDTH_I-1:0] in_write_cnt;
    reg [ADDR_WIDTH_W-1:0] wb_write_cnt;

    always @(posedge clk) begin 
        if (!rst_n) begin
            in_ena <= 0;
            in_wea <= 0;
            in_addra <= 0;
            wb_ena <= 0;
            wb_wea <= 0;
            wb_addra <= 0;
            in_write_cnt <= 0;
            wb_write_cnt <= 0;
            started <= 0;
        end 
        else if (en_top_matmul) begin
            // Input BRAM Write
            if (input_block_valid) begin
                in_ena      <= 1;
                in_wea      <= 8'hFF;
                in_addra    <= in_write_cnt;
                in_write_cnt <= in_write_cnt + 1;
            end else begin
                in_ena      <= 0;
                in_wea      <= 0;
            end

            // Weight BRAM Write
            if (weight_block_valid) begin
                wb_ena <= 1;
                wb_wea <= 8'hFF;
                wb_addra <= wb_write_cnt;
                wb_write_cnt <= wb_write_cnt + 1;
            end else begin
                wb_ena <= 0;
                wb_wea <= 0;
            end

            // Start matmul once both buffers are filled
            if (all_data_ready && !started) begin
                started <= 1;
            end
        end
        else begin
            // Reset all on disable
            in_ena <= 0; in_wea <= 0;
            wb_ena <= 0; wb_wea <= 0;
            in_write_cnt <= 0; wb_write_cnt <= 0;
            started <= 0;
        end
    end
endmodule
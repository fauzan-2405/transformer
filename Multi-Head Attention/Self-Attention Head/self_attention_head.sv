// self_attention_head.sv
// Top level of self attention-head
/*
import buffer0_pkg::W0_SLICE_WIDTH;
import buffer0_pkg::N0_MODULE_WIDTH;
import buffer0_pkg::TOTAL_INPUT_W_W0; */
import buffer0_pkg::*;
import linear_proj_pkg::*;

import self_attention_pkg::*;

module self_attention_head #(
    parameter TOTAL_SOFTMAX_ROW = NUM_CORES_A_Qn_KnT * BLOCK_SIZE,
    localparam NUMBER_OF_BUFFER_INSTANCES_LOCAL = 1
) (
    input clk, rst_n,
    input en_Qn_KnT,
    input rst_n_Qn_KnT,
    input reset_acc_Qn_KnT,
    input out_valid_Qn_KnT,
    input logic [W0_SLICE_WIDTH-1:0] input_w_Qn_KnT [TOTAL_INPUT_W_W0],
    input logic [N0_MODULE_WIDTH-1:0] input_n_Qn_KnT,

    input logic internal_rst_n_b2r,

    input logic softmax_en,
    input logic softmax_valid [TOTAL_SOFTMAX_ROW],
    input logic internal_rst_n_softmax [TOTAL_INPUT_W_Qn_KnT][TOTAL_SOFTMAX_ROW],

    input logic internal_rst_n_r2b_conv [TOTAL_TILE_SOFTMAX],

    //input logic [$clog2(TOTAL_SOFTMAX_ROW):0] r2b_row_idx,
    input logic [$clog2(TOTAL_SOFTMAX_ROW):0] r2b_row_idx [TOTAL_TILE_SOFTMAX],
    input logic in_valid_r2b [TOTAL_TILE_SOFTMAX],

    input logic [$clog2(TOTAL_TILE_SOFTMAX)-1:0] fifo_idx [NUM_BANKS_FIFO],
    input logic fifo_rd_en [TOTAL_TILE_SOFTMAX],
    input logic internal_rst_n_fifo [NUM_BANKS_FIFO],
    input logic fifo_out_valid,
    
    input logic [N1_IN_WIDTH-1:0] input_n_QKT_Vn [TOTAL_INPUT_W_N1],
    input logic in_valid_n_QKT_Vn,

    // Output
    output logic sys_finish_wrap_Qn_KnT,
    output logic acc_done_wrap_Qn_KnT,

    output logic out_valid_shifted,

    output logic slice_done_b2r_wrap,
    output logic out_ready_b2r_wrap,   // To Controller

    output logic done_softmax [TOTAL_INPUT_W_Qn_KnT][TOTAL_SOFTMAX_ROW],
    output logic out_softmax_valid [TOTAL_INPUT_W_Qn_KnT][TOTAL_SOFTMAX_ROW],

    output logic slice_last_r2b [TOTAL_TILE_SOFTMAX],

    output logic fifo_underflow [NUM_BANKS_FIFO],
    output logic [WR_DATA_COUNT_WIDTH-1:0] wr_data_count_fifo [NUM_BANKS_FIFO], 
    output logic [RD_DATA_COUNT_WIDTH-1:0] rd_data_count_fifo [NUM_BANKS_FIFO],
    //output logic fifo_full [NUM_BANKS_FIFO],

    // Temporary
    //output logic [TILE_SIZE_SOFTMAX*WIDTH_OUT-1:0] out_softmax_data [TOTAL_INPUT_W_Qn_KnT][TOTAL_SOFTMAX_ROW]
    //output logic [WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A_QKT_Vn-1:0] out_data_r2b [TOTAL_INPUT_W_Qn_KnT][TOTAL_TILE_SOFTMAX]
    //output logic [(WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A_QKT_Vn)-1:0] out_data_fifo [TOTAL_INPUT_W_Qn_KnT][NUM_BANKS_FIFO]
    output logic [(WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A_QKT_Vn*NUM_CORES_B_QKT_Vn*TOTAL_MODULES_LP_V)-1:0]
        out_matmul_QKT_Vn [NUMBER_OF_BUFFER_INSTANCES_LOCAL][TOTAL_INPUT_W_Qn_KnT]
);    
    
    // ************************** Matmul Module Qn x Kn^T **************************
    logic [(WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A_Qn_KnT*NUM_CORES_B_Qn_KnT*TOTAL_MODULES_LP_Q)-1:0]
        out_matmul_Qn_KnT [TOTAL_INPUT_W_Qn_KnT];

    multi_matmul_wrapper #(
        .WIDTH_A(WIDTH_A),
        .FRAC_WIDTH_A(FRAC_WIDTH_A),
        .WIDTH_B(WIDTH_B),
        .FRAC_WIDTH_B(FRAC_WIDTH_B),
        .WIDTH_OUT(WIDTH_OUT),
        .FRAC_WIDTH_OUT(FRAC_WIDTH_OUT),
        .BLOCK_SIZE(BLOCK_SIZE),
        .CHUNK_SIZE(CHUNK_SIZE),
        .INNER_DIMENSION(INNER_DIMENSION_Qn_KnT),
        .TOTAL_MODULES(TOTAL_MODULES_LP_Q),
        .TOTAL_INPUT_W(TOTAL_INPUT_W_Qn_KnT),
        .NUM_CORES_A(NUM_CORES_A_Qn_KnT),
        .NUM_CORES_B(NUM_CORES_B_Qn_KnT)
    ) matmul_Qn_KnT (
        .clk(clk),
        .rst_n(rst_n_Qn_KnT),
        .en(en_Qn_KnT),
        .reset_acc(reset_acc_Qn_KnT),
        .input_w(input_w_Qn_KnT),
        .input_n(input_n_Qn_KnT),
        .acc_done_wrap(acc_done_wrap_Qn_KnT),
        .systolic_finish_wrap(sys_finish_wrap_Qn_KnT),
        .out_multi_matmul(out_matmul_Qn_KnT)
    );

    // ************************** 4-BIT SHIFTER **************************
    logic [(WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A_Qn_KnT*NUM_CORES_B_Qn_KnT*TOTAL_MODULES_LP_Q)-1:0]
        out_shifted [TOTAL_INPUT_W_Qn_KnT];

    rshift #(
        .WIDTH_A(WIDTH_A),
        .FRAC_WIDTH_A(FRAC_WIDTH_A),
        .WIDTH_B(WIDTH_B),
        .FRAC_WIDTH_B(FRAC_WIDTH_B),
        .WIDTH_OUT(WIDTH_OUT),
        .FRAC_WIDTH_OUT(FRAC_WIDTH_OUT),
        .BLOCK_SIZE(BLOCK_SIZE),
        .CHUNK_SIZE(CHUNK_SIZE),
        .TOTAL_MODULES(TOTAL_MODULES_LP_Q),
        .TOTAL_INPUT_W(TOTAL_INPUT_W_Qn_KnT),
        .NUM_CORES_A(NUM_CORES_A_Qn_KnT),
        .NUM_CORES_B(NUM_CORES_B_Qn_KnT)
    ) rshift_four_bit (
        .clk(clk), .rst_n(rst_n),
        .in_valid(out_valid_Qn_KnT),
        .in_4bit_rshift(out_matmul_Qn_KnT),
        .out_valid(out_valid_shifted),
        .out_shifted(out_shifted)
    );


    // ************************** B2R CONVERTER **************************
    logic slice_done_b2r [TOTAL_INPUT_W_Qn_KnT];
    logic out_ready_b2r [TOTAL_INPUT_W_Qn_KnT];
    logic [(TILE_SIZE_SOFTMAX*WIDTH_OUT)-1:0] out_b2r_data [TOTAL_INPUT_W_Qn_KnT];
    assign slice_done_b2r_wrap  = slice_done_b2r[0] && slice_done_b2r[1];
    assign out_ready_b2r_wrap   = out_ready_b2r[0] && out_ready_b2r[1];

    genvar i;
    generate
        for (i = 0; i < TOTAL_INPUT_W_Qn_KnT; i++) begin: GEN_B2R_CONVERTER
            b2r_converter #(
                .WIDTH(WIDTH_OUT),
                .FRAC_WIDTH(FRAC_WIDTH_OUT),
                .ROW(ROW_B2R_CONVERTER),             // Resulting row
                .COL(COL_B2R_CONVERTER),             // Resulting col
                .BLOCK_SIZE(BLOCK_SIZE),
                .CHUNK_SIZE(CHUNK_SIZE),
                .NUM_CORES_H(NUM_CORES_H_B2R),
                .NUM_CORES_V(NUM_CORES_V_B2R)
            ) converter_b2r (
                .clk(clk),
                .rst_n(internal_rst_n_b2r),
                .en(1'b1),
                .in_data(out_shifted[i]),
                .in_valid(out_valid_shifted),
                .slice_done(slice_done_b2r[i]),
                .output_ready(out_ready_b2r[i]),
                .slice_last(),
                .buffer_done(),
                .out_data(out_b2r_data[i])
            );
        end
    endgenerate


    // ************************** SOFTMAX **************************
    logic [TILE_SIZE_SOFTMAX*WIDTH_OUT-1:0] out_softmax_data [TOTAL_INPUT_W_Qn_KnT][TOTAL_SOFTMAX_ROW];
    (* keep = "true" *) logic [(TILE_SIZE_SOFTMAX*WIDTH_OUT)-1:0] out_b2r_data_reg [TOTAL_INPUT_W_Qn_KnT]; // To delay the b2r_data

    genvar j,k;
    generate
        for (j = 0; j < TOTAL_INPUT_W_Qn_KnT; j++) begin
            for (k = 0; k < TOTAL_SOFTMAX_ROW; k++) begin
                softmax_vec #(
                    .WIDTH(WIDTH_OUT),
                    .FRAC_WIDTH(FRAC_WIDTH_OUT),
                    .TOTAL_ELEMENTS(TOTAL_ELEMENTS_SOFTMAX),
                    .TILE_SIZE(TILE_SIZE_SOFTMAX),
                    .USE_AMULT(0)
                ) softmax_unit (
                    .clk(clk),
                    .rst_n(internal_rst_n_softmax[j][k]),
                    .en(softmax_en),

                    .X_tile_in(out_b2r_data_reg[j]),
                    .tile_in_valid(softmax_valid[k]),

                    .Y_tile_out(out_softmax_data[j][k]),
                    .tile_out_valid(out_softmax_valid[j][k]),
                    .done(done_softmax[j][k])
                );
            end
        end
    endgenerate


    // ************************** R2B CONVERTER **************************
    logic [WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A_QKT_Vn-1:0] out_data_r2b [TOTAL_INPUT_W_Qn_KnT][TOTAL_TILE_SOFTMAX];
    logic output_valid_r2b [TOTAL_TILE_SOFTMAX];
    
    top_r2b_converter_v #(
        .WIDTH(WIDTH_OUT),
        .FRAC_WIDTH(FRAC_WIDTH_OUT),
        .BLOCK_SIZE(BLOCK_SIZE),
        .CHUNK_SIZE(CHUNK_SIZE),
        .ROW(TOTAL_SOFTMAX_ROW), // Real row representation
        .COL(TILE_SIZE_SOFTMAX), // Real col representation
        .NUM_CORES_V(NUM_CORES_A_QKT_Vn),
        .TOTAL_SOFTMAX_ROW(TOTAL_SOFTMAX_ROW),
        .TOTAL_TILE_SOFTMAX(TOTAL_TILE_SOFTMAX)
    ) top_r2b_converter_v_unit (
        .clk(clk),
        .rst_n(internal_rst_n_r2b_conv),
        .en(1'b1),
        .in_valid(in_valid_r2b),
        .in_data(out_softmax_data),
        .r2b_row_idx(r2b_row_idx),
        .slice_done(),
        .output_ready(output_valid_r2b),
        .slice_last(slice_last_r2b),
        .buffer_done(),
        .out_data(out_data_r2b)
    );

    // ************************** FIFO BUFFER **************************
    logic [(WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A_QKT_Vn)-1:0] out_data_fifo [TOTAL_INPUT_W_Qn_KnT][NUM_BANKS_FIFO];

    top_r2b_circular_fifo #(
        .WIDTH(WIDTH_OUT),
        .CHUNK_SIZE(CHUNK_SIZE),
        .NUM_CORES_V(NUM_CORES_A_QKT_Vn),
        .TOTAL_TILE_SOFTMAX(TOTAL_TILE_SOFTMAX),
        .TILE_SIZE_SOFTMAX(TILE_SIZE_SOFTMAX),
        .TOTAL_OUTPUTS_PER_TILE(TOTAL_OUTPUTS_PER_TILE),
        .NUM_BANKS_FIFO(NUM_BANKS_FIFO),
        .RD_DATA_COUNT_WIDTH(RD_DATA_COUNT_WIDTH),
        .WR_DATA_COUNT_WIDTH(WR_DATA_COUNT_WIDTH),
        .FIFO_WRITE_DEPTH(FIFO_WRITE_DEPTH)
    ) top_r2b_circular_fifo_inst (
        .clk(clk),
        .rst_n(internal_rst_n_fifo),
        .fifo_wr_en(output_valid_r2b),
        .in_data(out_data_r2b),
        .fifo_idx(fifo_idx),
        .fifo_rd_en(fifo_rd_en),
        //.fifo_full(fifo_full),
        .wr_data_count(wr_data_count_fifo),
        .rd_data_count(rd_data_count_fifo),
        .fifo_empty(),
        .fifo_underflow(fifo_underflow),
        .out_data(out_data_fifo)
    );

    // ************************** Matmul Module (Qn x Kn^T) x Vn **************************
    logic sig_internal_rst_n_ctrl;
    logic sig_internal_reset_acc_ctrl;
    logic sig_out_valid;
    logic sig_enable_matmul;

    logic sig_acc_done_wrap;
    logic sig_systolic_finish_wrap;
    
    logic [W1_IN_WIDTH-1:0] w_bank1_din_bridge [NUMBER_OF_BUFFER_INSTANCES_LOCAL][TOTAL_INPUT_W_W1];
    logic [N1_IN_WIDTH-1:0] n_bank1_din_bridge [NUMBER_OF_BUFFER_INSTANCES_LOCAL][TOTAL_INPUT_W_N1];
    //logic [N1_IN_WIDTH-1:0] input_n_QKT_Vn [TOTAL_INPUT_W_N1];
                
    genvar u,t, w,v;
    generate
        
        for (u = 0; u < TOTAL_INPUT_W_W1; u++) begin
            for (t = 0; t < NUM_BANKS_FIFO; t++) begin
                assign w_bank1_din_bridge[0][u] = out_data_fifo[u][fifo_idx[t]];
            end
        end
        
        for (w = 0; w < NUMBER_OF_BUFFER_INSTANCES_LOCAL; w++) begin
            for (v = 0; v < TOTAL_INPUT_W_N1; v++) begin
                assign n_bank1_din_bridge[w][v] = input_n_QKT_Vn[v];
            end
        end
    endgenerate
    
    logic [W1_SLICE_WIDTH-1:0] w_dout_b1 [NUMBER_OF_BUFFER_INSTANCES_LOCAL][TOTAL_INPUT_W_W1];
    logic [N1_MODULE_WIDTH-1:0] n_dout_b1 [NUMBER_OF_BUFFER_INSTANCES_LOCAL];
    
    top_buffer #(
        .NUMBER_OF_BUFFER_INSTANCES(NUMBER_OF_BUFFER_INSTANCES_LOCAL),
        // West
        .WIDTH              (B1_WIDTH),
        .W_NUM_CORES_A      (W1_NUM_CORES_A),
        .W_NUM_CORES_B      (W1_NUM_CORES_B),
        .W_TOTAL_MODULES    (W1_TOTAL_MODULES),
        .W_COL_X            (W1_COL_X),
        .W_ROW_X            (W1_ROW_X),
        .TOTAL_INPUT_W_W    (TOTAL_INPUT_W_W1),
        
        .ADDR_WIDTH_W       (ADDR_WIDTH_W1),
        .W_IN_WIDTH         (W1_IN_WIDTH),
        .W_SLICE_WIDTH      (W1_SLICE_WIDTH),
        .W_MODULE_WIDTH     (W1_MODULE_WIDTH),
        .W_MEMORY_SIZE      (W1_MEMORY_SIZE),
        .W_TOTAL_DEPTH      (W1_TOTAL_DEPTH),
        
        // North
        .N_NUM_CORES_A      (N1_NUM_CORES_A),
        .N_NUM_CORES_B      (N1_NUM_CORES_B),
        .N_TOTAL_MODULES    (N1_TOTAL_MODULES),
        .N_ROW_X            (N1_ROW_X),
        .N_COL_X            (N1_COL_X),
        .TOTAL_INPUT_W_N    (TOTAL_INPUT_W_N1),
        
        .ADDR_WIDTH_N       (ADDR_WIDTH_N1),
        .N_IN_WIDTH         (N1_IN_WIDTH),
        .N_MEMORY_SIZE      (N1_MEMORY_SIZE),
        .N_TOTAL_DEPTH      (N1_TOTAL_DEPTH),
        .N_SLICE_WIDTH      (N1_SLICE_WIDTH),
        .N_MODULE_WIDTH     (N1_MODULE_WIDTH),
    
        // ================= GLOBAL PARAMETERS =================
        .MAX_FLAG           (MAX_FLAG_B1),
        .COL_Y              (COL_SIZE_MAT_C_B1),
        .INNER_DIMENSION    (INNER_DIMENSION_QKT_Vn)
    ) buffer1 (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .in_valid_w             (fifo_out_valid),
        .in_valid_n             (in_valid_n_QKT_Vn),
        .acc_done_wrap          (sig_acc_done_wrap),
        .systolic_finish_wrap   (sig_systolic_finish_wrap),

        // -------- West --------
        .w_bank0_din(w_bank1_din_bridge),
        .w_dout     (w_dout_b1),

        // -------- North --------
        .n_bank0_din(n_bank1_din_bridge),
        .n_dout     (n_dout_b1),

        // -------- Global --------
        .internal_rst_n_ctrl     (sig_internal_rst_n_ctrl),
        .internal_reset_acc_ctrl (sig_internal_reset_acc_ctrl),
        .out_valid               (sig_out_valid),
        .enable_matmul           (sig_enable_matmul)
    );
    
    genvar a;
    generate
        for (a = 0; a < NUMBER_OF_BUFFER_INSTANCES_LOCAL; a++) begin
            multi_matmul_wrapper #(
                .WIDTH_A                    (WIDTH_A),      // Still from linear_proj_pkg
                .FRAC_WIDTH_A               (FRAC_WIDTH_A), // Still from linear_proj_pkg
                .WIDTH_B                    (WIDTH_B),      // Still from linear_proj_pkg
                .FRAC_WIDTH_B               (FRAC_WIDTH_B), // Still from linear_proj_pkg
                .WIDTH_OUT                  (WIDTH_OUT),    // Still from linear_proj_pkg
                .FRAC_WIDTH_OUT             (FRAC_WIDTH_OUT), // Still from linear_proj_pkg
                .BLOCK_SIZE                 (BLOCK_SIZE),
                .CHUNK_SIZE                 (CHUNK_SIZE),
                .INNER_DIMENSION            (INNER_DIMENSION_QKT_Vn),
                .TOTAL_MODULES              (TOTAL_MODULES_LP_V),
                .TOTAL_INPUT_W              (TOTAL_INPUT_W_W1),
                .NUM_CORES_A                (NUM_CORES_A_QKT_Vn),
                .NUM_CORES_B                (NUM_CORES_B_QKT_Vn)
            ) matmul_QKT_V (
                .clk                    (clk),
                .rst_n                  (sig_internal_rst_n_ctrl),
                .en                     (sig_enable_matmul),
                .reset_acc              (sig_internal_reset_acc_ctrl),
                .input_w                (w_dout_b1[a]),
                .input_n                (n_dout_b1[a]),
                .acc_done_wrap          (sig_acc_done_wrap),
                .systolic_finish_wrap   (sig_systolic_finish_wrap),
                .out_multi_matmul       (out_matmul_QKT_Vn[a])
            );
        end
    endgenerate

    // ************************** DELAYER **************************
    // Used as a register: out_b2r_data_reg

    always @(posedge clk) begin
        if (!rst_n) begin
            for (int a = 0; a < TOTAL_INPUT_W_Qn_KnT; a++) begin
                out_b2r_data_reg[a] <= '0;
            end
        end
        else begin
            for (int a = 0; a < TOTAL_INPUT_W_Qn_KnT; a++) begin
                out_b2r_data_reg[a] <= out_b2r_data[a];
            end
        end
    end



endmodule


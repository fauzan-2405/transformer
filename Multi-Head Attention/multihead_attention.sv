// multihead_attention.sv
// top module that contains top_linear_projection + top_self_attention_head

import linear_proj_pkg::*;
import self_attention_pkg::*;
import buffer0_pkg::*;

module multihead_attention #(
    localparam TOTAL_SOFTMAX_ROW = NUM_CORES_A_Qn_KnT * BLOCK_SIZE,
    parameter OUT_KEYS = WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A*NUM_CORES_B*TOTAL_MODULES,
    parameter NUMBER_OF_BUFFER_INSTANCES = 1
) (
    input logic clk, rst_n,
    input logic in_mat_ena,
    input logic in_mat_wea,
    input logic [ADDR_WIDTH_A-1:0] in_mat_wr_addra,
    input logic [DATA_WIDTH_A-1:0] in_mat_dina,

    input logic in_mat_enb,
    input logic in_mat_web,
    input logic [ADDR_WIDTH_A-1:0] in_mat_wr_addrb,
    input logic [DATA_WIDTH_A-1:0] in_mat_dinb,

    // Temporary output to see the intermediate results
    //output logic [TILE_SIZE_SOFTMAX*WIDTH_OUT-1:0] out_softmax_data [NUMBER_OF_BUFFER_INSTANCES][TOTAL_INPUT_W_Qn_KnT][TOTAL_SOFTMAX_ROW],
    //output logic out_softmax_valid [NUMBER_OF_BUFFER_INSTANCES][TOTAL_INPUT_W_Qn_KnT][TOTAL_SOFTMAX_ROW]
    //output logic [WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A_QKT_Vn-1:0] out_data_r2b [NUMBER_OF_BUFFER_INSTANCES][TOTAL_INPUT_W_Qn_KnT][TOTAL_TILE_SOFTMAX]
    //output logic [(WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A_QKT_Vn)-1:0] out_data_fifo [TOTAL_INPUT_W_Qn_KnT][NUM_BANKS_FIFO]
    output logic [(WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A_QKT_Vn*NUM_CORES_B_QKT_Vn*TOTAL_MODULES_LP_V)-1:0]
        out_matmul_QKT_Vn [TOTAL_INPUT_W_Qn_KnT]
);

    // ********************************************* TOP LINEAR PROJECTION *********************************************
    logic internal_rst_n_lp;
    logic [(OUT_KEYS)-1:0] out_q1_wire [TOTAL_INPUT_W];
    /*
    logic [(OUT_KEYS)-1:0] out_q2_wire [TOTAL_INPUT_W];
    logic [(OUT_KEYS)-1:0] out_q3_wire [TOTAL_INPUT_W];
    logic [(OUT_KEYS)-1:0] out_q4_wire [TOTAL_INPUT_W]; */

    logic [(OUT_KEYS)-1:0] out_k1_wire [TOTAL_INPUT_W];
    /*
    logic [(OUT_KEYS)-1:0] out_k2_wire [TOTAL_INPUT_W];
    logic [(OUT_KEYS)-1:0] out_k3_wire [TOTAL_INPUT_W];
    logic [(OUT_KEYS)-1:0] out_k4_wire [TOTAL_INPUT_W]; */

    logic [(OUT_KEYS)-1:0] out_v1_wire [TOTAL_INPUT_W];
    /*
    logic [(OUT_KEYS)-1:0] out_v2_wire [TOTAL_INPUT_W];
    logic [(OUT_KEYS)-1:0] out_v3_wire [TOTAL_INPUT_W];
    logic [(OUT_KEYS)-1:0] out_v4_wire [TOTAL_INPUT_W]; */

    logic lp_valid, lp_done;

    top_linear_projection #(
        .OUT_KEYS(OUT_KEYS)
    ) linear_projection_inst (
        .clk(clk), .rst_n(internal_rst_n_lp),
        
        .in_mat_ena(in_mat_ena),
        .in_mat_wea(in_mat_wea),
        .in_mat_wr_addra(in_mat_wr_addra),
        .in_mat_dina(in_mat_dina),

        .in_mat_enb(in_mat_enb),
        .in_mat_web(in_mat_web),
        .in_mat_wr_addrb(in_mat_wr_addrb),
        .in_mat_dinb(in_mat_dinb),

        .out_q1(out_q1_wire), // We're just using one output to see the behavior
        /* 
        .out_q2(out_q2_wire),
        .out_q3(out_q3_wire),
        .out_q4(out_q4_wire), */

        .out_k1(out_k1_wire),
        /*
        .out_k2(out_k2_wire),
        .out_k3(out_k3_wire),
        .out_k4(out_k4_wire), */

        .out_v1(out_v1_wire),
        /*
        .out_v2(out_v2_wire),
        .out_v3(out_v3_wire),
        .out_v4(out_v4_wire), */

        .out_valid(lp_valid),
        .done(lp_done)
    );


    // ********************************************* TOP BUFFER  *********************************************
    logic [W0_IN_WIDTH-1:0] w_bank0_din_bridge [NUMBER_OF_BUFFER_INSTANCES][TOTAL_INPUT_W_W0]; // For West Bank0 (Qn)
    logic [N0_IN_WIDTH-1:0] n_bank0_din_bridge [NUMBER_OF_BUFFER_INSTANCES][TOTAL_INPUT_W_N0]; // For North Bank0 (Kn)
    logic [N0_IN_WIDTH-1:0] n_bank1_din_bridge [NUMBER_OF_BUFFER_INSTANCES][TOTAL_INPUT_W_N0]; // For North Bank1 (Vn)

    genvar t, u;
    generate
        for (u = 0; u < NUMBER_OF_BUFFER_INSTANCES; u++) begin
            for (t = 0; t < TOTAL_INPUT_W_W0; t++) begin
                if (u == 0) begin
                    assign w_bank0_din_bridge[0][t] = out_q1_wire[t];
                    assign n_bank0_din_bridge[0][t] = out_k1_wire[t];
                    assign n_bank1_din_bridge[0][t] = out_v1_wire[t];
                end /*
                else if (u == 1) begin
                    assign w_bank0_din_bridge[1][t] = out_q2_wire[t];
                    assign n_bank0_din_bridge[1][t] = out_k2_wire[t];
                    assign n_bank1_din_bridge[1][t] = out_v2_wire[t];
                end
                else if (u == 2) begin
                    assign w_bank0_din_bridge[2][t] = out_q3_wire[t];
                    assign n_bank0_din_bridge[2][t] = out_k3_wire[t];
                    assign n_bank1_din_bridge[2][t] = out_v3_wire[t];
                end
                else if (u == 3) begin
                    assign w_bank0_din_bridge[3][t] = out_q4_wire[t];
                    assign n_bank0_din_bridge[3][t] = out_k4_wire[t];
                    assign n_bank1_din_bridge[3][t] = out_v4_wire[t];
                end */
            end
        end
    endgenerate

    logic [W0_SLICE_WIDTH-1:0] w_dout_b0 [NUMBER_OF_BUFFER_INSTANCES][TOTAL_INPUT_W_W0];
    logic [N0_MODULE_WIDTH-1:0] n_dout_b0 [NUMBER_OF_BUFFER_INSTANCES];

    logic sig_internal_rst_n_ctrl;
    logic sig_internal_reset_acc_ctrl;
    logic sig_out_valid;
    logic sig_enable_matmul;

    logic sig_acc_done_wrap;
    logic sig_systolic_finish_wrap;

    top_buffer #(
        .NUMBER_OF_BUFFER_INSTANCES(NUMBER_OF_BUFFER_INSTANCES),
        // West
        .WIDTH              (B0_WIDTH),
        .W_NUM_CORES_A      (W0_NUM_CORES_A),
        .W_NUM_CORES_B      (W0_NUM_CORES_B),
        .W_TOTAL_MODULES    (W0_TOTAL_MODULES),
        .W_COL_X            (W0_COL_X),
        .W_ROW_X            (W0_ROW_X),
        .TOTAL_INPUT_W_W    (TOTAL_INPUT_W_W0),
        
        .ADDR_WIDTH_W       (ADDR_WIDTH_W0),
        .W_IN_WIDTH         (W0_IN_WIDTH),
        .W_SLICE_WIDTH      (W0_SLICE_WIDTH),
        .W_MODULE_WIDTH     (W0_MODULE_WIDTH),
        .W_MEMORY_SIZE      (W0_MEMORY_SIZE),
        .W_TOTAL_DEPTH      (W0_TOTAL_DEPTH),
        
        // North
        .N_NUM_CORES_A      (N0_NUM_CORES_A),
        .N_NUM_CORES_B      (N0_NUM_CORES_B),
        .N_TOTAL_MODULES    (N0_TOTAL_MODULES),
        .N_ROW_X            (N0_ROW_X),
        .N_COL_X            (N0_COL_X),
        .TOTAL_INPUT_W_N    (TOTAL_INPUT_W_N0),
        
        .ADDR_WIDTH_N       (ADDR_WIDTH_N0),
        .N_IN_WIDTH         (N0_IN_WIDTH),
        .N_MEMORY_SIZE      (N0_MEMORY_SIZE),
        .N_TOTAL_DEPTH      (N0_TOTAL_DEPTH),
        .N_SLICE_WIDTH      (N0_SLICE_WIDTH),
        .N_MODULE_WIDTH     (N0_MODULE_WIDTH),
    
        // ================= GLOBAL PARAMETERS =================
        .MAX_FLAG           (MAX_FLAG_B0),
        .COL_Y              (COL_SIZE_MAT_C_B0),
        .INNER_DIMENSION    (B0_INNER_DIMENSION)
    ) bridge_buffer0 (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .in_valid_w             (lp_valid),
        .in_valid_n             (lp_valid),
        .acc_done_wrap          (sig_acc_done_wrap),
        .systolic_finish_wrap   (sig_systolic_finish_wrap),

        // -------- West --------
        .w_bank0_din(w_bank0_din_bridge),
        .w_dout     (w_dout_b0),

        // -------- North --------
        .n_bank0_din(n_bank0_din_bridge),
        .n_dout     (n_dout_b0),

        // -------- Global --------
        .internal_rst_n_ctrl     (sig_internal_rst_n_ctrl),
        .internal_reset_acc_ctrl (sig_internal_reset_acc_ctrl),
        .out_valid               (sig_out_valid),
        .enable_matmul           (sig_enable_matmul)
    );


    // ********************************************* TOP SELF ATTENTION HEAD *********************************************
    //logic [TILE_SIZE_SOFTMAX*WIDTH_OUT-1:0] out_softmax_data [TOTAL_INPUT_W_Qn_KnT][TOTAL_SOFTMAX_ROW];
    //logic out_softmax_valid [TOTAL_INPUT_W_Qn_KnT][TOTAL_SOFTMAX_ROW];
    top_self_attention_head #(
        .NUMBER_OF_BUFFER_INSTANCES(NUMBER_OF_BUFFER_INSTANCES)
    ) self_attention_inst (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .en_Qn_KnT              (sig_enable_matmul),
        .rst_n_Qn_KnT           (sig_internal_rst_n_ctrl),
        .reset_acc_Qn_KnT       (sig_internal_reset_acc_ctrl),
        .out_valid_Qn_KnT       (sig_out_valid),

        .acc_done_wrap_Qn_KnT   (sig_acc_done_wrap), 
        .sys_finish_wrap_Qn_KnT (sig_systolic_finish_wrap),

        .input_w_Qn_KnT         (w_dout_b0),
        .input_n_Qn_KnT         (n_dout_b0),
        
        .in_valid_n_QKT_Vn      (lp_valid),
        .input_n_QKT_Vn         (n_bank1_din_bridge)
        
        //.out_matmul_QKT_Vn      (out_matmul_QKT_Vn)
        
        // Temporary output
        //.out_softmax_data(out_softmax_data),
        //.out_softmax_valid(out_softmax_valid)
        //.out_data_r2b(out_data_r2b)
        //.out_data_fifo(out_data_fifo)
    );
    
    // ********************************************* Multi Head Controller *********************************************
    always @(posedge clk) begin
        if (~rst_n) begin
            internal_rst_n_lp   <= rst_n;
        end else begin
            // Internal reset for Linear Projection
            internal_rst_n_lp   <= ~lp_done;
        end
    end

endmodule

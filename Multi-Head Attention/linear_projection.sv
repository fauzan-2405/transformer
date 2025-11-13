// linear_projection.sv
// Used to do linear projection of course (duh)
import linear_proj_pkg::*;

module linear_pojection #(
    parameter OUT_KEYS = WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A*NUM_CORES_B*TOTAL_MODULES
) (
    input logic clk, rst_n,
    output logic [(OUT_KEYS)-1:0] out_q1 [TOTAL_INPUT_W],
    output logic [(OUT_KEYS)-1:0] out_q2 [TOTAL_INPUT_W],
    output logic [(OUT_KEYS)-1:0] out_q3 [TOTAL_INPUT_W],
    output logic [(OUT_KEYS)-1:0] out_q4 [TOTAL_INPUT_W],

    output logic [(OUT_KEYS)-1:0] out_k1 [TOTAL_INPUT_W],
    output logic [(OUT_KEYS)-1:0] out_k2 [TOTAL_INPUT_W],
    output logic [(OUT_KEYS)-1:0] out_k3 [TOTAL_INPUT_W],
    output logic [(OUT_KEYS)-1:0] out_k4 [TOTAL_INPUT_W],

    output logic [(OUT_KEYS)-1:0] out_v1 [TOTAL_INPUT_W],
    output logic [(OUT_KEYS)-1:0] out_v2 [TOTAL_INPUT_W],
    output logic [(OUT_KEYS)-1:0] out_v3 [TOTAL_INPUT_W],
    output logic [(OUT_KEYS)-1:0] out_v4 [TOTAL_INPUT_W],
    
);
    // ************************** Generating Q keys **************************
    logic [TOTAL_WEIGHT_PER_KEY-1:0] acc_done_q, systolic_finish_q;
    genvar i;
    generate
        for (i = 0; i < TOTAL_WEIGHT_PER_KEY; i++) begin : GEN_MULTWRAP_Q
            if (i == 0) begin : Q1
                multwrap_wbram #(.MEM_INIT_FILE("mem_q1.mem")) q1 (
                    .clk(clk),
                    .en_module(en),
                    .internal_rst_n(internal_rst_n),
                    .rst_n(rst_n),
                    .internal_reset_acc(internal_reset_acc),
                    .w_mat_enb(w_mat_enb),
                    .w_mat_addrb(w_mat_addrb),
                    .in_multi_matmul(in_multi_matmul),
                    .acc_done_wrap(acc_done_q[i]),
                    .systolic_finish_wrap(systolic_finish_q[i]),
                    .out_multwrap_wbram(out_q1)
                );
            end
            else if (i == 1) begin : Q2
                multwrap_wbram #(.MEM_INIT_FILE("mem_q2.mem")) q2 (
                    .clk(clk),
                    .en_module(en),
                    .internal_rst_n(internal_rst_n),
                    .rst_n(rst_n),
                    .internal_reset_acc(internal_reset_acc),
                    .w_mat_enb(w_mat_enb),
                    .w_mat_addrb(w_mat_addrb),
                    .in_multi_matmul(in_multi_matmul),
                    .acc_done_wrap(acc_done_q[i]),
                    .systolic_finish_wrap(systolic_finish_q[i]),
                    .out_multwrap_wbram(out_q2)
                );
            end
            else if (i == 2) begin : Q3
                multwrap_wbram #(.MEM_INIT_FILE("mem_q3.mem")) q3 (
                    .clk(clk),
                    .en_module(en),
                    .internal_rst_n(internal_rst_n),
                    .rst_n(rst_n),
                    .internal_reset_acc(internal_reset_acc),
                    .w_mat_enb(w_mat_enb),
                    .w_mat_addrb(w_mat_addrb),
                    .in_multi_matmul(in_multi_matmul),
                    .acc_done_wrap(acc_done_q[i]),
                    .systolic_finish_wrap(systolic_finish_q[i]),
                    .out_multwrap_wbram(out_q3)
                );
            end
            else if (i == 3) begin : Q4
                multwrap_wbram #(.MEM_INIT_FILE("mem_q4.mem")) q4 (
                    .clk(clk),
                    .en_module(en),
                    .internal_rst_n(internal_rst_n),
                    .rst_n(rst_n),
                    .internal_reset_acc(internal_reset_acc),
                    .w_mat_enb(w_mat_enb),
                    .w_mat_addrb(w_mat_addrb),
                    .in_multi_matmul(in_multi_matmul),
                    .acc_done_wrap(acc_done_q[i]),
                    .systolic_finish_wrap(systolic_finish_q[i]),
                    .out_multwrap_wbram(out_q4)
                );
            end
        end
    endgenerate

    // ************************** Generating K keys **************************
    logic [TOTAL_WEIGHT_PER_KEY-1:0] acc_done_k, systolic_finish_k;
    genvar j;
    generate
        for (j = 0; j < TOTAL_WEIGHT_PER_KEY; j++) begin : GEN_MULTWRAP_K
            else if (j == 0) begin : K1
                multwrap_wbram #(.MEM_INIT_FILE("mem_k1.mem")) k1 (
                    .clk(clk),
                    .en_module(en),
                    .internal_rst_n(internal_rst_n),
                    .rst_n(rst_n),
                    .internal_reset_acc(internal_reset_acc),
                    .w_mat_enb(w_mat_enb),
                    .w_mat_addrb(w_mat_addrb),
                    .in_multi_matmul(in_multi_matmul),
                    .acc_done_wrap(acc_done_k[j]),
                    .systolic_finish_wrap(systolic_finish_k[j]),
                    .out_multwrap_wbram(out_k1)
                );
            end
            else if (j == 1) begin : K2
                multwrap_wbram #(.MEM_INIT_FILE("mem_k2.mem")) k2 (
                    .clk(clk),
                    .en_module(en),
                    .internal_rst_n(internal_rst_n),
                    .rst_n(rst_n),
                    .internal_reset_acc(internal_reset_acc),
                    .w_mat_enb(w_mat_enb),
                    .w_mat_addrb(w_mat_addrb),
                    .in_multi_matmul(in_multi_matmul),
                    .acc_done_wrap(acc_done_k[j]),
                    .systolic_finish_wrap(systolic_finish_k[j]),
                    .out_multwrap_wbram(out_k2)
                );
            end
            else if (j == 2) begin : K3
                multwrap_wbram #(.MEM_INIT_FILE("mem_k3.mem")) k3 (
                    .clk(clk),
                    .en_module(en),
                    .internal_rst_n(internal_rst_n),
                    .rst_n(rst_n),
                    .internal_reset_acc(internal_reset_acc),
                    .w_mat_enb(w_mat_enb),
                    .w_mat_addrb(w_mat_addrb),
                    .in_multi_matmul(in_multi_matmul),
                    .acc_done_wrap(acc_done_k[j]),
                    .systolic_finish_wrap(systolic_finish_k[j]),
                    .out_multwrap_wbram(out_k3)
                );
            end
            else if (j == 3) begin : K4
                multwrap_wbram #(.MEM_INIT_FILE("mem_k4.mem")) k4 (
                    .clk(clk),
                    .en_module(en),
                    .internal_rst_n(internal_rst_n),
                    .rst_n(rst_n),
                    .internal_reset_acc(internal_reset_acc),
                    .w_mat_enb(w_mat_enb),
                    .w_mat_addrb(w_mat_addrb),
                    .in_multi_matmul(in_multi_matmul),
                    .acc_done_wrap(acc_done_k[j]),
                    .systolic_finish_wrap(systolic_finish_k[j]),
                    .out_multwrap_wbram(out_k4)
                );
            end
        end
    endgenerate

    // ************************** Generating V keys **************************
    logic [TOTAL_WEIGHT_PER_KEY-1:0] acc_done_v, systolic_finish_v;
    genvar k;
    generate
        for (k = 0; k < TOTAL_WEIGHT_PER_KEY; k++) begin : GEN_MULTWRAP_V
            else if (k == 0) begin : V1
                multwrap_wbram #(.MEM_INIT_FILE("mem_v1.mem")) v1 (
                    .clk(clk),
                    .en_module(en),
                    .internal_rst_n(internal_rst_n),
                    .rst_n(rst_n),
                    .internal_reset_acc(internal_reset_acc),
                    .w_mat_enb(w_mat_enb),
                    .w_mat_addrb(w_mat_addrb),
                    .in_multi_matmul(in_multi_matmul),
                    .acc_done_wrap(acc_done_v[k]),
                    .systolic_finish_wrap(systolic_finish_v[k]),
                    .out_multwrap_wbram(out_v1)
                );
            end
            else if (i == 9) begin : V2
                multwrap_wbram #(.MEM_INIT_FILE("mem_v2.mem")) v2 (
                    .clk(clk),
                    .en_module(en),
                    .internal_rst_n(internal_rst_n),
                    .rst_n(rst_n),
                    .internal_reset_acc(internal_reset_acc),
                    .w_mat_enb(w_mat_enb),
                    .w_mat_addrb(w_mat_addrb),
                    .in_multi_matmul(in_multi_matmul),
                    .acc_done_wrap(acc_done_v[k]),
                    .systolic_finish_wrap(systolic_finish_v[k]),
                    .out_multwrap_wbram(out_v2)
                );
            end
            else if (i == 10) begin : V3
                multwrap_wbram #(.MEM_INIT_FILE("mem_v3.mem")) v3 (
                    .clk(clk),
                    .en_module(en),
                    .internal_rst_n(internal_rst_n),
                    .rst_n(rst_n),
                    .internal_reset_acc(internal_reset_acc),
                    .w_mat_enb(w_mat_enb),
                    .w_mat_addrb(w_mat_addrb),
                    .in_multi_matmul(in_multi_matmul),
                    .acc_done_wrap(acc_done_v[k]),
                    .systolic_finish_wrap(systolic_finish_v[k]),
                    .out_multwrap_wbram(out_v3)
                );
            end
            else begin : V4
                multwrap_wbram #(.MEM_INIT_FILE("mem_v4.mem")) v4 (
                    .clk(clk),
                    .en_module(en),
                    .internal_rst_n(internal_rst_n),
                    .rst_n(rst_n),
                    .internal_reset_acc(internal_reset_acc),
                    .w_mat_enb(w_mat_enb),
                    .w_mat_addrb(w_mat_addrb),
                    .in_multi_matmul(in_multi_matmul),
                    .acc_done_wrap(acc_done_v[k]),
                    .systolic_finish_wrap(systolic_finish_v[k]),
                    .out_multwrap_wbram(out_v4)
                );
            end
        end
    endgenerate

    //
    logic acc_done_all = &acc_done_q && &acc_done_k && &acc_done_v;
    logic systolic_finish_all = &systolic_finish_q && &systolic_finish_k && &&systolic_finish_v;


endmodule
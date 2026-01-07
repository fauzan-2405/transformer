// top_ping_pong_buffers.sv
// Wrapper for ping_pong_buffer_w + ping_pong_buffer_n
// Controller signals are assumed to be driven externally (ping_pong_ctrl)

module top_ping_pong_buffers #(
    // West Buffer
    parameter WIDTH             = 16,

    parameter W_NUM_CORES_A     = 2,
    parameter W_NUM_CORES_B     = 1,
    parameter W_TOTAL_MODULES   = 4,
    parameter W_COL_X           = 4,
    parameter W_ROW_X           = 2,
    parameter TOTAL_INPUT_W_W   = 4,
    parameter ADDR_WIDTH_W      = 8,
    parameter W_IN_WIDTH        = 32,
    parameter W_MODULE_WIDTH    = 32,
    parameter W_MEMORY_SIZE     = 256,
    parameter W_TOTAL_DEPTH     = 12,

    // North Buffer
    parameter N_NUM_CORES_A     = 2,
    parameter N_NUM_CORES_B     = 1,
    parameter N_TOTAL_MODULES   = 4,
    parameter N_COL_X           = 4,
    parameter TOTAL_INPUT_W_N   = 4,
    parameter ADDR_WIDTH_N      = 8,
    parameter N_MEMORY_SIZE     = 256,
    parameter N_TOTAL_DEPTH     = 12,
    parameter N_IN_WIDTH        = 32,
    parameter N_SLICE_WIDTH     = 2,
    parameter N_MODULE_WIDTH    = 16
) (
    input  logic clk,
    input  logic rst_n,

    // ---------------- Controller interface ----------------
    input  logic [$clog2(W_TOTAL_MODULES)-1:0] w_slicing_idx,
    input  logic [$clog2(N_TOTAL_MODULES)-1:0] n_slicing_idx,

    // West buffer control
    input  logic                  w_bank0_ena,
    input  logic                  w_bank0_enb,
    input  logic                  w_bank0_wea,
    input  logic                  w_bank0_web,
    input  logic [ADDR_WIDTH_W-1:0] w_bank0_addra,
    input  logic [ADDR_WIDTH_W-1:0] w_bank0_addrb,

    input  logic                  w_bank1_ena,
    input  logic                  w_bank1_enb,
    input  logic                  w_bank1_wea,
    input  logic                  w_bank1_web,
    input  logic [ADDR_WIDTH_W-1:0] w_bank1_addra,
    input  logic [ADDR_WIDTH_W-1:0] w_bank1_addrb,

    // North buffer control
    input  logic                  n_bank0_ena,
    input  logic                  n_bank0_wea,
    input  logic [ADDR_WIDTH_N-1:0] n_bank0_addra,

    input  logic                  n_bank1_ena,
    input  logic                  n_bank1_wea,
    input  logic [ADDR_WIDTH_N-1:0] n_bank1_addra,

    // ---------------- Data inputs ----------------
    // From linear projection
    input  logic [W_IN_WIDTH-1:0] w_bank0_din [TOTAL_INPUT_W_W],
    input  logic [W_IN_WIDTH-1:0] w_bank1_din [TOTAL_INPUT_W_W],

    input  logic [N_IN_WIDTH-1:0] n_bank0_din [TOTAL_INPUT_W_N],
    input  logic [N_IN_WIDTH-1:0] n_bank1_din [TOTAL_INPUT_W_N],

    // ---------------- Data outputs ----------------
    // To systolic array
    output logic [W_MODULE_WIDTH-1:0] w_bank0_douta,
    output logic [W_MODULE_WIDTH-1:0] w_bank0_doutb,
    output logic [W_MODULE_WIDTH-1:0] w_bank1_douta,
    output logic [W_MODULE_WIDTH-1:0] w_bank1_doutb,

    output logic [N_MODULE_WIDTH-1:0] n_bank0_dout,
    output logic [N_MODULE_WIDTH-1:0] n_bank1_dout
);

    // =====================================================================
    // WEST PING-PONG BUFFER
    // =====================================================================
    ping_pong_buffer_w #(
        .WIDTH         (WIDTH),
        .NUM_CORES_A   (W_NUM_CORES_A),
        .NUM_CORES_B   (W_NUM_CORES_B),
        .TOTAL_MODULES (W_TOTAL_MODULES),
        .COL_X         (W_COL_X),
        .TOTAL_INPUT_W (TOTAL_INPUT_W_W),
        .MODULE_WIDTH  (W_MODULE_WIDTH),
        .IN_WIDTH      (W_IN_WIDTH),
        .TOTAL_DEPTH   (W_TOTAL_DEPTH),
        .MEMORY_SIZE   (W_MEMORY_SIZE),
        .ADDR_WIDTH    (ADDR_WIDTH_W)
    ) u_ping_pong_buffer_w (
        .clk        (clk),
        .rst_n      (rst_n),
        .slicing_idx(w_slicing_idx),

        // Bank 0
        .bank0_ena  (w_bank0_ena),
        .bank0_enb  (w_bank0_enb),
        .bank0_wea  (w_bank0_wea),
        .bank0_web  (w_bank0_web),
        .bank0_addra(w_bank0_addra),
        .bank0_addrb(w_bank0_addrb),
        .bank0_din  (w_bank0_din),
        .bank0_douta(w_bank0_douta),
        .bank0_doutb(w_bank0_doutb),

        // Bank 1
        .bank1_ena  (w_bank1_ena),
        .bank1_enb  (w_bank1_enb),
        .bank1_wea  (w_bank1_wea),
        .bank1_web  (w_bank1_web),
        .bank1_addra(w_bank1_addra),
        .bank1_addrb(w_bank1_addrb),
        .bank1_din  (w_bank1_din),
        .bank1_douta(w_bank1_douta),
        .bank1_doutb(w_bank1_doutb)
    );

    // =====================================================================
    // NORTH PING-PONG BUFFER
    // =====================================================================
    ping_pong_buffer_n #(
        .WIDTH         (WIDTH),
        .NUM_CORES_A   (N_NUM_CORES_A),
        .NUM_CORES_B   (N_NUM_CORES_B),
        .TOTAL_MODULES (N_TOTAL_MODULES),
        .COL_X         (N_COL_X),
        .TOTAL_INPUT_W (TOTAL_INPUT_W_N),
        .SLICE_WIDTH   (N_SLICE_WIDTH),
        .MODULE_WIDTH  (N_MODULE_WIDTH),
        .IN_WIDTH      (N_IN_WIDTH),
        .TOTAL_DEPTH   (N_TOTAL_DEPTH),
        .MEMORY_SIZE   (N_MEMORY_SIZE),
        .ADDR_WIDTH    (ADDR_WIDTH_N)
    ) u_ping_pong_buffer_n (
        .clk        (clk),
        .rst_n      (rst_n),
        .slicing_idx(n_slicing_idx),

        // Bank 0
        .bank0_ena  (n_bank0_ena),
        .bank0_wea  (n_bank0_wea),
        .bank0_addra(n_bank0_addra),
        .bank0_din  (n_bank0_din),
        .bank0_dout (n_bank0_dout),

        // Bank 1
        .bank1_ena  (n_bank1_ena),
        .bank1_wea  (n_bank1_wea),
        .bank1_addra(n_bank1_addra),
        .bank1_din  (n_bank1_din),
        .bank1_dout (n_bank1_dout)
    );

endmodule

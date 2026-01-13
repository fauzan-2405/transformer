// top_buffer.sv
// Wrapper for west_buffer + north_buffer
// Direction-based naming only (w_* and n_*)

module top_buffer #(
    // ---------------- WEST ----------------
    parameter WIDTH             = 16,
    parameter W_NUM_CORES_A     = 2,
    parameter W_NUM_CORES_B     = 1,
    parameter W_TOTAL_MODULES   = 4,
    parameter W_COL_X           = 4,
    parameter TOTAL_INPUT_W_W   = 4,
    parameter ADDR_WIDTH_W      = 8,

    // ---------------- NORTH ----------------
    parameter N_NUM_CORES_A     = 2,
    parameter N_NUM_CORES_B     = 1,
    parameter N_TOTAL_MODULES   = 4,
    parameter N_ROW_X           = 4,
    parameter TOTAL_INPUT_W_N   = 4,
    parameter ADDR_WIDTH_N      = 8
) (
    input  logic clk,
    input  logic rst_n,

    // ---------------- Controller ----------------
    input  logic [$clog2(W_TOTAL_MODULES)-1:0] w_slicing_idx,
    input  logic [$clog2(N_TOTAL_MODULES)-1:0] n_slicing_idx,

    // ================= WEST BUFFER =================
    input  logic                   w_ena,
    input  logic                   w_enb,
    input  logic                   w_wea,
    input  logic                   w_web,
    input  logic [ADDR_WIDTH_W-1:0] w_addra,
    input  logic [ADDR_WIDTH_W-1:0] w_addrb,
    input  logic [WIDTH-1:0]        w_din [TOTAL_INPUT_W_W],
    output logic [WIDTH-1:0]        w_douta,
    output logic [WIDTH-1:0]        w_doutb,

    // ================= NORTH BUFFER =================
    input  logic                   n_wr_en,
    input  logic [ADDR_WIDTH_N-1:0] n_wr_addr,
    input  logic [WIDTH-1:0]        n_wr_din [TOTAL_INPUT_W_N],

    input  logic                   n_rd_en,
    input  logic [ADDR_WIDTH_N-1:0] n_rd_addr,
    output logic [WIDTH-1:0]        n_rd_dout
);

    // ================================================================
    // WEST BUFFER
    // ================================================================
    west_buffer #(
        .WIDTH         (WIDTH),
        .NUM_CORES_A   (W_NUM_CORES_A),
        .NUM_CORES_B   (W_NUM_CORES_B),
        .TOTAL_MODULES (W_TOTAL_MODULES),
        .COL_X         (W_COL_X),
        .TOTAL_INPUT_W (TOTAL_INPUT_W_W)
    ) u_west_buffer (
        .clk         (clk),
        .rst_n       (rst_n),
        .slicing_idx (w_slicing_idx),

        .bank0_ena   (w_ena),
        .bank0_enb   (w_enb),
        .bank0_wea   (w_wea),
        .bank0_web   (w_web),
        .bank0_addra (w_addra),
        .bank0_addrb (w_addrb),
        .bank0_din   (w_din),
        .bank0_douta (w_douta),
        .bank0_doutb (w_doutb)
    );

    // ================================================================
    // NORTH BUFFER
    // ================================================================
    north_buffer #(
        .WIDTH         (WIDTH),
        .NUM_CORES_A   (N_NUM_CORES_A),
        .NUM_CORES_B   (N_NUM_CORES_B),
        .TOTAL_MODULES (N_TOTAL_MODULES),
        .COL_X         (N_ROW_X),
        .TOTAL_INPUT_W (TOTAL_INPUT_W_N)
    ) u_north_buffer (
        .clk         (clk),
        .rst_n       (rst_n),
        .slicing_idx (n_slicing_idx),

        // Write
        .wr_en       (n_wr_en),
        .wr_addr     (n_wr_addr),
        .wr_din      (n_wr_din),

        // Read
        .rd_en       (n_rd_en),
        .rd_addr     (n_rd_addr),
        .rd_dout     (n_rd_dout)
    );

endmodule

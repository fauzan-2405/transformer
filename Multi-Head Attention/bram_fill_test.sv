// ==========================================================
// bram_fill_test.sv
// Standalone BRAM fill/read test based on top_multwrap_bram.sv
// ==========================================================
`timescale 1ns/1ps
import linear_proj_pkg::*;

module bram_fill_test #(
    localparam MEMORY_SIZE_A = INNER_DIMENSION*A_OUTER_DIMENSION*WIDTH_A,
    localparam MEMORY_SIZE_B = INNER_DIMENSION*B_OUTER_DIMENSION*WIDTH_B,
    localparam DATA_WIDTH_A  = WIDTH_A*CHUNK_SIZE*NUM_CORES_A,
    localparam DATA_WIDTH_B  = WIDTH_B*CHUNK_SIZE*NUM_CORES_B*TOTAL_MODULES,
    localparam int ADDR_WIDTH_A = $clog2(MEMORY_SIZE_A/DATA_WIDTH_A),
    localparam int ADDR_WIDTH_B = $clog2(MEMORY_SIZE_B/DATA_WIDTH_B)
)(
    input  logic clk,
    input  logic rst_n,

    // Write-port inputs (from TB)
    input  logic in_mat_ena, in_mat_wea,
    input  logic [ADDR_WIDTH_A-1:0] in_mat_wr_addra,
    input  logic [DATA_WIDTH_A-1:0] in_mat_dina,

    input  logic in_mat_enb, in_mat_web,
    input  logic [ADDR_WIDTH_A-1:0] in_mat_wr_addrb,
    input  logic [DATA_WIDTH_A-1:0] in_mat_dinb,

    input  logic w_mat_ena, w_mat_wea,
    input  logic [ADDR_WIDTH_B-1:0] w_mat_wr_addra,
    input  logic [DATA_WIDTH_B-1:0] w_mat_dina,

    input  logic w_mat_enb, w_mat_web,
    input  logic [ADDR_WIDTH_B-1:0] w_mat_wr_addrb,
    input  logic [DATA_WIDTH_B-1:0] w_mat_dinb,

    // Status outputs
    output logic write_phase_done,
    output logic [DATA_WIDTH_A-1:0] in_read_a,
    output logic [DATA_WIDTH_A-1:0] in_read_b,
    output logic [DATA_WIDTH_B-1:0] w_read_b
);

    // --- mux logic as in your top file ---
    logic write_phase = 1'b1;
    logic [ADDR_WIDTH_A-1:0] in_mat_rd_addra, in_mat_rd_addrb;
    logic [ADDR_WIDTH_B-1:0] w_mat_rd_addrb;

    assign write_phase_done = ~write_phase;

    // Address muxes
    wire [ADDR_WIDTH_A-1:0] in_mat_addra_mux = (write_phase) ? in_mat_wr_addra : in_mat_rd_addra;
    wire [ADDR_WIDTH_A-1:0] in_mat_addrb_mux = (write_phase) ? in_mat_wr_addrb : in_mat_rd_addrb;
    wire [ADDR_WIDTH_B-1:0] w_mat_addra_mux  = (write_phase) ? w_mat_wr_addra : '0;
    wire [ADDR_WIDTH_B-1:0] w_mat_addrb_mux  = (write_phase) ? w_mat_wr_addrb : w_mat_rd_addrb;

    wire in_mat_wea_mux = (write_phase) ? in_mat_wea : 1'b0;
    wire in_mat_web_mux = (write_phase) ? in_mat_web : 1'b0;
    wire w_mat_wea_mux  = (write_phase) ? w_mat_wea  : 1'b0;
    wire w_mat_web_mux  = (write_phase) ? w_mat_web  : 1'b0;

    wire in_mat_ena_mux = (write_phase) ? in_mat_ena : 1'b1;
    wire in_mat_enb_mux = (write_phase) ? in_mat_enb : 1'b1;
    wire w_mat_ena_mux  = (write_phase) ? w_mat_ena  : 1'b1;
    wire w_mat_enb_mux  = (write_phase) ? w_mat_enb  : 1'b1;

    // --- XPM memories ---
    logic [DATA_WIDTH_A-1:0] in_mat_douta, in_mat_doutb;
    logic [DATA_WIDTH_B-1:0] w_mat_doutb;

    xpm_memory_tdpram #(
        .MEMORY_SIZE(MEMORY_SIZE_A),
        .MEMORY_PRIMITIVE("auto"),
        .CLOCKING_MODE("common_clock"),
        .MEMORY_INIT_FILE("none"),
        .MEMORY_INIT_PARAM("0"),
        .READ_LATENCY_A(1),
        .READ_LATENCY_B(1),
        .WRITE_DATA_WIDTH_A(DATA_WIDTH_A),
        .READ_DATA_WIDTH_A(DATA_WIDTH_A),
        .WRITE_DATA_WIDTH_B(DATA_WIDTH_A),
        .READ_DATA_WIDTH_B(DATA_WIDTH_A),
        .ADDR_WIDTH_A(ADDR_WIDTH_A),
        .ADDR_WIDTH_B(ADDR_WIDTH_A),
        .BYTE_WRITE_WIDTH_A(DATA_WIDTH_A),
        .BYTE_WRITE_WIDTH_B(DATA_WIDTH_A)
    ) xpm_in_mat (
        .sleep(1'b0),
        .clka(clk), .rsta(~rst_n),
        .ena(in_mat_ena_mux), .wea(in_mat_wea_mux),
        .addra(in_mat_addra_mux), .dina(in_mat_dina), .douta(in_mat_douta),
        .clkb(clk), .rstb(~rst_n),
        .enb(in_mat_enb_mux), .web(in_mat_web_mux),
        .addrb(in_mat_addrb_mux), .dinb(in_mat_dinb), .doutb(in_mat_doutb)
    );

    xpm_memory_tdpram #(
        .MEMORY_SIZE(MEMORY_SIZE_B),
        .MEMORY_PRIMITIVE("auto"),
        .CLOCKING_MODE("common_clock"),
        .MEMORY_INIT_FILE("none"),
        .MEMORY_INIT_PARAM("0"),
        .READ_LATENCY_A(1),
        .READ_LATENCY_B(1),
        .WRITE_DATA_WIDTH_A(DATA_WIDTH_B),
        .READ_DATA_WIDTH_A(DATA_WIDTH_B),
        .WRITE_DATA_WIDTH_B(DATA_WIDTH_B),
        .READ_DATA_WIDTH_B(DATA_WIDTH_B),
        .ADDR_WIDTH_A(ADDR_WIDTH_B),
        .ADDR_WIDTH_B(ADDR_WIDTH_B),
        .BYTE_WRITE_WIDTH_A(DATA_WIDTH_B),
        .BYTE_WRITE_WIDTH_B(DATA_WIDTH_B)
    ) xpm_w_mat (
        .sleep(1'b0),
        .clka(clk), .rsta(~rst_n),
        .ena(w_mat_ena_mux), .wea(w_mat_wea_mux),
        .addra(w_mat_addra_mux), .dina(w_mat_dina),
        .clkb(clk), .rstb(~rst_n),
        .enb(w_mat_enb_mux), .web(w_mat_web_mux),
        .addrb(w_mat_addrb_mux), .dinb(w_mat_dinb),
        .doutb(w_mat_doutb)
    );

    assign in_read_a = in_mat_douta;
    assign in_read_b = in_mat_doutb;
    assign w_read_b  = w_mat_doutb;

    // --- simple phase toggle + readback pattern ---
    typedef enum logic [1:0] {WRITE=0, WAIT=1, READ=2, DONE=3} state_t;
    state_t state;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= WRITE;
            in_mat_rd_addra <= '0;
            in_mat_rd_addrb <= '0;
            w_mat_rd_addrb  <= '0;
            write_phase <= 1'b1;
        end else begin
            case (state)
                WRITE: begin
                    // TB controls write ports; after some cycles, TB sets a flag to switch
                end
                WAIT: begin
                    write_phase <= 1'b0;
                    state <= READ;
                end
                READ: begin
                    in_mat_rd_addra <= in_mat_rd_addra + 1;
                    in_mat_rd_addrb <= in_mat_rd_addrb + 1;
                    w_mat_rd_addrb  <= w_mat_rd_addrb + 1;
                end
                default: state <= DONE;
            endcase
        end
    end

endmodule

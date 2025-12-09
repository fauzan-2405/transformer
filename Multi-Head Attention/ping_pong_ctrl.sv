// ping_pong_ctrl.sv
// Used to control ping_pong_buffer
// Basically utilizing the linear_proj_ctrl.sv but tweaks some of the settings

module ping_pong_ctrl #(
    parameter XXX = YYY,
    parameter XXX = YYY,
) (
    input logic clk, rst_n,

    output logic                    bram_ena_mux, bram_enb_mux,
    output logic [ADDR_WIDTH-1:0]   bram_addra_mux, bram_addrb_mux,
);
    

endmodule
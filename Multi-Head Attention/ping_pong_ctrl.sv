// ping_pong_ctrl.sv
// Used to control ping_pong_buffer
// Basically utilizing the linear_proj_ctrl.sv but tweaks some of the settings

module ping_pong_ctrl #(
    parameter XXX = YYY,
    parameter XXX = YYY,
) (
    input logic clk, rst_n,
    input logic in_valid,

    // Bank 0 Interface
    output logic                     bank0_ena_ctrl, bank0_enb_ctrl,
    output logic [ADDR_WIDTH-1:0]    bank0_addra_ctrl, bank0_addrb_ctrl,

    // Bank 1 Interface
    output logic                     bank1_ena_ctrl, bank1_enb_ctrl,
    output logic [ADDR_WIDTH-1:0]    bank1_addra_ctrl, bank1_addrb_ctrl,
);
    

endmodule
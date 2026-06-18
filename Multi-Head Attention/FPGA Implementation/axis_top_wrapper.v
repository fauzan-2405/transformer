// axis_top_wrapper.v
// axis_top_sv.sv wrapper for block diagram design

`timescale 1ns / 1ps
`include "config.svh"

module axis_top_wrapper #(
    localparam S0_WIDTH =   `SYSTEM_TOP_WIDTH_INPUT *
                            `TOP_CHUNK_SIZE *
                            `SYSTEM_NUM_CORES_A,
    localparam S1_WIDTH =   `SYSTEM_TOP_WIDTH_INPUT *
                            `TOP_CHUNK_SIZE *
                            `SYSTEM_NUM_CORES_A,
    localparam M0_WIDTH =   `SYSTEM_TOP_WIDTH_FINAL *
                            `TOP_CHUNK_SIZE * 
                            `SYSTEM_NUM_CORES_A * 
                            `SYSTEM_TOTAL_MODULES
) (
    input wire              aclk,
    input wire              aresetn,

    // *** AXIS Slave 0 port ***
    output wire                 s_axis_0_tready,
    input wire [S0_WIDTH-1:0]   s_axis_0_tdata, // Input Data
    input wire                  s_axis_0_tvalid,
    input wire                  s_axis_0_tlast,
    // *** AXIS Slave 1 port ***
    output wire                 s_axis_1_tready,
    input wire [S1_WIDTH-1:0]   s_axis_1_tdata, // Input Data
    input wire                  s_axis_1_tvalid,
    input wire                  s_axis_1_tlast,

    // *** Custom IP port (optional) ***
    output wire                 computation_done,
    
    // *** AXIS master port ***
    input wire                  m_axis_tready,
    output wire [M0_WIDTH-1:0]  m_axis_tdata, // Output Data
    output wire                 m_axis_tvalid,
    output wire                 m_axis_tlast
);

    axis_top_sv dut (
        .aclk       (aclk),
        .aresetn    (aresetn),
        // *** AXIS Slave 0 port ***
        .s_axis_0_tready    (s_axis_0_tready),
        .s_axis_0_tdata     (s_axis_0_tdata),
        .s_axis_0_tvalid    (s_axis_0_tvalid),
        .s_axis_0_tlast     (s_axis_0_tlast),
        // *** AXIS Slave 1 port ***
        .s_axis_1_tready    (s_axis_1_tready),
        .s_axis_1_tdata     (s_axis_1_tdata),
        .s_axis_1_tvalid    (s_axis_1_tvalid),
        .s_axis_1_tlast     (s_axis_1_tlast),
        // *** Custom IP port (optional) ***
        .computation_done   (computation_done),
        // *** AXIS master port ***
        .m_axis_tready      (m_axis_tready),
        .m_axis_tdata       (m_axis_tdata),
        .m_axis_tvalid      (m_axis_tvalid),
        .m_axis_tlast       (m_axis_tlast)
    );

endmodule
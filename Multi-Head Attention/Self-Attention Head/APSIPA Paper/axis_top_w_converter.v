// axis_top_w_converter.v
// Used as a wrapper for FPGA implementation

module axis_top_w_converter #(
    // Matrix Parameters
    parameter A_OUTER_DIMENSION = 16,
    parameter INNER_DIMENSION   = 10,
    parameter B_OUTER_DIMENSION = 12,

    // Elements Parameters 
    parameter WIDTH_A       = 16,
    parameter FRAC_WIDTH_A  = 8,
    parameter WIDTH_B       = 16,
    parameter FRAC_WIDTH_B  = 8,
    parameter WIDTH_OUT     = 16,
    parameter FRAC_WIDTH_OUT= 8,
    parameter BLOCK_SIZE    = 2,
    parameter CHUNK_SIZE    = BLOCK_SIZE * BLOCK_SIZE,
    parameter NUM_CORES_A   = 2,
    parameter NUM_CORES_B   = 2,
    parameter WIDTH_IN_A    = WIDTH_A * INNER_DIMENSION,
    parameter WIDTH_IN_B    = WIDTH_B * B_OUTER_DIMENSION,
    parameter WIDTH_OUT_C   = WIDTH_OUT * CHUNK_SIZE * NUM_CORES_A * NUM_CORES_B
) (
    input wire              aclk,
    input wire              aresetn,

    // *** AXIS Slave 0 port ***
    output wire                 s_axis_0_tready,
    input wire [WIDTH_IN_A-1:0] s_axis_0_tdata, // Input Data
    input wire                  s_axis_0_tvalid,
    input wire                  s_axis_0_tlast,
    // *** AXIS Slave 1 port ***
    output wire                 s_axis_1_tready,
    input wire [WIDTH_IN_B-1:0] s_axis_1_tdata, // Weight Data
    input wire                  s_axis_1_tvalid,
    input wire                  s_axis_1_tlast,

    // *** Custom IP port (optional) ***
    
    // *** AXIS master port ***
    input wire                  m_axis_tready,
    output wire [WIDTH_OUT_C-1:0]  m_axis_tdata, // Output Data
    output wire                 m_axis_tvalid,
    output wire                 m_axis_tlast
);

    top_w_converter #(
        .A_OUTER_DIMENSION(A_OUTER_DIMENSION),
        .INNER_DIMENSION(INNER_DIMENSION),
        .B_OUTER_DIMENSION(B_OUTER_DIMENSION),
        
        .WIDTH_A(WIDTH_A),
        .FRAC_WIDTH_A(FRAC_WIDTH_A),
        .WIDTH_B(WIDTH_B),
        .FRAC_WIDTH_B(FRAC_WIDTH_B),
        .WIDTH_OUT(WIDTH_OUT),
        .FRAC_WIDTH_OUT(FRAC_WIDTH_OUT),
        .NUM_CORES_A(NUM_CORES_A),
        .NUM_CORES_B(NUM_CORES_B)
    ) w_converter_dut (
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
        
        // *** AXIS master port ***
        .m_axis_tready      (m_axis_tready),
        .m_axis_tdata       (m_axis_tdata),
        .m_axis_tvalid      (m_axis_tvalid),
        .m_axis_tlast       (m_axis_tlast)
    );

endmodule
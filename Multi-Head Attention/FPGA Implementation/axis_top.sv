// AXI Stream Top Module
// Used to connect AXI DMA DIRECTLY with the top module

`timescale 1ns / 1ps
import linear_proj_pkg::*;
import self_attention_pkg::*;

module axis_top #(
    // DERIVED PARAMETERS
    localparam OUT_KEYS                     = WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A*NUM_CORES_B*TOTAL_MODULES;
    localparam NUMBER_OF_BUFFER_INSTANCES   = 1;
    localparam OUT_MULTIHEAD                = WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A_QKT_Vn*NUM_CORES_B_QKT_Vn*TOTAL_MODULES_LP_V

    // MANDATORY PARAMETERS
    parameter S0_WIDTH  = DATA_WIDTH_A, // Input width
    parameter S1_WIDTH  = DATA_WIDTH_A,
    parameter M0_WIDTH  = OUT_MULTIHEAD // Output width
    //parameter M1_WIDTH  = 64
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
    input wire [SN_WIDTH-1:0]   s_axis_1_tdata, // Input Data
    input wire                  s_axis_1_tvalid,
    input wire                  s_axis_1_tlast,

    // *** AXIS master port ***
    input wire                  m_axis_tready,
    output wire [M0_WIDTH-1:0]  m_axis_tdata, // Output Data
    output wire                 m_axis_tvalid,
    output wire                 m_axis_tlast
    );
    
    // ========================================= TOP CUSTOM IP =========================================
    parameter MEM_INIT_FILE_Q   = "mat_B_lp_bridge.mem";
    parameter MEM_INIT_FILE_K   = "mat_B_lp_bridge.mem";
    parameter MEM_INIT_FILE_V   = "mat_B_lp_bridge.mem";
    // DUT inputs
    logic in_mat_ena, in_mat_wea;
    logic [ADDR_WIDTH_A-1:0] in_mat_wr_addra;
    logic [DATA_WIDTH_A-1:0] in_mat_dina;

    logic in_mat_enb, in_mat_web;
    logic [ADDR_WIDTH_A-1:0] in_mat_wr_addrb;
    logic [DATA_WIDTH_A-1:0] in_mat_dinb;

    // DUT outputs
    /* These sections are not used
    logic [OUT_KEYS-1:0] out_Q_matrix [TOTAL_INPUT_W];
    logic [OUT_KEYS-1:0] out_K_matrix [TOTAL_INPUT_W]; 
    logic [OUT_KEYS-1:0] out_V_matrix [TOTAL_INPUT_W];
    logic linproj_valid, linproj_done;
    
    logic [(WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A_Qn_KnT*NUM_CORES_B_Qn_KnT*TOTAL_MODULES_LP_Q)-1:0]
        out_matmul_Qn_KnT [NUMBER_OF_BUFFER_INSTANCES][TOTAL_INPUT_W_Qn_KnT];
    logic out_Qn_KnT_valid;
    logic Qn_KnT_done;
    */
    
    logic [OUT_MULTIHEAD-1:0] out_matmul_QKT_Vn [NUMBER_OF_BUFFER_INSTANCES][TOTAL_INPUT_W_Qn_KnT];
    logic out_QKT_Vn_valid;
    logic QKT_Vn_done;

    multihead_attention #(
        .MEM_INIT_FILE_Q(MEM_INIT_FILE_Q),
        .MEM_INIT_FILE_K(MEM_INIT_FILE_K),
        .MEM_INIT_FILE_V(MEM_INIT_FILE_V),
        .OUT_KEYS(OUT_KEYS),
        .NUMBER_OF_BUFFER_INSTANCES(NUMBER_OF_BUFFER_INSTANCES)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),

        .in_mat_ena(in_mat_ena),
        .in_mat_wea(in_mat_wea),
        .in_mat_wr_addra(in_mat_wr_addra),
        .in_mat_dina(in_mat_dina),

        .in_mat_enb(in_mat_enb),
        .in_mat_web(in_mat_web),
        .in_mat_wr_addrb(in_mat_wr_addrb),
        .in_mat_dinb(in_mat_dinb),
        
        // Output
        /* These sections are not used
        .out_Q_matrix(out_Q_matrix),
        .out_K_matrix(out_K_matrix),
        .out_V_matrix(out_V_matrix),
        .linproj_valid(linproj_valid), 
        .linproj_done(linproj_done),
        
        .out_matmul_Qn_KnT(out_matmul_Qn_KnT),
        .out_Qn_KnT_valid(out_Qn_KnT_valid),
        .Qn_KnT_done(Qn_KnT_done),
        */
        
        .out_matmul_QKT_Vn(out_matmul_QKT_Vn),
        .out_QKT_Vn_valid(out_QKT_Vn_valid),
        .QKT_Vn_done(QKT_Vn_done)
        
        // Temporary output to see the intermediate results
        //.out_softmax_data(out_softmax_data),
        //.out_softmax_valid(out_softmax_valid)
        //.out_data_r2b(out_data_r2b)
        //.out_data_fifo(out_data_fifo)
    );
    
    
    // ========================================= OUTPUT FIFO =========================================
    // xpm_fifo_axis: AXI Stream FIFO
    // Xilinx Parameterized Macro, version 2018.3
    localparam FIFO_0_DEPTH                     = 2;  // Must be power of two
                                                        /* 
                                                        Technically, it could be just 1, because 
                                                        the larger the matrix, the longer the cycle 
                                                        between the output
                                                        */
    localparam FIFO_0_WR_RD_DATA_COUNT_WIDTH    = $clog2(FIFO_0_DEPTH) + 1; 
    localparam FIFO_0_TDATA_WIDTH               = OUT_MULTIHEAD; // Defines the width of the TDATA port, s_axis_tdata, and m_axis_tdata
    localparam FIFO_0_TKEEP_WIDTH               = FIFO_0_TDATA_WIDTH / 8;

    logic s2mm_ready;
    logic [OUT_MULTIHEAD-1:0] s2mm_data;
    logic s2mm_valid;
    logic s2mm_last;

    xpm_fifo_axis
    #(
        .CDC_SYNC_STAGES(2),                 // Default
        .CLOCKING_MODE("common_clock"),      // Default
        .ECC_MODE("no_ecc"),                 // Default
        .FIFO_DEPTH(FIFO_0_DEPTH),           // IMPORTANT, please change this
        .FIFO_MEMORY_TYPE("auto"),           // Default
        .PACKET_FIFO("false"),               // Default
        .PROG_EMPTY_THRESH(10),              // Default
        .PROG_FULL_THRESH(10),               // Default
        .RD_DATA_COUNT_WIDTH(FIFO_0_WR_RD_DATA_COUNT_WIDTH), // IMPORTANT, please change this
        .RELATED_CLOCKS(0),                  // Default
        .SIM_ASSERT_CHK(0),                  // Default
        .TDATA_WIDTH(FIFO_0_TDATA_WIDTH),    // IMPORTANT, please change this
        .TDEST_WIDTH(1),                     // Default
        .TID_WIDTH(1),                       // Default
        .TUSER_WIDTH(1),                     // Default
        .USE_ADV_FEATURES("0004"),           // Default, write data count
        .WR_DATA_COUNT_WIDTH(FIFO_0_WR_RD_DATA_COUNT_WIDTH) // IMPORTANT, please change this
    )
    xpm_fifo_axis_output
    (
        .almost_empty_axis(), 
        .almost_full_axis(), 
        .dbiterr_axis(), 
        .prog_empty_axis(), 
        .prog_full_axis(), 
        .rd_data_count_axis(), 
        .sbiterr_axis(), 
        .injectdbiterr_axis(1'b0), 
        .injectsbiterr_axis(1'b0), 
    
        .s_aclk(aclk), // aclk
        .m_aclk(aclk), // aclk
        .s_aresetn(aresetn), // aresetn
        
        .s_axis_tready(s2mm_ready), // ready    
        .s_axis_tdata(s2mm_data), // data
        .s_axis_tvalid(logic), // valid
        .s_axis_tdest(1'b0), 
        .s_axis_tid(1'b0), 
        .s_axis_tkeep({FIFO_0_TKEEP_WIDTH{1'b1}}), 
        .s_axis_tlast(s2mm_last),
        .s_axis_tstrb({FIFO_0_TKEEP_WIDTH{1'b1}}), 
        .s_axis_tuser(1'b0), 
        
        .m_axis_tready(m_axis_tready), // ready  
        .m_axis_tdata(m_axis_tdata), // data
        .m_axis_tvalid(m_axis_tvalid), // valid
        .m_axis_tdest(), 
        .m_axis_tid(), 
        .m_axis_tkeep(), 
        .m_axis_tlast(m_axis_tlast), 
        .m_axis_tstrb(), 
        .m_axis_tuser(),  
        
        .wr_data_count_axis() // data count
    );


    // ========================================= CONTROLLER =========================================
    // The controller goes here
    logic idx_out;  // Because TOTAL_INPUT_W_Qn_KnT == 2
    logic [$clog2((NUM_A_ELEMENTS + 1)/2)-1:0] idx_elements;

    always_ff @(aclk) begin
        if (~aresetn) begin
            idx_out     <= 0;
            // Input Mat A
            in_mat_ena      <= 0;
            in_mat_wea      <= 0;
            in_mat_wr_addra <= '0;
            in_mat_dina     <= '0;
            // Input Mat B
            in_mat_enb      <= 0;
            in_mat_web      <= 0;
            in_mat_wr_addrb <= '0;
            in_mat_dinb     <= '0;
        end else begin
            // ================== Write input BRAM ==================
            in_mat_ena  <= 1; 
            in_mat_enb  <= 1;
            in_mat_wea  <= 1; 
            in_mat_web  <= 1;

            if (in_mat_wea) begin
                // Port A: even
                in_mat_wr_addra     <= 2*i;

                // Port B: odd
                if (in_mat_web) begin
                    if (2*i + 1 < NUM_A_ELEMENTS) begin
                        in_mat_wr_addrb <= 2*i + 1;
                    end else begin
                        in_mat_wr_addrb <= NUM_A_ELEMENTS - 1;
                    end
                end
                idx_elements    <= idx_elements + 1;
            end


            // ================== Write input BRAM done ==================
            if (idx_elements == ((NUM_A_ELEMENTS + 1)/2) - 1) begin
                in_mat_ena  <= 0; 
                in_mat_enb  <= 0;
                in_mat_wea  <= 0; 
                in_mat_web  <= 0;
            end

            // ================== Output FIFO takes the output fromt he multihead attention ==================
            if (out_QKT_Vn_valid) begin
                if (~idx_out) begin
                    idx_out <= 1;
                end
            end else begin
                idx_out <= 0;
            end
            s2mm_data   <= out_matmul_QKT_Vn[0][idx_out];
        end
    end


endmodule
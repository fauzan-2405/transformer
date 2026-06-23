// top_wo_converter.sv
// Used as a top module for converter that does not use the r2b_converter

module top_wo_converter #(
    // Matrix Parameters
    parameter A_OUTER_DIMENSION = 16,
    parameter INNER_DIMENSION   = 10,
    parameter B_OUTER_DIMENSION = 12,

    // Elements Parameters 
    parameter WIDTH_A       = 16,
    parameter WIDTH_B       = 16,
    parameter WIDTH_OUT     = 16,
    parameter BLOCK_SIZE    = 2,
    parameter CHUNK_SIZE    = BLOCK_SIZE * BLOCK_SIZE,
    parameter NUM_CORES_A   = 2,
    parameter NUM_CORES_B   = 2,
    parameter WIDTH_IN_A    = WIDTH_A * CHUNK_SIZE * NUM_CORES_A,
    parameter WIDTH_IN_B    = WIDTH_B * CHUNK_SIZE * NUM_CORES_B,
    parameter WIDTH_OUT_C   = WIDTH_OUT * CHUNK_SIZE * NUM_CORES_A * NUM_CORES_B,
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
    output wire                 computation_done,
    
    // *** AXIS master port ***
    input wire                  m_axis_tready,
    output wire [WIDTH_OUT_C-1:0]  m_axis_tdata, // Output Data
    output wire                 m_axis_tvalid,
    output wire                 m_axis_tlast
);

    // ========================================= INPUT BRAM =========================================
    parameter MEMORY_SIZE_A = INNER_DIMENSION*A_OUTER_DIMENSION*WIDTH_A;
    parameter DATA_WIDTH_A  = WIDTH_A*CHUNK_SIZE*NUM_CORES_A;
    parameter int ADDR_WIDTH_A = $clog2(MEMORY_SIZE_A/DATA_WIDTH_A);

    logic in_mat_ena, in_mat_enb;
    logic in_mat_wea, in_mat_web;
    logic [ADDR_WIDTH_A-1:0] in_mat_addra, in_mat_addrb;
    logic [DATA_WIDTH_A-1:0] in_mat_doutb;
    
    xpm_memory_tdpram
    #(
        // Common module parameters
        .MEMORY_SIZE(MEMORY_SIZE_A),           // DECIMAL, 
        .MEMORY_PRIMITIVE("auto"),           // String
        .CLOCKING_MODE("common_clock"),      // String, "common_clock"
        .MEMORY_INIT_FILE("none"),           // String
        .MEMORY_INIT_PARAM("0"),             // String      
        .USE_MEM_INIT(1),                    // DECIMAL
        .WAKEUP_TIME("disable_sleep"),       // String
        .MESSAGE_CONTROL(0),                 // DECIMAL
        .AUTO_SLEEP_TIME(0),                 // DECIMAL          
        .ECC_MODE("no_ecc"),                 // String
        .MEMORY_OPTIMIZATION("true"),        // String              
        .USE_EMBEDDED_CONSTRAINT(0),         // DECIMAL
        
        // Port A module parameters
        .WRITE_DATA_WIDTH_A(DATA_WIDTH_A), // DECIMAL, varying based on the matrix size
        .READ_DATA_WIDTH_A(DATA_WIDTH_A),  // DECIMAL, varying based on the matrix size
        .BYTE_WRITE_WIDTH_A(DATA_WIDTH_A), // DECIMAL, how many bytes in WRITE_DATA_WIDTH_A, use $clog2 maybe?
        .ADDR_WIDTH_A(ADDR_WIDTH_A),         // DECIMAL, clog2(MEMORY_SIZE_A/WRITE_DATA_WIDTH_A)
        .READ_RESET_VALUE_A("0"),            // String
        .READ_LATENCY_A(1),                  // DECIMAL
        .WRITE_MODE_A("write_first"),        // String
        .RST_MODE_A("SYNC"),                 // String
        
        // Port B module parameters  
        .WRITE_DATA_WIDTH_B(DATA_WIDTH_A), // DECIMAL, varying based on the matrix size
        .READ_DATA_WIDTH_B(DATA_WIDTH_A),  // DECIMAL, varying based on the matrix size
        .BYTE_WRITE_WIDTH_B(DATA_WIDTH_A), // DECIMAL, how many bytes in WRITE_DATA_WIDTH_A
        .ADDR_WIDTH_B(ADDR_WIDTH_A),         // DECIMAL, clog2(MEMORY_SIZE/WRITE_DATA_WIDTH_A)
        .READ_RESET_VALUE_B("0"),            // String
        .READ_LATENCY_B(1),                  // DECIMAL
        .WRITE_MODE_B("write_first"),        // String
        .RST_MODE_B("SYNC")                  // String
    )
    xpm_memory_tdpram_in_mat
    (        
        // Port A module ports
        .clka(clk),
        .rsta(~rst_n),
        .ena(in_mat_ena),
        .wea(in_mat_wea),
        .addra(in_mat_addra), 
        .dina(s_axis_0_tdata),
        .douta(),
        
        // Port B module ports
        .clkb(clk),
        .rstb(~rst_n),
        .enb(in_mat_enb),
        .web(), 
        .addrb(in_mat_addrb), 
        .dinb(),
        .doutb(in_mat_doutb)
    );


    // ========================================= WEIGHT BRAM =========================================
    parameter MEMORY_SIZE_B = INNER_DIMENSION*B_OUTER_DIMENSION*WIDTH_B;
    parameter DATA_WIDTH_B  = WIDTH_B*CHUNK_SIZE*NUM_CORES_B;
    parameter int ADDR_WIDTH_B = $clog2(MEMORY_SIZE_B/DATA_WIDTH_B);

    logic we_mat_ena, we_mat_enb;
    logic we_mat_wea, we_mat_web;
    logic [ADDR_WIDTH_A-1:0] we_mat_addra, we_mat_addrb;
    logic [DATA_WIDTH_A-1:0] we_mat_doutb;

    xpm_memory_tdpram
    #(
        // Common module parameters
        .MEMORY_SIZE(MEMORY_SIZE_B),           // DECIMAL, 
        .MEMORY_PRIMITIVE("auto"),           // String
        .CLOCKING_MODE("common_clock"),      // String, "common_clock"
        .MEMORY_INIT_FILE("none"),           // String
        .MEMORY_INIT_PARAM("0"),             // String      
        .USE_MEM_INIT(1),                    // DECIMAL
        .WAKEUP_TIME("disable_sleep"),       // String
        .MESSAGE_CONTROL(0),                 // DECIMAL
        .AUTO_SLEEP_TIME(0),                 // DECIMAL          
        .ECC_MODE("no_ecc"),                 // String
        .MEMORY_OPTIMIZATION("true"),        // String              
        .USE_EMBEDDED_CONSTRAINT(0),         // DECIMAL
        
        // Port A module parameters
        .WRITE_DATA_WIDTH_A(DATA_WIDTH_B), // DECIMAL, varying based on the matrix size
        .READ_DATA_WIDTH_A(DATA_WIDTH_B),  // DECIMAL, varying based on the matrix size
        .BYTE_WRITE_WIDTH_A(DATA_WIDTH_B), // DECIMAL, how many bytes in WRITE_DATA_WIDTH_A, use $clog2 maybe?
        .ADDR_WIDTH_A(ADDR_WIDTH_B),         // DECIMAL, clog2(MEMORY_SIZE_A/WRITE_DATA_WIDTH_A)
        .READ_RESET_VALUE_A("0"),            // String
        .READ_LATENCY_A(1),                  // DECIMAL
        .WRITE_MODE_A("write_first"),        // String
        .RST_MODE_A("SYNC"),                 // String
        
        // Port B module parameters  
        .WRITE_DATA_WIDTH_B(DATA_WIDTH_B), // DECIMAL, varying based on the matrix size
        .READ_DATA_WIDTH_B(DATA_WIDTH_B),  // DECIMAL, varying based on the matrix size
        .BYTE_WRITE_WIDTH_B(DATA_WIDTH_B), // DECIMAL, how many bytes in WRITE_DATA_WIDTH_A
        .ADDR_WIDTH_B(ADDR_WIDTH_B),         // DECIMAL, clog2(MEMORY_SIZE/WRITE_DATA_WIDTH_A)
        .READ_RESET_VALUE_B("0"),            // String
        .READ_LATENCY_B(1),                  // DECIMAL
        .WRITE_MODE_B("write_first"),        // String
        .RST_MODE_B("SYNC")                  // String
    )
    xpm_memory_tdpram_we_mat
    (        
        // Port A module ports
        .clka(clk),
        .rsta(~rst_n),
        .ena(we_mat_ena),
        .wea(we_mat_wea),
        .addra(we_mat_addra), 
        .dina(s_axis_1_tdata),
        .douta(),
        
        // Port B module ports
        .clkb(clk),
        .rstb(~rst_n),
        .enb(we_mat_enb),
        .web(), 
        .addrb(we_mat_addrb), 
        .dinb(),
        .doutb(we_mat_doutb)
    );

    // ========================================= OUTPUT FIFO =========================================
    // xpm_fifo_axis: AXI Stream FIFO
    // Xilinx Parameterized Macro, version 2018.3
    localparam FIFO_0_DEPTH                     = 16;  // Must be power of two
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
        .s_axis_tvalid(s2mm_valid), // valid
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
    logic idx_out_reg;  // Delayed version

    // Combinational controller
    assign s_axis_0_tready  = in_mat_ena;
    assign s_axis_1_tready  = in_mat_enb;
    assign in_mat_wea       = s_axis_0_tvalid;
    assign in_mat_web       = s_axis_1_tvalid;
    assign in_mat_dina      = s_axis_0_tdata;
    assign in_mat_dinb      = s_axis_1_tdata;
    assign computation_done = QKT_Vn_done;
    assign s2mm_valid       = (idx_out_reg || idx_out);
    assign s2mm_last        = QKT_Vn_done && idx_out_reg;

    // Sequential controller
    always_ff @(posedge aclk) begin
        if (~aresetn) begin
            idx_out         <= 0;
            idx_out_reg     <= 0;
            in_mat_ena      <= 0;
            in_mat_enb      <= 0;
            in_mat_wr_addra <= '0;
            in_mat_wr_addrb <= 1;

        end else begin
            // ================== Write input BRAM ==================
            
            if (~s_axis_0_tlast) in_mat_ena  <= 1;
            if (~s_axis_1_tlast) in_mat_enb  <= 1;
            if (in_mat_wea) begin
                // Port A: even
                in_mat_wr_addra     <= in_mat_wr_addra + 2;
            end
            
            if (in_mat_web) begin
                // Port B: odd
                in_mat_wr_addrb     <= in_mat_wr_addrb + 2;
            end

            // ================== Output FIFO takes the output fromt he multihead attention ==================   
            idx_out_reg     <= idx_out;
                     
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
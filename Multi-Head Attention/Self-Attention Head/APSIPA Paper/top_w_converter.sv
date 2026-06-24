// top_w_converter.sv
// Used as a top module for converter that does not use the r2b_converter

module top_w_converter #(
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
    localparam int NUM_A_ELEMENTS = ((A_OUTER_DIMENSION/BLOCK_SIZE)*(INNER_DIMENSION/BLOCK_SIZE))/(NUM_CORES_A); // Total elements of Input if we converted the inputs based on the NUM_CORES, in tb_multihead_attention.sv
    localparam int NUM_B_ELEMENTS = ((B_OUTER_DIMENSION/BLOCK_SIZE)*(INNER_DIMENSION/BLOCK_SIZE))/(NUM_CORES_B);

    localparam int ROW_SIZE_MAT_C = A_OUTER_DIMENSION / (BLOCK_SIZE * NUM_CORES_A);  
    localparam int COL_SIZE_MAT_C = B_OUTER_DIMENSION / (BLOCK_SIZE * NUM_CORES_B); 
    localparam int MAX_FLAG = (ROW_SIZE_MAT_C * COL_SIZE_MAT_C);

    // ========================================= INPUT BRAM =========================================
    localparam MEMORY_SIZE_A0   = INNER_DIMENSION*A_OUTER_DIMENSION*WIDTH_A;
    localparam DATA_WIDTH_A0    = WIDTH_IN_A;
    localparam int ADDR_WIDTH_A0= $clog2(MEMORY_SIZE_A0/DATA_WIDTH_A0);

    logic in_mat_en_fill;
    logic in_mat_wea_fill;
    logic [ADDR_WIDTH_A0-1:0] in_mat_addra_fill;
    logic [ADDR_WIDTH_A0-1:0] in_mat_addrb_fill;
    logic [DATA_WIDTH_A0-1:0] in_mat_doutb_fill;
    
    xpm_memory_sdpram
    #(
        // Common module parameters
        .MEMORY_SIZE(MEMORY_SIZE_A0),           // DECIMAL, 
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
        
        // Port A (write)
        .WRITE_DATA_WIDTH_A(DATA_WIDTH_A0), // DECIMAL, varying based on the matrix size
        .BYTE_WRITE_WIDTH_A(DATA_WIDTH_A0), // DECIMAL, how many bytes in WRITE_DATA_WIDTH_A, use $clog2 maybe?
        .ADDR_WIDTH_A(ADDR_WIDTH_A0),         // DECIMAL, clog2(MEMORY_SIZE_A/WRITE_DATA_WIDTH_A)
        
        // Port B module parameters  
        .READ_DATA_WIDTH_B(DATA_WIDTH_A0),  // DECIMAL, varying based on the matrix size
        .ADDR_WIDTH_B(ADDR_WIDTH_A0),         // DECIMAL, clog2(MEMORY_SIZE/WRITE_DATA_WIDTH_A)
        .READ_RESET_VALUE_B("0"),            // String
        .READ_LATENCY_B(1),                  // DECIMAL
        .RST_MODE_B("SYNC")                  // String
    )
    xpm_memory_sdpram_in_mat_fill
    (        
        // Write ports
        .clka(aclk),
        .ena(in_mat_en_fill),
        .wea(in_mat_wea_fill),
        .addra(in_mat_addra_fill), 
        .dina(s_axis_0_tdata),
        
        // Port B module ports
        .clkb(aclk),
        .rstb(~aresetn),
        .enb(in_mat_en_fill),
        .addrb(in_mat_addrb_fill),
        .doutb(in_mat_doutb_fill)
    );


    // ========================================= WEIGHT BRAM =========================================
    localparam MEMORY_SIZE_B0   = INNER_DIMENSION*B_OUTER_DIMENSION*WIDTH_B;
    localparam DATA_WIDTH_B0    = WIDTH_IN_B;
    localparam int ADDR_WIDTH_B0= $clog2(MEMORY_SIZE_B0/DATA_WIDTH_B0);

    logic we_mat_en_fill;
    logic we_mat_wea_fill;
    logic [ADDR_WIDTH_B0-1:0] we_mat_addra_fill;
    logic [ADDR_WIDTH_B0-1:0] we_mat_addrb_fill;
    logic [DATA_WIDTH_B0-1:0] we_mat_doutb_fill;

    xpm_memory_sdpram
    #(
        // Common module parameters
        .MEMORY_SIZE(MEMORY_SIZE_B0),           // DECIMAL, 
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
        .WRITE_DATA_WIDTH_A(DATA_WIDTH_B0), // DECIMAL, varying based on the matrix size
        .BYTE_WRITE_WIDTH_A(DATA_WIDTH_B0), // DECIMAL, how many bytes in WRITE_DATA_WIDTH_A, use $clog2 maybe?
        .ADDR_WIDTH_A(ADDR_WIDTH_B0),         // DECIMAL, clog2(MEMORY_SIZE_A/WRITE_DATA_WIDTH_A)
        
        // Port B module parameters  
        .READ_DATA_WIDTH_B(DATA_WIDTH_B0),  // DECIMAL, varying based on the matrix size
        .ADDR_WIDTH_B(ADDR_WIDTH_B0),         // DECIMAL, clog2(MEMORY_SIZE/WRITE_DATA_WIDTH_A)
        .READ_RESET_VALUE_B("0"),            // String
        .READ_LATENCY_B(1),                  // DECIMAL
        .RST_MODE_B("SYNC")                  // String
    )
    xpm_memory_tdpram_we_mat_fill
    (        
        // Write ports
        .clka(aclk),
        .ena(we_mat_en_fill),
        .wea(we_mat_wea_fill),
        .addra(we_mat_addra_fill), 
        .dina(s_axis_1_tdata),
        
        // Port B module ports
        .clkb(aclk),
        .rstb(~aresetn),
        .enb(we_mat_en_fill),
        .addrb(we_mat_addrb_mux),
        .doutb(we_mat_doutb_fill)
    );

    // ========================================= R2B CONVERTER V =========================================
    logic en_r2b_v;
    logic in_valid_r2b_v;
    logic out_valid_r2b_v;
    logic done_r2b_v;
    logic [(WIDTH_A * CHUNK_SIZE * NUM_CORES_A)- 1:0] out_data_r2b_v;

    r2b_converter_v #(
        .WIDTH(WIDTH_A),
        .FRAC_WIDTH(FRAC_WIDTH_A),
        .ROW(A_OUTER_DIMENSION),
        .COL(INNER_DIMENSION),
        .NUM_CORES_V(NUM_CORES_A)
    ) r2b_converter_v_unit (
        .clk(aclk),
        .rst_n(aresetn),
        .en(en_r2b_v),
        .in_valid(in_valid_r2b_v),
        .in_data(in_mat_doutb_fill),
        .slice_done(),
        .output_ready(out_valid_r2b_v),
        .slice_last(),
        .buffer_done(done_r2b_v),
        .out_data(out_data_r2b_v)
    );

    // ========================================= R2B CONVERTER H =========================================
    logic en_r2b_h;
    logic in_valid_r2b_h;
    logic out_valid_r2b_h;
    logic done_r2b_h;
    logic [(WIDTH_B * CHUNK_SIZE * NUM_CORES_B)- 1:0] out_data_r2b_h;

    r2b_converter_h #(
        .WIDTH(WIDTH_B),
        .FRAC_WIDTH(FRAC_WIDTH_B),
        .ROW(INNER_DIMENSION),
        .COL(B_OUTER_DIMENSION),
        .NUM_CORES_V(NUM_CORES_B)
    ) r2b_converter_h_unit (
        .clk(aclk),
        .rst_n(aresetn),
        .en(en_r2b_h),
        .in_valid(in_valid_r2b_h),
        .in_data(we_mat_doutb_fill),
        .slice_done(),
        .output_ready(out_valid_r2b_h),
        .buffer_done(done_r2b_h),
        .out_data(out_data_r2b_h)
    );


    // ========================================= WB PUT BRAM =========================================
    localparam MEMORY_SIZE_A1   = INNER_DIMENSION*A_OUTER_DIMENSION*WIDTH_A;
    localparam DATA_WIDTH_A1    = WIDTH_A * CHUNK_SIZE * NUM_CORES_A;
    localparam int ADDR_WIDTH_A1= $clog2(MEMORY_SIZE_A1/DATA_WIDTH_A1);

    logic in_mat_en_wb;
    logic in_mat_wea_wb;
    logic [ADDR_WIDTH_A1-1:0] in_mat_addra_wb;
    logic [ADDR_WIDTH_A1-1:0] in_mat_addrb_wb;
    logic [DATA_WIDTH_A1-1:0] in_mat_doutb_wb;
    
    xpm_memory_sdpram
    #(
        // Common module parameters
        .MEMORY_SIZE(MEMORY_SIZE_A1),           // DECIMAL, 
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
        
        // Port A (write)
        .WRITE_DATA_WIDTH_A(DATA_WIDTH_A1), // DECIMAL, varying based on the matrix size
        .BYTE_WRITE_WIDTH_A(DATA_WIDTH_A1), // DECIMAL, how many bytes in WRITE_DATA_WIDTH_A, use $clog2 maybe?
        .ADDR_WIDTH_A(ADDR_WIDTH_A1),         // DECIMAL, clog2(MEMORY_SIZE_A/WRITE_DATA_WIDTH_A)
        
        // Port B module parameters  
        .READ_DATA_WIDTH_B(DATA_WIDTH_A1),  // DECIMAL, varying based on the matrix size
        .ADDR_WIDTH_B(ADDR_WIDTH_A1),         // DECIMAL, clog2(MEMORY_SIZE/WRITE_DATA_WIDTH_A)
        .READ_RESET_VALUE_B("0"),            // String
        .READ_LATENCY_B(1),                  // DECIMAL
        .RST_MODE_B("SYNC")                  // String
    )
    xpm_memory_sdpram_in_mat_wb
    (        
        // Write ports
        .clka(aclk),
        .ena(in_mat_en_wb),
        .wea(in_mat_wea_wb),
        .addra(in_mat_addra_wb), 
        .dina(),
        
        // Port B module ports
        .clkb(aclk),
        .rstb(~aresetn),
        .enb(in_mat_en_wb),
        .addrb(in_mat_addrb_wb),
        .doutb(in_mat_doutb_wb)
    );

    // ========================================= WB WEIGHT BRAM =========================================
    localparam MEMORY_SIZE_B1   = INNER_DIMENSION*B_OUTER_DIMENSION*WIDTH_B;
    localparam DATA_WIDTH_B1    = WIDTH_B * CHUNK_SIZE * NUM_CORES_B;
    localparam int ADDR_WIDTH_B1= $clog2(MEMORY_SIZE_B1/DATA_WIDTH_B1);

    logic we_mat_en_wb;
    logic we_mat_wea_wb;
    logic [ADDR_WIDTH_B1-1:0] we_mat_addra_wb;
    logic [ADDR_WIDTH_B1-1:0] we_mat_addrb_wb;
    logic [DATA_WIDTH_B1-1:0] we_mat_doutb_wb;

    xpm_memory_sdpram
    #(
        // Common module parameters
        .MEMORY_SIZE(MEMORY_SIZE_B1),           // DECIMAL, 
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
        .WRITE_DATA_WIDTH_A(DATA_WIDTH_B1), // DECIMAL, varying based on the matrix size
        .BYTE_WRITE_WIDTH_A(DATA_WIDTH_B1), // DECIMAL, how many bytes in WRITE_DATA_WIDTH_A, use $clog2 maybe?
        .ADDR_WIDTH_A(ADDR_WIDTH_B1),         // DECIMAL, clog2(MEMORY_SIZE_A/WRITE_DATA_WIDTH_A)
        
        // Port B module parameters  
        .READ_DATA_WIDTH_B(DATA_WIDTH_B1),  // DECIMAL, varying based on the matrix size
        .ADDR_WIDTH_B(ADDR_WIDTH_B1),         // DECIMAL, clog2(MEMORY_SIZE/WRITE_DATA_WIDTH_A)
        .READ_RESET_VALUE_B("0"),            // String
        .READ_LATENCY_B(1),                  // DECIMAL
        .RST_MODE_B("SYNC")                  // String
    )
    xpm_memory_tdpram_we_mat_wb
    (        
        // Write ports
        .clka(aclk),
        .ena(we_mat_en_wb),
        .wea(we_mat_wea_wb),
        .addra(we_mat_addra_wb), 
        .dina(),
        
        // Port B module ports
        .clkb(aclk),
        .rstb(~aresetn),
        .enb(we_mat_en_wb),
        .addrb(we_mat_addrb_wb),
        .doutb(we_mat_doutb_wb)
    );

    // ========================================= MATMUL MODULE =========================================
    logic acc_done;
    logic sys_finish;
    logic [WIDTH_OUT_C-1:0] out_matmul;
    logic en_module; // Toggle to ALWAYS HIGH after both BRAMs are filled
    logic internal_reset_acc, internal_rst_n;

    matmul_module #(
        .INNER_DIMENSION(INNER_DIMENSION),
        .CHUNK_SIZE(CHUNK_SIZE),
        .WIDTH_A(WIDTH_A),
        .FRAC_WIDTH_A(FRAC_WIDTH_A),
        .WIDTH_B(WIDTH_B),
        .FRAC_WIDTH_B(FRAC_WIDTH_B),
        .WIDTH_OUT(WIDTH_OUT),
        .FRAC_WIDTH_OUT(FRAC_WIDTH_OUT),
        .NUM_CORES_A(NUM_CORES_A),
        .NUM_CORES_B(NUM_CORES_B)
    ) matmul_module_inst (
        .clk(aclk), 
        .en(en_module), 
        .rst_n(internal_rst_n), 
        .reset_acc(internal_reset_acc),
        .input_w(in_mat_doutb_wb), 
        .input_n(we_mat_doutb_wb), // The first one is the MSB
        .accumulator_done(acc_done), 
        .systolic_finish(sys_finish),
        .out_top(out_matmul) // The first one is the MSB
    );

    // ========================================= OUTPUT FIFO =========================================
    // xpm_fifo_axis: AXI Stream FIFO
    // Xilinx Parameterized Macro, version 2018.3
    localparam FIFO_0_DEPTH                     = (MAX_FLAG < 16) ? 16 : MAX_FLAG;  // Must be power of two
                                                        /* 
                                                        Technically, it could be just 1, because 
                                                        the larger the matrix, the longer the cycle 
                                                        between the output
                                                        */
    localparam FIFO_0_WR_RD_DATA_COUNT_WIDTH    = $clog2(FIFO_0_DEPTH) + 1; 
    localparam FIFO_0_TDATA_WIDTH               = WIDTH_OUT_C; // Defines the width of the TDATA port, s_axis_tdata, and m_axis_tdata
    localparam FIFO_0_TKEEP_WIDTH               = FIFO_0_TDATA_WIDTH / 8;

    logic s2mm_ready;
    logic [WIDTH_OUT_C-1:0] s2mm_data;
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
    logic acc_done_rising;
    logic acc_done_d;
    assign acc_done_rising = ~acc_done_d & acc_done;
    logic [WIDTH_OUT-1:0] counter, counter_row, counter_col, flag;
    logic counter_acc_done, matmul_done;
    logic [2:0] state_reg, state_next;

    // Combinational controller
    assign in_mat_en_fill   = (state_reg == STATE_IDLE) || (state_reg == STATE_FILL) || (state_reg == STATE_CONV);
    assign we_mat_en_fill   = (state_reg == STATE_IDLE) || (state_reg == STATE_FILL) || (state_reg == STATE_CONV);
    assign in_mat_wea_fill  = s_axis_0_tvalid;
    assign we_mat_wea_fill  = s_axis_1_tvalid;

    assign s_axis_0_tready  = in_mat_en_fill;
    assign s_axis_1_tready  = we_mat_en_fill;

    assign en_r2b_v         = (state_reg == STATE_CONV);
    assign en_r2b_h         = (state_reg == STATE_CONV);
    assign in_valid_r2b_v   = (state_reg == STATE_CONV) && (in_mat_addrb_fill < A_OUTER_DIMENSION-1);
    assign in_valid_r2b_h   = (state_reg == STATE_CONV) && (we_mat_addrb_fill < INNER_DIMENSION-1);

    assign in_mat_en_wb     = (state_reg == STATE_CONV);
    assign we_mat_en_wb     = (state_reg == STATE_CONV);    
    assign in_mat_wea_wb    = (state_reg == STATE_CONV) && (out_valid_r2b_v);
    assign we_mat_wea_wb    = (state_reg == STATE_CONV) && (out_valid_r2b_h);

    assign s2mm_data        = out_matmul;
    assign s2mm_valid       = (counter_acc_done);
    assign s2mm_last        = counter_acc_done && matmul_done;

    localparam STATE_IDLE   = 3'd0;
    localparam STATE_FILL   = 3'd1;
    localparam STATE_CONV   = 3'd2;
    localparam STATE_COMP   = 3'd4;
    localparam STATE_DONE   = 3'd5;

    always_comb begin
        case(state_reg)
            STATE_IDLE: 
            begin
                state_next  = (!aresetn) ? STATE_FILL : STATE_IDLE;
            end

            STATE_FILL:
            begin
                state_next  = ((in_mat_addra_fill >= A_OUTER_DIMENSION-1) && (we_mat_addra_fill >= INNER_DIMENSION-1)) ? STATE_CONV : STATE_FILL;
            end

            STATE_CONV: // Convert and Fill the WB (write back) BRAM
            begin
                state_next  = ((in_mat_addra_wb >= NUM_A_ELEMENTS - 1) && (we_mat_addra_wb >= NUM_B_ELEMENTS)) ? STATE_COMP : STATE_CONV;
            end

            STATE_COMP: 
            begin
                state_next  = (matmul_done) ? STATE_DONE : STATE_COMP;
            end

            STATE_DONE:
            begin
                state_next  = STATE_IDLE;
            end

            default: 
            begin
                state_next  = STATE_IDLE;
            end
        endcase
    end

    // Sequential controller
    always_ff @(posedge aclk) begin
        if (~aresetn) begin
            state_reg           <= STATE_IDLE;
            in_mat_addra_fill   <= 0;
            in_mat_addrb_fill   <= 0;
            we_mat_addra_fill   <= 0;
            we_mat_addrb_fill   <= 0;

            in_mat_addra_wb     <= 0;
            in_mat_addrb_wb     <= 0;
            we_mat_addra_wb     <= 0;
            we_mat_addrb_wb     <= 0;
            
            en_module       <= 0;
            acc_done_d      <= 0;
            internal_rst_n      <= 0;
            internal_reset_acc  <= 0;
            counter         <= 0;
            counter_row     <= 0;
            counter_col     <= 0;
            counter_acc_done <= 0;
            flag            <= 0;
            matmul_done     <= 0;
        end else begin
            state_reg   <= state_next;
            acc_done_d  <= acc_done;
            counter_acc_done <= 0;
            
            if (state_reg == STATE_FILL) begin
                // ================== Write Input & Weight BRAM ==================
                if (in_mat_wea_fill) begin
                    in_mat_addra_fill   <= in_mat_addra_fill + 1;
                end

                if (we_mat_wea_fill) begin
                    we_mat_addra_fill   <= we_mat_addra_fill + 1;
                end
            end 
            else if (state_reg == STATE_CONV) begin
                // ================== Convert the Input & Weight from BRAM ==================
                if (in_mat_addrb_fill < A_OUTER_DIMENSION) begin
                    in_mat_addrb_fill   <= in_mat_addrb_fill + 1;
                end
                if (we_mat_addrb_fill < INNER_DIMENSION) begin
                    we_mat_addrb_fill   <= we_mat_addrb_fill + 1;
                end

                if (in_mat_wea_wb) begin
                    in_mat_addra_wb <= in_mat_addra_wb + 1;
                end
                if (we_mat_wea_wb) begin
                    we_mat_addra_wb <= we_mat_addra_wb + 1;
                end
            end
            else if (state_reg == STATE_COMP) begin
                // Port A & B Controller
                en_module <= 1'b1;// Control write enable of each BRAMs for both ports

                // Internal Reset Control
                if (en_module) begin
                    internal_rst_n  <= ~sys_finish;
                end

                if (sys_finish) begin
                    internal_reset_acc <= ~acc_done;
                end

                // Counter Update
                if (sys_finish) begin
                    // counter indicates the matrix C element iteration
                    if (counter == ((INNER_DIMENSION/BLOCK_SIZE) - 1)) begin 
                        counter     <= 0;
                    end
                    else begin
                        counter     <= counter + 1;
                    end
                    // Address controller
                    in_mat_addrb    <= counter + (INNER_DIMENSION/BLOCK_SIZE)*counter_row;
                    we_mat_addrb    <= counter + (INNER_DIMENSION/BLOCK_SIZE)*counter_col;
                end

                // Column/Row Update
                if (acc_done_rising) begin
                    // counter_row indicates the i-th row of the matrix C that we are working right now
                    // counter_col indicates the i-th column of the matrix C that we are working right now

                    // Check if we already at the end of the MAT C column
                    if (counter_col == (COL_SIZE_MAT_C - 1)) begin
                        counter_col <= 0;
                        counter_row <= counter_row + 1;
                    end else begin
                        counter_col <= counter_col + 1;
                    end

                    counter_acc_done <= 1;

                    // Flag assigning for 'done' variable
                    if (flag != MAX_FLAG) begin
                        flag <= flag + 1;   
                    end else if (flag >= MAX_FLAG - 1)
                        matmul_done <= 1;
                end
            end

            // ================== Output FIFO takes the output fromt he multihead attention ==================   
        end
    end
  
endmodule
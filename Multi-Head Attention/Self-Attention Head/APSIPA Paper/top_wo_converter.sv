// top_wo_converter.sv
// Used as a top module for converter that does not use the r2b_converter

module top_wo_converter #(
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
    parameter WIDTH_IN_A    = WIDTH_A * CHUNK_SIZE * NUM_CORES_A,
    parameter WIDTH_IN_B    = WIDTH_B * CHUNK_SIZE * NUM_CORES_B,
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
    localparam MEMORY_SIZE_A = INNER_DIMENSION*A_OUTER_DIMENSION*WIDTH_A;
    localparam DATA_WIDTH_A  = WIDTH_A*CHUNK_SIZE*NUM_CORES_A;
    localparam int ADDR_WIDTH_A = $clog2(MEMORY_SIZE_A/DATA_WIDTH_A);

    logic in_mat_en;
    logic in_mat_wea;
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
        .clka(aclk),
        .rsta(~aresetn),
        .ena(in_mat_en),
        .wea(in_mat_wea),
        .addra(in_mat_addra), 
        .dina(s_axis_0_tdata),
        .douta(),
        
        // Port B module ports
        .clkb(aclk),
        .rstb(~aresetn),
        .enb(in_mat_en),
        .web(1'b0), 
        .addrb(in_mat_addrb), 
        .dinb(1'b0),
        .doutb(in_mat_doutb)
    );


    // ========================================= WEIGHT BRAM =========================================
    localparam MEMORY_SIZE_B = INNER_DIMENSION*B_OUTER_DIMENSION*WIDTH_B;
    localparam DATA_WIDTH_B  = WIDTH_B*CHUNK_SIZE*NUM_CORES_B;
    localparam int ADDR_WIDTH_B = $clog2(MEMORY_SIZE_B/DATA_WIDTH_B);

    logic we_mat_en;
    logic we_mat_wea;
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
        .clka(aclk),
        .rsta(~aresetn),
        .ena(we_mat_en),
        .wea(we_mat_wea),
        .addra(we_mat_addra), 
        .dina(s_axis_1_tdata),
        .douta(),
        
        // Port B module ports
        .clkb(aclk),
        .rstb(~aresetn),
        .enb(we_mat_en),
        .web(1'b0), 
        .addrb(we_mat_addrb), 
        .dinb(1'b0),
        .doutb(we_mat_doutb)
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
        .input_w(in_mat_doutb), 
        .input_n(we_mat_doutb), // The first one is the MSB
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

    // Combinational controller
    assign s_axis_0_tready  = in_mat_en;
    assign s_axis_1_tready  = we_mat_en;
    assign in_mat_wea       = s_axis_0_tvalid;
    assign we_mat_wea       = s_axis_1_tvalid;
    assign s2mm_data        = out_matmul;
    assign s2mm_valid       = (counter_acc_done);
    assign s2mm_last        = counter_acc_done && matmul_done;

    // Sequential controller
    always_ff @(posedge aclk) begin
        if (~aresetn) begin
            in_mat_en       <= 0;
            we_mat_en       <= 0;
            in_mat_addra    <= 0;
            in_mat_addrb    <= 0;
            we_mat_addra    <= 0;
            we_mat_addrb    <= 0;
            
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
            // ================== Write Input & Weight BRAM ==================
            if (m_axis_tlast) begin
                in_mat_en   <= 0;
                we_mat_en   <= 0;
            end else begin
                in_mat_en   <= 1;
                we_mat_en   <= 1;
            end

            if (in_mat_wea) begin
                in_mat_addra    <= in_mat_addra + 1;
            end

            if (we_mat_wea) begin
                we_mat_addra    <= we_mat_addra + 1;
            end

            // ================== Read Input & Weight BRAM ==================
            acc_done_d  <= acc_done;
            counter_acc_done <= 0;
            
            // Port A & B Controller
            if ((in_mat_addra >= NUM_A_ELEMENTS-1) && (we_mat_addra >= NUM_B_ELEMENTS-1)) begin // enable AFTER BOTH of BRAMs are filled is HIGH
                en_module <= 1'b1;// Control write enable of each BRAMs for both ports
            end

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

            // ================== Output FIFO takes the output fromt he multihead attention ==================   
        end
    end

endmodule
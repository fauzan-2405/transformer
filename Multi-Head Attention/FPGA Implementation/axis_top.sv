// AXI Stream template
// Not used in the moment

`timescale 1ns / 1ps
import linear_proj_pkg::*;

module axis_top #(
    // MANDATORY PARAMETERS
    parameter S0_WIDTH  = DATA_WIDTH_A,     // Input width
    parameter S1_WIDTH  = DATA_WIDTH_A,
    parameter M0_WIDTH  = 64,               // Output width
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
    
     
    // ========================================= MM2S FIFO =========================================
    
    // ******************************* MM2S FIFO 0 *******************************
    // xpm_fifo_axis: AXI Stream FIFO
    // Xilinx Parameterized Macro, version 2018.3
    localparam FIFO_0_DEPTH                     = ...; // Must be power of two
    localparam FIFO_0_WR_RD_DATA_COUNT_WIDTH    = $clog2(FIFO_0_DEPTH) + 1; 
    localparam FIFO_0_TDATA_WIDTH               = ...; // Defines the width of the TDATA port, s_axis_tdata, and m_axis_tdata
    localparam FIFO_0_TKEEP_WIDTH               = FIFO_0_TDATA_WIDTH / 8;

    logic [FIFO_0_WR_RD_DATA_COUNT_WIDTH-1:0] mm2s_data_count_0;
    logic mm2s_ready_0_reg;
    logic mm2s_ready_0_next;
    logic [FIFO_0_TDATA_WIDTH-1:0] mm2s_data_0;

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
    xpm_fifo_axis_0
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
        
        .s_axis_tready(s_axis_0_tready), // ready    
        .s_axis_tdata(s_axis_0_tdata), // data
        .s_axis_tvalid(s_axis_0_tvalid), // valid
        .s_axis_tdest(1'b0), 
        .s_axis_tid(1'b0), 
        .s_axis_tkeep({FIFO_0_TKEEP_WIDTH{1'b1}}), 
        .s_axis_tlast(s_axis_0_tlast),
        .s_axis_tstrb({FIFO_0_TKEEP_WIDTH{1'b1}}), 
        .s_axis_tuser(1'b0), 
        
        .m_axis_tready(mm2s_ready_0_reg), // ready  
        .m_axis_tdata(mm2s_data_0), // data
        .m_axis_tvalid(), // valid
        .m_axis_tdest(), 
        .m_axis_tid(), 
        .m_axis_tkeep(), 
        .m_axis_tlast(), 
        .m_axis_tstrb(), 
        .m_axis_tuser(),  
        
        .wr_data_count_axis(mm2s_data_count_0) // data count
    );


    // ******************************* MM2S FIFO 1 *******************************
    // xpm_fifo_axis: AXI Stream FIFO
    // Xilinx Parameterized Macro, version 2018.3
    localparam FIFO_1_DEPTH                     = ...; // Must be power of two
    localparam FIFO_1_WR_RD_DATA_COUNT_WIDTH    = $clog2(FIFO_1_DEPTH) + 1; 
    localparam FIFO_1_TDATA_WIDTH               = ...; // Defines the width of the TDATA port, s_axis_tdata, and m_axis_tdata
    localparam FIFO_1_TKEEP_WIDTH               = FIFO_1_TDATA_WIDTH / 8;

    logic [FIFO_1_WR_RD_DATA_COUNT_WIDTH-1:0] mm2s_data_count_1;
    logic mm2s_ready_1_reg;
    logic mm2s_ready_1_next;
    logic [FIFO_1_TDATA_WIDTH-1:0] mm2s_data_1;

    xpm_fifo_axis
    #(
        .CDC_SYNC_STAGES(2),                 // Default
        .CLOCKING_MODE("common_clock"),      // Default
        .ECC_MODE("no_ecc"),                 // Default
        .FIFO_DEPTH(FIFO_1_DEPTH),           // IMPORTANT, please change this
        .FIFO_MEMORY_TYPE("auto"),           // Default
        .PACKET_FIFO("false"),               // Default
        .PROG_EMPTY_THRESH(10),              // Default
        .PROG_FULL_THRESH(10),               // Default
        .RD_DATA_COUNT_WIDTH(FIFO_1_WR_RD_DATA_COUNT_WIDTH), // IMPORTANT, please change this
        .RELATED_CLOCKS(0),                  // Default
        .SIM_ASSERT_CHK(0),                  // Default
        .TDATA_WIDTH(FIFO_1_TDATA_WIDTH),    // IMPORTANT, please change this

        .TDEST_WIDTH(1),                     // Default
        .TID_WIDTH(1),                       // Default
        .TUSER_WIDTH(1),                     // Default
        .USE_ADV_FEATURES("0004"),           // Default, write data count
        .WR_DATA_COUNT_WIDTH(FIFO_1_WR_RD_DATA_COUNT_WIDTH) // IMPORTANT, please change this
    )
    xpm_fifo_axis_1
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
        
        .s_axis_tready(s_axis_1_tready), // ready    
        .s_axis_tdata(s_axis_1_tdata), // data
        .s_axis_tvalid(s_axis_1_tvalid), // valid
        .s_axis_tdest(1'b0), 
        .s_axis_tid(1'b0), 
        .s_axis_tkeep({FIFO_1_TKEEP_WIDTH{1'b1}}), 
        .s_axis_tlast(s_axis_1_tlast),
        .s_axis_tstrb({FIFO_1_TKEEP_WIDTH{1'b1}}), 
        .s_axis_tuser(1'b0), 
        
        .m_axis_tready(mm2s_ready_1_reg), // ready  
        .m_axis_tdata(mm2s_data_1), // data
        .m_axis_tvalid(), // valid
        .m_axis_tdest(), 
        .m_axis_tid(), 
        .m_axis_tkeep(), 
        .m_axis_tlast(), 
        .m_axis_tstrb(), 
        .m_axis_tuser(),  
        
        .wr_data_count_axis(mm2s_data_count_1) // data count
    );
    

    // *** Top *******************************************************************
    wire top_start;
    wire top_done;
    wire top_ready;
    wire wb_ena;
    wire [ADDR_WIDTH_W-1:0] wb_addra;
    wire [WIDTH*CHUNK_SIZE-1:0] wb_dina;
    wire [7:0] wb_wea;
    wire in_ena;
    wire [ADDR_WIDTH_I-1:0] in_addra;
    wire [(WIDTH*CHUNK_SIZE*NUM_CORES)-1:0] in_dina;
    wire [7:0] in_wea;
    wire [(WIDTH*CHUNK_SIZE*NUM_CORES)-1:0] out_core;
    /*
    wire a_enb;
    wire [1:0] a_addrb;
    wire [63:0] a_doutb;
    */

    top_v2 #(
        .WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH), .BLOCK_SIZE(BLOCK_SIZE), .CHUNK_SIZE(CHUNK_SIZE),
        .INNER_DIMENSION(INNER_DIMENSION), .W_OUTER_DIMENSION(W_OUTER_DIMENSION), .I_OUTER_DIMENSION(I_OUTER_DIMENSION), 
        .ROW_SIZE_MAT_C(ROW_SIZE_MAT_C), .COL_SIZE_MAT_C(COL_SIZE_MAT_C), .NUM_CORES(NUM_CORES), .MAX_FLAG(MAX_FLAG),
        .ADDR_WIDTH_I(ADDR_WIDTH_I), .ADDR_WIDTH_W(ADDR_WIDTH_W)
    ) 
    top_inst
    (
        .clk(aclk),
        .rst_n(aresetn),

        .start(top_start),
        .done(top_done),
        .wb_ena(wb_ena),
        .wb_addra(wb_addra),
        .wb_dina(wb_dina),
        .wb_wea(wb_wea),

        .in_ena(in_ena),
        .in_addra(in_addra),
        .in_dina(in_dina),
        .in_wea(in_wea),

        .out_bram(out_core),
        .top_ready(top_ready)
    );
    
    // *** Main control *********************************************************
    // State machine
    reg [2:0] state_reg, state_next;
    reg [ADDR_WIDTH_I-1:0] cnt_word_i_reg, cnt_word_i_next; // Used as a counter for weight, input, and output
    reg [ADDR_WIDTH_W-1:0] cnt_word_w_reg, cnt_word_w_next; 

    // Start signal from DMA MM2S
    assign start_from_mm2s = ((mm2s_data_count_0 >= NUM_I_ELEMENTS) && (mm2s_data_count_n >= NUM_W_ELEMENTS)); // Start the operation after all elements had been streamed
    
    // State machine for AXI-Stream protocol
    always @(posedge aclk)
    begin
        if (!aresetn)
        begin
            state_reg <= 0;
            mm2s_ready_n_reg <= 0;
            mm2s_ready_0_reg <= 0;
            cnt_word_w_reg <= 0;
            cnt_word_i_reg <= 0;
        end
        else
        begin
            state_reg <= state_next;
            mm2s_ready_n_reg <= mm2s_ready_n_next;
            mm2s_ready_0_reg <= mm2s_ready_0_next;
            cnt_word_w_reg <= cnt_word_w_next;
            cnt_word_i_reg <= cnt_word_i_next;
        end
    end
    
    always @(*)
    begin
        state_next = state_reg;
        mm2s_ready_n_next = mm2s_ready_n_reg;
        mm2s_ready_0_next = mm2s_ready_0_reg;
        cnt_word_w_next = cnt_word_w_reg;
        cnt_word_i_next = cnt_word_i_reg;
        case (state_reg)
            0: // State 0: Wait until data from MM2S FIFOs are ready (Total = NUM_I_ELEMENTS + NUM_W_ELEMENTS)
            begin
                if (start_from_mm2s)
                begin
                    state_next = 1;
                    mm2s_ready_n_next = 1; // Tell the MM2S FIFO that it is ready to stream data
                    mm2s_ready_0_next = 1; 
                end
            end
            1: // State 1: Write the inputs and weights to BRAMs
            begin
                if ((cnt_word_i_reg == NUM_I_ELEMENTS-1) && (cnt_word_w_reg == NUM_W_ELEMENTS-1)) begin // If the counter for input and weight elements are equal to their max
                    state_next = 2;
                    mm2s_ready_0_next = 0;
                    mm2s_ready_n_next = 0;
                    cnt_word_i_next = 0;
                    cnt_word_w_next = 0;
                end
                else if ((cnt_word_i_reg == NUM_I_ELEMENTS-1) || (cnt_word_w_reg == NUM_W_ELEMENTS-1)) begin
                    if (cnt_word_i_reg == NUM_I_ELEMENTS-1) begin
                        cnt_word_i_next = NUM_I_ELEMENTS-1;
                        cnt_word_w_next = cnt_word_w_reg + 1;
                    end
                    else begin
                        cnt_word_w_next = NUM_W_ELEMENTS-1;
                        cnt_word_i_next = cnt_word_i_reg + 1;
                    end
                end
                else begin
                    cnt_word_w_next = cnt_word_w_reg + 1;
                    cnt_word_i_next = cnt_word_i_reg + 1;
                end
            end
            2: // Start the Top module 
            begin
                state_next = 3;          
            end
            3: // Wait until Top computation done + begin inserting the result to FIFO and S2MM FIFO is ready to accept data
            begin
                if (s2mm_ready && top_done)
                begin
                    state_next = 4;
                end
            end
            4: // Read data output from Top
            begin
                if ((s2mm_last == 1) && (m_axis_tvalid == 0)) // If there is no valid data to be sent
                begin
                    state_next = 0;
                    cnt_word_i_next = 0;
                    cnt_word_w_next = 0;
                end
            end
        endcase
    end

    // Control weight port Top
    assign wb_ena = (state_reg == 1) ? 1 : 0;
    assign wb_addra = cnt_word_w_reg;
    assign wb_dina = mm2s_data_n;
    assign wb_wea = (state_reg == 1) ? 8'hff : 0;
    
    // Control data input port Top
    assign in_ena = (state_reg == 1) ? 1 : 0;
    assign in_addra = cnt_word_i_reg;
    assign in_dina = mm2s_data_0;
    assign in_wea = (state_reg == 1) ? 8'hff : 0;
    
    // Start NN
    assign top_start = (state_reg == 2) || (state_reg == 3) ? 1 : 0;

    // Control S2MM FIFO
    assign s2mm_data = out_core;
    assign s2mm_valid = ((state_reg == 3) && (top_ready)) ? 1 : 0;
    // register #(1) reg_s2mm_valid(aclk, aresetn, s2mm_valid, s2mm_valid_reg); 
    assign s2mm_last = (top_done == 1) ? 1 : 0;
    // register #(1) reg_s2mm_last(aclk, aresetn, s2mm_last, s2mm_last_reg);

    // *** S2MM FIFO Output ************************************************************
    // xpm_fifo_axis: AXI Stream FIFO
    // Xilinx Parameterized Macro, version 2018.3
    // S2MM FIFO (Outputs)
    wire s2mm_ready;
    wire [WIDTH*CHUNK_SIZE*NUM_CORES:0] s2mm_data;
    wire s2mm_valid;
    wire s2mm_last;
    wire [DATA_COUNT_O-1:0] s2mm_data_count_o;

    xpm_fifo_axis
    #(
        .CDC_SYNC_STAGES(2),                 // DECIMAL
        .CLOCKING_MODE("common_clock"),      // String
        .ECC_MODE("no_ecc"),                 // String
        .FIFO_DEPTH(INNER_DIMENSION*I_OUTER_DIMENSION), // DECIMAL, EDIT THIS IN THE FUTURE
        .FIFO_MEMORY_TYPE("auto"),           // String
        .PACKET_FIFO("false"),               // String
        .PROG_EMPTY_THRESH(10),              // DECIMAL
        .PROG_FULL_THRESH(10),               // DECIMAL
        .RD_DATA_COUNT_WIDTH(1),             // DECIMAL
        .RELATED_CLOCKS(0),                  // DECIMAL
        .SIM_ASSERT_CHK(0),                  // DECIMAL
        .TDATA_WIDTH(WIDTH*CHUNK_SIZE*NUM_CORES), // DECIMAL, data width 64 bit
        .TDEST_WIDTH(1),                     // DECIMAL
        .TID_WIDTH(1),                       // DECIMAL
        .TUSER_WIDTH(1),                     // DECIMAL
        .USE_ADV_FEATURES("0004"),           // String, write data count
        .WR_DATA_COUNT_WIDTH(DATA_COUNT_O)   // DECIMAL, 
    )
    xpm_fifo_axis_o
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
        .s_axis_tkeep({TKEEP_WIDTH_I{1'b1}}), 
        .s_axis_tlast(s2mm_last),
        .s_axis_tstrb({TKEEP_WIDTH_I{1'b1}}), 
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

endmodule
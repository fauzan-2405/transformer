// AXI Stream for top_v2.v or top.v(?)
/* TODO
    1. Ask about the FIFO DEPTH
    2. Ask about can you deploy two FIFOs using two DMAs at the same time?
    3. Ask about s_axis ports
*/
`timescale 1ns / 1ps

module axis_top (
        input wire              aclk,
        input wire              aresetn,
        // *** AXIS Input slave port ***
        output wire             s_axis_tready_i,
        input wire [64*17-1:0]  s_axis_tdata_i, // Data for input
        input wire              s_axis_tvalid_i,
        input wire              s_axis_tlast_i,
        // *** AXIS Weight slave port ***
        output wire             s_axis_tready_w,
        input wire [63:0]       s_axis_tdata_w, // Data for weight
        input wire              s_axis_tvalid_w,
        input wire              s_axis_tlast_w,
        // *** AXIS master port ***
        input wire              m_axis_tready,
        output wire [64*17-1:0] m_axis_tdata, // If we're using top_v2.v
        output wire             m_axis_tvalid,
        output wire             m_axis_tlast
    );

    // Parameters
    localparam WIDTH = 16,
    localparam FRAC_WIDTH = 8,
    localparam BLOCK_SIZE = 2, 
    localparam CHUNK_SIZE = 4,
    localparam INNER_DIMENSION = 4, 
    // W stands for weight
    localparam W_OUTER_DIMENSION = 6,
    // I stands for input
    localparam I_OUTER_DIMENSION = 6,
    localparam ROW_SIZE_MAT_C = I_OUTER_DIMENSION / BLOCK_SIZE,
    localparam COL_SIZE_MAT_C = W_OUTER_DIMENSION / BLOCK_SIZE,
    localparam MAX_FLAG = ROW_SIZE_MAT_C * COL_SIZE_MAT_C,
    localparam NUM_CORES = (INNER_DIMENSION == 2754) ? 17 :
                               (INNER_DIMENSION == 256)  ? 8 :
                               (INNER_DIMENSION == 200)  ? 5 :
                               (INNER_DIMENSION == 64)   ? 4 : 2

    // State machine
    reg [2:0] state_reg, state_next;
    reg [2:0] cnt_word_reg, cnt_word_next;

    // MM2S FIFO    
    wire [11:0] mm2s_data_count;
    wire start_from_mm2s;
    reg mm2s_ready_reg, mm2s_ready_next;
    wire [CHUNK_SIZE*WIDTH*NUM_CORES-1:0] mm2s_data_i;
    wire [CHUNK_SIZE*WIDTH-1:0] mm2s_data_w;
    
    // NN
    wire nn_start;
    wire nn_ready;
    wire wb_ena;
    wire [2:0] wb_addra;
    wire [63:0] wb_dina;
    wire [7:0] wb_wea;
    wire k_ena;
    wire [1:0] k_addra;
    wire [63:0] k_dina;
    wire [7:0] k_wea;
    wire a_enb;
    wire [1:0] a_addrb;
    wire [63:0] a_doutb;

    // S2MM FIFO
    wire s2mm_ready;
    wire [WIDTH*CHUNK_SIZE*NUM_CORES:0] s2mm_data;
    wire s2mm_valid, s2mm_valid_reg;
    wire s2mm_last, s2mm_last_reg;

    // *** MM2S FIFO: INPUT ************************************************************
    // xpm_fifo_axis: AXI Stream FIFO
    // Xilinx Parameterized Macro, version 2018.3
    xpm_fifo_axis
    #(
        .CDC_SYNC_STAGES(2),                 // DECIMAL
        .CLOCKING_MODE("common_clock"),      // String
        .ECC_MODE("no_ecc"),                 // String
        .FIFO_DEPTH(INNER_DIMENSION*I_OUTER_DIMENSION), // DECIMAL, THIS IS IMPORTANT
        .FIFO_MEMORY_TYPE("auto"),           // String
        .PACKET_FIFO("false"),               // String
        .PROG_EMPTY_THRESH(10),              // DECIMAL
        .PROG_FULL_THRESH(10),               // DECIMAL
        .RD_DATA_COUNT_WIDTH(1),             // DECIMAL
        .RELATED_CLOCKS(0),                  // DECIMAL
        .SIM_ASSERT_CHK(0),                  // DECIMAL
        .TDATA_WIDTH(WIDTH*CHUNK_SIZE*NUM_CORES), // DECIMAL, 64 x NUM_CORES-bit, THIS IS IMPORTANT
        .TDEST_WIDTH(1),                     // DECIMAL
        .TID_WIDTH(1),                       // DECIMAL
        .TUSER_WIDTH(1),                     // DECIMAL
        .USE_ADV_FEATURES("0004"),           // String, write data count
        .WR_DATA_COUNT_WIDTH(21)              // DECIMAL, width log2(FIFO_DEPTH)+1=20.42, take 21 instead 
    )
    xpm_fifo_axis_i
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
        
        .s_axis_tready(s_axis_tready_i), // ready    
        .s_axis_tdata(s_axis_tdata_i), // data, NOTICE THIS!!!
        .s_axis_tvalid(s_axis_tvalid_i), // valid
        .s_axis_tdest(1'b0), 
        .s_axis_tid(1'b0), 
        .s_axis_tkeep(8'hff), 
        .s_axis_tlast(s_axis_tlast_i),
        .s_axis_tstrb(8'hff), 
        .s_axis_tuser(1'b0), 
        
        .m_axis_tready(mm2s_ready_reg), // ready  
        .m_axis_tdata(mm2s_data_i), // data
        .m_axis_tvalid(), // valid
        .m_axis_tdest(), 
        .m_axis_tid(), 
        .m_axis_tkeep(), 
        .m_axis_tlast(), 
        .m_axis_tstrb(), 
        .m_axis_tuser(),  
        
        .wr_data_count_axis(mm2s_data_count) // data count
    );

    // *** MM2S FIFO: WEIGHT ************************************************************
    // xpm_fifo_axis: AXI Stream FIFO
    // Xilinx Parameterized Macro, version 2018.3
    xpm_fifo_axis
    #(
        .CDC_SYNC_STAGES(2),                 // DECIMAL
        .CLOCKING_MODE("common_clock"),      // String
        .ECC_MODE("no_ecc"),                 // String
        .FIFO_DEPTH(INNER_DIMENSION*W_OUTER_DIMENSION), // DECIMAL, THIS IS IMPORTANT
        .FIFO_MEMORY_TYPE("auto"),           // String
        .PACKET_FIFO("false"),               // String
        .PROG_EMPTY_THRESH(10),              // DECIMAL
        .PROG_FULL_THRESH(10),               // DECIMAL
        .RD_DATA_COUNT_WIDTH(1),             // DECIMAL
        .RELATED_CLOCKS(0),                  // DECIMAL
        .SIM_ASSERT_CHK(0),                  // DECIMAL
        .TDATA_WIDTH(WIDTH*CHUNK_SIZE),      // DECIMAL, 64-bit THIS IS IMPORTANT
        .TDEST_WIDTH(1),                     // DECIMAL
        .TID_WIDTH(1),                       // DECIMAL
        .TUSER_WIDTH(1),                     // DECIMAL
        .USE_ADV_FEATURES("0004"),           // String, write data count
        .WR_DATA_COUNT_WIDTH(15)              // DECIMAL, width log2(FIFO_DEPTH)+1=15.42
    )
    xpm_fifo_axis_wb
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
        
        .s_axis_tready(s_axis_tready_w), // ready    
        .s_axis_tdata(s_axis_tdata_w), // data
        .s_axis_tvalid(s_axis_tvalid_w), // valid
        .s_axis_tdest(1'b0), 
        .s_axis_tid(1'b0), 
        .s_axis_tkeep(8'hff), 
        .s_axis_tlast(s_axis_tlast_w),
        .s_axis_tstrb(8'hff), 
        .s_axis_tuser(1'b0), 
        
        .m_axis_tready(mm2s_ready_reg), // ready  
        .m_axis_tdata(mm2s_data_w), // data
        .m_axis_tvalid(), // valid
        .m_axis_tdest(), 
        .m_axis_tid(), 
        .m_axis_tkeep(), 
        .m_axis_tlast(), 
        .m_axis_tstrb(), 
        .m_axis_tuser(),  
        
        .wr_data_count_axis(mm2s_data_count) // data count
    );
    
    // *** Main control *********************************************************
    // Start signal from DMA MM2S
    assign start_from_mm2s = (mm2s_data_count >= 7); // Weight = 5 word, input = 2 word, total = 7 word
    
    // State machine for AXI-Stream protocol
    always @(posedge aclk)
    begin
        if (!aresetn)
        begin
            state_reg <= 0;
            mm2s_ready_reg <= 0;
            cnt_word_reg <= 0;
        end
        else
        begin
            state_reg <= state_next;
            mm2s_ready_reg <= mm2s_ready_next;
            cnt_word_reg <= cnt_word_next;
        end
    end
    
    always @(*)
    begin
        state_next = state_reg;
        mm2s_ready_next = mm2s_ready_reg;
        cnt_word_next = cnt_word_reg;
        case (state_reg)
            0: // Wait until data from MM2S is ready (7 words)
            begin
                if (start_from_mm2s)
                begin
                    state_next = 1;
                    mm2s_ready_next = 1; // Tell the MM2S FIFO that it is ready to accept data
                end
            end
            1: // Write data to weight BRAM of the NN
            begin
                if (cnt_word_reg == 4)
                begin
                    state_next = 2;
                    cnt_word_next = 0;
                end
                else
                begin
                    cnt_word_next = cnt_word_reg + 1;
                end
            end
            2: // Write data to input BRAM of the NN
            begin
                if (cnt_word_reg == 1)
                begin
                    state_next = 3;
                    mm2s_ready_next = 0;
                    cnt_word_next = 0;
                end
                else
                begin
                    cnt_word_next = cnt_word_reg + 1;
                end                
            end
            3: // Start the NN
            begin
                state_next = 4;
            end
            4: // Wait until NN computation done and S2MM FIFO is ready to accept data
            begin
                if (nn_ready && s2mm_ready)
                begin
                    state_next = 5;
                end
            end
            5: // Read data output from BRAM of the NN
            begin
                if (cnt_word_reg == 1)
                begin
                    state_next = 0;
                    cnt_word_next = 0;
                end
                else
                begin
                    cnt_word_next = cnt_word_reg + 1;
                end
            end
        endcase
    end

    // Control weight port NN
    assign wb_ena = (state_reg == 1) ? 1 : 0;
    assign wb_addra = cnt_word_reg;
    assign wb_dina = mm2s_data;
    assign wb_wea = (state_reg == 1) ? 8'hff : 0;
    
    // Control data input port NN
    assign k_ena = (state_reg == 2) ? 1 : 0;
    assign k_addra = cnt_word_reg[1:0];
    assign k_dina = mm2s_data;
    assign k_wea = (state_reg == 2) ? 8'hff : 0;
    
    // Start NN
    assign nn_start = (state_reg == 3) ? 1 : 0;
    
    // Control data output port NN
    assign a_enb = (state_reg == 5) ? 1 : 0;
    assign a_addrb = cnt_word_reg[1:0];

    // Control S2MM FIFO
    assign s2mm_data = a_doutb;
    assign s2mm_valid = a_enb;
    register #(1) reg_s2mm_valid(aclk, aresetn, 1'b1, 1'b0, s2mm_valid, s2mm_valid_reg); 
    assign s2mm_last = ((state_reg == 5) && (a_addrb == 2'b01)) ? 1 : 0;
    register #(1) reg_s2mm_last(aclk, aresetn, 1'b1, 1'b0, s2mm_last, s2mm_last_reg);

    // *** NN *******************************************************************
    nn nn_0
    (
        .clk(aclk),
        .rst_n(aresetn),
        .en(1'b1),
        .clr(1'b0),
        .ready(nn_ready),
        .start(nn_start),
        .done(),
        .wb_ena(wb_ena),
        .wb_addra(wb_addra),
        .wb_dina(wb_dina),
        .wb_wea(wb_wea),
        .k_ena(k_ena),
        .k_addra(k_addra),
        .k_dina(k_dina),
        .k_wea(k_wea),
        .a_enb(a_enb),
        .a_addrb(a_addrb),
        .a_doutb(a_doutb)
    );

    // *** S2MM FIFO Output ************************************************************
    // xpm_fifo_axis: AXI Stream FIFO
    // Xilinx Parameterized Macro, version 2018.3
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
        .WR_DATA_COUNT_WIDTH(21)              // DECIMAL, width log2(256)+1=9 
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
        .s_axis_tvalid(s2mm_valid_reg), // valid
        .s_axis_tdest(1'b0), 
        .s_axis_tid(1'b0), 
        .s_axis_tkeep(8'hff), 
        .s_axis_tlast(s2mm_last_reg),
        .s_axis_tstrb(8'hff), 
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
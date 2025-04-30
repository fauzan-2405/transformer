// AXI Stream for top_v2.v or top.v(?)
// DONT FORGET TO EDIT THE WIDTH OF INPUTS AND OUTPUT ACCORDING TO THE DATA SIZE
/* TODO
    1. Ask about the FIFO DEPTH (DONE)
    2. Ask about can you deploy two FIFOs using two DMAs at the same time? (DONE)
    3. Ask about s_axis ports (DONE)
    4. Create the state machine process (DONE)
    5. Add clog2_value parameter to the top_v2, then change the width of the inputs and output
    6. Dont forget to update the top_v2 testbench as well (tb_top.v)
*/
`timescale 1ns / 1ps

module axis_top (
        input wire              aclk,
        input wire              aresetn,
        // *** AXIS Input slave port ***
        output wire             s_axis_i_tready,
        input wire [64*2-1:0]   s_axis_i_tdata, // Data for input
        input wire              s_axis_i_tvalid,
        input wire              s_axis_i_tlast,
        // *** AXIS Weight slave port ***
        output wire             s_axis_w_tready,
        input wire [63:0]       s_axis_w_tdata, // Data for weight
        input wire              s_axis_w_tvalid,
        input wire              s_axis_w_tlast,
        // *** AXIS master port ***
        input wire              m_axis_tready,
        output wire [64*2-1:0]  m_axis_tdata, // If we're using top_v2.v
        output wire             m_axis_tvalid,
        output wire             m_axis_tlast
    );

    // clog2 function
    function integer clog2;
        input integer value;
        begin  
            value = value-1;
            for (clog2=0; value>0; clog2=clog2+1)
            value = value>>1;
        end
    endfunction

    // Parameters
    localparam WIDTH = 16;
    localparam FRAC_WIDTH = 8;
    localparam BLOCK_SIZE = 2; 
    localparam CHUNK_SIZE = 4;
    localparam INNER_DIMENSION = 4; 
    // W stands for weight
    localparam W_OUTER_DIMENSION = 6;
    // I stands for input
    localparam I_OUTER_DIMENSION = 8;
    localparam ROW_SIZE_MAT_C = I_OUTER_DIMENSION / BLOCK_SIZE;
    localparam COL_SIZE_MAT_C = W_OUTER_DIMENSION / BLOCK_SIZE;
    localparam MAX_FLAG = ROW_SIZE_MAT_C * COL_SIZE_MAT_C;
    localparam NUM_CORES = (INNER_DIMENSION == 2754) ? 9 :
                               (INNER_DIMENSION == 256)  ? 8 :
                               (INNER_DIMENSION == 200)  ? 5 :
                               (INNER_DIMENSION == 64)   ? 4 : 2;
    localparam NUM_I_ELEMENTS = ((I_OUTER_DIMENSION/BLOCK_SIZE)*(INNER_DIMENSION/BLOCK_SIZE))/NUM_CORES; // Total elements of Input if we converted the inputs based on the NUM_CORES
    localparam NUM_W_ELEMENTS = (W_OUTER_DIMENSION/BLOCK_SIZE)*(INNER_DIMENSION/BLOCK_SIZE);
    localparam NUM_O_ELEMENTS = (ROW_SIZE_MAT_C/NUM_CORES)*COL_SIZE_MAT_C;
    localparam DATA_COUNT_I = clog2(INNER_DIMENSION*I_OUTER_DIMENSION) + 1; // Used for counting the required width for WR_DATA_COUNT_WIDTH parameter in FIFO
    localparam DATA_COUNT_W = clog2(INNER_DIMENSION*W_OUTER_DIMENSION) + 1;   
    localparam ADDR_WIDTH_I = clog2((INNER_DIMENSION*I_OUTER_DIMENSION*WIDTH)/(WIDTH*CHUNK_SIZE*NUM_CORES)); // Used for determining the width of wb and input address and other parameters in BRAMs
    localparam ADDR_WIDTH_W = clog2((INNER_DIMENSION*W_OUTER_DIMENSION*WIDTH)/(WIDTH*CHUNK_SIZE));

    // MM2S FIFO (Inputs and Weights)
    wire [DATA_COUNT_I-1:0] mm2s_data_count_i;
    wire [DATA_COUNT_W-1:0] mm2s_data_count_w;
    wire start_from_mm2s;
    reg mm2s_ready_w_reg, mm2s_ready_i_reg;
    reg mm2s_ready_w_next, mm2s_ready_i_next;
    wire [CHUNK_SIZE*WIDTH*NUM_CORES-1:0] mm2s_data_i;
    wire [CHUNK_SIZE*WIDTH-1:0] mm2s_data_w;

    // S2MM FIFO (Outputs)
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
        .WR_DATA_COUNT_WIDTH(DATA_COUNT_I)   // DECIMAL, width log2(FIFO_DEPTH)+1=20.42, take 21 instead 
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
        
        .s_axis_tready(s_axis_i_tready), // ready    
        .s_axis_tdata(s_axis_i_tdata), // data, NOTICE THIS!!!
        .s_axis_tvalid(s_axis_i_tvalid), // valid
        .s_axis_tdest(1'b0), 
        .s_axis_tid(1'b0), 
        .s_axis_tkeep(8'hff), 
        .s_axis_tlast(s_axis_i_tlast),
        .s_axis_tstrb(8'hff), 
        .s_axis_tuser(1'b0), 
        
        .m_axis_tready(mm2s_ready_i_reg), // ready  
        .m_axis_tdata(mm2s_data_i), // data
        .m_axis_tvalid(), // valid
        .m_axis_tdest(), 
        .m_axis_tid(), 
        .m_axis_tkeep(), 
        .m_axis_tlast(), 
        .m_axis_tstrb(), 
        .m_axis_tuser(),  
        
        .wr_data_count_axis(mm2s_data_count_i) // data count
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
        .WR_DATA_COUNT_WIDTH(DATA_COUNT_W)   // DECIMAL, width log2(FIFO_DEPTH)+1=15.42
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
        
        .s_axis_tready(s_axis_w_tready), // ready    
        .s_axis_tdata(s_axis_w_tdata), // data
        .s_axis_tvalid(s_axis_w_tvalid), // valid
        .s_axis_tdest(1'b0), 
        .s_axis_tid(1'b0), 
        .s_axis_tkeep(8'hff), 
        .s_axis_tlast(s_axis_w_tlast),
        .s_axis_tstrb(8'hff), 
        .s_axis_tuser(1'b0), 
        
        .m_axis_tready(mm2s_ready_w_reg), // ready  
        .m_axis_tdata(mm2s_data_w), // data
        .m_axis_tvalid(), // valid
        .m_axis_tdest(), 
        .m_axis_tid(), 
        .m_axis_tkeep(), 
        .m_axis_tlast(), 
        .m_axis_tstrb(), 
        .m_axis_tuser(),  
        
        .wr_data_count_axis(mm2s_data_count_w) // data count
    );

    // *** Top *******************************************************************
    wire top_start;
    wire top_done;
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
        //.ready(ready),
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

        .out_bram(out_core)
    );
    
    // *** Main control *********************************************************
    // State machine
    reg [2:0] state_reg, state_next;
    reg [ADDR_WIDTH_I-1:0] cnt_word_i_reg, cnt_word_i_next; // Used as a counter for weight, input, and output
    reg [ADDR_WIDTH_W-1:0] cnt_word_w_reg, cnt_word_w_next; 

    // Start signal from DMA MM2S
    assign start_from_mm2s = ((mm2s_data_count_i >= NUM_I_ELEMENTS) && (mm2s_data_count_w >= NUM_W_ELEMENTS)); // Start the operation after all elements had been streamed
    
    // State machine for AXI-Stream protocol
    always @(posedge aclk)
    begin
        if (!aresetn)
        begin
            state_reg <= 0;
            mm2s_ready_w_reg <= 0;
            mm2s_ready_i_reg <= 0;
            cnt_word_w_reg <= 0;
            cnt_word_i_reg <= 0;
        end
        else
        begin
            state_reg <= state_next;
            mm2s_ready_w_reg <= mm2s_ready_w_next;
            mm2s_ready_i_reg <= mm2s_ready_i_next;
            cnt_word_w_reg <= cnt_word_w_next;
            cnt_word_i_reg <= cnt_word_i_next;
        end
    end
    
    always @(*)
    begin
        state_next = state_reg;
        mm2s_ready_w_next = mm2s_ready_w_reg;
        mm2s_ready_i_next = mm2s_ready_i_reg;
        cnt_word_w_next = cnt_word_w_reg;
        cnt_word_i_next = cnt_word_i_reg;
        case (state_reg)
            0: // State 0: Wait until data from MM2S FIFOs are ready (Total = NUM_I_ELEMENTS + NUM_W_ELEMENTS)
            begin
                if (start_from_mm2s)
                begin
                    state_next = 1;
                    mm2s_ready_w_next = 1; // Tell the MM2S FIFO that it is ready to stream data
                    mm2s_ready_i_next = 1; 
                end
            end
            1: // State 1: Write the inputs and weights to BRAMs
            begin
                if ((cnt_word_i_reg == NUM_I_ELEMENTS-1) && (cnt_word_w_reg == NUM_W_ELEMENTS-1)) begin // If the counter for input and weight elements are equal to their max
                    state_next = 2;
                    mm2s_ready_i_next = 0;
                    mm2s_ready_w_next = 0;
                    cnt_word_i_next = 0;
                    cnt_word_w_next = 0;
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
            3: // Wait until Top computation done and S2MM FIFO is ready to accept data
            begin
                if (s2mm_ready && top_done)
                begin
                    state_next = 4;
                end
            end
            4: // Read data output from Top
            begin
                if (cnt_word_i_reg == NUM_O_ELEMENTS-1) // If the counter for output reached its maximum value, we just reuse the cnt_word_i_reg
                begin
                    state_next = 0;
                    cnt_word_i_next = 0;
                    cnt_word_w_next = 0;
                end
                else
                begin
                    cnt_word_i_next = cnt_word_i_reg + 1;
                end
            end
        endcase
    end

    // Control weight port Top
    assign wb_ena = (state_reg == 1) ? 1 : 0;
    assign wb_addra = cnt_word_w_reg;
    assign wb_dina = mm2s_data_w;
    assign wb_wea = (state_reg == 1) ? 8'hff : 0;
    
    // Control data input port Top
    assign in_ena = (state_reg == 1) ? 1 : 0;
    assign in_addra = cnt_word_i_reg;
    assign in_dina = mm2s_data_i;
    assign in_wea = (state_reg == 1) ? 8'hff : 0;
    
    // Start NN
    assign top_start = (state_reg == 2) ? 1 : 0;
    
    // Control data output port Top
    /*
    assign a_enb = (state_reg == 5) ? 1 : 0;
    assign a_addrb = cnt_word_reg[1:0];
    */

    // Control S2MM FIFO
    assign s2mm_data = out_core;
    assign s2mm_valid = (state_reg == 4) ? 1 : 0;
    register #(1) reg_s2mm_valid(aclk, aresetn, s2mm_valid, s2mm_valid_reg); 
    assign s2mm_last = ((state_reg == 4) && (cnt_word_i_reg == NUM_O_ELEMENTS-1)) ? 1 : 0;
    register #(1) reg_s2mm_last(aclk, aresetn, s2mm_last, s2mm_last_reg);

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
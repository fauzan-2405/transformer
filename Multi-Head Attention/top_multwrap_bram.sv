// top_multwrap_bram
// This top module wraps multi_matmul_wrapper + bram for testing purposes

import linear_proj_pkg::*;

module top_multwrap_bram #(
    localparam MEMORY_SIZE_A = INNER_DIMENSION*A_OUTER_DIMENSION*WIDTH_A,
    localparam MEMORY_SIZE_B = INNER_DIMENSION*B_OUTER_DIMENSION*WIDTH_B,
    localparam DATA_WIDTH_A  = WIDTH_A*CHUNK_SIZE*NUM_CORES_A,
    localparam DATA_WIDTH_B  = WIDTH_B*CHUNK_SIZE*NUM_CORES_B*TOTAL_MODULES,
    localparam int ADDR_WIDTH_A = $clog2(MEMORY_SIZE_A/DATA_WIDTH_A),
    localparam int ADDR_WIDTH_B = $clog2(MEMORY_SIZE_A/DATA_WIDTH_B) 
) (
    input logic clk, rst_n,
    input logic start,

    // For Input Matrix BRAM
    input logic in_mat_ena,
    input logic in_mat_wea,
    input logic [ADDR_WIDTH_A-1:0] in_mat_wr_addra,
    input logic [WIDTH_A*CHUNK_SIZE*NUM_CORES_A-1:0] in_mat_dina,

    input logic in_mat_enb,
    input logic in_mat_web,
    input logic [ADDR_WIDTH_A-1:0] in_mat_wr_addrb,
    input logic [WIDTH_A*CHUNK_SIZE*NUM_CORES_A-1:0] in_mat_dinb,

    // For Weight Matrix BRAM
    input logic w_mat_ena,
    input logic w_mat_wea,
    input logic [ADDR_WIDTH_B-1:0] w_mat_wr_addra,
    input logic [WIDTH_B*CHUNK_SIZE*NUM_CORES_B*TOTAL_MODULES-1:0] w_mat_dina,

    input logic w_mat_enb,
    input logic w_mat_web,
    input logic [ADDR_WIDTH_B-1:0] w_mat_wr_addrb,
    input logic [WIDTH_B*CHUNK_SIZE*NUM_CORES_B*TOTAL_MODULES-1:0] w_mat_dinb,

    output logic done, out_valid,
    output logic [(WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A*NUM_CORES_B*TOTAL_MODULES)-1:0] out_multi_matmul [TOTAL_INPUT_W]
);

    // BRAM address/control mux outputs (driven to XPM ports)
    logic [ADDR_WIDTH_A-1:0] in_mat_addra_mux, in_mat_addrb_mux;
    logic [ADDR_WIDTH_B-1:0] w_mat_addra_mux, w_mat_addrb_mux;
    logic in_mat_wea_mux, in_mat_web_mux, in_mat_ena_mux, in_mat_enb_mux;
    logic w_mat_wea_mux, w_mat_web_mux, w_mat_ena_mux, w_mat_enb_mux;

    // Internal read address counters (controller-driven)
    logic [ADDR_WIDTH_A-1:0] in_mat_rd_addra; // used when reading port A
    logic [ADDR_WIDTH_A-1:0] in_mat_rd_addrb; // used when reading port B
    logic [ADDR_WIDTH_B-1:0] w_mat_rd_addra;    // reading weights (we'll use only one BRAM port for read later)
    logic [ADDR_WIDTH_B-1:0] w_mat_rd_addrb;    // reading weights (we'll use only one BRAM port for read later)

    logic multi_en; // enable to multi_matmul_wrapper


    // *** Control Signals for Mux ***********************************************************
    // These signals will be connected to the BRAM
    // write_phase == 1: BRAM ports are in write mode (external ena/we* used)
    // write_phase == 0: BRAM ports are in read mode (we* == 0)
    logic write_phase;
    
    // For input matrix BRAM (in_mat)
    assign in_mat_addra_mux = (write_phase) ? in_mat_wr_addra : in_mat_rd_addra;
    assign in_mat_addrb_mux = (write_phase) ? in_mat_wr_addrb : in_mat_rd_addrb;

    assign in_mat_wea_mux   = (write_phase) ? in_mat_wea : 1'b0;
    assign in_mat_web_mux   = (write_phase) ? in_mat_web : 1'b0;

    assign in_mat_ena_mux   = (write_phase) ? in_mat_ena : 1'b1; // For now, let's toggle it to 1 in read mode
    assign in_mat_enb_mux   = (write_phase) ? in_mat_enb : 1'b1;

    // For weight matrix BRAM (w_mat)
    assign w_mat_addra_mux  = (write_phase) ? w_mat_wr_addra : w_mat_rd_addra;
    assign w_mat_addrb_mux  = (write_phase) ? w_mat_wr_addrb : w_mat_rd_addrb;

    assign w_mat_wea_mux   = (write_phase) ? w_mat_wea : 1'b0;
    assign w_mat_web_mux   = (write_phase) ? w_mat_web : 1'b0;

    assign w_mat_ena_mux   = (write_phase) ? w_mat_ena : 1'b1; 
    assign w_mat_enb_mux   = (write_phase) ? w_mat_enb : 1'b1; 
    

    // *** Input Matrix BRAM ***********************************************************
    // xpm_memory_tdpram: True Dual Port RAM
    // Xilinx Parameterized Macro, version 2018.3
    logic [WIDTH_A*CHUNK_SIZE*NUM_CORES_A-1:0] in_mat_douta, in_mat_doutb;

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
        .sleep(1'b0),
        .regcea(1'b1), //do not change
        .injectsbiterra(1'b0), //do not change
        .injectdbiterra(1'b0), //do not change   
        .sbiterra(), //do not change
        .dbiterra(), //do not change
        .regceb(1'b1), //do not change
        .injectsbiterrb(1'b0), //do not change
        .injectdbiterrb(1'b0), //do not change              
        .sbiterrb(), //do not change
        .dbiterrb(), //do not change
        
        // Port A module ports
        .clka(clk),
        .rsta(~rst_n),
        .ena(in_mat_ena_mux),
        .wea(in_mat_wea_mux),
        .addra(in_mat_addra_mux), // in_mat_rd_addra or in_mat_wr_addra
        .dina(in_mat_dina),
        .douta(in_mat_douta),
        
        // Port B module ports
        .clkb(clk),
        .rstb(~rst_n),
        .enb(in_mat_enb_mux),
        .web(in_mat_web_mux), 
        .addrb(in_mat_addrb_mux),  // please toggle between in_mat_rd_addrb or in_mat_wr_addrb
        .dinb(in_mat_dinb),
        .doutb(in_mat_doutb)
    );


    // *** Input Weight BRAM **********************************************************
    // xpm_memory_tdpram: True Dual Port RAM
    // Xilinx Parameterized Macro, version 2018.3
    logic [WIDTH_B*CHUNK_SIZE*NUM_CORES_B*TOTAL_MODULES-1:0] w_mat_doutb;

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
        .WRITE_DATA_WIDTH_A(DATA_WIDTH_B), // DECIMAL, data width: 64-bit
        .READ_DATA_WIDTH_A(DATA_WIDTH_B),  // DECIMAL, data width: 64-bit
        .BYTE_WRITE_WIDTH_A(DATA_WIDTH_B), // DECIMAL, how many bytes in WRITE_DATA_WIDTH_A, use $clog2 maybe?
        .ADDR_WIDTH_A(ADDR_WIDTH_B),         // DECIMAL, clog2(MEMORY_SIZE/WRITE_DATA_WIDTH_A)
        .READ_RESET_VALUE_A("0"),            // String
        .READ_LATENCY_A(1),                  // DECIMAL
        .WRITE_MODE_A("write_first"),        // String
        .RST_MODE_A("SYNC"),                 // String
        
        // Port B module parameters  
        .WRITE_DATA_WIDTH_B(DATA_WIDTH_B), // DECIMAL, data width: 64-bit
        .READ_DATA_WIDTH_B(DATA_WIDTH_B),  // DECIMAL, data width: 64-bit
        .BYTE_WRITE_WIDTH_B(DATA_WIDTH_B), // DECIMAL
        .ADDR_WIDTH_B(ADDR_WIDTH_B),         // DECIMAL, clog2(MEMORY_SIZE/WRITE_DATA_WIDTH_A)
        .READ_RESET_VALUE_B("0"),            // String
        .READ_LATENCY_B(1),                  // DECIMAL
        .WRITE_MODE_B("write_first"),        // String
        .RST_MODE_B("SYNC")                  // String
    )
    xpm_memory_tdpram_we_mat
    (
        .sleep(1'b0),
        .regcea(1'b1), //do not change
        .injectsbiterra(1'b0), //do not change
        .injectdbiterra(1'b0), //do not change   
        .sbiterra(), //do not change
        .dbiterra(), //do not change
        .regceb(1'b1), //do not change
        .injectsbiterrb(1'b0), //do not change
        .injectdbiterrb(1'b0), //do not change              
        .sbiterrb(), //do not change
        .dbiterrb(), //do not change
        
        // Port A module ports
        .clka(clk),
        .rsta(~rst_n),
        .ena(w_mat_ena_mux), 
        .wea(w_mat_wea_mux),
        .addra(w_mat_addra_mux), // please toggle between w_mat_rd_addra or w_mat_wr_addra
        .dina(w_mat_dina),
        .douta(),
        
        // Port B module ports
        .clkb(clk),
        .rstb(~rst_n),
        .enb(w_mat_enb_mux),
        .web(w_mat_web_mux), 
        .addrb(w_mat_addrb_mux), // please toggle between w_mat_rd_addrb or w_mat_wr_addrb
        .dinb(w_mat_dinb),
        .doutb(w_mat_doutb) // For now, we only use port B to read
    );

    // Hook up read results into multi_matmul_wrapper input array
    // We'll map: in_bram[0] <= in_mat_douta (even rows), in_bram[1] <= in_mat_doutb (odd rows)
    logic [WIDTH_A*CHUNK_SIZE*NUM_CORES_A-1:0] in_multi_matmul [TOTAL_INPUT_W];
    genvar i;
    generate
        for (i = 0; i < TOTAL_INPUT_W; i = i + 1) begin
            if (i == 0) assign in_multi_matmul[i] = in_mat_douta;
            if (i == 1) assign in_multi_matmul[i] = in_mat_doutb;
        end
    endgenerate


    // *** Matmul wrapper ***********************************************************
    logic internal_rst_n, internal_reset_acc;
    logic systolic_finish_wrap;
    logic acc_done_wrap_rising;
    logic acc_done_wrap_d, acc_done_wrap;
    assign acc_done_wrap_rising = ~acc_done_wrap_d & acc_done_wrap;
    logic en_module; // Toggle to ALWAYS HIGH after both BRAMs are filled
    
    multi_matmul_wrapper #(
        .WIDTH_A(WIDTH_A),
        .FRAC_WIDTH_A(FRAC_WIDTH_A),
        .WIDTH_B(WIDTH_B),
        .FRAC_WIDTH_B(FRAC_WIDTH_B),
        .WIDTH_OUT(WIDTH_OUT),
        .FRAC_WIDTH_OUT(FRAC_WIDTH_OUT),
        .BLOCK_SIZE(BLOCK_SIZE),
        .CHUNK_SIZE(CHUNK_SIZE),
        .TOTAL_MODULES(TOTAL_MODULES),
        .TOTAL_INPUT_W(TOTAL_INPUT_W),
        .INNER_DIMENSION(INNER_DIMENSION),
        .NUM_CORES_A(NUM_CORES_A),
        .NUM_CORES_B(NUM_CORES_B)
    ) 
    multi_matmul_wrapper_inst (
        .clk(clk), .en(en_module), // toggle enable after BOTH Input and Weight BRAM are entirely filled
        .rst_n(internal_rst_n), .reset_acc(internal_reset_acc),
        .in_bram(in_multi_matmul),
        .acc_done_wrap(acc_done_wrap), .systolic_finish_wrap(systolic_finish_wrap),
        .out_multi_matmul(out_multi_matmul)
    );

    // *** Main Controller **********************************************************
    // Create the mux here to toggle the write enable port and write/read addresses for BRAMs
    logic [WIDTH_OUT-1:0] counter, counter_row, counter_col, flag;
    logic counter_acc_done;

    // Main controller logic
    always @(posedge clk) begin
        if (~rst_n) begin
            // Counter for controllers
            counter <= 0;
            counter_row <=0;
            counter_col <=0;
            counter_acc_done <= 0;
            internal_rst_n <=0;
            internal_reset_acc <=0;
            acc_done_wrap_d <=0;
            flag <=0;
            // Addresses
            in_mat_rd_addra <= '0;
            in_mat_rd_addrb <= '0;
            w_mat_rd_addra  <= '0;
            w_mat_rd_addrb  <= '0;
            // Controllers
            write_phase     <= 1'b1;
            en_module       <= 1'b0;
            internal_rst_n  <= 1'b0;
            internal_reset_acc <= 1'b0;
            // Output
            for (int i = 0; i < TOTAL_INPUT_W; i = i +1) begin
                out_multi_matmul[i] <= '0;
            end
        end
        else begin
            acc_done_wrap_d  <= acc_done_wrap; // Assigninig the delayed version 
            counter_acc_done <= 0; // Assign this to zero every clock cycle
            //internal_rst_n   <= 1'b1; // Advice 
            //in_a_enb_d <= in_a_enb;
            //in_b_enb_d <= in_b_enb;
            
            // Port A & B Controller
            if ((in_mat_wr_addra >= NUM_A_ELEMENTS-1) && (w_mat_wr_addra >= NUM_B_ELEMENTS-1)) begin // enable AFTER BOTH of BRAMs are filled is HIGH
                en_module <= 1'b1;// Control write enable of each BRAMs for both ports
            end

            // Internal Reset Control
            if (en_module) begin
                write_phase     <= 1'b0;
                internal_rst_n  <= ~systolic_finish_wrap;
            end

            if (systolic_finish_wrap) begin
                internal_reset_acc <= ~acc_done_wrap;
            end

            // Counter Update
            if (systolic_finish_wrap) begin
                // counter indicates the matrix C element iteration
                if (counter == ((INNER_DIMENSION/BLOCK_SIZE) - 1)) begin 
                    counter <=0;
                end
                else begin
                    counter <= counter + 1;
                end
                // Address controller
                /* These are the old controllers when I use only 1 port for input matrix
                in_mat_rd_addrb <= counter + (INNER_DIMENSION/BLOCK_SIZE)*counter_row;
                we_mat_rd_addrb <= counter + (INNER_DIMENSION/BLOCK_SIZE)*counter_col;
                */
                in_mat_rd_addra <= counter + (INNER_DIMENSION/BLOCK_SIZE)*(counter_row*2); // same as the old one but port A used for even addresses (starting from 0)
                in_mat_rd_addrb <= counter + (INNER_DIMENSION/BLOCK_SIZE)*(counter_row*2 + 1); // and port B used for odd addresses (starting from 1)`
                w_mat_rd_addrb = counter + (INNER_DIMENSION/BLOCK_SIZE)*counter_col;
            end

            // Column/Row Update
            if (acc_done_wrap_rising) begin
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
                end
            end
        end
    end

    // Assign out_valid port when first acc_done_wrap is 1
    assign out_valid = counter_acc_done;
    // Done assigning based on flag
    assign done = (flag == MAX_FLAG);

endmodule
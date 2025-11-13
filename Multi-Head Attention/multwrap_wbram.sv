// multwrap_wbram.sv
// This used to wrap multi_matmul_wrapper.sv + its corresponding BRAMs
import linear_proj_pkg::*;

module multwrap_wbram #(
    parameter string MEM_INIT_FILE = "mem_q1.mem",
    localparam MEMORY_SIZE_B = INNER_DIMENSION*B_OUTER_DIMENSION*WIDTH_B,
    localparam DATA_WIDTH_B  = WIDTH_B*CHUNK_SIZE*NUM_CORES_B*TOTAL_MODULES,
    localparam int ADDR_WIDTH_B = $clog2(MEMORY_SIZE_B/DATA_WIDTH_B) 
) (
    input logic clk, en_module,
    input logic internal_rst_n, rst_n, // internal_rst_n used for multimatmul, while rst_n used for the BRAM
    input logic internal_reset_acc,
    input logic w_mat_enb,
    input logic [ADDR_WIDTH_B-1:0] w_mat_addrb,
    input logic [WIDTH_A*CHUNK_SIZE*NUM_CORES_A-1:0] in_multi_matmul [TOTAL_INPUT_W],

    output logic acc_done_wrap, systolic_finish_wrap,
    output logic [(WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A*NUM_CORES_B*TOTAL_MODULES)-1:0] out_multwrap_wbram [TOTAL_INPUT_W]
);

    // *** Key Weight BRAM **********************************************************
    // xpm_memory_tdpram: True Dual Port RAM
    // Xilinx Parameterized Macro, version 2018.3
    logic [WIDTH_B*CHUNK_SIZE*NUM_CORES_B*TOTAL_MODULES-1:0] w_mat_doutb;
    
    xpm_memory_tdpram
    #(
        // Common module parameters
        .MEMORY_SIZE(MEMORY_SIZE_B),           // DECIMAL, 
        .MEMORY_PRIMITIVE("auto"),           // String
        .CLOCKING_MODE("common_clock"),      // String, "common_clock"
        .MEMORY_INIT_FILE(MEM_INIT_FILE),     // String
        .MEMORY_INIT_PARAM("0"),             // String      
        .USE_MEM_INIT(1),                    // DECIMAL
        
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
    xpm_memory_tdpram_inst
    (
        // Port A module ports
        .clka(clk),
        .rsta(~rst_n),
        .ena(1'b0), 
        .wea(),
        .addra(), 
        .dina(),
        .douta(),
        
        // Port B module ports
        .clkb(clk),
        .rstb(~rst_n),
        .enb(w_mat_enb),
        .web(), 
        .addrb(w_mat_addrb),
        .dinb(),
        .doutb(w_mat_doutb) // For now, we only use port B to read
    );


    // *** Multimatmul wrapper generation **********************************************************
    multi_matmul_wrapper #(
        .WIDTH_A(WIDTH_A),
        .FRAC_WIDTH_A(FRAC_WIDTH_A),
        .WIDTH_B(WIDTH_B),
        .FRAC_WIDTH_B(FRAC_WIDTH_B),
        .WIDTH_OUT(WIDTH_OUT),
        .FRAC_WIDTH_OUT(FRAC_WIDTH_OUT),
        .BLOCK_SIZE(BLOCK_SIZE),
        .CHUNK_SIZE(CHUNK_SIZE),
        .INNER_DIMENSION(INNER_DIMENSION),
        .TOTAL_MODULES(TOTAL_MODULES),
        .TOTAL_INPUT_W(TOTAL_INPUT_W),
        .NUM_CORES_A(NUM_CORES_A),
        .NUM_CORES_B(NUM_CORES_B)
    ) multwrap_inst (
        .clk(clk),
        .rst_n(internal_rst_n),
        .en(en_module),
        .reset_acc(internal_reset_acc),
        .input_w(in_multi_matmul), 
        .input_n(w_mat_doutb), 
        .acc_done_wrap(acc_done_wrap), 
        .systolic_finish_wrap(systolic_finish_wrap),
        .out_multi_matmul(out_multwrap_wbram)
    );

endmodule
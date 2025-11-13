// top_linear_projection.sv
// Top module for linear_projection (keys + matmul modules) + controller + input BRAM
import linear_proj_pkg::*;

module top_linear_projection #(
) (
    input logic clk, rst_n,
    input logic in_mat_ena,
    input logic in_mat_wea,
    input logic [ADDR_WIDTH_A-1:0] in_mat_wr_addra,
    input logic [DATA_WIDTH_A-1:0] in_mat_dina,

    input logic in_mat_enb,
    input logic in_mat_web,
    input logic [ADDR_WIDTH_A-1:0] in_mat_wr_addrb,
    input logic [DATA_WIDTH_A-1:0] in_mat_dinb,

    output logic xxx
);
    // ************************** Controller **************************
    linear_proj_ctrl #(
        .MEMORY_SIZE_A(MEMORY_SIZE_A),
        .DATA_WIDTH_A(DATA_WIDTH_A),
        .ADDR_WIDTH_A(ADDR_WIDTH_A)
    ) linear_proj_ctrl (
        .clk(clk), .rst_n(rst_n),
        // For port A Input Matrix
        .in_mat_ena(in_mat_ena), .in_mat_wea(in_mat_wea),
        .in_mat_wr_addra(in_mat_wr_addra),
        .

    );

    // ************************** Input BRAM **************************
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
        .ena(),
        .wea(),
        .addra(), 
        .dina(),
        .douta(),
        
        // Port B module ports
        .clkb(clk),
        .rstb(~rst_n),
        .enb(),
        .web(), 
        .addrb(), 
        .dinb(),
        .doutb()
    );

    // ************************** Linear Projection **************************
    linear_projection (
        .clk(clk), .rst_n(rst_n),
        .w_mat_enb_q(),
        .w_mat_addrb_q(),
        .w_mat_enb_k(),
        .w_mat_addrb_k(),
        .w_mat_enb_v(),
        .w_mat_addrb_v(),

        .acc_done_all(), .systolic_finish_all(),
        ...
    )

endmodule
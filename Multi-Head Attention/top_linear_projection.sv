// top_linear_projection.sv
// Top module for linear_projection (keys + matmul modules) + controller + input BRAM
import linear_proj_pkg::*;

module top_linear_projection #(
    parameter OUT_KEYS = WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A*NUM_CORES_B*TOTAL_MODULES
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

    output logic [(OUT_KEYS)-1:0] out_q1 [TOTAL_INPUT_W],
    output logic [(OUT_KEYS)-1:0] out_q2 [TOTAL_INPUT_W],
    output logic [(OUT_KEYS)-1:0] out_q3 [TOTAL_INPUT_W],
    output logic [(OUT_KEYS)-1:0] out_q4 [TOTAL_INPUT_W],

    output logic [(OUT_KEYS)-1:0] out_k1 [TOTAL_INPUT_W],
    output logic [(OUT_KEYS)-1:0] out_k2 [TOTAL_INPUT_W],
    output logic [(OUT_KEYS)-1:0] out_k3 [TOTAL_INPUT_W],
    output logic [(OUT_KEYS)-1:0] out_k4 [TOTAL_INPUT_W],

    output logic [(OUT_KEYS)-1:0] out_v1 [TOTAL_INPUT_W],
    output logic [(OUT_KEYS)-1:0] out_v2 [TOTAL_INPUT_W],
    output logic [(OUT_KEYS)-1:0] out_v3 [TOTAL_INPUT_W],
    output logic [(OUT_KEYS)-1:0] out_v4 [TOTAL_INPUT_W]
    
    output logic out_valid, done
);
    // **************************** Wires ****************************
    logic w_mat_enb_mux;
    logic [ADDR_WIDTH_B-1:0] w_mat_addrb_mux;

    logic in_mat_ena_mux, in_mat_enb_mux;
    logic in_mat_wea_mux, in_mat_web_mux;
    logic [ADDR_WIDTH_A-1:0] in_mat_addra_mux, in_mat_addrb_mux;

    logic enable_linear_proj;
    logic internal_rst_n_ctrl, internal_reset_acc_ctrl;

    logic [DATA_WIDTH_A-1:0] in_mat_douta;
    logic [DATA_WIDTH_A-1:0] in_mat_doutb;

    logic acc_done_all_sig;
    logic systolic_finish_all_sig;

    // ************************** Controller **************************
    linear_proj_ctrl linear_proj_ctrl (
        .clk(clk), .rst_n(rst_n),
        .acc_done_wrap(acc_done_all_sig), 
        .systolic_finish_wrap(systolic_finish_all_sig),

        // For port A & B Input Matrix
        .in_mat_ena(in_mat_ena), .in_mat_wea(in_mat_wea),
        .in_mat_wr_addra(in_mat_wr_addra),
        .in_mat_enb(in_mat_enb), .in_mat_web(in_mat_web),
        .in_mat_wr_addrb(in_mat_wr_addrb),

        // Output
        .in_mat_ena_mux(in_mat_ena_mux),
        .in_mat_enb_mux(in_mat_enb_mux),
        .in_mat_wea_mux(in_mat_wea_mux),
        .in_mat_web_mux(in_mat_web_mux),
        .in_mat_addra_mux(in_mat_addra_mux),
        .in_mat_addrb_mux(in_mat_addrb_mux),
        .w_mat_enb_mux(w_mat_enb_mux),
        .w_mat_addrb_mux(w_mat_addrb_mux),

        .enable_linear_proj(enable_linear_proj),
        .internal_rst_n_ctrl(internal_rst_n_ctrl),
        .internal_reset_acc_ctrl(internal_reset_acc_ctrl),
        .out_valid(out_valid),
        .done(done)
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
        .ena(in_mat_ena_mux),
        .wea(in_mat_wea_mux),
        .addra(in_mat_addra_mux), 
        .dina(in_mat_dina),
        .douta(in_mat_douta),
        
        // Port B module ports
        .clkb(clk),
        .rstb(~rst_n),
        .enb(in_mat_enb_mux),
        .web(in_mat_web_mux), 
        .addrb(in_mat_addrb_mux), 
        .dinb(in_mat_dinb),
        .doutb(in_mat_doutb)
    );

    // ************************** Linear Projection **************************
    // Hook up read results into multi_matmul_wrapper input array
    // We'll map: input_w[0] <= in_mat_douta (even rows), input_w[1] <= in_mat_doutb (odd rows)
    logic [WIDTH_A*CHUNK_SIZE*NUM_CORES_A-1:0] in_multi_matmul [TOTAL_INPUT_W];
    genvar i;
    generate
        for (i = 0; i < TOTAL_INPUT_W; i = i + 1) begin
            if (i == 0) assign in_multi_matmul[i] = in_mat_douta;
            if (i == 1) assign in_multi_matmul[i] = in_mat_doutb;
        end
    endgenerate

    linear_projection #(
        .OUT_KEYS(OUT_KEYS)
    )(
        .clk(clk), .rst_n(rst_n),
        .en_module(enable_linear_proj),
        .internal_rst_n(internal_rst_n_ctrl),
        .internal_reset_acc(internal_reset_acc_ctrl),
        
        .in_multi_matmul(in_multi_matmul),

        .w_mat_enb_q(w_mat_enb_mux),
        .w_mat_enb_k(w_mat_enb_mux),
        .w_mat_enb_v(w_mat_enb_mux),
        .w_mat_addrb_q(w_mat_addrb_mux),
        .w_mat_addrb_k(w_mat_addrb_mux),
        .w_mat_addrb_v(w_mat_addrb_mux),

        // Back to controller
        .acc_done_all(acc_done_all_sig),
        .systolic_finish_all(systolic_finish_all_sig),

        ..out_q1(out_q1),
        .out_q2(out_q2),
        .out_q3(out_q3),
        .out_q4(out_q4),

        .out_k1(out_k1),
        .out_k2(out_k2),
        .out_k3(out_k3),
        .out_k4(out_k4),

        .out_v1(out_v1),
        .out_v2(out_v2),
        .out_v3(out_v3),
        .out_v4(out_v4)
    );

endmodule
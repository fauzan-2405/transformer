// top_multihead_attention.sv
// top module that contains top_linear_projection + top_self_attention_head

module top_multihead_attention #(
    parameter OUT_KEYS = WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A*NUM_CORES_B*TOTAL_MODULES
) (
    input clk, rst_n,
    output XXX
);
    // ************************** LINEAR PROJECTION **************************
    logic [OUT_KEYS-1:0] sig_out_q1, sig_out_q2, sig_out_q3, sig_out_q4;
    logic [OUT_KEYS-1:0] sig_out_k1, sig_out_k2, sig_out_k3, sig_out_k4;
    logic [OUT_KEYS-1:0] sig_out_v1, sig_out_v2, sig_out_v3, sig_out_v4;

    top_linear_projection #(
        .OUT_KEYS(OUT_KEYS) 
    ) linear_projection_inst (
        .clk(clk), .rst_n(rst_n),
        ...
        ...
        .out_q1(sig_out_q1)
        .out_q2(sig_out_q2)
        .out_q3(sig_out_q3)
        .out_q4(sig_out_q4)

        .out_k1(sig_out_k1)
        .out_k2(sig_out_k2)
        .out_k3(sig_out_k3)
        .out_k4(sig_out_k4)

        .out_v1(sig_out_v1)
        .out_v2(sig_out_v2)
        .out_v3(sig_out_v3)
        .out_v4(sig_out_v4)
    );

    // ************************** Temporary BRAM **************************
    // ************ for buffering before self-attention head **************
    xpm_memory_tdpram
    #(
        // Common module parameters
        .MEMORY_SIZE(MEMORY_SIZE_A),           // DECIMAL, 
        
        // Port A module parameters
        .WRITE_DATA_WIDTH_A(DATA_WIDTH_A), // DECIMAL, varying based on the matrix size
        .READ_DATA_WIDTH_A(DATA_WIDTH_A),  // DECIMAL, varying based on the matrix size
        .BYTE_WRITE_WIDTH_A(DATA_WIDTH_A), // DECIMAL, how many bytes in WRITE_DATA_WIDTH_A, use $clog2 maybe?
        .ADDR_WIDTH_A(ADDR_WIDTH_A),         // DECIMAL, clog2(MEMORY_SIZE_A/WRITE_DATA_WIDTH_A)

        // Port B module parameters  
        .WRITE_DATA_WIDTH_B(DATA_WIDTH_A), // DECIMAL, varying based on the matrix size
        .READ_DATA_WIDTH_B(DATA_WIDTH_A),  // DECIMAL, varying based on the matrix size
        .BYTE_WRITE_WIDTH_B(DATA_WIDTH_A), // DECIMAL, how many bytes in WRITE_DATA_WIDTH_A
        .ADDR_WIDTH_B(ADDR_WIDTH_A),         // DECIMAL, clog2(MEMORY_SIZE/WRITE_DATA_WIDTH_A)
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


endmodule
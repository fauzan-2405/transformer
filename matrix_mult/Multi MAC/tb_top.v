`timescale 1ns / 1ps
`include "top.v"

module tb_top();
parameter WIDTH = 16,
parameter FRAC_WIDTH = 8,
parameter BLOCK_SIZE = 2, // The size of systolic array dimension (N x N)
parameter CHUNK_SIZE = 4,
parameter INNER_DIMENSION = 4, // The same number of rows in one matrix and same number of columns in the other matrix
// W stands for weight
parameter W_OUTER_DIMENSION = 6,
// I stands for input
parameter I_OUTER_DIMENSION = 6,
parameter ROW_SIZE_MAT_C = I_OUTER_DIMENSION / BLOCK_SIZE,
parameter COL_SIZE_MAT_C = W_OUTER_DIMENSION / BLOCK_SIZE,
// To calculate the max_flag, the formula is:
// ROW_SIZE_MAT_C = (ROW_SIZE_MAT_A / BLOCK_SIZE)
// COL_SIZE_MAT_C = (COL_SIZE_MAT_B / BLOCK_SIZE) 
// MAX_FLAG = ROW_SIZE_MAT_C * COL_SIZE_MAT_C
parameter MAX_FLAG = ROW_SIZE_MAT_C * COL_SIZE_MAT_C;

localparam T = 10;

reg clk;
reg rst_n;

reg start;
wire done;

reg wb_ena;
reg [11:0] wb_addra;
reg [WIDTH*CHUNK_SIZE-1:0] wb_dina;
reg [7:0] wb_wea;

reg in_ena;
reg [13:0] in_addra;
reg [WIDTH*CHUNK_SIZE-1:0] in_dina;
reg [7:0] in_wea;

wire [WIDTH*CHUNK_SIZE-1:0] out_bram;

top top_inst
(
    .clk(clk),
    .rst_n(rst_n),
    .ready(ready),
    .start(start),
    //.done(done),
    .wb_ena(wb_ena),
    .wb_addra(wb_addra),
    .wb_dina(wb_dina),
    .wb_wea(wb_wea),
    .in_ena(in_ena),
    .in_addra(in_addra),
    .in_dina(in_dina),
    .in_wea(in_wea),
    .out_bram(out_bram)
);

always
begin
    clk = 0;
    #(T/2);
    clk = 1;
    #(T/2);
end

initial
begin
    start = 0;
    wb_ena = 1;
    wb_addra = 0;
    wb_dina = 0;
    wb_wea = 0;
    in_ena = 1;
    in_addra = 0;
    in_dina = 0;
    in_wea = 0;
    
    rst_n = 0;
    #(T*5);
    rst_n = 1;
    #(T*5);
    
    // *** Testvector 1 ***
    // Write weight and bias
    wb_wea = 8'hff;
    wb_addra = 0;
    wb_dina = 64'b0000000000000000_1011000001111010_0000010101111010_0000010101111010;
    #T;     
    wb_addra = 1;
    wb_dina = 64'b0000000000000000_1111110001100110_0000001111100001_0000001100010100;
    #T;
    wb_addra = 2;  
    wb_dina = 64'b0000000000000000_1111110001110000_0000001010001111_0000010000110011;
    #T;
    wb_addra = 3;  
    wb_dina = 64'b1111010110100011_0000000001010001_1111101011000010_0001110001110000;
    #T;
    wb_addra = 4;  
    wb_dina = 64'b0000000011001100_0000011111100001_0000011010000101_1110001110011001;
    #T;
    wb_wea = 8'h00;
    wb_addra = 0;  
    wb_dina = 0;
    #T;
    
    // Write input
    k_wea = 8'hff;
    k_addra = 0;
    k_dina = 64'b0001010000000000_0001010000000000_0010000000000000_0010000000000000;
    #T; 
    k_wea = 8'hff;
    k_addra = 1;
    k_dina = 64'b0001010000000000_0010000000000000_0001010000000000_0010000000000000;
    #T;
    k_wea = 8'h00;
    k_addra = 0;  
    k_dina = 0;
    #T;
    
    // Start module
    start = 1;
    #T;
    start = 0;
    #T;
    
    #(T*50);
end

endmodule
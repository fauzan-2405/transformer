// Testbench for top.v and top_v2.v

`timescale 1ns / 1ps

module tb_top;
// clog2 function
function integer clog2;
    input integer value;
    begin  
        value = value-1;
        for (clog2=0; value>0; clog2=clog2+1)
        value = value>>1;
    end
endfunction

parameter WIDTH = 16;
parameter FRAC_WIDTH = 8;
parameter BLOCK_SIZE = 2; // The size of systolic array dimension (N x N)
parameter CHUNK_SIZE = 4;
parameter INNER_DIMENSION = 4; // The same number of rows in one matrix and same number of columns in the other matrix
// W stands for weight
parameter W_OUTER_DIMENSION = 6;
// I stands for input
parameter I_OUTER_DIMENSION = 8;
parameter ROW_SIZE_MAT_C = I_OUTER_DIMENSION / BLOCK_SIZE;
parameter COL_SIZE_MAT_C = W_OUTER_DIMENSION / BLOCK_SIZE;
// To calculate the max_flag, the formula is:
// ROW_SIZE_MAT_C = (ROW_SIZE_MAT_A / BLOCK_SIZE)
// COL_SIZE_MAT_C = (COL_SIZE_MAT_B / BLOCK_SIZE) 
// MAX_FLAG = ROW_SIZE_MAT_C * COL_SIZE_MAT_C
parameter NUM_CORES = (INNER_DIMENSION == 2754) ? 9 :
                               (INNER_DIMENSION == 256)  ? 8 :
                               (INNER_DIMENSION == 200)  ? 5 :
                               (INNER_DIMENSION == 64)   ? 4 : 2;
parameter MAX_FLAG = ROW_SIZE_MAT_C * COL_SIZE_MAT_C / NUM_CORES;
parameter ADDR_WIDTH_I = clog2((INNER_DIMENSION*I_OUTER_DIMENSION*WIDTH)/(WIDTH*CHUNK_SIZE*NUM_CORES)); // Used for determining the width of wb and input address and other parameters in BRAMs
parameter ADDR_WIDTH_W = clog2((INNER_DIMENSION*W_OUTER_DIMENSION*WIDTH)/(WIDTH*CHUNK_SIZE));

reg clk;
reg rst_n;

reg start;

reg wb_ena;
reg [ADDR_WIDTH_W-1:0] wb_addra;
reg [WIDTH*CHUNK_SIZE-1:0] wb_dina;
reg [7:0] wb_wea;

reg in_ena;
reg [ADDR_WIDTH_I-1:0] in_addra;
reg [WIDTH*CHUNK_SIZE*NUM_CORES-1:0] in_dina;
reg [7:0] in_wea;

wire done;
// DONT FORGET TO CHANGE THIS
wire [(WIDTH*CHUNK_SIZE)-1:0] out_bram; // For top.v
wire [(WIDTH*CHUNK_SIZE*NUM_CORES)-1:0] out_bram; // For top_v2.v


top #( // DONT FORGET TO CHANGE THIS TOO
    .WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH), .BLOCK_SIZE(BLOCK_SIZE), .CHUNK_SIZE(CHUNK_SIZE),
    .INNER_DIMENSION(INNER_DIMENSION), .W_OUTER_DIMENSION(W_OUTER_DIMENSION), .I_OUTER_DIMENSION(I_OUTER_DIMENSION), 
    .ROW_SIZE_MAT_C(ROW_SIZE_MAT_C), .COL_SIZE_MAT_C(COL_SIZE_MAT_C), .NUM_CORES(NUM_CORES), .MAX_FLAG(MAX_FLAG),
    .ADDR_WIDTH_W(ADDR_WIDTH_W), .ADDR_WIDTH_I(ADDR_WIDTH_I)
) top_inst ( 
    .clk(clk),
    .rst_n(rst_n),
    //.ready(ready),
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
    
    .done(done),
    .out_bram(out_bram)
);

always #5 clk = ~clk;

initial
begin
    clk = 0;
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
    #50
    rst_n = 1;
    #5
    start = 1;
    wb_wea = 8'hFF;
    in_wea = 8'hFF;

    wb_addra = 0;
    wb_dina = 64'h0200020001000100;
    in_addra = 0;
    in_dina = 128'h02000100020002000100020001000100;
    #10

    wb_addra = 1;
    wb_dina = 64'h0200010002000100;
    in_addra = 1;
    in_dina = 128'h01000100020002000100010001000200;
    #10
    
    wb_addra = 2;
    wb_dina = 64'h0100010001000100;
    in_addra = 2;
    in_dina = 128'h00000100020001000100010001000200;
    #10

    wb_addra = 3;
    wb_dina = 64'h0200010001000200;
    in_addra = 3;
    in_dina = 128'h01000200010001000200010002000100;
    #10

    wb_addra = 4;
    wb_dina = 64'h0100010001000100;
    in_wea = 8'h00;
    #10

    wb_addra = 5;
    wb_dina = 64'h0200010002000100;
    #10

    wb_wea = 8'h00;
    #500;
    

end

endmodule
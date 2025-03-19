`timescale 1ns / 1ps
`include "core.v"
`include "RAM1_inputA.v"
`include "RAM1_inputB.v"

module tb_core;
parameter WIDTH = 16;
parameter FRAC_WIDTH = 8;
parameter BLOCK_SIZE = 2; // The size of systolic array dimension (N x N)
parameter CHUNK_SIZE = 4;
parameter INNER_DIMENSION = 8;// The same number of rows in one matrix and same number of columns in the other matrix
// If the matrices are NOT symmetrical
parameter ROW_SIZE_MAT_A = 16;
parameter COL_SIZE_MAT_B = 10;
// Matrix C parameter
parameter ROW_SIZE_MAT_C = ROW_SIZE_MAT_A / BLOCK_SIZE;
parameter COL_SIZE_MAT_C = COL_SIZE_MAT_B / BLOCK_SIZE;


// Be aware that MAT C is represented by sys array output NOT the actual resulting matix

// To calculate the max_flag, the formula is:
// ROW_SIZE_MAT_C = (ROW_SIZE_MAT_A / BLOCK_SIZE)
// COL_SIZE_MAT_C = (COL_SIZE_MAT_B / BLOCK_SIZE) 
// MAX_FLAG = ROW_SIZE_MAT_C * COL_SIZE_MAT_C
parameter MAX_FLAG = ROW_SIZE_MAT_C * COL_SIZE_MAT_C;

reg clk;
reg en;
reg rst_n;
reg reset_acc;
reg [WIDTH-1:0] counter_A, counter_B;

//
reg [WIDTH-1:0] counter;
reg [15:0] counter_row;
reg [15:0] counter_col;
reg [WIDTH-1:0] flag; // Used to track the sys array index in the resulting matrix 

wire accumulator_done, systolic_finish;
wire [(WIDTH*CHUNK_SIZE)-1:0] out;
wire [(WIDTH*CHUNK_SIZE)-1:0] outputA, outputB;

RAM1_inputA #(.WIDTH(WIDTH), .INNER_DIMENSION(INNER_DIMENSION), .CHUNK_SIZE(CHUNK_SIZE), .OUTER_DIMENSION(ROW_SIZE_MAT_A)) RAM1_inst_A (
    .clk(clk), .counter_A(counter_A),
    .outputA(outputA)
);

RAM1_inputB #(.WIDTH(WIDTH), .INNER_DIMENSION(INNER_DIMENSION), .CHUNK_SIZE(CHUNK_SIZE), .OUTER_DIMENSION(COL_SIZE_MAT_B)) RAM1_inst_B (
    .clk(clk), .counter_B(counter_B),
    .outputB(outputB)
);

toplevel #(.WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH), .BLOCK_SIZE(BLOCK_SIZE), .INNER_DIMENSION(INNER_DIMENSION), .CHUNK_SIZE(CHUNK_SIZE)) top_inst (
    .clk(clk), .rst_n(rst_n), .reset_acc(reset_acc), .en(en),
    .input_w(outputA), .input_n(outputB), 
    .accumulator_done(accumulator_done), 
    .systolic_finish(systolic_finish),
    .out(out)
);


initial begin
    rst_n <= 0;
	clk <= 0;
	en <=0;
    reset_acc <= 0;
    counter_A <= 0;
    counter_B <= 0;
    counter <= 0;
    counter_row <= 0;
    counter_col <= 0;
    flag <= 0;
    #10
	rst_n <= 1; // This will be overwrote by the next always block
	reset_acc <= 0;
	#40
	en <= 1;
end


always @(posedge clk) begin
	if (en) begin
		if (systolic_finish == 1) begin
			rst_n <= 0;
		end else begin // kalau 0
			rst_n <= 1;
		end
	end
end


always @(posedge systolic_finish) begin
    if (accumulator_done == 1) begin
        reset_acc <= 0;
    end else begin
        reset_acc <= 1;
    end
end


initial begin
    forever begin
        #5 clk <= ~clk;
    end
end

// We decided to be input stationary (input A)
always @(posedge systolic_finish) begin
    counter_A <= counter + (INNER_DIMENSION/BLOCK_SIZE)*counter_row;
    counter_B <= counter + (INNER_DIMENSION/BLOCK_SIZE)*counter_col;
end

always @(posedge systolic_finish) begin
	if (counter == ((INNER_DIMENSION/BLOCK_SIZE) - 1)) begin
		counter <=0;
	end
	else begin
		counter <= counter + 1;
	end
end

// Check if we already at the end of the MAT C column
always @(posedge accumulator_done) begin 
	if (counter_col == (COL_SIZE_MAT_C - 1)) begin
		counter_col <= 0;
		counter_row <= counter_row + 1;
	end else begin
		counter_col <= counter_col + 1;
	end
end


// Flag to see the output
always @(posedge accumulator_done) begin 
	if (flag == MAX_FLAG) begin // Change the max flag to your desired flag for seeing the output
		flag <= 0;
		$fclose(f); 
		$finish;
	end else begin
		flag <= flag + 1;
	end
end

integer f;
// data parsing section
initial begin
    f = $fopen("output.txt","w");
end


always @(posedge accumulator_done) begin //address offset generation
        $fwrite(f,"%h\n",out);
end


initial begin
	$dumpfile("tb_core.vcd");
	$dumpvars(0, tb_core);
end







endmodule


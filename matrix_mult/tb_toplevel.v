`timescale 1ns / 1ps
`include "toplevel.v"
`include "RAM2_input.v"

module tb_toplevel;
parameter WIDTH = 16;
parameter FRAC_WIDTH = 8;
parameter BLOCK_SIZE = 2; // The size of systolic array dimension (N x N)
parameter CHUNK_SIZE = 4;
parameter INNER_DIMENSION = 4 ;// The same number of rows in one matrix and same number of columns in the other matrix
// If the matrices are symmetrical
parameter OUTER_DIMENSION = 6; // The size of rows/cols of the matrix outside of inner dimension
// If not
parameter ROW_SIZE_MAT_A = 6;
parameter COL_SIZE_MAT_B = 6;
// Matrix C parameter
parameter ROW_SIZE_MAT_C = ROW_SIZE_MAT_A / BLOCK_SIZE;
parameter COL_SIZE_MAT_C = COL_SIZE_MAT_B / BLOCK_SIZE;


// Be aware that MAT C is represented by sys array output NOT the actual resulting matix

// To calculate the max_flag, the formula is:
// ROW_SIZE_MAT_C = (ROW_SIZE_MAT_A / BLOCK_SIZE)
// COL_SIZE_MAT_C = (COL_SIZE_MAT_B / BLOCK_SIZE) 
// MAX_FLAG = ROW_SIZE_MAT_C * COL_SIZE_MAT_C
parameter MAX_FLAG = 9;

reg clk;
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
wire [(WIDTH*CHUNK_SIZE)-1:0] output1, output2;

RAM2_input #(.WIDTH(WIDTH), .INNER_DIMENSION(INNER_DIMENSION), .CHUNK_SIZE(CHUNK_SIZE), .OUTER_DIMENSION(OUTER_DIMENSION)) RAM2_inst (
    .clk(clk), .counter_A(counter_A), .counter_B(counter_B),
    .output1(output1), .output2(output2)
);

toplevel #(.WIDTH(WIDTH), .FRAC_WIDTH(FRAC_WIDTH), .BLOCK_SIZE(BLOCK_SIZE), .INNER_DIMENSION(INNER_DIMENSION), .CHUNK_SIZE(CHUNK_SIZE)) top_inst (
    .clk(clk), .rst_n(rst_n), .reset_acc(reset_acc), 
    .input_w(output1), .input_n(output2), 
    .accumulator_done(accumulator_done), 
    .systolic_finish(systolic_finish),
    .out(out)
);


initial begin
    rst_n <= 0;
	clk <= 0;
    reset_acc <= 0;
    counter_A <= 0;
    counter_B <= 0;
    counter <= 0;
    counter_row <= 0;
    counter_col <= 0;
    flag <= 0;
    #5
	rst_n <= ~systolic_finish;
	reset_acc <= 0;
end


always @(posedge clk) begin
    if (systolic_finish == 1) begin
        rst_n <= 0;
    end else begin // kalau 0
		rst_n <= 1;
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
    counter_A <= counter + BLOCK_SIZE*counter_row;
    counter_B <= counter + BLOCK_SIZE*counter_col;
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
	$dumpfile("tb_toplevel.vcd");
	$dumpvars(0, tb_toplevel);
end







endmodule


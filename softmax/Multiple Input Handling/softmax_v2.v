
module softmax_v2 #(
    parameter WIDTH         = 32,
    parameter FRAC_WIDTH    = 16,
    parameter TOTAL_ELEMENT  = 4
)  (
    input wire clk,
    input wire rst_n, 
    input wire start,
    // =====input x=======
    input wire signed [WIDTH-1:0] X1, X2, X3, X4,
    // =====output y======
    output wire signed [WIDTH-1:0] Y1, Y2, Y3,Y4,
    output wire done_out
    );

    // Local Parameters
    localparam IDLE = 2'b00, BUSY = 2'b01, DONE = 2'b10;

    // Wires and registers
    reg [1:0] state_reg, state_next;
    reg done;
    wire signed [WIDTH-1:0] exp1, exp2, exp3, exp4;
    wire signed [WIDTH-1:0] sum_exp; 
    wire signed [WIDTH-1:0] ln_out;
    wire signed [WIDTH-1:0] lg1, lg2, lg3, lg4;
    
    // modul max ========================================
    reg signed [WIDTH-1:0] X1_in, X2_in, X3_in, X4_in;
     
    // cek max untuk normalisasi
//    reg signed [WIDTH-1:0] max_val;
//    always @(*) begin
//        max_val = X1;
//        if (X2 > max_val) max_val = X2;
//        if (X3 > max_val) max_val = X3;
//        if (X4 > max_val) max_val = X4;
//    end
//    assign X1_in = X1 - max_val;
//    assign X2_in = X2 - max_val;
//    assign X3_in = X3 - max_val;
//    assign X4_in = X4 - max_val;
    //=============================================================
   
    
   

    // FSM sequential: state_reg transition
    always @(posedge clk) begin
        if (!rst_n)
            state_reg <= IDLE;
        else
            state_reg <= state_next;
    end
    // Simulasi proses multicycle: lakukan operasi di akhir BUSY
    always @(posedge clk) begin
        if (!rst_n) begin
            X1_in <= 32'd0;
            X2_in <= 32'd0;
            X3_in <= 32'd0;
            X4_in <= 32'd0;
//            result <= 32'd0;
            end
        else if (state_reg == BUSY) begin 
//            max_val = X1;
//                if (X2 > max_val) max_val = X2;
//                if (X3 > max_val) max_val = X3;
//                if (X4 > max_val) max_val = X4;
//            X1_in <= X1 - max_val;
//            X2_in <= X2 - max_val;
//            X3_in <= X3 - max_val;
//            X4_in <= X4 - max_val;
                X1_in <= X1;
                X2_in <= X2;
                X3_in <= X3;
                X4_in <= X4;
            end
    end
    
    // FSM combinational: next state_reg logic dan output
    always @(*) begin
        // Default
        state_next = state_reg;
        done = 1'b0;

        case (state_reg)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    state_next = BUSY;
                end    
            end
            BUSY: begin
                state_next = DONE;
            end
            DONE: begin
                done = 1'b1;
                state_next = IDLE;
            end
        endcase
    end
    assign done_out = done;
     //====input dari norm X =======================================
    
    exp #(.WIDTH(WIDTH)) exp_1
        (.X(X1_in),
        .Y(exp1)
    );
    exp #(.WIDTH(WIDTH)) exp_2
        (.X(X2_in),
        .Y(exp2)
    );
    exp #(.WIDTH(WIDTH)) exp_3
        (.X(X3_in),
        .Y(exp3)
    );
    exp #(.WIDTH(WIDTH)) exp_4
        (.X(X4_in),
        .Y(exp4)
    );    
    assign sum_exp = exp1+exp2+exp3+exp4;
    
    lnu LNU (.x_in(sum_exp),
             .ln_out(ln_out));
             
    assign lg1 = X1_in - ln_out;
    assign lg2 = X2_in - ln_out;
    assign lg3 = X3_in - ln_out;
    assign lg4 = X4_in - ln_out;
    exp #(.WIDTH(WIDTH)) exp_5
        (.X(lg1),
        .Y(Y1)
    ); 
    exp #(.WIDTH(WIDTH)) exp_6
        (.X(lg2),
        .Y(Y2)
    ); 
    exp #(.WIDTH(WIDTH)) exp_7
        (.X(lg3),
        .Y(Y3)
    ); 
    exp #(.WIDTH(WIDTH)) exp_8
        (.X(lg4),
        .Y(Y4)
    ); 

endmodule

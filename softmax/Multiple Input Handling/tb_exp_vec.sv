`timescale 1ns/1ps

module tb_exp_vec;

    // Parameters
    localparam WIDTH     = 32;
    localparam FRAC      = 16;
    localparam TILE_SIZE = 4;
    localparam real SCALE = 65536.0; // 2^FRAC

    // DUT I/O
    reg  signed [WIDTH*TILE_SIZE-1:0] X_flat;
    wire signed [WIDTH*TILE_SIZE-1:0] Y_flat;

    // Instantiate DUT
    exp_vec #(
        .WIDTH(WIDTH),
        .FRAC(FRAC),
        .TILE_SIZE(TILE_SIZE),
        .USE_AMULT(0)
    ) dut (
        .X_flat(X_flat),
        .Y_flat(Y_flat)
    );

    // Test vectors (real values for checking)
    real X_real   [0:TILE_SIZE-1];
    real Y_expect [0:TILE_SIZE-1];
    real Y_actual [0:TILE_SIZE-1];

    integer i, msb, lsb;

    // Task: pack array of fixed-point values into flattened vector
    task pack_input;
        input real arr[];
        output reg signed [WIDTH*TILE_SIZE-1:0] pack_i;
        integer idx;
        reg signed [WIDTH-1:0] temp;
    begin
        pack_i = {WIDTH*TILE_SIZE{1'b0}};
        for (idx = 0; idx < TILE_SIZE; idx = idx + 1) begin
            temp = $rtoi(arr[idx] * SCALE);
            pack_i[(TILE_SIZE-1-idx)*WIDTH +: WIDTH] = temp;
        end
    end
    endtask

    // Task: unpack flattened output into array of real
    task unpack_output;
        input signed [WIDTH*TILE_SIZE-1:0] pack_o;
        output real arr[];
        integer idx;
        reg signed [WIDTH-1:0] temp;
    begin
        for (idx = 0; idx < TILE_SIZE; idx = idx + 1) begin
            temp = pack_o[(TILE_SIZE-1-idx)*WIDTH +: WIDTH];
            arr[idx] = temp / SCALE;
        end
    end
    endtask

    initial begin
        // Example inputs (in float)
        X_real[0] = 1.0;
        X_real[1] = -0.5;
        X_real[2] = 0.0;
        X_real[3] = 2;

        // Pack into flattened fixed-point input
        pack_input(X_real, X_flat);

        // Wait for combinational DUT to settle
        #1;

        // Compute reference outputs in double precision
        for (i = 0; i < TILE_SIZE; i = i + 1) begin
            Y_expect[i] = $exp(X_real[i]);
        end

        // Unpack DUT output
        unpack_output(Y_flat, Y_actual);

        $finish;
    end

endmodule


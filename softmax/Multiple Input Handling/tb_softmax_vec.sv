// tb_softmax_vec.sv
`timescale 1ns/1ps

module tb_softmax_vec;

  // Parameters (same as DUT)
  localparam WIDTH          = 32;
  localparam FRAC_WIDTH     = 16;
  localparam TOTAL_ELEMENTS = 16;   // keep small for sim
  localparam TILE_SIZE      = 4;    // easy debugging
  localparam USE_AMULT      = 0;

  // Clock & Reset
  reg clk;
  reg rst_n;

  // DUT inputs
  reg en;
  reg start;
  reg [TILE_SIZE*WIDTH-1:0] X_tile_in;
  reg tile_in_valid;

  // DUT outputs
  wire [TILE_SIZE*WIDTH-1:0] Y_tile_out;
  wire tile_out_valid;
  wire done;

  // Instantiate DUT
  softmax_vec #(
    .WIDTH(WIDTH),
    .FRAC_WIDTH(FRAC_WIDTH),
    .TOTAL_ELEMENTS(TOTAL_ELEMENTS),
    .TILE_SIZE(TILE_SIZE),
    .USE_AMULT(USE_AMULT)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .en(en),
    .start(start),
    .X_tile_in(X_tile_in),
    .tile_in_valid(tile_in_valid),
    .Y_tile_out(Y_tile_out),
    .tile_out_valid(tile_out_valid),
    .done(done)
  );

  // -------------------------------------------------
  // Clock generator
  // -------------------------------------------------
  initial begin
    clk = 0;
    forever #5 clk = ~clk; // 100MHz clock
  end

  // -------------------------------------------------
  // Stimulus
  // -------------------------------------------------
  integer i;
  reg [WIDTH-1:0] test_data [0:TOTAL_ELEMENTS-1];

  initial begin
    // Initialize signals
    rst_n        = 0;
    en           = 0;
    start        = 0;
    tile_in_valid= 0;
    X_tile_in    = 0;

    // Reset for a few cycles
    repeat (5) @(posedge clk);
    rst_n = 1;
    @(posedge clk);

    // Enable DUT
    en = 1;

    // Prepare some input data
    for (i = 0; i < TOTAL_ELEMENTS; i=i+1) begin
      test_data[i] = 32'h00010000 + i; // Q16.16 numbers: 1.0, 1.000015, ...
    end

    // Kick off
    start = 1;
    @(posedge clk);
    start = 0;

    // Feed the data tile by tile
    for (i = 0; i < TOTAL_ELEMENTS; i += TILE_SIZE) begin
      X_tile_in = {
        test_data[i+0],
        test_data[i+1],
        test_data[i+2],
        test_data[i+3]
      };
      tile_in_valid = 1;
      @(posedge clk);
      tile_in_valid = 0;
      @(posedge clk); // idle 1 cycle
    end

    // Wait for outputs
    wait (done);
    $display("Softmax computation finished at time %t", $time);

    // Extra wait to see final waveforms
    repeat (10) @(posedge clk);
    $finish;
  end

  // -------------------------------------------------
  // Output Monitor
  // -------------------------------------------------
  always @(posedge clk) begin
    if (tile_out_valid) begin
      $display("Time %t: Y_tile_out = %h", $time, Y_tile_out);
    end
  end

endmodule

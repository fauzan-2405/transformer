// top_multwrap_bram.sv
// Top that wraps multi_matmul_wrapper + input/weight BRAMs + internal controller
// Controller does strict phase separation: WRITE (external testbench writes BRAMs) -> READ+COMPUTE

`timescale 1ns/1ps
module top_multwrap_bram #(
    // local top overrides - keep consistent with linear_proj_pkg or override here
    parameter int TOTAL_INPUT_W = 2,
    parameter int TOTAL_MODULES  = 4
) (
    // import package symbols inside module (SystemVerilog)
    // NOTE: linear_proj_pkg must be compiled/specified to the toolchain before this file.
    input  logic clk,
    input  logic rst_n,
    input  logic en_module,            // external "start compute" from testbench

    // For Input Matrix BRAM (external write ports)
    input  logic in_mat_ena,
    input  logic in_mat_wea,
    input  logic [ADDR_WIDTH_A-1:0] in_mat_wr_addra,
    input  logic [WIDTH_A*CHUNK_SIZE*NUM_CORES_A-1:0] in_mat_dina,

    input  logic in_mat_enb,
    input  logic in_mat_web,
    input  logic [ADDR_WIDTH_A-1:0] in_mat_wr_addrb,
    input  logic [WIDTH_A*CHUNK_SIZE*NUM_CORES_A-1:0] in_mat_dinb,

    // For Weight Matrix BRAM (external write ports)
    input  logic w_mat_ena,
    input  logic w_mat_wea,
    input  logic [ADDR_WIDTH_B-1:0] w_mat_wr_addra,
    input  logic [WIDTH_B*CHUNK_SIZE*NUM_CORES_B*TOTAL_MODULES-1:0] w_mat_dina,

    input  logic w_mat_enb,
    input  logic w_mat_web,
    input  logic [ADDR_WIDTH_B-1:0] w_mat_wr_addrb,
    input  logic [WIDTH_B*CHUNK_SIZE*NUM_CORES_B*TOTAL_MODULES-1:0] w_mat_dinb,

    // Outputs
    output logic done,
    output logic out_valid,

    // outputs from multi_matmul_wrapper : array per TOTAL_INPUT_W
    output logic [(WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A*NUM_CORES_B*TOTAL_MODULES)-1:0] out_multi_matmul [TOTAL_INPUT_W]
);

    import linear_proj_pkg::*; // brings WIDTH_A, ADDR_WIDTH_A, etc into scope

    // ---------------------------
    // Internal wires & registers
    // ---------------------------
    // BRAM data outputs
    logic [WIDTH_A*CHUNK_SIZE*NUM_CORES_A-1:0] in_mat_douta;
    logic [WIDTH_A*CHUNK_SIZE*NUM_CORES_A-1:0] in_mat_doutb;
    logic [WIDTH_B*CHUNK_SIZE*NUM_CORES_B*TOTAL_MODULES-1:0] w_mat_doutb;

    // BRAM address/control mux outputs (driven to XPM ports)
    logic [ADDR_WIDTH_A-1:0] in_mat_addr_a_mux, in_mat_addr_b_mux;
    logic [ADDR_WIDTH_B-1:0] w_mat_addr_a_mux, w_mat_addr_b_mux;
    logic in_mat_wea_mux, in_mat_web_mux, in_mat_ena_mux, in_mat_enb_mux;
    logic w_mat_wea_mux, w_mat_web_mux, w_mat_ena_mux, w_mat_enb_mux;

    // Internal read address counters (controller-driven)
    logic [ADDR_WIDTH_A-1:0] in_mat_rd_addr_cnt_a; // used when reading port A
    logic [ADDR_WIDTH_A-1:0] in_mat_rd_addr_cnt_b; // used when reading port B
    logic [ADDR_WIDTH_B-1:0] w_mat_rd_addr_cnt;    // reading weights (we'll use only one BRAM port for read later)

    // Hook up read results into multi_matmul_wrapper input array
    // We'll map: in_bram[0] <= in_mat_douta (even rows), in_bram[1] <= in_mat_doutb (odd rows)
    logic [WIDTH_A*CHUNK_SIZE*NUM_CORES_A-1:0] in_bram_internal [TOTAL_INPUT_W];

    // Status signals from multi_matmul_wrapper
    logic acc_done_wrap, systolic_finish_wrap;
    logic multi_en; // enable to multi_matmul_wrapper
    logic internal_reset_acc;
    logic internal_rst_n;

    // Controller counters for matrix C iteration
    // counter: inner-loop (k) over (INNER_DIMENSION / BLOCK_SIZE)
    localparam int INNER_STEPS = (INNER_DIMENSION / BLOCK_SIZE);
    logic [$clog2(INNER_STEPS+1)-1:0] counter;     // counts 0..INNER_STEPS-1
    logic [$clog2(A_OUTER_DIMENSION+1)-1:0] counter_row; // row index over A_OUTER_DIMENSION/BLOCK sizing
    logic [$clog2(B_OUTER_DIMENSION+1)-1:0] counter_col;

    // For done/out_valid tracking
    // determine the number of C tiles: ROW_SIZE_MAT_C * COL_SIZE_MAT_C (as you used earlier)
    localparam int ROW_SIZE_MAT_C = A_OUTER_DIMENSION / (BLOCK_SIZE * NUM_CORES_A * TOTAL_INPUT_W);
    localparam int COL_SIZE_MAT_C = B_OUTER_DIMENSION / (BLOCK_SIZE * NUM_CORES_B * TOTAL_MODULES);
    localparam int MAX_FLAG = (ROW_SIZE_MAT_C * COL_SIZE_MAT_C);
    integer flag_cnt;

    // Simple FSM states
    typedef enum logic [2:0] {
        S_IDLE,
        S_WAIT_FILL,    // waiting for en_module (external write done)
        S_START,        // prepare counters / deassert writes / switch to read
        S_COMPUTE,      // drive read addresses, assert multi_en
        S_WAIT_ACC_DONE,// wait for accumulator done from wrapper
        S_COL_UPDATE,   // update column/row counters and capture outputs
        S_DONE
    } state_t;

    state_t state, next_state;

    // ---------------------------
    // XPM BRAM wiring: MUX addra/addrb to choose between external write addrs and internal read counters
    // during write phase, external ports drive addra/addrb and wea/web come from external inputs.
    // during read phase, controller drives addresses and sets wea/web to zero.
    // ---------------------------

    // Control signal that determines phase:
    // write_phase == 1: BRAM ports accept external writes (external ena/we* used)
    // write_phase == 0: BRAM ports in read mode (controller drives addresses, we=0)
    logic write_phase;

    // default assign: mux between external write controls and controller read controls
    // For input matrix BRAM (in_mat)
    assign in_mat_addr_a_mux = (write_phase) ? in_mat_wr_addra : in_mat_rd_addr_cnt_a;
    assign in_mat_addr_b_mux = (write_phase) ? in_mat_wr_addrb : in_mat_rd_addr_cnt_b;

    assign in_mat_wea_mux = (write_phase) ? in_mat_wea : 1'b0;
    assign in_mat_web_mux = (write_phase) ? in_mat_web : 1'b0;

    assign in_mat_ena_mux = (write_phase) ? in_mat_ena : 1'b1; // keep enabled in read mode
    assign in_mat_enb_mux = (write_phase) ? in_mat_enb : 1'b1;

    // For weight matrix BRAM (w_mat)
    assign w_mat_addr_a_mux = (write_phase) ? w_mat_wr_addra : w_mat_rd_addr_cnt;
    assign w_mat_addr_b_mux = (write_phase) ? w_mat_wr_addrb : w_mat_rd_addr_cnt; // both can read same location if needed

    assign w_mat_wea_mux = (write_phase) ? w_mat_wea : 1'b0;
    assign w_mat_web_mux = (write_phase) ? w_mat_web : 1'b0;

    assign w_mat_ena_mux = (write_phase) ? w_mat_ena : 1'b1;
    assign w_mat_enb_mux = (write_phase) ? w_mat_enb : 1'b1;

    // ---------------------------
    // XPM instantiations (connect address/control mux signals)
    // (I only replace addra/addrb and wea/web/ena/enb wiring; everything else left as in your original)
    // ---------------------------

    // Input matrix TDPRAM
    xpm_memory_tdpram #(
        .MEMORY_SIZE((INNER_DIMENSION*A_OUTER_DIMENSION*WIDTH_A)), // keep as originally parameterized in your file
        .MEMORY_PRIMITIVE("auto"),
        .CLOCKING_MODE("common_clock"),
        .MEMORY_INIT_FILE("none"),
        .USE_MEM_INIT(1),
        .WAKEUP_TIME("disable_sleep"),
        .MESSAGE_CONTROL(0),
        .AUTO_SLEEP_TIME(0),
        .ECC_MODE("no_ecc"),
        .MEMORY_OPTIMIZATION("true"),
        .USE_EMBEDDED_CONSTRAINT(0),
        .WRITE_DATA_WIDTH_A(WIDTH_A*CHUNK_SIZE*NUM_CORES_A),
        .READ_DATA_WIDTH_A(WIDTH_A*CHUNK_SIZE*NUM_CORES_A),
        .BYTE_WRITE_WIDTH_A((WIDTH_A*CHUNK_SIZE*NUM_CORES_A)),
        .ADDR_WIDTH_A(ADDR_WIDTH_A),
        .READ_RESET_VALUE_A("0"),
        .READ_LATENCY_A(1),
        .WRITE_MODE_A("write_first"),
        .RST_MODE_A("SYNC"),
        .WRITE_DATA_WIDTH_B(WIDTH_A*CHUNK_SIZE*NUM_CORES_A),
        .READ_DATA_WIDTH_B(WIDTH_A*CHUNK_SIZE*NUM_CORES_A),
        .BYTE_WRITE_WIDTH_B((WIDTH_A*CHUNK_SIZE*NUM_CORES_A)),
        .ADDR_WIDTH_B(ADDR_WIDTH_A),
        .READ_RESET_VALUE_B("0"),
        .READ_LATENCY_B(1),
        .WRITE_MODE_B("write_first"),
        .RST_MODE_B("SYNC")
    ) xpm_in_mat (
        .sleep(1'b0),
        .regcea(1'b1),
        .injectsbiterra(1'b0),
        .injectdbiterra(1'b0),
        .sbiterra(),
        .dbiterra(),
        .regceb(1'b1),
        .injectsbiterrb(1'b0),
        .injectdbiterrb(1'b0),
        .sbiterrb(),
        .dbiterrb(),

        .clka(clk),
        .rsta(~rst_n),
        .ena(in_mat_ena_mux),
        .wea(in_mat_wea_mux),
        .addra(in_mat_addr_a_mux),
        .dina(in_mat_dina),
        .douta(in_mat_douta),

        .clkb(clk),
        .rstb(~rst_n),
        .enb(in_mat_enb_mux),
        .web(in_mat_web_mux),
        .addrb(in_mat_addr_b_mux),
        .dinb(in_mat_dinb),
        .doutb(in_mat_doutb)
    );


    // Weight matrix TDPRAM (we will read from port B, but both ports available)
    xpm_memory_tdpram #(
        .MEMORY_SIZE((INNER_DIMENSION*B_OUTER_DIMENSION*WIDTH_B)),
        .MEMORY_PRIMITIVE("auto"),
        .CLOCKING_MODE("common_clock"),
        .MEMORY_INIT_FILE("none"),
        .USE_MEM_INIT(1),
        .WAKEUP_TIME("disable_sleep"),
        .MESSAGE_CONTROL(0),
        .AUTO_SLEEP_TIME(0),
        .ECC_MODE("no_ecc"),
        .MEMORY_OPTIMIZATION("true"),
        .USE_EMBEDDED_CONSTRAINT(0),
        .WRITE_DATA_WIDTH_A(WIDTH_B*CHUNK_SIZE*NUM_CORES_B*TOTAL_MODULES),
        .READ_DATA_WIDTH_A(WIDTH_B*CHUNK_SIZE*NUM_CORES_B*TOTAL_MODULES),
        .BYTE_WRITE_WIDTH_A((WIDTH_B*CHUNK_SIZE*NUM_CORES_B*TOTAL_MODULES)),
        .ADDR_WIDTH_A(ADDR_WIDTH_B),
        .READ_RESET_VALUE_A("0"),
        .READ_LATENCY_A(1),
        .WRITE_MODE_A("write_first"),
        .RST_MODE_A("SYNC"),
        .WRITE_DATA_WIDTH_B(WIDTH_B*CHUNK_SIZE*NUM_CORES_B*TOTAL_MODULES),
        .READ_DATA_WIDTH_B(WIDTH_B*CHUNK_SIZE*NUM_CORES_B*TOTAL_MODULES),
        .BYTE_WRITE_WIDTH_B((WIDTH_B*CHUNK_SIZE*NUM_CORES_B*TOTAL_MODULES)),
        .ADDR_WIDTH_B(ADDR_WIDTH_B),
        .READ_RESET_VALUE_B("0"),
        .READ_LATENCY_B(1),
        .WRITE_MODE_B("write_first"),
        .RST_MODE_B("SYNC")
    ) xpm_w_mat (
        .sleep(1'b0),
        .regcea(1'b1),
        .injectsbiterra(1'b0),
        .injectdbiterra(1'b0),
        .sbiterra(),
        .dbiterra(),
        .regceb(1'b1),
        .injectsbiterrb(1'b0),
        .injectdbiterrb(1'b0),
        .sbiterrb(),
        .dbiterrb(),

        .clka(clk),
        .rsta(~rst_n),
        .ena(w_mat_ena_mux),
        .wea(w_mat_wea_mux),
        .addra(w_mat_addr_a_mux),
        .dina(w_mat_dina),
        .douta(), // not used

        .clkb(clk),
        .rstb(~rst_n),
        .enb(w_mat_enb_mux),
        .web(w_mat_web_mux),
        .addrb(w_mat_addr_b_mux),
        .dinb(w_mat_dinb),
        .doutb(w_mat_doutb)
    );

    // ---------------------------
    // Map BRAM outputs into in_bram_internal[] for the wrapper
    // For now: TOTAL_INPUT_W==2 mapping:
    //   in_bram_internal[0] <= in_mat_douta (even rows)
    //   in_bram_internal[1] <= in_mat_doutb (odd rows)
    // If TOTAL_INPUT_W > 2, we assign alternately as a simple fallback (see notes below).
    // ---------------------------
    genvar ii;
    generate
        for (ii = 0; ii < TOTAL_INPUT_W; ii = ii + 1) begin : MAP_INBRAM
            if (TOTAL_INPUT_W == 2) begin
                // map 0->port A, 1->port B
                if (ii == 0) assign in_bram_internal[ii] = in_mat_douta;
                if (ii == 1) assign in_bram_internal[ii] = in_mat_doutb;
            end else begin
                // fallback: even indices map to A, odd indices map to B
                if ((ii % 2) == 0) assign in_bram_internal[ii] = in_mat_douta;
                else assign in_bram_internal[ii] = in_mat_doutb;
            end
        end
    endgenerate

    // ---------------------------
    // Instantiate multi_matmul_wrapper
    // ---------------------------
    multi_matmul_wrapper #(
        .WIDTH_A(WIDTH_A),
        .FRAC_WIDTH_A(FRAC_WIDTH_A),
        .WIDTH_B(WIDTH_B),
        .FRAC_WIDTH_B(FRAC_WIDTH_B),
        .WIDTH_OUT(WIDTH_OUT),
        .FRAC_WIDTH_OUT(FRAC_WIDTH_OUT),
        .BLOCK_SIZE(BLOCK_SIZE),
        .CHUNK_SIZE(CHUNK_SIZE),
        .INNER_DIMENSION(INNER_DIMENSION),
        .TOTAL_MODULES(TOTAL_MODULES),
        .TOTAL_INPUT_W(TOTAL_INPUT_W),
        .NUM_CORES_A(NUM_CORES_A),
        .NUM_CORES_B(NUM_CORES_B)
    ) multi_matmul_wrapper_inst (
        .clk(clk),
        .rst_n(internal_rst_n),
        .en(multi_en),
        .reset_acc(internal_reset_acc),
        .in_bram(in_bram_internal),
        .input_n(w_mat_doutb),               // use weight BRAM port B read data as input_n
        .acc_done_wrap(acc_done_wrap),
        .systolic_finish_wrap(systolic_finish_wrap),
        .out_multi_matmul(out_multi_matmul)
    );

    // ---------------------------
    // Controller FSM
    // ---------------------------
    // We use en_module as the start signal indicating BRAMs have been filled by external testbench.
    // The controller ensures strict phase separation: only when en_module goes high do we switch to read mode / compute.

    // Signals for detecting rising edge of en_module (start)
    logic en_module_d;
    wire en_start_pulse = en_module & ~en_module_d;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            en_module_d <= 1'b0;
        end else begin
            en_module_d <= en_module;
        end
    end

    // FSM sequential
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            // reset many controller registers
            counter <= '0;
            counter_row <= '0;
            counter_col <= '0;
            flag_cnt <= 0;
            in_mat_rd_addr_cnt_a <= '0;
            in_mat_rd_addr_cnt_b <= '0;
            w_mat_rd_addr_cnt <= '0;
            write_phase <= 1'b1;         // default: allow external writes
            multi_en <= 1'b0;
            internal_rst_n <= 1'b1;
            internal_reset_acc <= 1'b0;
        end else begin
            state <= next_state;

            // a few per-state sequential actions
            case (state)
                S_IDLE: begin
                    // maintain default (external writes allowed)
                    write_phase <= 1'b1;
                    multi_en <= 1'b0;
                end
                S_WAIT_FILL: begin
                    // just wait for start pulse from external (en_module)
                    write_phase <= 1'b1;
                    multi_en <= 1'b0;
                end
                S_START: begin
                    // flip to read mode
                    write_phase <= 1'b0;
                    // initialize counters
                    counter <= 0;
                    counter_row <= 0;
                    counter_col <= 0;
                    flag_cnt <= 0;
                    in_mat_rd_addr_cnt_a <= 0;
                    in_mat_rd_addr_cnt_b <= 0;
                    w_mat_rd_addr_cnt <= 0;
                    multi_en <= 1'b0;
                    internal_rst_n <= 1'b1;
                    internal_reset_acc <= 1'b0;
                end
                S_COMPUTE: begin
                    // on each cycle of COMPUTE we drive read addresses and set multi_en=1
                    multi_en <= 1'b1;
                    // read addresses are computed below in combinational logic or sequential counters
                end
                S_WAIT_ACC_DONE: begin
                    // stop asserting compute enable while we wait? keep it asserted until wrapper clears?
                    multi_en <= 1'b0;
                    internal_reset_acc <= 1'b1; // pulse reset_acc low->high to clear accumulators next cycle (matches your earlier internal_reset_acc semantics)
                end
                S_COL_UPDATE: begin
                    // after accumulator done, update counters and capture output
                    internal_reset_acc <= 1'b0;
                    // increment counters below
                end
                S_DONE: begin
                    multi_en <= 1'b0;
                    write_phase <= 1'b0;
                end
            endcase
        end
    end

    // FSM combinational next-state logic
    always_comb begin
        next_state = state;
        unique case (state)
            S_IDLE: begin
                next_state = S_WAIT_FILL;
            end
            S_WAIT_FILL: begin
                if (en_start_pulse) next_state = S_START;
            end
            S_START: begin
                // small delay cycle to allow BRAM mux to settle; then go to COMPUTE.
                next_state = S_COMPUTE;
            end
            S_COMPUTE: begin
                // stay in COMPUTE until inner counter reaches end (we will then wait acc_done)
                if (counter == (INNER_STEPS - 1)) begin
                    next_state = S_WAIT_ACC_DONE;
                end
            end
            S_WAIT_ACC_DONE: begin
                // wait for wrapper accumulator done (rising)
                if (acc_done_wrap) next_state = S_COL_UPDATE;
            end
            S_COL_UPDATE: begin
                // Advance column/row counters and check termination
                if ((counter_row == (ROW_SIZE_MAT_C - 1)) && (counter_col == (COL_SIZE_MAT_C - 1))) begin
                    // we've completed all tiles
                    next_state = S_DONE;
                end else begin
                    next_state = S_COMPUTE;
                end
            end
            S_DONE: begin
                // stay here until external reset or re-start
                if (!en_module) next_state = S_WAIT_FILL; // allow re-start when en_module toggles
            end
            default: next_state = S_IDLE;
        endcase
    end

    // ---------------------------
    // Read-address sequencing and counter updates
    // in_mat_rd_addr_cnt_a and _b update during S_COMPUTE
    // We'll implement the scheme:
    //   base_addr = (INNER_DIMENSION / BLOCK_SIZE) * (row_index)
    //   addr = base_addr + counter
    // Where row_index = 2*counter_row for even rows mapped to A, and 2*counter_row+1 for odd rows mapped to B
    // This yields pairs of row indices per outer iteration.
    // ---------------------------

    // Compute row indices for port A (even) and port B (odd)
    logic [$clog2(A_OUTER_DIMENSION+1)-1:0] row_index_a, row_index_b;
    assign row_index_a = counter_row * 2;        // even row
    assign row_index_b = counter_row * 2 + 1;    // odd row

    // base addresses (number of inner steps per row)
    logic [ADDR_WIDTH_A-1:0] base_addr_a, base_addr_b;
    // multiply by INNER_STEPS (which is small and known compile-time) -> use arithmetic
    // base = row_index * INNER_STEPS
    assign base_addr_a = row_index_a * INNER_STEPS;
    assign base_addr_b = row_index_b * INNER_STEPS;

    // Update read counters sequentially during S_COMPUTE
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            in_mat_rd_addr_cnt_a <= '0;
            in_mat_rd_addr_cnt_b <= '0;
            w_mat_rd_addr_cnt <= '0;
        end else begin
            if (state == S_COMPUTE) begin
                // read addresses = base + counter
                in_mat_rd_addr_cnt_a <= base_addr_a + counter;
                in_mat_rd_addr_cnt_b <= base_addr_b + counter;
                // for weights we might stream by the same counter (same inner step)
                w_mat_rd_addr_cnt <= counter; // or some mapping appropriate to your weight layout
            end else begin
                // hold values otherwise
                in_mat_rd_addr_cnt_a <= in_mat_rd_addr_cnt_a;
                in_mat_rd_addr_cnt_b <= in_mat_rd_addr_cnt_b;
                w_mat_rd_addr_cnt <= w_mat_rd_addr_cnt;
            end
        end
    end

    // inner counter update
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) counter <= '0;
        else if (state == S_COMPUTE) begin
            if (counter == (INNER_STEPS - 1)) counter <= 0;
            else counter <= counter + 1;
        end else counter <= 0;
    end

    // after acc_done_wrap we update column/row counters and flag_cnt
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter_row <= 0;
            counter_col <= 0;
            flag_cnt <= 0;
        end else if (state == S_COL_UPDATE) begin
            // update counters following your earlier logic
            if (counter_col == (COL_SIZE_MAT_C - 1)) begin
                counter_col <= 0;
                if (counter_row == (ROW_SIZE_MAT_C - 1)) begin
                    counter_row <= 0;
                end else begin
                    counter_row <= counter_row + 1;
                end
            end else begin
                counter_col <= counter_col + 1;
            end

            // increment flag (tracking how many C tiles completed)
            if (flag_cnt < MAX_FLAG) flag_cnt <= flag_cnt + 1;
        end
    end

    // produce out_valid pulse when we see acc_done_wrap rising (simple edge detect)
    logic acc_done_wrap_d;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) acc_done_wrap_d <= 1'b0;
        else acc_done_wrap_d <= acc_done_wrap;
    end
    assign out_valid = (~acc_done_wrap_d) & acc_done_wrap;

    // done asserted when flag_cnt reaches MAX_FLAG
    assign done = (flag_cnt == MAX_FLAG);

    // internal reset signals: tie these appropriately for multi_matmul_wrapper
    // internal_rst_n: keep high normally, tie low if you want to reset whole wrapper
    // internal_reset_acc: pulse to clear accumulators when required
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) internal_rst_n <= 1'b0;
        else begin
            // keep internal_rst_n high unless we move to a special reset state
            internal_rst_n <= 1'b1;
        end
    end

    // If user wants the wrapper enabled only when compute loop is running:
    assign multi_en = (state == S_COMPUTE);

endmodule

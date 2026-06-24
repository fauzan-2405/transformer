`timescale 1ns/1ps

module tb_axis_top_wo_converter;

    //----------------------------------------------------------------------
    // Parameters (must match DUT)
    //----------------------------------------------------------------------
    localparam A_OUTER_DIMENSION = 16;
    localparam INNER_DIMENSION   = 10;
    localparam B_OUTER_DIMENSION = 12;

    localparam WIDTH_A = 16;
    localparam FRAC_WIDTH_A = 8;
    localparam WIDTH_B = 16;
    localparam FRAC_WIDTH_B = 8;
    localparam WIDTH_OUT = 16;
    localparam FRAC_WIDTH_OUT = 8;

    localparam BLOCK_SIZE = 2;
    localparam CHUNK_SIZE = BLOCK_SIZE*BLOCK_SIZE;

    localparam NUM_CORES_A = 2;
    localparam NUM_CORES_B = 2;

    localparam WIDTH_IN_A  = WIDTH_A*CHUNK_SIZE*NUM_CORES_A;
    localparam WIDTH_IN_B  = WIDTH_B*CHUNK_SIZE*NUM_CORES_B;
    localparam WIDTH_OUT_C = WIDTH_OUT*CHUNK_SIZE*NUM_CORES_A*NUM_CORES_B;

    localparam NUM_A_WORDS =
        ((A_OUTER_DIMENSION/BLOCK_SIZE)*
         (INNER_DIMENSION/BLOCK_SIZE))/NUM_CORES_A;

    localparam NUM_B_WORDS =
        ((B_OUTER_DIMENSION/BLOCK_SIZE)*
         (INNER_DIMENSION/BLOCK_SIZE))/NUM_CORES_B;

    //----------------------------------------------------------------------
    // Clock / Reset
    //----------------------------------------------------------------------
    logic aclk = 0;
    always #5 aclk = ~aclk;

    logic aresetn;

    //----------------------------------------------------------------------
    // AXIS Slave 0
    //----------------------------------------------------------------------
    logic                     s_axis_0_tvalid;
    logic                     s_axis_0_tlast;
    logic [WIDTH_IN_A-1:0]    s_axis_0_tdata;
    wire                      s_axis_0_tready;

    //----------------------------------------------------------------------
    // AXIS Slave 1
    //----------------------------------------------------------------------
    logic                     s_axis_1_tvalid;
    logic                     s_axis_1_tlast;
    logic [WIDTH_IN_B-1:0]    s_axis_1_tdata;
    wire                      s_axis_1_tready;

    //----------------------------------------------------------------------
    // AXIS Master
    //----------------------------------------------------------------------
    logic                     m_axis_tready;
    wire                      m_axis_tvalid;
    wire                      m_axis_tlast;
    wire [WIDTH_OUT_C-1:0]    m_axis_tdata;

    //----------------------------------------------------------------------
    // Memory
    //----------------------------------------------------------------------
    logic [WIDTH_IN_A-1:0] mem_A [0:NUM_A_WORDS-1];
    logic [WIDTH_IN_B-1:0] mem_B [0:NUM_B_WORDS-1];

    initial begin
        $readmemh("mat_A_lp_bridge.mem", mem_A);
        $readmemh("mat_B_lp_bridge.mem", mem_B);
    end
    
    axis_top_wo_converter #(
        .A_OUTER_DIMENSION(A_OUTER_DIMENSION),
        .INNER_DIMENSION(INNER_DIMENSION),
        .B_OUTER_DIMENSION(B_OUTER_DIMENSION),
        .WIDTH_A(WIDTH_A),
        .FRAC_WIDTH_A(FRAC_WIDTH_A),
        .WIDTH_B(WIDTH_B),
        .FRAC_WIDTH_B(FRAC_WIDTH_B),
        .WIDTH_OUT(WIDTH_OUT),
        .FRAC_WIDTH_OUT(FRAC_WIDTH_OUT),
        .NUM_CORES_A(NUM_CORES_A),
        .NUM_CORES_B(NUM_CORES_B)
    ) dut (
        .aclk(aclk),
        .aresetn(aresetn),

        .s_axis_0_tready(s_axis_0_tready),
        .s_axis_0_tdata(s_axis_0_tdata),
        .s_axis_0_tvalid(s_axis_0_tvalid),
        .s_axis_0_tlast(s_axis_0_tlast),

        .s_axis_1_tready(s_axis_1_tready),
        .s_axis_1_tdata(s_axis_1_tdata),
        .s_axis_1_tvalid(s_axis_1_tvalid),
        .s_axis_1_tlast(s_axis_1_tlast),

        .m_axis_tready(m_axis_tready),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tlast(m_axis_tlast)
    );

    initial begin
        aresetn = 0;
        s_axis_0_tvalid = 0;
        s_axis_1_tvalid = 0;
        s_axis_0_tlast = 0;
        s_axis_1_tlast = 0;
        s_axis_0_tdata = 0;
        s_axis_1_tdata = 0;
        m_axis_tready = 1;

        repeat(10) @(posedge aclk);

        aresetn = 1;
    end

    task send_matrix_A;
    integer i;
    begin
        @(posedge aclk);
        for(i=0;i<NUM_A_WORDS;i=i+1) begin
            s_axis_0_tdata  <= mem_A[i];
            s_axis_0_tvalid <= 1;
            s_axis_0_tlast  <= (i==NUM_A_WORDS-1);

            wait(s_axis_0_tready);

            @(posedge aclk);
        end
        s_axis_0_tvalid <= 0;
        s_axis_0_tlast  <= 0;
    end
    endtask

    task send_matrix_B;
    integer i;
    begin
        @(posedge aclk);
        for(i=0;i<NUM_B_WORDS;i=i+1) begin
            s_axis_1_tdata  <= mem_B[i];
            s_axis_1_tvalid <= 1;
            s_axis_1_tlast  <= (i==NUM_B_WORDS-1);
            wait(s_axis_1_tready);
            @(posedge aclk);
        end
        s_axis_1_tvalid <= 0;
        s_axis_1_tlast  <= 0;
    end
    endtask

    always @(posedge aclk) begin
        if(m_axis_tvalid && m_axis_tready) begin
            $display("%t Output = %h",
                    $time,
                    m_axis_tdata);
            if(m_axis_tlast) begin
                $display("Finished.");
                #20;
                $finish;
            end
        end
    end

    initial begin
        wait(aresetn);
        fork
            send_matrix_A();
            send_matrix_B();
        join
    end

endmodule
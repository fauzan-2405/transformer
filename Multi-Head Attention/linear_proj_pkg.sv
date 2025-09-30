package matmul_pkg;
    // Parameterization
    parameter int WIDTH_A        = 16;
    parameter int FRAC_WIDTH_A   = 8;
    parameter int WIDTH_B        = 16;
    parameter int FRAC_WIDTH_B   = 8;
    parameter int WIDTH_OUT      = 16;
    parameter int FRAC_WIDTH_OUT = 8;

    parameter int BLOCK_SIZE     = 2; 
    parameter int CHUNK_SIZE     = 4;

    parameter int A_OUTER_DIMENSION = 6;
    parameter int B_OUTER_DIMENSION = 6;
    parameter int INNER_DIMENSION= 64;
    parameter int NUM_CORES_B    = 1;
    parameter int NUM_CORES_A    = 4;
    
    parameter int ADDR_WIDTH_A = $clog2((INNER_DIMENSION*A_OUTER_DIMENSION*WIDTH_A)/(WIDTH_A*CHUNK_SIZE*NUM_CORES_A)),
    parameter int ADDR_WIDTH_B = $clog2((INNER_DIMENSION*B_OUTER_DIMENSION*WIDTH_B)/(WIDTH_B*CHUNK_SIZE*NUM_CORES_B))

endpackage
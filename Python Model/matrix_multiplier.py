#!/usr/bin/env python3
# matrix_multiplier.py  (modified to add linear_projection task)
"""
Usage examples:
  # old/full matmul
  python matrix_multiplier.py --display float --integers --min_val 0 --max_val 100 \
      --block_size 2 --cores_a 1 --cores_b 1

  # linear projection example:
  python matrix_multiplier.py --task linear_projection --heads 12 \
      --unique_per_head --rows_a 16 --cols_a 64 --proj_dim 64 --block_size 2 --cores_a 2 --cores_b 2
"""

import numpy as np
import os
import argparse
from typing import Tuple

# ---------------------------
# Fixed-point helper classes
# ---------------------------
class FixedPointConverter:
    """Handles fixed-point number conversion and arithmetic"""
    def __init__(self, total_bits: int, fractional_bits: int, is_signed: bool = True):
        self.total_bits = total_bits
        self.fractional_bits = fractional_bits
        self.integer_bits = total_bits - fractional_bits
        self.is_signed = is_signed
        
        if is_signed:
            # Note: these max/min calculations are for convenience only
            self.max_val = (1 << (self.integer_bits - 1)) - 1 / (1 << fractional_bits)
            self.min_val = -(1 << (self.integer_bits - 1))
            self.max_int = (1 << (total_bits - 1)) - 1
            self.min_int = -(1 << (total_bits - 1))
        else:
            self.max_val = (1 << self.integer_bits) - 1 / (1 << fractional_bits)
            self.min_val = 0
            self.max_int = (1 << total_bits) - 1
            self.min_int = 0

    def float_to_fixed(self, val: float) -> int:
        """Convert float to fixed-point integer representation (two's complement if signed)"""
        scaled = round(val * (1 << self.fractional_bits))
        clamped = int(np.clip(scaled, self.min_int, self.max_int))
        if self.is_signed and clamped < 0:
            return (1 << self.total_bits) + clamped
        return int(clamped)
    
    def fixed_to_float(self, val: int) -> float:
        """Convert fixed-point integer to float"""
        if self.is_signed and val >= (1 << (self.total_bits - 1)):
            val = val - (1 << self.total_bits)
        return val / (1 << self.fractional_bits)
    
    def int_to_binary(self, val: int) -> str:
        """Convert fixed-point integer to binary string"""
        v = int(val)
        if self.is_signed and v < 0:
            v = (1 << self.total_bits) + v
        return format(v & ((1 << self.total_bits) - 1), f'0{self.total_bits}b')

# ---------------------------
# Matrix processing helper
# ---------------------------
class MatrixProcessor:
    """Handles matrix creation, multiplication, and export"""
    def __init__(self):
        self.matrices = {'A': None, 'B': None, 'C': None}
        self.converters = {'A': None, 'B': None, 'C': None}
        self.cores_a = 1
        self.cores_b = 1
    
    def create_matrix(self, rows: int, cols: int, min_val: float, max_val: float, 
                     converter: FixedPointConverter, integers_only: bool = False) -> np.ndarray:
        """Generate random matrix with fixed-point conversion"""
        if integers_only:
            data = np.random.randint(int(min_val), int(max_val) + 1, (rows, cols))
        else:
            data = np.random.uniform(min_val, max_val, (rows, cols))
        vec_converter = np.vectorize(converter.float_to_fixed)
        return vec_converter(data).astype(np.int64)
    
    def multiply_matrices(self, A: np.ndarray, B: np.ndarray, 
                         converter_A: FixedPointConverter, 
                         converter_B: FixedPointConverter,
                         converter_C: FixedPointConverter) -> np.ndarray:
        """Fixed-point matrix multiplication with intermediate conversion"""
        to_float_A = np.vectorize(converter_A.fixed_to_float)
        to_float_B = np.vectorize(converter_B.fixed_to_float)
        A_float = to_float_A(A)
        B_float = to_float_B(B)
        C_float = np.matmul(A_float, B_float)
        to_fixed_C = np.vectorize(converter_C.float_to_fixed)
        return to_fixed_C(C_float).astype(np.int64)
    
    def print_matrix(self, matrix: np.ndarray, converter: FixedPointConverter, 
                    name: str, display_format: str = 'int'):
        """Print matrix in specified format"""
        print(f"\n{name}:")
        for row in matrix:
            line = []
            for val in row:
                int_val = int(val)
                if display_format == 'float':
                    float_val = converter.fixed_to_float(int_val)
                    line.append(f"{float_val:8.4f}")
                else:  # 'int' format
                    line.append(f"{int_val:6}")
            print(" ".join(line))
    
    def export_matrix(self, matrix: np.ndarray, converter: FixedPointConverter, 
                     filename: str, mode: str = 'row', 
                     block_size: int = 2, num_cores: int = 1,
                     matrix_type: str = 'A'):
        """Export matrix in specified format (row/core modes supported)"""
        rows, cols = matrix.shape
        
        if mode == 'row':
            self._export_row_mode(matrix, converter, filename)
        elif mode == 'core':
            if matrix_type == 'A':
                self._export_core_mode_A(matrix, converter, filename, block_size, num_cores)
            elif matrix_type == 'B':
                self._export_core_mode_B(matrix, converter, filename, block_size, num_cores)
            elif matrix_type == 'C':
                self._export_core_mode_C(matrix, converter, filename, block_size)
    
    def _export_row_mode(self, matrix: np.ndarray, 
                        converter: FixedPointConverter, filename: str):
        """Export matrix row by row in binary"""
        with open(filename, 'w') as f:
            for row in matrix:
                bin_row = [converter.int_to_binary(int(x)) for x in row]
                f.write(" ".join(bin_row) + '\n')
    
    def _export_core_mode_A(self, matrix: np.ndarray, 
                          converter: FixedPointConverter, filename: str,
                          block_size: int, num_cores: int):
        """
        Export matrix A in core block format (horizontal access)
        Pattern: Process block rows horizontally, left to right.
        This matches your FPGA’s expectation for matrix A arrangement.
        """
        rows, cols = matrix.shape
        if rows % (num_cores * block_size) != 0:
            raise ValueError(f"Matrix A: Rows ({rows}) must be divisible by cores×block_size ({num_cores}×{block_size})")
        if cols % block_size != 0:
            raise ValueError(f"Matrix A: Columns ({cols}) must be divisible by block_size ({block_size})")
        row_groups = rows // (num_cores * block_size)
        blocks_per_row = cols // block_size
        
        with open(filename, 'w') as f:
            for group_idx in range(row_groups):
                group_start_row = group_idx * num_cores * block_size
                for block_col in range(blocks_per_row):
                    col_start = block_col * block_size
                    line = []
                    for core_idx in range(num_cores):
                        row_start = group_start_row + core_idx * block_size
                        block = matrix[row_start:row_start+block_size, col_start:col_start+block_size]
                        for r in range(block_size):
                            for c in range(block_size):
                                line.append(converter.int_to_binary(int(block[r, c])))
                    f.write(" ".join(line) + '\n')
    
    def _export_core_mode_B(self, matrix: np.ndarray, 
                          converter: FixedPointConverter, filename: str,
                          block_size: int, num_cores: int):
        """
        Export matrix B in core block format (vertical access)
        Pattern: Process block columns vertically, top to bottom.
        This matches your FPGA’s expectation for weight matrix arrangement.
        """
        rows, cols = matrix.shape
        if cols % (num_cores * block_size) != 0:
            raise ValueError(f"Matrix B: Columns ({cols}) must be divisible by cores×block_size ({num_cores}×{block_size})")
        if rows % block_size != 0:
            raise ValueError(f"Matrix B: Rows ({rows}) must be divisible by block_size ({block_size})")
        col_groups = cols // (num_cores * block_size)
        blocks_per_col = rows // block_size
        
        with open(filename, 'w') as f:
            for group_idx in range(col_groups):
                group_start_col = group_idx * num_cores * block_size
                for block_row in range(blocks_per_col):
                    row_start = block_row * block_size
                    line = []
                    for core_idx in range(num_cores):
                        col_start = group_start_col + core_idx * block_size
                        block = matrix[row_start:row_start+block_size, col_start:col_start+block_size]
                        for c in range(block_size):
                            for r in range(block_size):
                                line.append(converter.int_to_binary(int(block[r, c])))
                    f.write(" ".join(line) + '\n')
    
    def _export_core_mode_C(self, matrix: np.ndarray, 
                      converter: FixedPointConverter, filename: str,
                      block_size: int):
        """Export matrix C (result) in core block format using the pattern expected by HW"""
        rows, cols = matrix.shape
        if rows % (self.cores_a * block_size) != 0:
            raise ValueError(f"Matrix C: Rows ({rows}) must be divisible by cores_a×block_size ({self.cores_a}×{block_size})")
        if cols % (self.cores_b * block_size) != 0:
            raise ValueError(f"Matrix C: Columns ({cols}) must be divisible by cores_b×block_size ({self.cores_b}×{block_size})")
        row_groups = rows // (self.cores_a * block_size)
        col_groups = cols // (self.cores_b * block_size)
        
        with open(filename, 'w') as f:
            for row_group in range(row_groups):
                row_start = row_group * self.cores_a * block_size
                for col_group in range(col_groups):
                    col_start = col_group * self.cores_b * block_size
                    line = []
                    for col_subgroup in range(self.cores_b):
                        col_sub_start = col_start + col_subgroup * block_size
                        for row_subgroup in range(self.cores_a):
                            row_sub_start = row_start + row_subgroup * block_size
                            block = matrix[row_sub_start:row_sub_start+block_size,
                                          col_sub_start:col_sub_start+block_size]
                            for r in range(block_size):
                                for c in range(block_size):
                                    line.append(converter.int_to_binary(int(block[r, c])))
                    f.write(" ".join(line) + '\n')

# ---------------------------
# Linear projection generation
# ---------------------------
def generate_linear_projection(processor: MatrixProcessor,
                               conv_A: FixedPointConverter,
                               conv_W: FixedPointConverter,
                               conv_C: FixedPointConverter,
                               rows_a: int,
                               cols_a: int,
                               proj_dim: int,
                               heads: int,
                               unique_per_head: bool,
                               unique_per_type: bool,
                               block_size: int,
                               cores_a: int,
                               cores_b: int,
                               integers_only: bool,
                               min_val: float,
                               max_val: float,
                               display: str):
    """
    Create:
      - one input matrix A (rows_a x cols_a) and export as mem_input.mem (A arrangement)
      - weight matrices Wq/Wk/Wv depending on heads and uniqueness choice (B arrangement)
      - compute outputs Q/K/V per head: A x W*
      - export results as mem_out_q1.mem, mem_out_k1.mem, ...
    Naming convention:
      mem_input.mem
      mem_q1.mem ... mem_qH.mem
      mem_k1.mem ... mem_kH.mem
      mem_v1.mem ... mem_vH.mem
      mem_out_q1.mem ... mem_out_vH.mem
    """
    # create folders
    os.makedirs("exports", exist_ok=True)

    # 1) Create input matrix A
    A = processor.create_matrix(rows_a, cols_a, min_val, max_val, conv_A, integers_only)
    processor.cores_a = cores_a
    processor.cores_b = cores_b

    # Export input as mem_input.mem in core A mode
    in_fname = "exports/mem_input.mem"
    processor.export_matrix(A, conv_A, in_fname, mode='core', block_size=block_size, num_cores=cores_a, matrix_type='A')
    if display:
        processor.print_matrix(A, conv_A, "Input Matrix A", display)

    # 2) Create weight matrices (Wq, Wk, Wv). Weight dims: (cols_a x proj_dim)
    #    Each weight matrix must satisfy cols_a * proj_dim for multiplication
    weight_shape = (cols_a, proj_dim)

    # Decide weight generation strategy
    # If unique_per_type: create one Wq, one Wk, one Wv and reuse for all heads
    # If unique_per_head: create distinct Wq_h, Wk_h, Wv_h for each head
    Wq_list = []
    Wk_list = []
    Wv_list = []

    if unique_per_type:
        Wq = processor.create_matrix(weight_shape[0], weight_shape[1], min_val, max_val, conv_W, integers_only)
        Wk = processor.create_matrix(weight_shape[0], weight_shape[1], min_val, max_val, conv_W, integers_only)
        Wv = processor.create_matrix(weight_shape[0], weight_shape[1], min_val, max_val, conv_W, integers_only)
        for h in range(heads):
            Wq_list.append(Wq)
            Wk_list.append(Wk)
            Wv_list.append(Wv)
    else:
        # unique_per_head (default) — make distinct matrices for each head
        for h in range(heads):
            Wq_list.append(processor.create_matrix(weight_shape[0], weight_shape[1], min_val, max_val, conv_W, integers_only))
            Wk_list.append(processor.create_matrix(weight_shape[0], weight_shape[1], min_val, max_val, conv_W, integers_only))
            Wv_list.append(processor.create_matrix(weight_shape[0], weight_shape[1], min_val, max_val, conv_W, integers_only))

    # Export weight matrices using B arrangement (core mode B)
    for h in range(heads):
        qname = f"exports/mem_q{h+1}.mem"
        kname = f"exports/mem_k{h+1}.mem"
        vname = f"exports/mem_v{h+1}.mem"
        processor.export_matrix(Wq_list[h], conv_W, qname, mode='core', block_size=block_size, num_cores=cores_b, matrix_type='B')
        processor.export_matrix(Wk_list[h], conv_W, kname, mode='core', block_size=block_size, num_cores=cores_b, matrix_type='B')
        processor.export_matrix(Wv_list[h], conv_W, vname, mode='core', block_size=block_size, num_cores=cores_b, matrix_type='B')

    # 3) Compute outputs per head and export using matrix C arrangement (core mode C)
    #    Output shape: (rows_a x proj_dim)
    for h in range(heads):
        Qh = processor.multiply_matrices(A, Wq_list[h], conv_A, conv_W, conv_C)
        Kh = processor.multiply_matrices(A, Wk_list[h], conv_A, conv_W, conv_C)
        Vh = processor.multiply_matrices(A, Wv_list[h], conv_A, conv_W, conv_C)

        # Export results
        out_q_name = f"exports/mem_out_q{h+1}.mem"
        out_k_name = f"exports/mem_out_k{h+1}.mem"
        out_v_name = f"exports/mem_out_v{h+1}.mem"

        # set cores info used by C export
        processor.cores_a = cores_a
        processor.cores_b = cores_b

        processor.export_matrix(Qh, conv_C, out_q_name, mode='core', block_size=block_size, num_cores=0, matrix_type='C')
        processor.export_matrix(Kh, conv_C, out_k_name, mode='core', block_size=block_size, num_cores=0, matrix_type='C')
        processor.export_matrix(Vh, conv_C, out_v_name, mode='core', block_size=block_size, num_cores=0, matrix_type='C')

        if display:
            processor.print_matrix(Qh, conv_C, f"Q head {h+1}", display)
            processor.print_matrix(Kh, conv_C, f"K head {h+1}", display)
            processor.print_matrix(Vh, conv_C, f"V head {h+1}", display)

    print(f"\nLinear projection exports written to 'exports/' (heads={heads})")

# ---------------------------
# main() entry
# ---------------------------
def main():
    parser = argparse.ArgumentParser(description='Fixed-Point Matrix Multiplier & Linear Projection Exporter')
    parser.add_argument('--task', choices=['matmul', 'linear_projection'], default='matmul',
                        help='Select task: matmul (default) or linear_projection')
    parser.add_argument('--display', choices=['int', 'float'], default='int',
                        help='Display format for matrices (int or float)')
    parser.add_argument('--min_val', type=float, default=0.0, help='Minimum value for matrix elements')
    parser.add_argument('--max_val', type=float, default=2.0, help='Maximum value for matrix elements')
    parser.add_argument('--integers', action='store_true', help='Use integer-only values')
    parser.add_argument('--block_size', type=int, default=2, help='Block size for core-mode export')
    parser.add_argument('--cores_a', type=int, default=2, help='Number of cores for matrix A')
    parser.add_argument('--cores_b', type=int, default=2, help='Number of cores for matrix B')

    # linear projection specific
    parser.add_argument('--heads', type=int, default=12, help='Number of heads (weight matrices per Q/K/V)')
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--unique_per_head', action='store_true',
                        help='Generate distinct Wq/Wk/Wv per head (default)')
    group.add_argument('--unique_per_type', action='store_true',
                        help='Generate one Wq, one Wk, one Wv and reuse for all heads')

    # matrix shape options (both tasks)
    parser.add_argument('--rows_a', type=int, default=8, help='Rows of input matrix A')
    parser.add_argument('--cols_a', type=int, default=6, help='Cols of input matrix A (and rows of B)')
    parser.add_argument('--proj_dim', type=int, default=8, help='Projection dimension (cols of weight matrices B / cols of results)')

    args = parser.parse_args()

    # Fixed-point configurations (total_bits, fractional_bits, signed)
    fp_config_A = (16, 8, True)
    fp_config_B = (16, 8, True)
    fp_config_C = (16, 8, True)

    processor = MatrixProcessor()
    processor.cores_a = args.cores_a
    processor.cores_b = args.cores_b

    conv_A = FixedPointConverter(*fp_config_A)
    conv_W = FixedPointConverter(*fp_config_B)
    conv_C = FixedPointConverter(*fp_config_C)

    if args.task == 'matmul':
        # Original matrix multiplication flow (unchanged)
        ROWS_A, COLS_A = args.rows_a, args.cols_a
        COLS_B = args.proj_dim

        A = processor.create_matrix(ROWS_A, COLS_A, args.min_val, args.max_val, conv_A, args.integers)
        B = processor.create_matrix(COLS_A, COLS_B, args.min_val, args.max_val, conv_W, args.integers)
        C = processor.multiply_matrices(A, B, conv_A, conv_W, conv_C)

        processor.print_matrix(A, conv_A, "Matrix A", args.display)
        processor.print_matrix(B, conv_W, "Matrix B", args.display)
        processor.print_matrix(C, conv_C, "Matrix C (A x B)", args.display)

        os.makedirs("exports", exist_ok=True)
        processor.export_matrix(A, conv_A, "exports/matrix_A_row.mem", 'row')
        processor.export_matrix(B, conv_W, "exports/matrix_B_row.mem", 'row')
        processor.export_matrix(C, conv_C, "exports/matrix_C_row.mem", 'row')

        processor.export_matrix(A, conv_A, "exports/matrix_A_core.mem", 'core', args.block_size, args.cores_a, 'A')
        processor.export_matrix(B, conv_W, "exports/matrix_B_core.mem", 'core', args.block_size, args.cores_b, 'B')
        processor.export_matrix(C, conv_C, "exports/matrix_C_core.mem", 'core', args.block_size, 0, 'C')

        print("\nExports saved to 'exports' directory (matmul)")

    elif args.task == 'linear_projection':
        # Linear projection flow
        heads = args.heads
        unique_head = True if (args.unique_per_head or not args.unique_per_type) else False
        unique_type = args.unique_per_type

        # Validate dims
        rows_a = args.rows_a
        cols_a = args.cols_a
        proj_dim = args.proj_dim

        if cols_a <= 0 or rows_a <= 0 or proj_dim <= 0:
            raise ValueError("Matrix dimensions must be positive integers")

        generate_linear_projection(
            processor=processor,
            conv_A=conv_A,
            conv_W=conv_W,
            conv_C=conv_C,
            rows_a=rows_a,
            cols_a=cols_a,
            proj_dim=proj_dim,
            heads=heads,
            unique_per_head=unique_head,
            unique_per_type=unique_type,
            block_size=args.block_size,
            cores_a=args.cores_a,
            cores_b=args.cores_b,
            integers_only=args.integers,
            min_val=args.min_val,
            max_val=args.max_val,
            display=args.display == 'float'
        )

if __name__ == "__main__":
    main()

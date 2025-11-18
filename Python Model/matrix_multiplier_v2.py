#!/usr/bin/env python3
"""
matrix_multiplier_v2.py

Usage examples:

# original matmul:
python matrix_multiplier_v2.py --task matmul --display float --integers --min_val 0 --max_val 2 --cores_a 2 --cores_b 4

# linear projection (unique per type; only one Q/K/V, single out_* exported & printed)
python matrix_multiplier_v2.py --task linear_projection --rows_a 8 --cols_a 6 --proj_dim 8 \
    --unique_per_type --display float --integers --min_val 0 --max_val 2 --cores_a 2 --cores_b 4

# linear projection (unique per head; generate 4 heads by default)
python matrix_multiplier_v2.py --task linear_projection --rows_a 8 --cols_a 6 --proj_dim 8 \
    --unique_per_head --heads 4 --display float --integers --min_val 0 --max_val 2 --cores_a 2 --cores_b 4
"""
import os
import argparse
import numpy as np
from typing import List

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
            self.max_int = (1 << (total_bits - 1)) - 1
            self.min_int = -(1 << (total_bits - 1))
        else:
            self.max_int = (1 << total_bits) - 1
            self.min_int = 0

    def float_to_fixed(self, val: float) -> int:
        """Convert float to fixed-point integer (two's complement for signed)"""
        scaled = int(round(val * (1 << self.fractional_bits)))
        clamped = int(np.clip(scaled, self.min_int, self.max_int))
        if self.is_signed and clamped < 0:
            return (1 << self.total_bits) + clamped
        return int(clamped)

    def fixed_to_float(self, val: int) -> float:
        """Convert fixed-point integer to python float"""
        v = int(val)
        if self.is_signed and v >= (1 << (self.total_bits - 1)):
            v = v - (1 << self.total_bits)
        return float(v) / (1 << self.fractional_bits)

    def int_to_binary(self, val: int) -> str:
        """Convert integer representation to binary string of width total_bits"""
        v = int(val)
        mask = (1 << self.total_bits) - 1
        if self.is_signed and v < 0:
            v = (1 << self.total_bits) + v
        return format(v & mask, f'0{self.total_bits}b')

# ---------------------------
# Matrix processing helper
# ---------------------------
class MatrixProcessor:
    """Handles matrix creation, multiplication, and export"""
    def __init__(self):
        self.cores_a = 1
        self.cores_b = 1

    def create_matrix(self, rows: int, cols: int, min_val: float, max_val: float,
                      converter: FixedPointConverter, integers_only: bool = False) -> np.ndarray:
        """Generate random matrix and convert to fixed-point representation (integers)"""
        if integers_only:
            data = np.random.randint(int(min_val), int(max_val) + 1, (rows, cols))
        else:
            data = np.random.uniform(min_val, max_val, (rows, cols))
        vec = np.vectorize(converter.float_to_fixed)
        return vec(data).astype(np.int64)

    def multiply_matrices(self, A: np.ndarray, B: np.ndarray,
                          conv_A: FixedPointConverter, conv_B: FixedPointConverter,
                          conv_C: FixedPointConverter) -> np.ndarray:
        """Multiply fixed-point matrices using float intermediate, then convert to fixed-point"""
        to_float_A = np.vectorize(conv_A.fixed_to_float)
        to_float_B = np.vectorize(conv_B.fixed_to_float)
        A_f = to_float_A(A)
        B_f = to_float_B(B)
        C_f = np.matmul(A_f, B_f)
        to_fixed_C = np.vectorize(conv_C.float_to_fixed)
        return to_fixed_C(C_f).astype(np.int64)

    def print_matrix(self, matrix: np.ndarray, converter: FixedPointConverter,
                     name: str, display_format: str = 'int'):
        """Print matrix in either int (raw fixed-int) or float (converted)"""
        print(f"\n{name}:")
        for row in matrix:
            parts = []
            for v in row:
                vi = int(v)
                if display_format == 'float':
                    parts.append(f"{converter.fixed_to_float(vi):8.4f}")
                else:
                    parts.append(f"{vi:6}")
            print(" ".join(parts))

    def export_matrix(self, matrix: np.ndarray, converter: FixedPointConverter,
                      filename: str, mode: str = 'row',
                      block_size: int = 2, num_cores: int = 1,
                      matrix_type: str = 'A'):
        """
        Export matrix:
          - mode 'row' => simple row-by-row binary strings
          - mode 'core' => core block formats:
             * matrix_type 'A' => _export_core_mode_A
             * matrix_type 'B' => _export_core_mode_B
             * matrix_type 'C' => _export_core_mode_C
        """
        rows, cols = matrix.shape
        if mode == 'row':
            self._export_row_mode(matrix, converter, filename)
        elif mode == 'core':
            if matrix_type == 'A':
                self._export_core_mode_A(matrix, converter, filename, block_size, num_cores)
            elif matrix_type == 'B':
                self._export_core_mode_B(matrix, converter, filename, block_size, num_cores)
            elif matrix_type == 'C':
                # For C we rely on processor.cores_a and cores_b
                self._export_core_mode_C(matrix, converter, filename, block_size)

    def _export_row_mode(self, matrix: np.ndarray, converter: FixedPointConverter, filename: str):
        with open(filename, 'w') as f:
            for row in matrix:
                f.write(" ".join(converter.int_to_binary(int(x)) for x in row) + "\n")

    def _export_core_mode_A(self, matrix: np.ndarray, converter: FixedPointConverter, filename: str,
                             block_size: int, num_cores: int):
        """
        Export matrix A in core block format (horizontal access).
        Requirements:
          - rows % (num_cores * block_size) == 0
          - cols % block_size == 0
        """
        rows, cols = matrix.shape
        if rows % (num_cores * block_size) != 0:
            raise ValueError(f"Matrix A: Rows ({rows}) must be divisible by cores×block_size ({num_cores}×{block_size})")
        if cols % block_size != 0:
            raise ValueError(f"Matrix A: Cols ({cols}) must be divisible by block_size ({block_size})")

        row_groups = rows // (num_cores * block_size)
        blocks_per_row = cols // block_size

        with open(filename, 'w') as f:
            for g in range(row_groups):
                base_row = g * num_cores * block_size
                for block_col in range(blocks_per_row):
                    col_start = block_col * block_size
                    elements = []
                    for core in range(num_cores):
                        rstart = base_row + core * block_size
                        block = matrix[rstart:rstart+block_size, col_start:col_start+block_size]
                        for r in range(block_size):
                            for c in range(block_size):
                                elements.append(converter.int_to_binary(int(block[r, c])))
                    f.write(" ".join(elements) + "\n")

    def _export_core_mode_B(self, matrix: np.ndarray, converter: FixedPointConverter, filename: str,
                             block_size: int, num_cores: int):
        """
        Export matrix B in core block format (vertical access).
        Requirements:
          - cols % (num_cores * block_size) == 0
          - rows % block_size == 0
        """
        rows, cols = matrix.shape
        if cols % (num_cores * block_size) != 0:
            raise ValueError(f"Matrix B: Cols ({cols}) must be divisible by cores×block_size ({num_cores}×{block_size})")
        if rows % block_size != 0:
            raise ValueError(f"Matrix B: Rows ({rows}) must be divisible by block_size ({block_size})")

        col_groups = cols // (num_cores * block_size)
        blocks_per_col = rows // block_size

        with open(filename, 'w') as f:
            for g in range(col_groups):
                base_col = g * num_cores * block_size
                for block_row in range(blocks_per_col):
                    rstart = block_row * block_size
                    elements = []
                    for core in range(num_cores):
                        cstart = base_col + core * block_size
                        block = matrix[rstart:rstart+block_size, cstart:cstart+block_size]
                        for c in range(block_size):
                            for r in range(block_size):
                                elements.append(converter.int_to_binary(int(block[r, c])))
                    f.write(" ".join(elements) + "\n")

    def _export_core_mode_C(self, matrix: np.ndarray, converter: FixedPointConverter, filename: str,
                             block_size: int):
        """
        Export matrix C in core block format using self.cores_a and self.cores_b
        Requirements:
          - rows % (cores_a * block_size) == 0
          - cols % (cores_b * block_size) == 0
        """
        rows, cols = matrix.shape
        if rows % (self.cores_a * block_size) != 0:
            raise ValueError(f"Matrix C: Rows ({rows}) must be divisible by cores_a×block_size ({self.cores_a}×{block_size})")
        if cols % (self.cores_b * block_size) != 0:
            raise ValueError(f"Matrix C: Cols ({cols}) must be divisible by cores_b×block_size ({self.cores_b}×{block_size})")

        row_groups = rows // (self.cores_a * block_size)
        col_groups = cols // (self.cores_b * block_size)

        with open(filename, 'w') as f:
            for rg in range(row_groups):
                rbase = rg * self.cores_a * block_size
                for cg in range(col_groups):
                    cbase = cg * self.cores_b * block_size
                    elements = []
                    for cb in range(self.cores_b):
                        csub = cbase + cb * block_size
                        for ra in range(self.cores_a):
                            rsub = rbase + ra * block_size
                            block = matrix[rsub:rsub+block_size, csub:csub+block_size]
                            for r in range(block_size):
                                for c in range(block_size):
                                    elements.append(converter.int_to_binary(int(block[r, c])))
                    f.write(" ".join(elements) + "\n")

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
    Generate input matrix A, weight matrices (Wq/Wk/Wv) and compute projections (Q/K/V).
    Export:
      - exports/mem_input.mem         (A arrangement, core mode)
      - exports/mem_q{h}.mem, ...     (B arrangement for weights)
      - exports/mem_out_q{h}.mem ... (C arrangement for outputs)
    Behavior:
      - If unique_per_type: generate only one Wq/Wk/Wv (exported as mem_q1.mem etc.)
        and compute/export/print only out_q1/out_k1/out_v1.
      - If unique_per_head: generate distinct weights per head and compute/export/print all heads.
    """
    os.makedirs("exports", exist_ok=True)
    processor.cores_a = cores_a
    processor.cores_b = cores_b

    # Create input A
    A = processor.create_matrix(rows_a, cols_a, min_val, max_val, conv_A, integers_only)
    in_fname = "exports/mem_input.mem"
    processor.export_matrix(A, conv_A, in_fname, mode='core', block_size=block_size, num_cores=cores_a, matrix_type='A')
    processor.print_matrix(A, conv_A, "Input Matrix A", display)

    # Weight dimensions: (cols_a x proj_dim) so that A(rows_a x cols_a) * W(cols_a x proj_dim) -> (rows_a x proj_dim)
    weight_rows, weight_cols = cols_a, proj_dim

    # Prepare weight lists
    Wq_list = []
    Wk_list = []
    Wv_list = []

    if unique_per_type:
        # generate one of each and reuse
        Wq = processor.create_matrix(weight_rows, weight_cols, min_val, max_val, conv_W, integers_only)
        Wk = processor.create_matrix(weight_rows, weight_cols, min_val, max_val, conv_W, integers_only)
        Wv = processor.create_matrix(weight_rows, weight_cols, min_val, max_val, conv_W, integers_only)
        Wq_list = [Wq] * heads  # used internally, but they all point to same matrix
        Wk_list = [Wk] * heads
        Wv_list = [Wv] * heads
        # Export only one copy for each type (mem_q1.mem etc.)
        processor.export_matrix(Wq, conv_W, f"exports/mem_q1.mem", mode='core', block_size=block_size, num_cores=cores_b, matrix_type='B')
        processor.export_matrix(Wk, conv_W, f"exports/mem_k1.mem", mode='core', block_size=block_size, num_cores=cores_b, matrix_type='B')
        processor.export_matrix(Wv, conv_W, f"exports/mem_v1.mem", mode='core', block_size=block_size, num_cores=cores_b, matrix_type='B')
        if display:
            processor.print_matrix(Wq, conv_W, "Weight Wq (type)", display)
            processor.print_matrix(Wk, conv_W, "Weight Wk (type)", display)
            processor.print_matrix(Wv, conv_W, "Weight Wv (type)", display)

    else:
        # unique_per_head: generate distinct matrices per head and export each
        for h in range(heads):
            wq = processor.create_matrix(weight_rows, weight_cols, min_val, max_val, conv_W, integers_only)
            wk = processor.create_matrix(weight_rows, weight_cols, min_val, max_val, conv_W, integers_only)
            wv = processor.create_matrix(weight_rows, weight_cols, min_val, max_val, conv_W, integers_only)
            Wq_list.append(wq)
            Wk_list.append(wk)
            Wv_list.append(wv)
            processor.export_matrix(wq, conv_W, f"exports/mem_q{h+1}.mem", mode='core', block_size=block_size, num_cores=cores_b, matrix_type='B')
            processor.export_matrix(wk, conv_W, f"exports/mem_k{h+1}.mem", mode='core', block_size=block_size, num_cores=cores_b, matrix_type='B')
            processor.export_matrix(wv, conv_W, f"exports/mem_v{h+1}.mem", mode='core', block_size=block_size, num_cores=cores_b, matrix_type='B')
            if display:
                processor.print_matrix(wq, conv_W, f"Weight Wq head {h+1}", display)
                processor.print_matrix(wk, conv_W, f"Weight Wk head {h+1}", display)
                processor.print_matrix(wv, conv_W, f"Weight Wv head {h+1}", display)

    # Compute outputs and export
    # If unique_per_type: we only print/export head 1 (out_q1/out_k1/out_v1)
    # If unique_per_head: we print/export all heads
    head_indices: List[int] = [0] if unique_per_type else list(range(heads))

    for idx in head_indices:
        Q = processor.multiply_matrices(A, Wq_list[idx], conv_A, conv_W, conv_C)
        K = processor.multiply_matrices(A, Wk_list[idx], conv_A, conv_W, conv_C)
        V = processor.multiply_matrices(A, Wv_list[idx], conv_A, conv_W, conv_C)

        out_q_name = f"exports/mem_out_q{idx+1}.mem"
        out_k_name = f"exports/mem_out_k{idx+1}.mem"
        out_v_name = f"exports/mem_out_v{idx+1}.mem"

        # Ensure processor has correct cores for exporting C
        processor.cores_a = cores_a
        processor.cores_b = cores_b

        processor.export_matrix(Q, conv_C, out_q_name, mode='core', block_size=block_size, num_cores=None, matrix_type='C')
        processor.export_matrix(K, conv_C, out_k_name, mode='core', block_size=block_size, num_cores=None, matrix_type='C')
        processor.export_matrix(V, conv_C, out_v_name, mode='core', block_size=block_size, num_cores=None, matrix_type='C')

        # Print results (float or int depending display)
        processor.print_matrix(Q, conv_C, f"Out_Q{idx+1}", display)
        processor.print_matrix(K, conv_C, f"Out_K{idx+1}", display)
        processor.print_matrix(V, conv_C, f"Out_V{idx+1}", display)

    print("\nLinear projection exports written to 'exports/'")

# ---------------------------
# main
# ---------------------------
def main():
    parser = argparse.ArgumentParser(description="Matrix multiplier + linear projection exporter")
    parser.add_argument('--task', choices=['matmul', 'linear_projection'], default='matmul')
    parser.add_argument('--display', choices=['int', 'float'], default='int',
                        help='Format to display matrices (int: raw fixed-int, float: converted)')
    parser.add_argument('--min_val', type=float, default=0.0)
    parser.add_argument('--max_val', type=float, default=2.0)
    parser.add_argument('--integers', action='store_true', help='Use integer-only random generation')
    parser.add_argument('--block_size', type=int, default=2)
    parser.add_argument('--cores_a', type=int, default=2)
    parser.add_argument('--cores_b', type=int, default=2)

    # linear projection specific
    parser.add_argument('--heads', type=int, default=4, help='Number of heads (default 4)')
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--unique_per_head', action='store_true', help='Unique weights per head (generate all heads)')
    group.add_argument('--unique_per_type', action='store_true', help='One Wq/Wk/Wv reused for all heads')

    # matrix shapes
    parser.add_argument('--rows_a', type=int, default=8)
    parser.add_argument('--cols_a', type=int, default=6)
    parser.add_argument('--proj_dim', type=int, default=8)

    args = parser.parse_args()

    # fixed-point config (can be made CLI params if needed)
    fp_A = (16, 8, True)
    fp_B = (16, 8, True)
    fp_C = (16, 8, True)

    conv_A = FixedPointConverter(*fp_A)
    conv_W = FixedPointConverter(*fp_B)
    conv_C = FixedPointConverter(*fp_C)

    processor = MatrixProcessor()
    processor.cores_a = args.cores_a
    processor.cores_b = args.cores_b

    if args.task == 'matmul':
        # original behavior (unchanged)
        ROWS_A, COLS_A = args.rows_a, args.cols_a
        COLS_B = args.proj_dim
        A = processor.create_matrix(ROWS_A, COLS_A, args.min_val, args.max_val, conv_A, args.integers)
        B = processor.create_matrix(COLS_A, COLS_B, args.min_val, args.max_val, conv_W, args.integers)
        C = processor.multiply_matrices(A, B, conv_A, conv_W, conv_C)

        processor.print_matrix(A, conv_A, "Matrix A", args.display)
        processor.print_matrix(B, conv_W, "Matrix B", args.display)
        processor.print_matrix(C, conv_C, "Matrix C (A x B)", args.display)

        os.makedirs("exports", exist_ok=True)
        processor.export_matrix(A, conv_A, "exports/matrix_A_row.mem", mode='row')
        processor.export_matrix(B, conv_W, "exports/matrix_B_row.mem", mode='row')
        processor.export_matrix(C, conv_C, "exports/matrix_C_row.mem", mode='row')

        processor.export_matrix(A, conv_A, "exports/matrix_A_core.mem", mode='core', block_size=args.block_size, num_cores=args.cores_a, matrix_type='A')
        processor.export_matrix(B, conv_W, "exports/matrix_B_core.mem", mode='core', block_size=args.block_size, num_cores=args.cores_b, matrix_type='B')
        processor.export_matrix(C, conv_C, "exports/matrix_C_core.mem", mode='core', block_size=args.block_size, num_cores=None, matrix_type='C')

        print("\nExports saved to 'exports' directory (matmul)")

    elif args.task == 'linear_projection':
        heads = args.heads if args.heads > 0 else 4
        unique_head = bool(args.unique_per_head)
        unique_type = bool(args.unique_per_type)

        # If neither specified, default to unique_per_head (generate distinct heads)
        if not unique_head and not unique_type:
            unique_head = True

        generate_linear_projection(
            processor=processor,
            conv_A=conv_A,
            conv_W=conv_W,
            conv_C=conv_C,
            rows_a=args.rows_a,
            cols_a=args.cols_a,
            proj_dim=args.proj_dim,
            heads=heads,
            unique_per_head=unique_head,
            unique_per_type=unique_type,
            block_size=args.block_size,
            cores_a=args.cores_a,
            cores_b=args.cores_b,
            integers_only=args.integers,
            min_val=args.min_val,
            max_val=args.max_val,
            display=args.display
        )

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
block_matmul.py

Block-based matrix multiplication driver using matrix_multiplier_v2 utilities.

- Reads floating-point matrix A and B from text files
- Converts to fixed-point (single global format)
- Performs block matrix multiplication
- Exports Matrix C in core-mode format (matrix_C rules)

Example:
 python -u "d:\DATA\Documents\Xirka Internship\PME\Transformer\transformer\Python Model\block_matmul.py" --matrix_A "d:\DATA\Documents\Xirka Internship\PME\Transformer\transformer\Python Model\A.txt" --matrix_B "d:\DATA\Documents\Xirka Internship\PME\Transformer\transformer\Python Model\B.txt" --cores_a 2 --cores_b 2 --display float
"""

import argparse
import numpy as np
import os

# Reuse your existing implementation
from matrix_multiplier_v2 import FixedPointConverter, MatrixProcessor

BLOCK_SIZE = 2  # fixed by design


# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------
def load_float_matrix(path: str) -> np.ndarray:
    """
    Load a floating-point matrix from text file.
    Expected format:
      1.0 2.0 3.0
      4.0 5.0 6.0
    """
    try:
        return np.loadtxt(path, dtype=np.float64)
    except Exception as e:
        raise RuntimeError(f"Failed to load matrix from {path}: {e}")


def float_to_fixed_matrix(mat: np.ndarray, conv: FixedPointConverter) -> np.ndarray:
    vec = np.vectorize(conv.float_to_fixed)
    return vec(mat).astype(np.int64)


# ------------------------------------------------------------
# Block Matrix Multiplication
# ------------------------------------------------------------
def block_matmul(A: np.ndarray,
                 B: np.ndarray,
                 processor: MatrixProcessor,
                 conv: FixedPointConverter) -> np.ndarray:
    """
    Perform block matrix multiplication with block_size = 2.

    Computation is done in float domain per block,
    final output is converted to fixed-point.
    """

    rows_a, cols_a = A.shape
    rows_b, cols_b = B.shape

    assert cols_a == rows_b, "Matrix dimension mismatch A.cols != B.rows"

    # Convert fixed → float for computation
    to_float = np.vectorize(conv.fixed_to_float)
    A_f = to_float(A)
    B_f = to_float(B)

    C_f = np.zeros((rows_a, cols_b), dtype=np.float64)

    for i in range(0, rows_a, BLOCK_SIZE):
        for j in range(0, cols_b, BLOCK_SIZE):
            for k in range(0, cols_a, BLOCK_SIZE):
                A_blk = A_f[i:i+BLOCK_SIZE, k:k+BLOCK_SIZE]
                B_blk = B_f[k:k+BLOCK_SIZE, j:j+BLOCK_SIZE]
                C_f[i:i+BLOCK_SIZE, j:j+BLOCK_SIZE] += A_blk @ B_blk

    # Convert result back to fixed-point
    to_fixed = np.vectorize(conv.float_to_fixed)
    return to_fixed(C_f).astype(np.int64)


# ------------------------------------------------------------
# Main
# ------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(description="Block Matrix Multiplication Tool")

    parser.add_argument('--matrix_A', required=True, help='Path to matrix A (float txt)')
    parser.add_argument('--matrix_B', required=True, help='Path to matrix B (float txt)')

    parser.add_argument('--total_bits', type=int, default=16)
    parser.add_argument('--frac_bits', type=int, default=8)
    parser.add_argument('--signed', action='store_true', default=True)

    parser.add_argument('--cores_a', type=int, required=True)
    parser.add_argument('--cores_b', type=int, required=True)

    parser.add_argument('--display', choices=['int', 'float', 'none'], default='none',
                        help='Print matrices or not')

    args = parser.parse_args()

    # --------------------------------------------------------
    # Load matrices
    # --------------------------------------------------------
    A_float = load_float_matrix(args.matrix_A)
    B_float = load_float_matrix(args.matrix_B)

    rows_a, cols_a = A_float.shape
    rows_b, cols_b = B_float.shape

    if cols_a != rows_b:
        raise ValueError("Invalid dimensions: A.cols must equal B.rows")

    # --------------------------------------------------------
    # Fixed-point setup
    # --------------------------------------------------------
    conv = FixedPointConverter(
        total_bits=args.total_bits,
        fractional_bits=args.frac_bits,
        is_signed=args.signed
    )

    A = float_to_fixed_matrix(A_float, conv)
    B = float_to_fixed_matrix(B_float, conv)

    # --------------------------------------------------------
    # Processor config
    # --------------------------------------------------------
    processor = MatrixProcessor()
    processor.cores_a = args.cores_a
    processor.cores_b = args.cores_b

    # --------------------------------------------------------
    # Dimension checks (core-mode C rules)
    # --------------------------------------------------------
    if rows_a % (args.cores_a * BLOCK_SIZE) != 0:
        raise ValueError("Rows of C not divisible by cores_a × block_size")

    if cols_b % (args.cores_b * BLOCK_SIZE) != 0:
        raise ValueError("Cols of C not divisible by cores_b × block_size")

    # --------------------------------------------------------
    # Block matrix multiplication
    # --------------------------------------------------------
    C = block_matmul(A, B, processor, conv)

    # --------------------------------------------------------
    # Optional printing
    # --------------------------------------------------------
    if args.display != 'none':
        processor.print_matrix(A, conv, "Matrix A", args.display)
        processor.print_matrix(B, conv, "Matrix B", args.display)
        processor.print_matrix(C, conv, "Matrix C (Block MatMul)", args.display)

    # --------------------------------------------------------
    # Export Matrix C (core mode)
    # --------------------------------------------------------
    os.makedirs("exports", exist_ok=True)
    out_name = "exports/matrix_C_bmm_core.mem"

    processor.export_matrix(
        matrix=C,
        converter=conv,
        filename=out_name,
        mode='core',
        block_size=BLOCK_SIZE,
        num_cores=None,
        matrix_type='C'
    )

    print(f"\n✅ Block matrix multiplication complete")
    print(f"📄 Output written to: {out_name}")


if __name__ == "__main__":
    main()

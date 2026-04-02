#!/usr/bin/env python3
"""
block_matmul.py (FINAL VERSION - MIXED INPUT SUPPORT)

Features:
- Mixed input formats:
    A: float / hex
    B: float / hex
- Output format: float / int / hex
- Output layout: normal / block
"""

import argparse
import numpy as np
import os

from matrix_multiplier_v2 import FixedPointConverter, MatrixProcessor

BLOCK_SIZE = 2


# ------------------------------------------------------------
# Loaders
# ------------------------------------------------------------
def load_float_matrix(path: str) -> np.ndarray:
    return np.loadtxt(path, dtype=np.float64)


def load_hex_matrix(path: str) -> np.ndarray:
    data = []
    with open(path, 'r') as f:
        for line in f:
            row = [int(x, 16) for x in line.strip().split()]
            data.append(row)
    return np.array(data, dtype=np.int64)


def float_to_fixed_matrix(mat: np.ndarray, conv: FixedPointConverter) -> np.ndarray:
    vec = np.vectorize(conv.float_to_fixed)
    return vec(mat).astype(np.int64)


# ------------------------------------------------------------
# Printing helper
# ------------------------------------------------------------
def print_matrix_custom(matrix, conv, name, fmt):
    print(f"\n{name}:")
    for row in matrix:
        parts = []
        for v in row:
            vi = int(v)
            if fmt == 'float':
                parts.append(f"{conv.fixed_to_float(vi):8.4f}")
            elif fmt == 'hex':
                parts.append(f"{vi:04x}")
            else:
                parts.append(f"{vi}")
        print(" ".join(parts))


# ------------------------------------------------------------
# Block Matrix Multiplication
# ------------------------------------------------------------
def block_matmul(A, B, conv):
    rows_a, cols_a = A.shape
    rows_b, cols_b = B.shape

    assert cols_a == rows_b, "Matrix dimension mismatch"

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

    to_fixed = np.vectorize(conv.float_to_fixed)
    return to_fixed(C_f).astype(np.int64)


# ------------------------------------------------------------
# Export helper
# ------------------------------------------------------------
def export_matrix_custom(matrix, conv, filename, fmt, layout):
    os.makedirs(os.path.dirname(filename), exist_ok=True)

    if layout == 'normal':
        with open(filename, 'w') as f:
            for row in matrix:
                line = []
                for v in row:
                    vi = int(v)
                    if fmt == 'float':
                        line.append(f"{conv.fixed_to_float(vi):.6f}")
                    elif fmt == 'hex':
                        line.append(f"{vi:04x}")
                    else:
                        line.append(str(vi))
                f.write(" ".join(line) + "\n")

    else:  # block layout
        rows, cols = matrix.shape
        bs = BLOCK_SIZE

        with open(filename, 'w') as f:
            for i in range(0, rows, bs):
                for j in range(0, cols, bs):
                    block = matrix[i:i+bs, j:j+bs]

                    elements = []
                    for r in range(bs):
                        for c in range(bs):
                            vi = int(block[r, c])
                            if fmt == 'float':
                                elements.append(f"{conv.fixed_to_float(vi):.6f}")
                            elif fmt == 'hex':
                                elements.append(f"{vi:04x}")
                            else:
                                elements.append(str(vi))

                    f.write(" ".join(elements) + "\n")


# ------------------------------------------------------------
# Main
# ------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(description="Block MatMul (Mixed Input Support)")

    parser.add_argument('--matrix_A', required=True)
    parser.add_argument('--matrix_B', required=True)

    # 🔥 NEW: separate formats
    parser.add_argument('--input_format_A', choices=['float', 'hex'], default='float')
    parser.add_argument('--input_format_B', choices=['float', 'hex'], default='float')

    parser.add_argument('--output_format', choices=['float', 'int', 'hex'], default='int')
    parser.add_argument('--output_layout', choices=['normal', 'block'], default='block')

    parser.add_argument('--total_bits', type=int, default=16)
    parser.add_argument('--frac_bits', type=int, default=8)
    parser.add_argument('--signed', action='store_true', default=True)

    parser.add_argument('--cores_a', type=int, required=True)
    parser.add_argument('--cores_b', type=int, required=True)

    parser.add_argument('--display', action='store_true')

    args = parser.parse_args()

    # --------------------------------------------------------
    # Fixed-point setup
    # --------------------------------------------------------
    conv = FixedPointConverter(
        total_bits=args.total_bits,
        fractional_bits=args.frac_bits,
        is_signed=args.signed
    )

    # --------------------------------------------------------
    # Load A
    # --------------------------------------------------------
    if args.input_format_A == 'float':
        A_float = load_float_matrix(args.matrix_A)
        A = float_to_fixed_matrix(A_float, conv)
    else:
        A = load_hex_matrix(args.matrix_A)

    # --------------------------------------------------------
    # Load B
    # --------------------------------------------------------
    if args.input_format_B == 'float':
        B_float = load_float_matrix(args.matrix_B)
        B = float_to_fixed_matrix(B_float, conv)
    else:
        B = load_hex_matrix(args.matrix_B)

    rows_a, cols_a = A.shape
    rows_b, cols_b = B.shape

    if cols_a != rows_b:
        raise ValueError("A.cols must equal B.rows")

    # --------------------------------------------------------
    # Dimension checks (important for HW)
    # --------------------------------------------------------
    if rows_a % (args.cores_a * BLOCK_SIZE) != 0:
        raise ValueError("Rows not divisible by cores_a × block_size")

    if cols_b % (args.cores_b * BLOCK_SIZE) != 0:
        raise ValueError("Cols not divisible by cores_b × block_size")

    # --------------------------------------------------------
    # Compute
    # --------------------------------------------------------
    C = block_matmul(A, B, conv)

    # --------------------------------------------------------
    # Display
    # --------------------------------------------------------
    if args.display:
        print_matrix_custom(A, conv, "Matrix A", args.output_format)
        print_matrix_custom(B, conv, "Matrix B", args.output_format)
        print_matrix_custom(C, conv, "Matrix C", args.output_format)

    # --------------------------------------------------------
    # Export
    # --------------------------------------------------------
    out_file = "exports/matrix_C_result.mem"

    export_matrix_custom(
        matrix=C,
        conv=conv,
        filename=out_file,
        fmt=args.output_format,
        layout=args.output_layout
    )

    print("\n✅ Done")
    print(f"📄 Output: {out_file}")


if __name__ == "__main__":
    main()
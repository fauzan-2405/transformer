#!/usr/bin/env python3
"""
block_matmul.py (FINAL VERSION - MIXED INPUT SUPPORT)

Features:
- Mixed input formats:
    A: float / hex
    B: float / hex
- Output format: float / int / hex
- Output layout: normal / block

example usage:
 python "d:\DATA\Documents\Xirka Internship\PME\Transformer\transformer\Python Model\block_matmul.py" --matrix_A "D:\DATA\Documents\Xirka Internship\PME\Transformer\transformer\exports\softmax_results.txt" 
            --matrix_B "D:\DATA\Documents\Xirka Internship\PME\Transformer\transformer\Python Model\B.txt" --input_format_A hex --input_format_B float 
            --cores_a 2 --cores_b 2 --display --export_c_v2 --transpose_B
"""

import argparse
import numpy as np
import os

from matrix_multiplier import FixedPointConverter, MatrixProcessor

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
    dirpath = os.path.dirname(filename)
    if dirpath:
        os.makedirs(dirpath, exist_ok=True)

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

def debug_print_c_v2(matrix, conv, cores_a, cores_b, block_size, total_input_w, total_modules):
    rows, cols = matrix.shape

    row_groups = rows // (cores_a * total_input_w * block_size)
    col_groups = cols // (cores_b * total_modules * block_size)

    line_idx = 0

    for rg in range(row_groups):
        rbase = rg * cores_a * total_input_w * block_size

        for cg in range(col_groups):
            cbase = cg * cores_b * total_modules * block_size

            line_slices = []

            for iw in range(total_input_w):
                elements = []

                for module in range(total_modules):
                    for cb in range(cores_b):

                        cstart = cbase + (module * cores_b + cb) * block_size

                        for ra in range(cores_a):
                            rstart = rbase + (iw * cores_a + ra) * block_size

                            block = matrix[
                                rstart:rstart+block_size,
                                cstart:cstart+block_size
                            ]

                            for r in range(block_size):
                                for c in range(block_size):
                                    elements.append(f"{int(block[r, c]):04x}")

                line_slices.append(elements)

            print(f"\nLine {line_idx}, 0:", " ".join(line_slices[0]))
            for i in range(1, len(line_slices)):
                print(f"         {i}:", " ".join(line_slices[i]))

            line_idx += 1

# ------------------------------------------------------------
# Main
# ------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(description="Block MatMul (Mixed Input Support)")

    parser.add_argument('--matrix_A', required=True)
    parser.add_argument('--matrix_B', required=True)

    # separate formats
    parser.add_argument('--input_format_A', choices=['float', 'hex'], default='float')
    parser.add_argument('--input_format_B', choices=['float', 'hex'], default='float')

    parser.add_argument('--output_format', choices=['float', 'int', 'hex'], default='hex')
    parser.add_argument('--output_layout', choices=['normal', 'block'], default='block')

    parser.add_argument('--total_bits', type=int, default=16)
    parser.add_argument('--frac_bits', type=int, default=8)
    parser.add_argument('--signed', action='store_true', default=True)

    parser.add_argument('--cores_a', type=int, required=True)
    parser.add_argument('--cores_b', type=int, required=True)
    parser.add_argument('--total_input_w', type=int, default=2)
    parser.add_argument('--total_modules', type=int, default=1)

    parser.add_argument('--export_c_v2', action='store_true')
    parser.add_argument('--transpose_B', action='store_true',
                    help='Transpose matrix B before multiplication')

    parser.add_argument('--output_file', required=True,
                    help='Output file path (.txt or .mem)')

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

    # --------------------------------------------------------
    # Optional transpose (for Q × Kᵀ)
    # --------------------------------------------------------
    if args.transpose_B:
        B = B.T

    rows_a, cols_a = A.shape
    rows_b, cols_b = B.shape

    if cols_a != rows_b:
        raise ValueError("A.cols must equal B.rows")

    # --------------------------------------------------------
    # Dimension checks (important for HW)
    # --------------------------------------------------------
    if rows_a % (args.cores_a * args.total_input_w * BLOCK_SIZE) != 0:
        raise ValueError("Rows not divisible by cores_a × total_input_w × block_size")

    if cols_b % (args.cores_b * args.total_modules * BLOCK_SIZE) != 0:
        raise ValueError("Cols not divisible by cores_b × total_modules × block_size")

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
    out_file = args.output_file

    processor = MatrixProcessor()
    processor.cores_a = args.cores_a
    processor.cores_b = args.cores_b

    if args.export_c_v2:
        # RTL Format Export
        processor.export_matrix_C_v2(
            matrix=C,
            converter=conv,
            filename=out_file,
            block_size=BLOCK_SIZE,
            total_input_w=args.total_input_w,
            total_modules=args.total_modules,
            output_format='hex',
            debug_print=True
        )

        #2 Real Format Export
        base, ext = os.path.splitext(out_file)
        row_file = f"{base}_row{ext}"
        with open(row_file, 'w') as f:
            for row in C:
                line = " ".join(conv.int_to_hex(int(v)) for v in row)
                f.write(line + "\n")

        print(f"Row output: {row_file}")
    else:
        export_matrix_custom(
            matrix=C,
            conv=conv,
            filename=out_file,
            fmt=args.output_format,
            layout=args.output_layout
        )
    
    if args.display and args.export_c_v2:
        debug_print_c_v2(
            C, conv,
            args.cores_a,
            args.cores_b,
            BLOCK_SIZE,
            args.total_input_w,
            args.total_modules
        )

    print("\n Done")
    print(f"Output: {out_file}")


if __name__ == "__main__":
    main()
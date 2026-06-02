#!/usr/bin/env python3
"""
softmax_real.py

REAL Softmax Reference Model
============================

Features:
---------
1. Reads input matrix from:
    - .txt
    - .mem

2. Supports:
    - hex fixed-point input
    - signed fixed-point conversion

3. Computes REAL softmax:
       softmax(x_i) = exp(x_i) / sum(exp(x))

4. Optional scaling:
       x = x / div_value

5. Quantizes output back into fixed-point

6. Exports:
       softmax_real_results.txt

Example:
--------
python softmax_real.py \
    --input_file Q_KT.mem \
    --total_bits 16 \
    --frac_bits 8 \
    --apply_div \
    --div_value 16
"""

import argparse
import numpy as np
import os


# ============================================================
# Fixed Point Converter
# ============================================================
class FixedPointConverter:
    def __init__(self, total_bits, frac_bits):
        self.total_bits = total_bits
        self.frac_bits = frac_bits

        self.max_int = (1 << (total_bits - 1)) - 1
        self.min_int = -(1 << (total_bits - 1))

    def fixed_to_float(self, val):
        """
        Convert signed fixed-point integer -> float
        """
        if val & (1 << (self.total_bits - 1)):
            val -= (1 << self.total_bits)

        return float(val) / (1 << self.frac_bits)

    def float_to_fixed(self, x):
        """
        Convert float -> signed fixed-point integer
        """
        scaled = int(round(x * (1 << self.frac_bits)))

        if scaled > self.max_int:
            scaled = self.max_int

        if scaled < self.min_int:
            scaled = self.min_int

        return scaled

    def int_to_hex(self, val):
        """
        Convert signed integer -> hex
        """
        if val < 0:
            val = (1 << self.total_bits) + val

        width_hex = (self.total_bits + 3) // 4
        return f"{val:0{width_hex}X}"


# ============================================================
# Load Matrix
# ============================================================
def load_hex_matrix(path):
    matrix = []

    with open(path, 'r') as f:
        for line in f:
            line = line.strip()

            if not line:
                continue

            row = [int(x, 16) for x in line.split()]
            matrix.append(row)

    return np.array(matrix, dtype=np.int64)


# ============================================================
# Convert Fixed -> Float Matrix
# ============================================================
def fixed_matrix_to_float(matrix, conv):
    out = np.zeros(matrix.shape, dtype=np.float64)

    for i in range(matrix.shape[0]):
        for j in range(matrix.shape[1]):
            out[i, j] = conv.fixed_to_float(int(matrix[i, j]))

    return out


# ============================================================
# Convert Float -> Fixed Matrix
# ============================================================
def float_matrix_to_fixed(matrix, conv):
    out = np.zeros(matrix.shape, dtype=np.int64)

    for i in range(matrix.shape[0]):
        for j in range(matrix.shape[1]):
            x = max(0.0, min(1.0, float(matrix[i, j])))
            out[i, j] = conv.float_to_fixed(x)

    return out


# ============================================================
# REAL Softmax
# ============================================================
def softmax_real(x):
    """
    Numerically stable softmax
    """

    # subtract max for stability
    x_shift = x - np.max(x, axis=1, keepdims=True)

    exp_x = np.exp(x_shift)

    sum_exp = np.sum(exp_x, axis=1, keepdims=True)

    return exp_x / sum_exp


# ============================================================
# Export
# ============================================================
def export_hex_matrix(matrix, conv, filename):
    with open(filename, 'w') as f:
        for row in matrix:
            line = " ".join(conv.int_to_hex(int(v)) for v in row)
            f.write(line + "\n")


# ============================================================
# Main
# ============================================================
def main():

    parser = argparse.ArgumentParser(description="REAL Softmax Reference Model")

    parser.add_argument('--input_file', required=True)

    # input format
    parser.add_argument("--width_in", type=int, default=16)
    parser.add_argument("--frac_in", type=int, default=8)

    # output format
    parser.add_argument("--width_out", type=int, default=8)
    parser.add_argument("--frac_out", type=int, default=7)

    parser.add_argument('--apply_div', action='store_true')
    parser.add_argument('--div_value', type=float, default=16.0)

    parser.add_argument(
        '--output_file',
        default='softmax_real_results.txt'
    )

    parser.add_argument('--display', action='store_true')

    args = parser.parse_args()

    # --------------------------------------------------------
    # Converter
    # --------------------------------------------------------
    conv_in = FixedPointConverter(
        total_bits=args.width_in,
        frac_bits=args.frac_in
    )

    conv_out = FixedPointConverter(
        total_bits=args.width_out,
        frac_bits=args.frac_out
    )

    # --------------------------------------------------------
    # Load Input
    # --------------------------------------------------------
    matrix_fixed = load_hex_matrix(args.input_file)

    # --------------------------------------------------------
    # Convert to float
    # --------------------------------------------------------
    matrix_float = fixed_matrix_to_float(matrix_fixed, conv_in)

    # --------------------------------------------------------
    # Optional division
    # --------------------------------------------------------
    if args.apply_div:
        matrix_float = matrix_float / args.div_value

    # --------------------------------------------------------
    # REAL softmax
    # --------------------------------------------------------
    softmax_out = softmax_real(matrix_float)

    # --------------------------------------------------------
    # Quantize output
    # --------------------------------------------------------
    softmax_fixed = float_matrix_to_fixed(softmax_out, conv_out)

    # --------------------------------------------------------
    # Export
    # --------------------------------------------------------
    export_hex_matrix(
        softmax_fixed,
        conv_out,
        args.output_file
    )

    # --------------------------------------------------------
    # Display
    # --------------------------------------------------------
    if args.display:

        np.set_printoptions(
            suppress=True,
            precision=6
        )

        print("\nInput Float Matrix:")
        print(matrix_float)

        print("\nSoftmax Float Output:")
        print(softmax_out)

        print("\nSoftmax Fixed Output:")
        print(softmax_fixed)

    print("\nDone.")
    print(f"Output saved to: {args.output_file}")


if __name__ == "__main__":
    main()
import numpy as np
import os


def float_to_fixed_bin(val, bit_width, frac_width):
    scale = 2 ** frac_width
    int_val = int(np.round(val * scale))
    if int_val < 0:
        int_val = (1 << bit_width) + int_val
    return format(int_val & ((1 << bit_width) - 1), f'0{bit_width}b')


def generate_matrix(rows, cols, min_val, max_val):
    return np.random.uniform(low=min_val, high=max_val, size=(rows, cols))


def fixed_point_matrix(matrix, bit_width, frac_width):
    return np.vectorize(lambda x: float_to_fixed_bin(x, bit_width, frac_width))(matrix)


def print_matrix(name, matrix):
    print(f"\n{name} =")
    for row in matrix:
        print("  ", ["{:.3f}".format(x) for x in row])


def matrix_multiply(A, B):
    return np.dot(A, B)


def export_row_mode(matrix_bin, filename):
    with open(filename, 'w') as f:
        for row in matrix_bin:
            for val in row:
                f.write(val + '\n')


def export_core_mode_A(matrix_bin, filename, num_cores):
    rows, cols = matrix_bin.shape
    block_height = rows // num_cores
    with open(filename, 'w') as f:
        for core in range(num_cores):
            for r in range(block_height):
                row_idx = core * block_height + r
                if r % 2 == 0:
                    for c in range(cols):
                        f.write(matrix_bin[row_idx][c] + '\n')
                else:
                    for c in reversed(range(cols)):
                        f.write(matrix_bin[row_idx][c] + '\n')


def export_core_mode_B(matrix_bin, filename, num_cores):
    rows, cols = matrix_bin.shape
    block_width = cols // num_cores
    with open(filename, 'w') as f:
        for core in range(num_cores):
            for c in range(block_width):
                col_idx = core * block_width + c
                if c % 2 == 0:
                    for r in range(rows):
                        f.write(matrix_bin[r][col_idx] + '\n')
                else:
                    for r in reversed(range(rows)):
                        f.write(matrix_bin[r][col_idx] + '\n')


def export_core_mode_C(matrix_bin, filename, num_cores_A, num_cores_B):
    rows, cols = matrix_bin.shape
    block_h = rows // num_cores_A
    block_w = cols // num_cores_B
    with open(filename, 'w') as f:
        for block_y in range(num_cores_A):
            for block_x in range(num_cores_B):
                for r in range(block_h):
                    for c in range(block_w):
                        rr = block_y * block_h + r
                        cc = block_x * block_w + c
                        f.write(matrix_bin[rr][cc] + '\n')


# ------------------ USER CONFIG ------------------

A_ROWS = 12
A_COLS = 6
B_COLS = 8

A_MIN, A_MAX = -2.0, 2.0
B_MIN, B_MAX = -2.0, 2.0

A_BIT_WIDTH, A_FRAC_WIDTH = 8, 4
B_BIT_WIDTH, B_FRAC_WIDTH = 8, 4
C_BIT_WIDTH, C_FRAC_WIDTH = 16, 8

NUM_CORES_A = 2   # divides A_ROWS
NUM_CORES_B = 2   # divides B_COLS

EXPORT_MODE = "core"  # "row" or "core"

# ------------------ END CONFIG -------------------

def main():
    A = generate_matrix(A_ROWS, A_COLS, A_MIN, A_MAX)
    B = generate_matrix(A_COLS, B_COLS, B_MIN, B_MAX)
    C = matrix_multiply(A, B)

    print_matrix("Matrix A", A)
    print_matrix("Matrix B", B)
    print_matrix("Matrix C", C)

    A_bin = fixed_point_matrix(A, A_BIT_WIDTH, A_FRAC_WIDTH)
    B_bin = fixed_point_matrix(B, B_BIT_WIDTH, B_FRAC_WIDTH)
    C_bin = fixed_point_matrix(C, C_BIT_WIDTH, C_FRAC_WIDTH)

    if EXPORT_MODE == "row":
        export_row_mode(A_bin, "matrix_A.mem")
        export_row_mode(B_bin, "matrix_B.mem")
        export_row_mode(C_bin, "matrix_C.mem")
    elif EXPORT_MODE == "core":
        export_core_mode_A(A_bin, "matrix_A.mem", NUM_CORES_A)
        export_core_mode_B(B_bin, "matrix_B.mem", NUM_CORES_B)
        export_core_mode_C(C_bin, "matrix_C.mem", NUM_CORES_A, NUM_CORES_B)
    else:
        raise ValueError("Invalid EXPORT_MODE. Use 'row' or 'core'.")

    print(f"\n✅ Export completed in '{EXPORT_MODE}' mode.")
    print("📄 Generated: matrix_A.mem, matrix_B.mem, matrix_C.mem")

if __name__ == "__main__":
    main()

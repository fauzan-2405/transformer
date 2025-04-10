import numpy as np
from conversion import *  # Ensure this module exists with to_q8_8_hex() and to_q8_8_bin()

# ========================
# Configuration
# ========================
# Matrix parameters A
size_row_A = 16
size_coloumn_A = 8

# Matrix parameters B
size_row_B = 8
size_coloumn_B = 16

# Systolic array size
size_sys_array = 2

# Export format: 'hex' or 'bin'
export_format = 'hex'  # Change to 'bin' if you want binary .mem

# ========================
# Functions
# ========================

def convert_value(value):
    return to_q8_8_hex(value) if export_format == 'hex' else to_q8_8_bin(value)

def export_matrix(filename_txt, filename_mem, hex_matrix, rows, cols, buffer_size):
    buffer = [["" for _ in range(buffer_size)] for _ in range(buffer_size)]
    write_val = ""

    with open(filename_txt, "w") as file_txt, open(filename_mem, "w") as file_mem:
        for row_out in range(0, rows // buffer_size):
            for col_out in range(0, cols // buffer_size):
                for row_buff in range(buffer_size):
                    for col_buff in range(buffer_size):
                        buffer[row_buff][col_buff] = hex_matrix[
                            buffer_size * row_out + row_buff
                        ][buffer_size * col_out + col_buff]
                        write_val += buffer[row_buff][col_buff]
                # Write to both txt and mem files
                file_txt.write(write_val + "\n")
                file_mem.write(write_val + "\n")
                write_val = ""

# ========================
# Main Program
# ========================

# Generate random integer matrices with values from 0 to 1
array_A = np.random.randint(0, 2, size=(size_row_A, size_coloumn_A))
array_B = np.random.randint(0, 2, size=(size_row_B, size_coloumn_B))

# Ensure matrix multiplication compatibility
assert size_coloumn_A == size_row_B, "Matrix multiplication is not possible with these dimensions."

# Matrix multiplication using NumPy
array_C = np.matmul(array_A, array_B)

# Initialize hex/bin matrices
hex_A = [[convert_value(array_A[row, col]) for col in range(size_coloumn_A)] for row in range(size_row_A)]
hex_B = [[convert_value(array_B[row, col]) for col in range(size_coloumn_B)] for row in range(size_row_B)]
hex_C = [[convert_value(array_C[row, col]) for col in range(size_coloumn_B)] for row in range(size_row_A)]

# Export all matrices
export_matrix("A.txt", "A.mem", hex_A, size_row_A, size_coloumn_A, size_sys_array)
export_matrix("B.txt", "B.mem", hex_B, size_row_B, size_coloumn_B, size_sys_array)
export_matrix("C.txt", "C.mem", hex_C, size_row_A, size_coloumn_B, size_sys_array)

print("Export completed in both .txt and .mem formats!")

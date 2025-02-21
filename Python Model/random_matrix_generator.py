import numpy as np
from conversion import *  # Ensure this module exists or replace with appropriate logic

# Matrix parameters
size_row = 6
size_coloumn = 4
# Systolic array size (e.g., 2x2, 4x4, etc.)
size_sys_array = 2 

# Generate random matrices
array_A = np.random.uniform(0, 1, size=(size_row, size_coloumn))  # 6x4 matrix A
array_B = np.random.uniform(0, 1, size=(size_coloumn, size_row))  # 4x6 matrix B

# Initialize hex arrays for converting values to Q8.8 format
hex_A = [["" for _ in range(size_coloumn)] for _ in range(size_row)]
hex_B = [["" for _ in range(size_row)] for _ in range(size_coloumn)]
hex_C = [["" for _ in range(size_row)] for _ in range(size_row)]  # Resultant matrix

# Buffers for partitioning matrices according to `size_sys_array`
buffer_A = [["" for _ in range(size_sys_array)] for _ in range(size_sys_array)]
buffer_B = [["" for _ in range(size_sys_array)] for _ in range(size_sys_array)]
buffer_C = [["" for _ in range(size_sys_array)] for _ in range(size_sys_array)]

# Matrix multiplication using NumPy
array_C = np.matmul(array_A, array_B)  # Resultant 6x6 matrix

# Save the resulting matrix C to a CSV file
np.savetxt("result_python.csv", array_C, delimiter=",")

# Convert expected result into Q8.8 format and save to 'C.txt'
write_val = ""
for row in range(size_row):
    for col in range(size_row):
        hex_C[row][col] = to_q8_8_hex(array_C[row, col])

with open("C.txt", "w") as file:
    for row_out in range(0, size_row // size_sys_array):
        for col_out in range(0, size_row // size_sys_array):
            for row_buff in range(size_sys_array):
                for col_buff in range(size_sys_array):
                    buffer_C[row_buff][col_buff] = hex_C[size_sys_array * row_out + row_buff][size_sys_array * col_out + col_buff]
                    write_val += buffer_C[row_buff][col_buff]
            file.write(write_val + "\n")
            write_val = ""

# Convert input arrays A and B into Q8.8 format and save to 'A.txt' and 'B.txt'
write_val = ""
for row in range(size_row):
    for col in range(size_coloumn):
        hex_A[row][col] = to_q8_8_hex(array_A[row, col])

with open("A.txt", "w") as file:
    for row_out in range(0, size_row // size_sys_array):
        for scan_col in range(0, size_coloumn // size_sys_array):
            for row_buff in range(size_sys_array):
                for col_buff in range(size_sys_array):
                    buffer_A[row_buff][col_buff] = hex_A[row_out * size_sys_array + row_buff][scan_col * size_sys_array + col_buff]
                    write_val += buffer_A[row_buff][col_buff]
            file.write(write_val + "\n")
            write_val = ""

write_val = ""
for row in range(size_coloumn):
    for col in range(size_row):
        hex_B[row][col] = to_q8_8_hex(array_B[row, col])

with open("B.txt", "w") as file:
    for col_out in range(0, size_row // size_sys_array):
        for scan_col in range(0, size_coloumn // size_sys_array):
            for row_buff in range(size_sys_array):
                for col_buff in range(size_sys_array):
                    buffer_B[col_buff][row_buff] = hex_B[scan_col * size_sys_array + col_buff][col_out * size_sys_array + row_buff]
                    write_val += buffer_B[col_buff][row_buff]
            file.write(write_val + "\n")
            write_val = ""

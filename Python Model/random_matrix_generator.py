import numpy as np
from conversion import *  # Ensure this module exists or replace with appropriate logic

# Matrix parameters A
size_row_A = 16
size_coloumn_A = 8

# Matrix parameters B
size_row_B = 8
size_coloumn_B = 16

# Systolic array size (e.g., 2x2, 4x4, etc.)
size_sys_array = 2 

# Generate random integer matrices with values from 1 to 2
array_A = np.random.randint(0, 2, size=(size_row_A, size_coloumn_A))  
array_B = np.random.randint(0, 2, size=(size_row_B, size_coloumn_B))  

# Ensure matrix multiplication compatibility
assert size_coloumn_A == size_row_B, "Matrix multiplication is not possible with these dimensions."

# Matrix multiplication using NumPy
array_C = np.matmul(array_A, array_B)  # Resultant matrix with shape (size_row_A, size_coloumn_B)

# Initialize hex arrays for converting values to Q8.8 format
hex_A = [["" for _ in range(size_coloumn_A)] for _ in range(size_row_A)]
hex_B = [["" for _ in range(size_coloumn_B)] for _ in range(size_row_B)]
hex_C = [["" for _ in range(size_coloumn_B)] for _ in range(size_row_A)]  # Resultant matrix

# Buffers for partitioning matrices according to size_sys_array
buffer_A = [["" for _ in range(size_sys_array)] for _ in range(size_sys_array)]
buffer_B = [["" for _ in range(size_sys_array)] for _ in range(size_sys_array)]
buffer_C = [["" for _ in range(size_sys_array)] for _ in range(size_sys_array)]

# Save the resulting matrix C to a CSV file
#np.savetxt("result_python.csv", array_C, delimiter=",")

# Convert expected result into Q8.8 format and save to 'C.txt'
write_val = ""
for row in range(size_row_A):
    for col in range(size_coloumn_B):
        hex_C[row][col] = to_q8_8_hex(array_C[row, col])

with open("C.txt", "w") as file:
    for row_out in range(0, size_row_A // size_sys_array):
        for col_out in range(0, size_coloumn_B // size_sys_array):
            for row_buff in range(size_sys_array):
                for col_buff in range(size_sys_array):
                    buffer_C[row_buff][col_buff] = hex_C[size_sys_array * row_out + row_buff][size_sys_array * col_out + col_buff]
                    write_val += buffer_C[row_buff][col_buff]
            file.write(write_val + "\n")
            write_val = ""

# Convert input matrices A and B into Q8.8 format and save to 'A.txt' and 'B.txt'
write_val = ""
for row in range(size_row_A):
    for col in range(size_coloumn_A):
        hex_A[row][col] = to_q8_8_hex(array_A[row, col])

with open("A.txt", "w") as file:
    for row_out in range(0, size_row_A // size_sys_array):
        for scan_col in range(0, size_coloumn_A // size_sys_array):
            for row_buff in range(size_sys_array):
                for col_buff in range(size_sys_array):
                    buffer_A[row_buff][col_buff] = hex_A[row_out * size_sys_array + row_buff][scan_col * size_sys_array + col_buff]
                    write_val += buffer_A[row_buff][col_buff]
            file.write(write_val + "\n")
            write_val = ""

write_val = ""
for row in range(size_row_B):
    for col in range(size_coloumn_B):
        hex_B[row][col] = to_q8_8_hex(array_B[row, col])

with open("B.txt", "w") as file:
    for col_out in range(0, size_coloumn_B // size_sys_array):
        for scan_col in range(0, size_row_B // size_sys_array):
            for row_buff in range(size_sys_array):
                for col_buff in range(size_sys_array):
                    buffer_B[col_buff][row_buff] = hex_B[scan_col * size_sys_array + col_buff][col_out * size_sys_array + row_buff]
                    write_val += buffer_B[col_buff][row_buff]
            file.write(write_val + "\n")
            write_val = ""

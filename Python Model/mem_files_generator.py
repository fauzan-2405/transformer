import random

def generate_matrix(rows, cols, min_val, max_val):
    return [[random.randint(min_val, max_val) for _ in range(cols)] for _ in range(rows)]

def save_as_mem_hex(matrix, filename):
    with open(filename, 'w') as f:
        for row in matrix:
            for val in row:
                hex_value = format(val, '04x')  # 16-bit hex
                f.write(f"{hex_value}\n")
    print(f"{filename} (hex) generated.")

def save_as_mem_bin(matrix, filename):
    with open(filename, 'w') as f:
        for row in matrix:
            for val in row:
                bin_value = format(val, '016b')  # 16-bit binary
                f.write(f"{bin_value}\n")
    print(f"{filename} (binary) generated.")

def save_as_readable_txt(matrix, filename):
    with open(filename, 'w') as f:
        for row in matrix:
            line = ' '.join(str(val) for val in row)
            f.write(line + '\n')
    print(f"{filename} (readable text) generated.")

def generate_and_save_matrix(matrix_name, rows, cols, min_val, max_val):
    matrix = generate_matrix(rows, cols, min_val, max_val)
    save_as_mem_hex(matrix, f"{matrix_name}.mem")
    save_as_mem_bin(matrix, f"{matrix_name}_bin.mem")
    save_as_readable_txt(matrix, f"{matrix_name}.txt")

# Example usage:
# Generate matrix A: 2754x256, values from 0 to 1
generate_and_save_matrix("matrix_A", rows=4, cols=6, min_val=0, max_val=1)

# Generate matrix B: 256x256, values from 0 to 1
generate_and_save_matrix("matrix_B", rows=6, cols=4, min_val=0, max_val=1)

import numpy as np

# Original matrix dimensions (M × K and K × N)
M, K, N = 2754, 256, 64  # Example non-mirrored dimensions

# Create random matrices
array_A = np.random.randint(1, 20, size=(M, K))
array_B = np.random.randint(1, 20, size=(K, N))

# Output matrix
array_C = np.zeros((M, N))  # No pre-padding

# Buffers
buffer_A = np.zeros((4, 4))
buffer_B = np.zeros((4, 4))
buffer_mult = np.zeros((4, 4))

# Perform block-wise multiplication
for row_out in range(0, (M + 3) // 4):  # ceil(M / 4)
    for col_out in range(0, (N + 3) // 4):  # ceil(N / 4)
        buffer_mult.fill(0)  # Reset accumulator

        for scan_col in range(0, (K + 3) // 4):  # ceil(K / 4)
            # Fill buffer_A with values or 0 if out-of-bounds
            for row_buff in range(4):
                for col_buff in range(4):
                    a_row = row_out * 4 + row_buff
                    a_col = scan_col * 4 + col_buff
                    buffer_A[row_buff, col_buff] = array_A[a_row, a_col] if a_row < M and a_col < K else 0

            # Fill buffer_B with values or 0 if out-of-bounds
            for row_buff in range(4):
                for col_buff in range(4):
                    b_row = scan_col * 4 + col_buff
                    b_col = col_out * 4 + row_buff
                    buffer_B[col_buff, row_buff] = array_B[b_row, b_col] if b_row < K and b_col < N else 0

            buffer_mult += np.matmul(buffer_A, buffer_B)

        # Store results into array_C, ensuring no out-of-bounds writes
        for row_buff in range(4):
            for col_buff in range(4):
                c_row = row_out * 4 + row_buff
                c_col = col_out * 4 + col_buff
                if c_row < M and c_col < N:
                    array_C[c_row, c_col] = buffer_mult[row_buff, col_buff]

# Compare with standard multiplication
array_D = np.matmul(array_A, array_B)
print(np.allclose(array_C, array_D))  # Should print True

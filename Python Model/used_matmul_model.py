import numpy as np

# Helper function for systolic array-like model with integers
def systolic_multiply(A_1_chunk, B_1_chunk):
    """ Simulates the systolic array multiplication and accumulation for a 16x16 chunk with integers. """
    return np.sum(A_1_chunk * B_1_chunk)

# Initialize Matrix A and B with integers
M, N, T = 2754, 256, 64
A = np.random.randint(1, 3, size=(M, N), dtype=np.int32)  
B = np.random.randint(1, 3, size=(N, T), dtype=np.int32)  


# Create A_1 and B_1 by reshaping the original matrices into 16x16 chunks
A_1 = A.reshape(M * 16, 16)  # Size 44064 x 16
B_1 = B.reshape(16, T * 16)  # Size 16 x 4096

# Matrix C to store results
C_systolic = np.zeros((M, T), dtype=np.int32)

# Systolic array-like matrix multiplication with integer arithmetic
for i in range(M):
    for j in range(T):
        accumulator = 0
        # Process chunks
        for k in range(16):  # 16 chunks per row of A_1 and column of B_1
            A_1_chunk = A_1[i * 16 + k].reshape(16, 1)
            B_1_chunk = B_1[k, j * 16:j * 16 + 16].reshape(16, 1)
            
            # Perform systolic multiplication (dot product of chunks)
            accumulator += systolic_multiply(A_1_chunk, B_1_chunk)
        
        C_systolic[i, j] = accumulator

# Compare the result with normal matrix multiplication using numpy's matmul (with integers)
C_normal = np.matmul(A, B)

# Calculate the absolute error and error percentage
absolute_error = np.abs(C_systolic - C_normal)
relative_error_percentage = (absolute_error / np.abs(C_normal)) * 100

# Calculate the mean error percentage
mean_error_percentage = np.mean(relative_error_percentage)


# Print the mean error percentage across the matrix
print("\nMean error percentage across all elements in C:")
print(mean_error_percentage)

# Check if the results are close
print("\nAre the results close?")
print(np.allclose(C_systolic, C_normal))  # Should return False if results are not identical

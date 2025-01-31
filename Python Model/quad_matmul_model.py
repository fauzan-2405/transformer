import numpy as np

# Matrix parameter (You can edit this as long your matrix are quadratic)
row_size = 512
col_size = 64

array_A = np.random.randint(1,10,size=(row_size, col_size)) # Array A 512x64 with random number between 1 to 10
array_B = np.random.randint(1,10,size=(col_size, row_size)) # Array B 64x512 with random number between 1 to 10
array_C = np.zeros((row_size, row_size)) # Array C for storing the result from matmul A x B

array_test = np.zeros((row_size, row_size)) # Array to test and compare with Array C

# Now we initialize the buffer to store many things
buffer_A = np.zeros((4,4)) # Buffer A for storing partition block from matrix A
buffer_B = np.zeros((4,4)) # For storing partitiion block from matrix B
buffer_mult = np.zeros((4,4)) # For storing the temporary matmul result from buffer_A x buffe_B

# Mutltiplication process
for row_out in range(0, row_size//4):
    for col_out in range (0, row_size//4):
        for scan_col in range(0, col_size//4):
            for row_buff in range(0,4):
                for col_buff in range(0,4):
                    buffer_A[row_buff, col_buff] = array_A[row_out*4 + row_buff, scan_col*4+col_buff]
                    buffer_B[col_buff, row_buff] = array_B[scan_col*4 + col_buff, col_out*4+row_buff]
            
            buffer_mult = np.add(buffer_mult, np.matmul(buffer_A, buffer_B))

        for row_buff in range (0,4):
            for col_buff in range (0,4):
                array_C[4*row_out+row_buff, 4*col_out+col_buff] = buffer_mult[row_buff,col_buff]

        buffer_mult = np.zeros((4,4))

array_test = np.matmul(array_A, array_B)

right = 0

if (array_C.all() == array_test.all()):
    right = 1

print(right)






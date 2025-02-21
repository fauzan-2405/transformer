import numpy as np
from conversion import *

#matrix parameter (note : B will be tranversed)
size_row = 512
size_coloumn = 64

array_A = np.random.uniform(0,1,size=(size_row,size_coloumn)) #random array A with size 512 and 64
array_B = np.random.uniform(0,1,size=(size_coloumn,size_row)) #random array B with size 64 and 512

hex_A = [["" for _ in range(size_coloumn)] for _ in range(size_row)]
hex_B = [["" for _ in range(size_row)] for _ in range(size_coloumn)]
hex_C = [["" for _ in range(size_row)] for _ in range(size_row)]


buffer_A = [["" for _ in range(4)] for _ in range(4)] #buffer for selecting partition block form matrix A
buffer_B = [["" for _ in range(4)] for _ in range(4)] #buffer for selecting partition block form matrix B
buffer_C = [["" for _ in range(4)] for _ in range(4)] #buffer for selecting partition block form matrix B


array_D = np.zeros((size_row,size_row)) #normal multiplication method result
array_D = np.matmul(array_A,array_B)


#converting expected result into Q8.8 format
#for row in range(0,size_row):
#    for col in range(0,size_row):
#        array_D[row,col] = to_q8_8_hex(array_D[row,col])

write_val = ""

a = np.asarray(array_D)
np.savetxt("result_python.csv", a, delimiter=",")


#converting input array into Q8.8 format
for row in range(0,size_row):
    for col in range(0,size_row):
        hex_C[row][col] = to_q8_8_hex(array_D[row,col])

with open("C.txt", "w") as file:
    for row_out in range(0,size_row//4):
        for col_out in range(0,size_row//4):
            for row_buff in range (0,4):
                for col_buff in range (0,4):
                    buffer_C[row_buff][col_buff] = hex_C[4*row_out+row_buff][4*col_out+col_buff]   
                    write_val = write_val + buffer_C[row_buff][col_buff]
            file.write(write_val+"\n")
            #print(write_val+"\n")
            write_val = ""

write_val = ""

#converting input array into Q8.8 format
for row in range(0,size_row):
    for col in range(0,size_coloumn):
        hex_A[row][col] = to_q8_8_hex(array_A[row,col])


for row in range(0,size_coloumn):
    for col in range(0,size_row):
        hex_B[row][col] = to_q8_8_hex(array_B[row,col])


with open("A.txt", "w") as file:
    for row_out in range(0,size_row//4):
        for scan_col in range (0,size_coloumn//4):
            for row_buff in range (0,4):
                for col_buff in range (0,4):
                    buffer_A[row_buff][col_buff] = hex_A[row_out*4+row_buff][scan_col*4+col_buff]
                    write_val = write_val + buffer_A[row_buff][col_buff]
            file.write(write_val+"\n")
            #print(write_val+"\n")
            write_val = ""


write_val = ""

with open("B.txt", "w") as file:
    for col_out in range(0,size_row//4):
        for scan_col in range (0,size_coloumn//4):
            for row_buff in range (0,4):
                for col_buff in range (0,4):
                    buffer_B[col_buff][row_buff] = hex_B[scan_col*4+col_buff][col_out*4+row_buff]           
                    write_val = write_val+ buffer_B[col_buff][row_buff]
            file.write(write_val+"\n")
            #print(write_val+"\n")
            write_val = ""
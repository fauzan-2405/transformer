This is the documentation for 4x4 by 4x6 => 4x6
--display float --min_val 0.0 --max_val 2 --block_size 2 --cores_a 2 --cores_b 3 --integers

Fixed-point configurations (total_bits, fractional_bits, signed)
fp_config_A = (8, 4, True)   
fp_config_B = (8, 2, True)   
fp_config_C = (12, 4, True)  

Matrix A (4x4, 2 Cores):
0.0000   0.0000   0.0000   1.0000
1.0000   1.0000   2.0000   1.0000
2.0000   0.0000   2.0000   0.0000
0.0000   2.0000   2.0000   0.0000

Matrix B (4x6, 3 cores):
2.0000   0.0000   0.0000   0.0000   2.0000   1.0000
1.0000   2.0000   1.0000   0.0000   1.0000   0.0000
2.0000   0.0000   0.0000   1.0000   0.0000   1.0000
0.0000   1.0000   1.0000   2.0000   0.0000   0.0000

Matrix C (A x B) (4x6):
0.0000   1.0000   1.0000   2.0000   0.0000   0.0000
7.0000   3.0000   2.0000   4.0000   3.0000   3.0000
8.0000   0.0000   0.0000   2.0000   4.0000   4.0000
6.0000   4.0000   2.0000   2.0000   2.0000   2.0000

Please check matrix_C_core to see the resulting order
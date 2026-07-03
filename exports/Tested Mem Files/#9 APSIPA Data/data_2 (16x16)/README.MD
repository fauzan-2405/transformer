**For producing the matrix** 
python -u "d:\DATA\Documents\Xirka Internship\PME\Transformer\transformer\Python Model + Scripts\matrix_multiplier.py" --task matmul --rows_a 16 --cols_a 16 --proj_dim 16 --display float --integers --min_val 0 --max_val 1 --cores_a 4 --cores_b 4 --A_total_bits 4 --A_frac_bits 0 --B_total_bits 4 --B_frac_bits 0 --C_total_bits 8 --C_frac_bits 0

**For converting the binary to hex for row files**
> Core A
python -u "D:\DATA\Documents\Xirka Internship\PME\Transformer\transformer\Python Model + Scripts\bin2hex.py" "D:\DATA\Documents\Xirka Internship\PME\Transformer\transformer\exports\Tested Mem Files\#9 APSIPA Data\data_2 (16X16)\matrix_A_core.mem" --element-bits 4  

> Core B
python -u "D:\DATA\Documents\Xirka Internship\PME\Transformer\transformer\Python Model + Scripts\bin2hex.py" "D:\DATA\Documents\Xirka Internship\PME\Transformer\transformer\exports\Tested Mem Files\#9 APSIPA Data\data_2 (16X16)\matrix_B_core.mem" --element-bits 4  

> Row A
python -u "D:\DATA\Documents\Xirka Internship\PME\Transformer\transformer\Python Model + Scripts\bin2hex.py" "D:\DATA\Documents\Xirka Internship\PME\Transformer\transformer\exports\Tested Mem Files\#9 APSIPA Data\data_2 (16x16)\matrix_A_row.mem" --element-bits 1

> Row B
python -u "D:\DATA\Documents\Xirka Internship\PME\Transformer\transformer\Python Model + Scripts\bin2hex.py" "D:\DATA\Documents\Xirka Internship\PME\Transformer\transformer\exports\Tested Mem Files\#9 APSIPA Data\data_2 (16x16)\matrix_B_row.mem" --element-bits 1


Notice the element bits used in Row mode is /4 with the one used in Core
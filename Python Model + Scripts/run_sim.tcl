# ============================================
# FAST NON-PROJECT SIMULATION
# run_sim.tcl

# In Windows
# vivado -mode batch -source /mnt/ssd/mfauzan/transformer/python_code/run_sim.tcl -tclargs ....

# In Linux:
# vivado -mode batch -source transformer/python_code/run_sim.tcl -tclargs /mnt/ssd/mfauzan/transformer/python_code/exports_1/hardware 
# /mnt/ssd/mfauzan/transformer/python_code/exports_1/cleaned_files/mem_input_hex.mem 
# /mnt/ssd/mfauzan/transformer/python_code/exports_1/cleaned_files/mem_q1_hex.mem 
# /mnt/ssd/mfauzan/transformer/python_code/exports_1/cleaned_files/mem_k1_hex.mem 
# /mnt/ssd/mfauzan/transformer/python_code/exports_1/cleaned_files/mem_v1_hex.mem
# 16 8 16 10 12 2 2

# ============================================

# Get arguments
set out_dir     [lindex $argv 0]
set input_file  [lindex $argv 1]
set mem_q       [lindex $argv 2]
set mem_k       [lindex $argv 3]
set mem_v       [lindex $argv 4]

# Width precision
set in_width    [lindex $argv 5]
set in_frac     [lindex $argv 6]
set w_width     [lindex $argv 7]
set w_frac      [lindex $argv 8]
#set key_width   [lindex $argv 9]
#set key_frac    [lindex $argv 10]
#set qkt_width   [lindex $argv 11]
#set qkt_frac    [lindex $argv 12]
set soft_width  [lindex $argv 9]
set soft_frac   [lindex $argv 10]
set final_width [lindex $argv 11]
set final_frac  [lindex $argv 12]

set i_mat       [lindex $argv 13]
set inner_mat   [lindex $argv 14]
set w_mat       [lindex $argv 15]
set cores_a     [lindex $argv 16]
set tot_modules [lindex $argv 17]

# Clean
file delete -force xsim.dir
file delete -force *.log *.jou *.pb

puts "Compiling..."
exec xvlog -sv \
    -d SYSTEM_TOP_WIDTH_INPUT=$in_width \
    -d SYSTEM_FRAC_WIDTH_INPUT=$in_frac \
    -d SYSTEM_TOP_WIDTH_WEIGHT=$w_width \
    -d SYSTEM_FRAC_WIDTH_WEIGHT=$w_frac \
    -d SYSTEM_TOP_WIDTH_SOFTMAX=$soft_width \
    -d SYSTEM_FRAC_WIDTH_SOFTMAX=$soft_frac \
    -d SYSTEM_TOP_WIDTH_FINAL=$final_width \
    -d SYSTEM_FRAC_WIDTH_FINAL=$final_frac \
    -d I_MATRIX_DIMENSION=$i_mat \
    -d INNER_MATRIX_DIMENSION=$inner_mat \
    -d W_MATRIX_DIMENSION=$w_mat \
    -d SYSTEM_NUM_CORES_A=$cores_a \
    -d SYSTEM_TOTAL_MODULES=$tot_modules \
    -i /mnt/ssd/mfauzan/transformer/source_code_real/config.svh \
    -f /mnt/ssd/mfauzan/transformer/python_code/filelist.f

puts "Elaborating..."
exec xelab tb_multihead_attention -s tb_sim \
    -relax -debug typical -L xpm \
    -generic_top "MEM_INIT_FILE_Q=$mem_q" \
    -generic_top "MEM_INIT_FILE_K=$mem_k" \
    -generic_top "MEM_INIT_FILE_V=$mem_v"

puts "Running..."

exec xsim tb_sim \
    -runall \
    -testplusarg OUT_DIR=$out_dir \
    -testplusarg INPUT_FILE=$input_file

puts "DONE"
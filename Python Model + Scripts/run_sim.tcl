# ============================================
# FAST NON-PROJECT SIMULATION
# run_sim.tcl
# vivado -mode batch -source /mnt/ssd/mfauzan/transformer/python_code/run_sim.tcl -tclargs ....
# ============================================

# Get arguments
set out_dir     [lindex $argv 0]
set input_file  [lindex $argv 1]
set mem_q       [lindex $argv 2]
set mem_k       [lindex $argv 3]
set mem_v       [lindex $argv 4]

# Clean
file delete -force xsim.dir
file delete -force *.log *.jou *.pb

puts "Compiling..."
exec xvlog -sv -f /mnt/ssd/mfauzan/transformer/python_code/filelist.f

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
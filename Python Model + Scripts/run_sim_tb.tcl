# ============================================
# SIMPLE TESTBENCH RUN (NO PROJECT)
# ============================================

# Clean previous sim
file delete -force xsim.dir
file delete -force *.log *.jou *.pb

puts "Compiling sources..."
puts "Compiling with filelist..."

exec xvlog -sv -f /mnt/ssd/mfauzan/transformer/python_code/filelist.f

# Elaborate testbench
puts "Elaborating..."

exec xelab tb_multihead_attention -s tb_sim \
    --relax --debug typical -L xpm \
    -generic_top {MEM_INIT_FILE_Q=/mnt/ssd/mfauzan/transformer/source_code_real/mat_B_lp_bridge.mem} \
    -generic_top {MEM_INIT_FILE_K=/mnt/ssd/mfauzan/transformer/source_code_real/mat_B_lp_bridge.mem} \
    -generic_top {MEM_INIT_FILE_V=/mnt/ssd/mfauzan/transformer/source_code_real/mat_B_lp_bridge.mem}

# Run simulation with plusargs
puts "Running simulation..."

exec xsim tb_sim \
    -runall \
    -testplusarg OUT_DIR=/mnt/ssd/mfauzan/transformer/python_code/exports_1/hardware \
    -testplusarg INPUT_FILE=/mnt/ssd/mfauzan/transformer/source_code/linproj_mem/mem_A_lp_bridge.mem

puts "TCL simulation all done"
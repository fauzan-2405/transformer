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

#exec xelab /mnt/ssd/mfauzan/transformer/source_code/multi_head_attention/tb_multihead_attention_script -s tb_sim --relax --debug typical -L xpm
exec xelab tb_multihead_attention_script -s tb_sim

# Run simulation with plusargs
puts "Running simulation..."

exec xsim tb_sim \
    -runall \
    -testplusarg OUT_DIR=/mnt/ssd/mfauzan/transformer/python_code/exports_1/hardware \
    -testplusarg INPUT_FILE=/mnt/ssd/mfauzan/transformer/source_code/linproj_mem/mem_A_lp_bridge.mem
# ============================================
# run_sim.tcl
# Example run:
# vivado -mode batch -source run_sim.tcl 
#    "/mnt/ssd/mfauzan/transformer/python_code/exports_1/hardware/" \
#    "/mnt/ssd/mfauzan/transformer/python_code/exports_1/cleaned_files/mat_A.mem" \
#    "/mnt/ssd/mfauzan/transformer/python_code/exports_1/cleaned_files/mat_Q.mem" \
#    "/mnt/ssd/mfauzan/transformer/python_code/exports_1/cleaned_files/mat_K.mem" \
#    "/mnt/ssd/mfauzan/transformer/python_code/exports_1/cleaned_files/mat_V.mem"
# ============================================

# Get arguments from bash
set out_dir     [lindex $argv 0]
set input_file  [lindex $argv 1]
set mem_q       [lindex $argv 2]
set mem_k       [lindex $argv 3]
set mem_v       [lindex $argv 4]

puts "OUT_DIR     = $out_dir"
puts "INPUT_FILE  = $input_file"
puts "MEM_Q       = $mem_q"
puts "MEM_K       = $mem_k"
puts "MEM_V       = $mem_v"

# Open project
open_project /mnt/ssd/mfauzan/transformer/transformer.xpr

# Add all RTL recursively
add_files -fileset sources_1 [concat \
    [glob -nocomplain -recursive "/mnt/ssd/mfauzan/transformer/source_code/**/*.sv"] \
    [glob -nocomplain -recursive "/mnt/ssd/mfauzan/transformer/source_code/**/*.v"] \
]

# Add testbench
add_files -fileset sim_1 /mnt/ssd/mfauzan/transformer/source_code/multi_head_attention/tb_multihead_attention_script.sv

# Update compile order
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# Set TB as top
set_property top tb_multihead_attention_script [get_filesets sim_1]
# Parameter override
set_property generic [format { \
    MEM_Q_FILE=%s \
    MEM_K_FILE=%s \
    MEM_V_FILE=%s \
} $mem_q $mem_k $mem_v] [get_filesets sim_1]

# Pass +args into simulator
set_property -name {xsim.simulate.xsim.more_options} \
    -value "+OUT_DIR=$out_dir +INPUT_FILE=$input_file" \
    -objects [get_filesets sim_1]

# Run simulation
launch_simulation

# Run until finish
run all

# Exit Vivado
quit
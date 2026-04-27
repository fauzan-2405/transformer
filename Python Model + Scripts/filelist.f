# =========================
# PACKAGES (MUST BE FIRST)
# =========================
/mnt/ssd/mfauzan/transformer/source_code_real/top_pkg.sv
/mnt/ssd/mfauzan/transformer/source_code_real/linear_proj_pkg.sv
/mnt/ssd/mfauzan/transformer/source_code_real/self_attention_pkg.sv
/mnt/ssd/mfauzan/transformer/source_code_real/buffer/buffer0_pkg.sv

# =========================
# BASIC BUILDING BLOCKS
# =========================
/mnt/ssd/mfauzan/transformer/source_code_real/reg.v
/mnt/ssd/mfauzan/transformer/source_code_real/saturate_v2.v
/mnt/ssd/mfauzan/transformer/source_code_real/pe_v2.v
/mnt/ssd/mfauzan/transformer/source_code_real/mux2_1.v
/mnt/ssd/mfauzan/transformer/source_code_real/control_mux2_1.v
/mnt/ssd/mfauzan/transformer/source_code_real/softmax/ram_1w2r.v
/mnt/ssd/mfauzan/transformer/source_code_real/ram_1w_1r.v

# =========================
# COMPUTE UNITS
# =========================
/mnt/ssd/mfauzan/transformer/source_code_real/accumulator_v2.v
/mnt/ssd/mfauzan/transformer/source_code_real/systolic_array_2x2_v2.v
/mnt/ssd/mfauzan/transformer/source_code_real/mac_v2.v
/mnt/ssd/mfauzan/transformer/source_code_real/core_v2.v
/mnt/ssd/mfauzan/transformer/source_code_real/matmul_module.v
/mnt/ssd/mfauzan/transformer/source_code_real/multi_matmul.sv
/mnt/ssd/mfauzan/transformer/source_code_real/multi_matmul_wrapper.sv
/mnt/ssd/mfauzan/transformer/source_code_real/multwrap_wbram.sv

# =========================
# SOFTMAX + SUPPORTING MODULES
# =========================
/mnt/ssd/mfauzan/transformer/source_code_real/softmax/amult.v
/mnt/ssd/mfauzan/transformer/source_code_real/softmax/exp_vec.v
/mnt/ssd/mfauzan/transformer/source_code_real/softmax/lnu.v
/mnt/ssd/mfauzan/transformer/source_code_real/softmax/lnu_range_adapter_1to8.v
/mnt/ssd/mfauzan/transformer/source_code_real/softmax/softmax_vec.v
/mnt/ssd/mfauzan/transformer/source_code_real/rshift.sv

# =========================
# BUFFER SYSTEM
# =========================
/mnt/ssd/mfauzan/transformer/source_code_real/buffer/buffer_ctrl.sv
/mnt/ssd/mfauzan/transformer/source_code_real/buffer/buffer_ctrl_special.sv
/mnt/ssd/mfauzan/transformer/source_code_real/buffer/buffer_n.sv
/mnt/ssd/mfauzan/transformer/source_code_real/buffer/buffer_n_special.sv
/mnt/ssd/mfauzan/transformer/source_code_real/buffer/buffer_w.sv
/mnt/ssd/mfauzan/transformer/source_code_real/buffer/buffer_wrapper.sv
/mnt/ssd/mfauzan/transformer/source_code_real/buffer/top_buffer.sv

# =========================
# DATAFLOW / CONVERTERS
# =========================
/mnt/ssd/mfauzan/transformer/source_code_real/r2b_converter_v.v
/mnt/ssd/mfauzan/transformer/source_code_real/b2r_converter.v
/mnt/ssd/mfauzan/transformer/source_code_real/top_r2b_converter_v.sv
/mnt/ssd/mfauzan/transformer/source_code_real/top_r2b_circular_fifo.sv

# =========================
# LINEAR PROJECTION
# =========================
/mnt/ssd/mfauzan/transformer/source_code_real/linear_proj_ctrl.sv
/mnt/ssd/mfauzan/transformer/source_code_real/linear_projection.sv
/mnt/ssd/mfauzan/transformer/source_code_real/top_linear_projection.sv

# =========================
# SELF ATTENTION
# =========================
/mnt/ssd/mfauzan/transformer/source_code_real/self_attention_head/self_attention_ctrl.sv
/mnt/ssd/mfauzan/transformer/source_code_real/self_attention_head/self_attention_head.sv
/mnt/ssd/mfauzan/transformer/source_code_real/self_attention_head/top_self_attention_head.sv
/mnt/ssd/mfauzan/transformer/source_code_real/multi_head_attention/multihead_attention.sv
/mnt/ssd/mfauzan/transformer/source_code_real/multi_head_attention/tb_multihead_attention_script.sv
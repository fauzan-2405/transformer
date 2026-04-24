#!/bin/bash

# ============================================
# USER CONFIG
# ============================================

BASE=/mnt/ssd/mfauzan/transformer/python_code/exports_1

SOFT_DIR=$BASE/software
CLEAN_DIR=$BASE/cleaned_files
HW_DIR=$BASE/hardware

mkdir -p $SOFT_DIR
mkdir -p $CLEAN_DIR
mkdir -p $HW_DIR

echo "========================================"
echo "STEP 1: Python Golden Model"
echo "========================================"

python3 matrix_multiplier.py \
    --task linear_projection \
    --rows_a 16 --cols_a 10 --proj_dim 12 \
    --cores_a 2 --cores_b 1 \
    --total_modules 2 \
    --unique_per_type \
    --integers \
    --export_c_v2 \
    --out_dir $SOFT_DIR

echo "========================================"
echo "STEP 2: Clean (bin2hex)"
echo "========================================"

python3 bin2hex.py --input_dir $SOFT_DIR --output_dir $CLEAN_DIR

echo "========================================"
echo "STEP 3: Vivado Simulation"
echo "========================================"

vivado -mode batch -source run_sim.tcl -tclargs \
    $HW_DIR \
    $CLEAN_DIR/mat_A.mem \
    $CLEAN_DIR/mat_Q.mem \
    $CLEAN_DIR/mat_K.mem \
    $CLEAN_DIR/mat_V.mem

echo "========================================"
echo "STEP 4: Compare"
echo "========================================"

python3 compare.py \
    --golden $SOFT_DIR/final_results.mem \
    --rtl    $HW_DIR/out_FINAL.mem

echo "========================================"
echo "PIPELINE DONE"
echo "========================================"
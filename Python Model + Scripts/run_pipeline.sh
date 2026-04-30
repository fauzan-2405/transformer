#!/bin/bash
# run_pipeline.sh
set -e
set -x
# ============================================
# USER CONFIG
# ============================================

# AUTO-INCREMENT EXPORT DIRECTORY
ROOT=/mnt/ssd/mfauzan/transformer/python_code

# Find next export index
i=0
while [ -d "$ROOT/exports_$i" ]; do
    ((i++))
done

BASE=$ROOT/exports_$i
echo "Using export directory: $BASE"

SOFT_DIR=$BASE/software
CLEAN_DIR=$BASE/cleaned_files
HW_DIR=$BASE/hardware

mkdir -p $SOFT_DIR
mkdir -p $CLEAN_DIR
mkdir -p $HW_DIR

echo "========================================"
echo "STEP 1: Python Golden Model"
echo "========================================"

python3 $ROOT/pipeline_runner.py \
    --rows_a 16 --cols_a 10 --proj_dim 12 \
    --cores_a 2 \
    --total_modules 2 \
    --out_dir $SOFT_DIR

echo "========================================"
echo "STEP 2: Clean (bin2hex + mem+processor)"
echo "========================================"

python3 $ROOT/bin2hex.py $SOFT_DIR/mem_input.mem --out_dir $CLEAN_DIR
python3 $ROOT/bin2hex.py $SOFT_DIR/mem_q1.mem --out_dir $CLEAN_DIR
python3 $ROOT/bin2hex.py $SOFT_DIR/mem_k1.mem --out_dir $CLEAN_DIR
python3 $ROOT/bin2hex.py $SOFT_DIR/mem_v1.mem --out_dir $CLEAN_DIR


echo "========================================"
echo "STEP 3: Vivado Simulation"
echo "========================================"

vivado -mode batch -source $ROOT/run_sim.tcl -tclargs \
    $HW_DIR \
    $CLEAN_DIR/mem_input_hex.mem \
    $CLEAN_DIR/mem_q1_hex.mem \
    $CLEAN_DIR/mem_k1_hex.mem \  
    $CLEAN_DIR/mem_v1_hex.mem     

# echo "========================================"
# echo "STEP 4: Compare"
# echo "========================================"

# python3 compare.py \
#     --golden $SOFT_DIR/final_results.mem \
#     --rtl    $HW_DIR/out_FINAL.mem

# echo "========================================"
# echo "PIPELINE DONE"
# echo "========================================"
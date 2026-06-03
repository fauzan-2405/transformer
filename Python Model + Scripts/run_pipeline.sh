#!/bin/bash
# run_pipeline.sh
#set -e
#set -x
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
LOG_FILE=$BASE/run_config.log
echo "Using export directory: $BASE"

SOFT_DIR=$BASE/software
CLEAN_DIR=$BASE/cleaned_files
HW_DIR=$BASE/hardware

mkdir -p $SOFT_DIR
mkdir -p $CLEAN_DIR
mkdir -p $HW_DIR

# USER INPUTS
ROWS=512
COLS=64
PROJ_DIM=512
CORES_A=8
TOTAL_MODULES=8
MIN_VAL=-1
MAX_VAL=1
SOFTMAX_MODE=rtl

# WARNING: For now, we can not use total width = 32, it will result in error
# INPUT MATRIX PRECISION
INPUT_TOTAL_BITS=32
INPUT_FRAC_BITS=16

# WEIGHT MATRIX PRECISION
WEIGHT_TOTAL_BITS=32
WEIGHT_FRAC_BITS=16

# SOFTMAX PRECISION
SOFT_TOTAL_BITS=16
SOFT_FRAC_BITS=15

# FINAL PRECISION
FINAL_TOTAL_BITS=16
FINAL_FRAC_BITS=15

# DERIVED PRECISIONS
# Linear projection output precision (Q/K/V)
KEYS_TOTAL_BITS=$((INPUT_TOTAL_BITS + 2))
KEYS_FRAC_BITS=$((INPUT_FRAC_BITS + 1))

# QK^T precision
QKT_TOTAL_BITS=$((KEYS_TOTAL_BITS + 4))
QKT_FRAC_BITS=$((KEYS_FRAC_BITS + 1))

# DERIVED PARAMETERS
ROW_SIZE_MAT_KEYS=$((ROWS/(2*2*CORES_A)))
COL_SIZE_MAT_KEYS=$((PROJ_DIM/(2*1*TOTAL_MODULES)))
MAX_FLAG_MAT_KEYS=$(($ROW_SIZE_MAT_KEYS * $COL_SIZE_MAT_KEYS))
CORES_A_MAT_KEYS=$CORES_A
CORES_B_MAT_KEYS=$TOTAL_MODULES

ROW_SIZE_MAT_Q_KT=$ROW_SIZE_MAT_KEYS
COL_SIZE_MAT_Q_KT=$ROW_SIZE_MAT_Q_KT
MAX_FLAG_MAT_Q_KT=$(($ROW_SIZE_MAT_Q_KT * $COL_SIZE_MAT_Q_KT))
CORES_A_MAT_Q_KT=$CORES_A
CORES_B_MAT_Q_KT=$CORES_A

SOFTMAX_ROW=$((CORES_A * 2))
TOTAL_TILE_SOFT=$((ROWS/(CORES_A*2*2)))
NUM_BANK_FIFO_MIN=$TOTAL_TILE_SOFT
NUM_BANK_FIFO_MAX=$(((CORES_A*2*2)/2))

ROW_SIZE_MAT_FINAL=$((ROWS/(2*2*CORES_A)))
COL_SIZE_MAT_FINAL=$((PROJ_DIM/(2*1*TOTAL_MODULES)))
MAX_FLAG_MAT_FINAL=$(($ROW_SIZE_MAT_FINAL * $COL_SIZE_MAT_FINAL))
CORES_A_MAT_FINAL=$CORES_A
CORES_B_MAT_FINAL=$TOTAL_MODULES

echo "[MODEL CONFIG]" >> $LOG_FILE
echo "rows           : $ROWS" >> $LOG_FILE
echo "cols           : $COLS" >> $LOG_FILE
echo "proj_dim       : $PROJ_DIM" >> $LOG_FILE
echo "cores_a        : $CORES_A" >> $LOG_FILE
echo "total_modules  : $TOTAL_MODULES" >> $LOG_FILE
echo "min_val        : $MIN_VAL" >> $LOG_FILE
echo "max_val        : $MAX_VAL" >> $LOG_FILE
echo "INPUT_TOTAL_BITS   : $INPUT_TOTAL_BITS" >> $LOG_FILE
echo "INPUT_FRAC_BITS    : $INPUT_FRAC_BITS" >> $LOG_FILE
echo "WEIGHT_TOTAL_BITS  : $WEIGHT_TOTAL_BITS" >> $LOG_FILE
echo "WEIGHT_FRAC_BITS   : $WEIGHT_FRAC_BITS" >> $LOG_FILE
echo "KEYS_TOTAL_BITS    : $KEYS_TOTAL_BITS" >> $LOG_FILE
echo "KEYS_FRAC_BITS     : $KEYS_FRAC_BITS" >> $LOG_FILE
echo "QKT_TOTAL_BITS     : $QKT_TOTAL_BITS" >> $LOG_FILE
echo "QKT_FRAC_BITS      : $QKT_FRAC_BITS" >> $LOG_FILE
echo "SOFT_TOTAL_BITS    : $SOFT_TOTAL_BITS" >> $LOG_FILE
echo "SOFT_FRAC_BITS     : $SOFT_FRAC_BITS" >> $LOG_FILE
echo "FINAL_TOTAL_BITS   : $FINAL_TOTAL_BITS" >> $LOG_FILE
echo "FINAL_FRAC_BITS    : $FINAL_FRAC_BITS" >> $LOG_FILE
echo "========================================" >> $LOG_FILE
echo "Q,K,V Parameters" >> $LOG_FILE
echo "ROW_SIZE       : $ROW_SIZE_MAT_KEYS" >> $LOG_FILE
echo "COL_SIZE       : $COL_SIZE_MAT_KEYS" >> $LOG_FILE
echo "MAX_FLAG       : $MAX_FLAG_MAT_KEYS" >> $LOG_FILE
echo "CORES_A        : $CORES_A_MAT_KEYS" >> $LOG_FILE
echo "CORES_B        : $CORES_B_MAT_KEYS" >> $LOG_FILE
echo "========================================" >> $LOG_FILE
echo "QK_T Parameters" >> $LOG_FILE
echo "ROW_SIZE       : $ROW_SIZE_MAT_Q_KT" >> $LOG_FILE
echo "COL_SIZE       : $COL_SIZE_MAT_Q_KT" >> $LOG_FILE
echo "MAX_FLAG       : $MAX_FLAG_MAT_Q_KT" >> $LOG_FILE
echo "CORES_A        : $CORES_A_MAT_Q_KT" >> $LOG_FILE
echo "CORES_B        : $CORES_B_MAT_Q_KT" >> $LOG_FILE
echo "========================================" >> $LOG_FILE
echo "PRECURSOR MODULES Parameters" >> $LOG_FILE
echo "SOFTMAX_ROW    : $SOFTMAX_ROW" >> $LOG_FILE
echo "HOW MANY SOFTMAX INPUT TO PRODUCE ONE OUTPUT/HOW MANY R2B CONVERTER    : $TOTAL_TILE_SOFT" >> $LOG_FILE
echo "NUM_BANK_FIFO(MINIMAL)  : $NUM_BANK_FIFO_MIN" >> $LOG_FILE
echo "NUM_BANK_FIFO(MAXIMAL)  : $NUM_BANK_FIFO_MAX" >> $LOG_FILE
echo "========================================" >> $LOG_FILE
echo "FINAL QKT_V Parameters" >> $LOG_FILE
echo "ROW_SIZE       : $ROW_SIZE_MAT_FINAL" >> $LOG_FILE
echo "COL_SIZE       : $COL_SIZE_MAT_FINAL" >> $LOG_FILE
echo "MAX_FLAG       : $MAX_FLAG_MAT_FINAL" >> $LOG_FILE
echo "CORES_A        : $CORES_A_MAT_FINAL" >> $LOG_FILE
echo "CORES_B        : $CORES_B_MAT_FINAL" >> $LOG_FILE


echo "========================================"
echo "STEP 1: Python Golden Model"
echo "========================================"

python3 $ROOT/pipeline_runner.py \
    --rows $ROWS \
    --cols $COLS \
    --proj_dim $PROJ_DIM \
    --cores_a $CORES_A \
    --total_modules $TOTAL_MODULES \
    --min_val $MIN_VAL \
    --max_val $MAX_VAL \
    --softmax_mode $SOFTMAX_MODE \
    \
    --input_total_bits $INPUT_TOTAL_BITS \
    --input_frac_bits $INPUT_FRAC_BITS \
    \
    --weight_total_bits $WEIGHT_TOTAL_BITS \
    --weight_frac_bits $WEIGHT_FRAC_BITS \
    \
    --keys_total_bits $KEYS_TOTAL_BITS \
    --keys_frac_bits $KEYS_FRAC_BITS \
    \
    --qkt_total_bits $QKT_TOTAL_BITS \
    --qkt_frac_bits $QKT_FRAC_BITS \
    \
    --soft_total_bits $SOFT_TOTAL_BITS \
    --soft_frac_bits $SOFT_FRAC_BITS \
    \
    --final_total_bits $FINAL_TOTAL_BITS \
    --final_frac_bits $FINAL_FRAC_BITS \
    \
    --out_dir $SOFT_DIR

echo "========================================"
echo "STEP 2: Clean (bin2hex + mem+processor)"
echo "========================================"
python3 $ROOT/bin2hex.py \
    $SOFT_DIR/mem_input.mem \
    --out_dir $CLEAN_DIR \
    --element-bits $INPUT_TOTAL_BITS

python3 $ROOT/bin2hex.py \
    $SOFT_DIR/mem_q1.mem \
    --out_dir $CLEAN_DIR \
    --element-bits $WEIGHT_TOTAL_BITS

python3 $ROOT/bin2hex.py \
    $SOFT_DIR/mem_k1.mem \
    --out_dir $CLEAN_DIR \
    --element-bits $WEIGHT_TOTAL_BITS

python3 $ROOT/bin2hex.py \
    $SOFT_DIR/mem_v1.mem \
    --out_dir $CLEAN_DIR \
    --element-bits $WEIGHT_TOTAL_BITS


echo "========================================"
echo "STEP 3: Vivado Simulation"
echo "========================================"

vivado -mode batch -source $ROOT/run_sim.tcl -tclargs \
    $HW_DIR \
    $CLEAN_DIR/mem_input_hex.mem \
    $CLEAN_DIR/mem_q1_hex.mem \
    $CLEAN_DIR/mem_k1_hex.mem \
    $CLEAN_DIR/mem_v1_hex.mem \
    \
    $INPUT_TOTAL_BITS \
    $INPUT_FRAC_BITS \
    \
    $WEIGHT_TOTAL_BITS \
    $WEIGHT_FRAC_BITS \
    \
    $SOFT_TOTAL_BITS \
    $SOFT_FRAC_BITS \
    \
    $FINAL_TOTAL_BITS \
    $FINAL_FRAC_BITS \
    \
    $ROWS \
    $COLS \
    $PROJ_DIM \
    \
    $CORES_A \
    $TOTAL_MODULES

echo "========================================"
echo "STEP 4: Compare"
echo "========================================"

echo "KEYS COMPARISON"
echo "================"
python3 $ROOT/compare.py \
     --golden $SOFT_DIR/mem_out_q1.mem \
     --rtl    $HW_DIR/out_Q.mem \
     --total_bits $KEYS_TOTAL_BITS \
     --frac_bits  $KEYS_FRAC_BITS

python3 $ROOT/compare.py \
     --golden $SOFT_DIR/mem_out_k1.mem \
     --rtl    $HW_DIR/out_K.mem \
     --total_bits $KEYS_TOTAL_BITS \
     --frac_bits  $KEYS_FRAC_BITS

python3 $ROOT/compare.py \
     --golden $SOFT_DIR/mem_out_v1.mem \
     --rtl    $HW_DIR/out_V.mem \
     --total_bits $KEYS_TOTAL_BITS \
     --frac_bits  $KEYS_FRAC_BITS

echo "QKT COMPARISON"
echo "================"
python3 $ROOT/compare.py \
     --golden $SOFT_DIR/Q_KT.mem \
     --rtl    $HW_DIR/out_QKT.mem \
     --total_bits $QKT_TOTAL_BITS \
     --frac_bits  $QKT_FRAC_BITS

echo "FINAL COMPARISON"
echo "================"
python3 $ROOT/compare.py \
     --golden $SOFT_DIR/final_results.mem \
     --rtl    $HW_DIR/out_FINAL.mem \
     --total_bits $FINAL_TOTAL_BITS \
     --frac_bits  $FINAL_FRAC_BITS

echo "========================================"
echo "PIPELINE DONE"
echo "========================================"
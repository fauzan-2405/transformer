#!/usr/bin/env python3

import os
import subprocess
import argparse

"""
example run:
python "d:\DATA\Documents\Xirka Internship\PME\Transformer\transformer\Python Model\pipeline_runner.py" --rows 16 --cols 10 --proj_dim 12 --cores_a 2  --total_modules 2 --out_dir exports
"""

def run_cmd(cmd):
    print("\n[RUNNING]")
    print(" ".join(cmd))
    result = subprocess.run(cmd)
    if result.returncode != 0:
        raise RuntimeError("Command failed!")

def main():
    parser = argparse.ArgumentParser()

    # USER INPUTS
    parser.add_argument('--rows', type=int, required=True)
    parser.add_argument('--cols', type=int, required=True)
    parser.add_argument('--proj_dim', type=int, required=True)

    parser.add_argument('--cores_a', type=int, required=True)
    parser.add_argument('--total_modules', type=int, required=True)

    parser.add_argument('--min_val', type=int, default=0)
    parser.add_argument('--max_val', type=int, default=1)

    parser.add_argument('--total_bits', type=int, default=16)
    parser.add_argument('--frac_bits', type=int, default=8)

    parser.add_argument('--out_dir', type=str, default="exports")

    args = parser.parse_args()

    os.makedirs(args.out_dir, exist_ok=True)

    # ----------------------------------
    # STEP 1: MATRIX MULTIPLIER
    # ----------------------------------
    run_cmd([
        "python", 
        r"D:\DATA\Documents\Xirka Internship\PME\Transformer\transformer\Python Model\matrix_multiplier.py",
        "--task", "linear_projection",
        "--rows_a", str(args.rows),
        "--cols_a", str(args.cols),
        "--proj_dim", str(args.proj_dim),

        "--cores_a", str(args.cores_a),
        "--cores_b", "1",
        "--total_modules", str(args.total_modules),

        "--unique_per_type",
        "--integers",

        "--min_val", str(args.min_val),
        "--max_val", str(args.max_val),

        "--A_total_bits", str(args.total_bits),
        "--A_frac_bits", str(args.frac_bits),
        "--B_total_bits", str(args.total_bits),
        "--B_frac_bits", str(args.frac_bits),
        "--C_total_bits", str(args.total_bits),
        "--C_frac_bits", str(args.frac_bits),

        "--export_c_v2",
        "--output_format", "hex",

        "--out_dir", args.out_dir
    ])

    Q = os.path.join(args.out_dir, "mem_out_q1_row.mem")
    K = os.path.join(args.out_dir, "mem_out_k1_row.mem")
    V = os.path.join(args.out_dir, "mem_out_v1_row.mem")

    QKT = os.path.join(args.out_dir, "Q_KT.mem")
    SOFTMAX = os.path.join(args.out_dir, "softmax_results.mem")
    FINAL = os.path.join(args.out_dir, "final_results.mem")

    # ----------------------------------
    # STEP 2: Q × K^T
    # ----------------------------------
    run_cmd([
        "python", 
        r"D:\DATA\Documents\Xirka Internship\PME\Transformer\transformer\Python Model\block_matmul.py",
        "--matrix_A", Q,
        "--matrix_B", K,

        "--input_format_A", "hex",
        "--input_format_B", "hex",

        "--cores_a", str(args.cores_a),
        "--cores_b", str(args.cores_a),
        "--total_modules", "2",

        "--transpose_B",
        "--export_c_v2",

        "--output_file", QKT
    ])

    # ----------------------------------
    # STEP 3: SOFTMAX
    # ----------------------------------
    run_cmd([
        "python", 
        r"D:\DATA\Documents\Xirka Internship\PME\Transformer\transformer\Python Model\softmax.py",
        "--input", QKT,

        "--input_format", "hex",
        "--output_format", "hex",

        "--apply_div",
        "--div_value", "16",

        "--total_bits", str(args.total_bits),
        "--frac_bits", str(args.frac_bits),

        "--output_file", SOFTMAX
    ])

    # ----------------------------------
    # STEP 4: SOFTMAX × V
    # ----------------------------------
    run_cmd([
        "python", 
        r"D:\DATA\Documents\Xirka Internship\PME\Transformer\transformer\Python Model\block_matmul.py",
        "--matrix_A", SOFTMAX,
        "--matrix_B", V,

        "--input_format_A", "hex",
        "--input_format_B", "hex",

        "--cores_a", str(args.cores_a),
        "--cores_b", str(args.total_modules),
        "--total_modules", "1",

        "--export_c_v2",

        "--output_file", FINAL
    ])

    print("\n✅ PIPELINE COMPLETE")
    print(f"Final result: {FINAL}")

if __name__ == "__main__":
    main()
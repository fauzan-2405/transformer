#!/usr/bin/env python3

import argparse


# ============================================================
# Fixed-point helper
# ============================================================
def fixed_to_float(hex_str, total_bits, frac_bits, signed=True):
    """
    Convert fixed-point hex string to float.
    Example:
        0080 (Q8.8)  -> 0.5
        FF80 (Q8.8)  -> -0.5
    """

    value = int(hex_str, 16)

    if signed:
        sign_bit = 1 << (total_bits - 1)

        if value & sign_bit:
            value = value - (1 << total_bits)

    return value / (1 << frac_bits)


# ============================================================
# Load file
# ============================================================
def load_hex_file(path):
    data = []

    with open(path, 'r') as f:
        for line in f:
            tokens = line.strip().split()

            for t in tokens:
                if t == "":
                    continue

                t = t.lower().replace("0x", "")
                data.append(t)

    return data


# ============================================================
# Compare
# ============================================================
def compare_files(
    golden,
    rtl,
    total_bits,
    frac_bits,
    signed=True,
    max_print=10
):
    if len(golden) != len(rtl):
        print(f"❌ Size mismatch: golden={len(golden)}, rtl={len(rtl)}")
        return False

    mismatch_count = 0

    total_error_percent = 0.0
    max_error_percent = 0.0

    for i, (g_hex, r_hex) in enumerate(zip(golden, rtl)):

        # ----------------------------------------
        # Convert to float
        # ----------------------------------------
        g_val = fixed_to_float(g_hex, total_bits, frac_bits, signed)
        r_val = fixed_to_float(r_hex, total_bits, frac_bits, signed)

        # ----------------------------------------
        # Absolute error
        # ----------------------------------------
        abs_error = abs(r_val - g_val)

        # ----------------------------------------
        # Percentage error
        #
        # If golden == 0:
        #   - exact match -> 0%
        #   - otherwise -> 100%
        # ----------------------------------------
        if abs(g_val) < 1e-12:
            if abs(r_val) < 1e-12:
                percent_error = 0.0
            else:
                percent_error = 100.0
        else:
            percent_error = (abs_error / abs(g_val)) * 100.0

        total_error_percent += percent_error

        if percent_error > max_error_percent:
            max_error_percent = percent_error

        # ----------------------------------------
        # Mismatch print
        # ----------------------------------------
        if g_hex != r_hex:

            if mismatch_count < max_print:
                print(
                    f"[Mismatch {mismatch_count}] "
                    f"idx={i} | "
                    f"golden={g_hex} ({g_val:.6f}) | "
                    f"rtl={r_hex} ({r_val:.6f}) | "
                    f"error={percent_error:.4f}%"
                )

            mismatch_count += 1

    # ========================================================
    # Final statistics
    # ========================================================
    avg_error_percent = total_error_percent / len(golden)

    print("\n================================================")
    print("COMPARE SUMMARY")
    print("================================================")
    print(f"Total elements     : {len(golden)}")
    print(f"Total mismatches   : {mismatch_count}")
    print(f"Match percentage   : {(1 - mismatch_count/len(golden))*100:.4f}%")
    print(f"Average error      : {avg_error_percent:.6f}%")
    print(f"Maximum error      : {max_error_percent:.6f}%")
    print("================================================")

    if mismatch_count == 0:
        print("✅ PERFECT MATCH")
        return True
    else:
        print("⚠️ Differences detected")
        return False


# ============================================================
# Main
# ============================================================
def main():

    parser = argparse.ArgumentParser()

    parser.add_argument('--golden', required=True)
    parser.add_argument('--rtl', required=True)

    parser.add_argument('--total_bits', type=int, required=True)
    parser.add_argument('--frac_bits', type=int, required=True)

    parser.add_argument('--unsigned', action='store_true')

    parser.add_argument('--max_print', type=int, default=10)

    args = parser.parse_args()

    signed = not args.unsigned

    print("Loading files...")

    golden_data = load_hex_file(args.golden)
    rtl_data    = load_hex_file(args.rtl)

    print(f"Golden size: {len(golden_data)}")
    print(f"RTL size   : {len(rtl_data)}")

    print("Comparing...")

    compare_files(
        golden=golden_data,
        rtl=rtl_data,
        total_bits=args.total_bits,
        frac_bits=args.frac_bits,
        signed=signed,
        max_print=args.max_print
    )


if __name__ == "__main__":
    main()
#!/usr/bin/env python3

import argparse

def load_hex_file(path):
    data = []
    with open(path, 'r') as f:
        for line in f:
            # Split by whitespace
            tokens = line.strip().split()
            for t in tokens:
                if t == "":
                    continue
                # Normalize: lowercase + remove optional 0x
                t = t.lower().replace("0x", "")
                data.append(t)
    return data


def compare_files(golden, rtl, max_print=10):
    if len(golden) != len(rtl):
        print(f"❌ Size mismatch: golden={len(golden)}, rtl={len(rtl)}")
        return False

    mismatch_count = 0

    for i, (g, r) in enumerate(zip(golden, rtl)):
        if g != r:
            if mismatch_count < max_print:
                print(f"[Mismatch {mismatch_count}] idx={i} | golden={g} | rtl={r}")
            mismatch_count += 1

    if mismatch_count == 0:
        print("✅ PERFECT MATCH")
        return True
    else:
        print(f"❌ Total mismatches: {mismatch_count} / {len(golden)}")
        return False


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--golden', required=True)
    parser.add_argument('--rtl', required=True)
    parser.add_argument('--max_print', type=int, default=10)

    args = parser.parse_args()

    print("Loading files...")
    golden_data = load_hex_file(args.golden)
    rtl_data    = load_hex_file(args.rtl)

    print(f"Golden size: {len(golden_data)}")
    print(f"RTL size   : {len(rtl_data)}")

    print("Comparing...")
    compare_files(golden_data, rtl_data, args.max_print)


if __name__ == "__main__":
    main()
#!/usr/bin/env python3
"""
bin2hex_xpm.py

Recursively converts binary _cleaned.mem files into XPM-compatible HEX _cleaned.mem files.

XPM-Compatible Output Format:
    - Each line = ONE BRAM word
    - Single continuous HEX string (no spaces)
    - Uppercase HEX
    - Length = (binary_line_length / 4)

Automatically handles:
    - spaced binary (e.g., "0001 0010 1111 ...")
    - unspaced binary ("000100101111...")

python -u "d:\DATA\Documents\Xirka Internship\PME\Transformer\transformer\Python Model\bin2hex.py" "d:\DATA\Documents\Xirka Internship\PME\Transformer\transformer\exports\Tested Mem Files\#7 Linear Projection Testing" --element-bits 16
"""

import argparse
import os
import sys


def is_binary(s):
    return all(ch in "01" for ch in s)


def process_line_to_hex(line, elem_bits):
    """
    Convert one binary line (spaced or unspaced) into continuous HEX string.
    """
    # Remove whitespace
    clean = "".join(line.split())

    if not is_binary(clean):
        raise ValueError("Line contains non-binary characters")

    if len(clean) % elem_bits != 0:
        raise ValueError(
            f"Line length {len(clean)} not divisible by element_bits {elem_bits}"
        )

    # Split into element sized tokens
    chunks = [clean[i:i+elem_bits] for i in range(0, len(clean), elem_bits)]

    # Convert each chunk to hex
    hex_digits = (elem_bits + 3) // 4
    hex_chunks = [format(int(ch, 2), f"0{hex_digits}X") for ch in chunks]

    # XPM requires one continuous hex word per line → concatenate
    return "".join(hex_chunks)


def convert_file(infile, elem_bits=16, out_suffix="_hex.mem"):
    with open(infile, "r") as f:
        raw_lines = [ln.strip() for ln in f.readlines() if ln.strip()]

    if not raw_lines:
        return False, "empty file"

    out_lines = []

    for i, line in enumerate(raw_lines, 1):
        try:
            hex_line = process_line_to_hex(line, elem_bits)
        except Exception as e:
            return False, f"Line {i}: {e}"

        out_lines.append(hex_line)

    outfile = os.path.splitext(infile)[0] + out_suffix

    # Write XPM-compatible hex
    with open(outfile, "w") as f:
        for ln in out_lines:
            f.write(ln + "\n")

    return True, outfile


def find_mem_files(path, recursive=True):
    files = []
    if os.path.isfile(path):
        if path.lower().endswith("_cleaned.mem"):
            files.append(path)
        return files

    for root, dirs, filenames in os.walk(path):
        for fn in filenames:
            if fn.lower().endswith("_cleaned.mem"):
                files.append(os.path.join(root, fn))
        if not recursive:
            break

    return files


def main():
    parser = argparse.ArgumentParser(description="Binary → XPM-HEX .mem converter")
    parser.add_argument("path", type=str,
                        help="File or directory containing .mem files")
    parser.add_argument("--element-bits", type=int, default=16,
                        help="Bit width per element (default 16)")
    parser.add_argument("--no-recursive", action="store_true",
                        help="Disable recursive directory scan")
    args = parser.parse_args()

    recursive = not args.no_recursive
    elem_bits = args.element_bits

    mem_files = find_mem_files(args.path, recursive)

    if not mem_files:
        print("No _cleaned.mem files found.")
        return

    print(f"Found {len(mem_files)} _cleaned.mem files.")
    print(f"element_bits = {elem_bits} bits per element")
    print()

    success = 0
    fail = 0

    for fn in mem_files:
        ok, msg = convert_file(fn, elem_bits)
        if ok:
            print(f"[OK] {fn} → {msg}")
            success += 1
        else:
            print(f"[FAIL] {fn} : {msg}")
            fail += 1

    print()
    print("-------------- Summary --------------")
    print(f"Converted : {success}")
    print(f"Failed    : {fail}")


if __name__ == "__main__":
    main()

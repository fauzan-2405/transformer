#!/usr/bin/env python3
"""
bin2hex_dir.py

Recursively convert binary-format .mem files to space-separated HEX .mem files.
Output file for `foo.mem` is `foo_hex.mem` written beside original.

Examples:
    # Convert directory recursively, element width 16 bits (default)
    python bin2hex_dir.py "/path/to/exports" --element-bits 16

    # Convert a single file and output to same folder
    python bin2hex_dir.py exports/mem_q1.mem --element-bits 16

    # Disable recursion
    python bin2hex_dir.py exports/ --element-bits 16 --no-recursive

Notes:
- element_bits: bit-width of each numeric element in the binary mem.
  For 16-bit fixed-point values use --element-bits 16 (common).
- The script expects binary tokens (only 0/1). Lines may contain single long concatenated binary
  strings or multiple space-separated binary tokens.
- Produced hex tokens are uppercase and zero-padded to element_bits/4 hex digits.
"""

import argparse
import os
import sys
from typing import List, Tuple

def is_binary_string(s: str) -> bool:
    return all(ch in "01" for ch in s)

def split_into_chunks(binstr: str, chunk_bits: int) -> List[str]:
    return [binstr[i:i+chunk_bits] for i in range(0, len(binstr), chunk_bits)]

def bin_token_to_padded_hex(bin_token: str, element_bits: int) -> str:
    # Remove underscores or stray whitespace as precaution (but validate only 0/1)
    b = "".join(bin_token.split())
    if not is_binary_string(b):
        raise ValueError("Token contains non-binary characters.")
    if len(b) != element_bits:
        raise ValueError(f"Token length {len(b)} != element_bits {element_bits}")
    val = int(b, 2)
    hex_digits = (element_bits + 3) // 4
    return format(val, '0{}X'.format(hex_digits))

def process_file(inpath: str, element_bits: int, out_suffix: str = "_hex.mem") -> Tuple[bool, str]:
    """
    Process single file. Returns (success, message).
    success True -> file converted and written to outpath
    success False -> file skipped with message explaining reason
    """
    try:
        with open(inpath, 'r') as f:
            raw_lines = [ln.rstrip('\n') for ln in f.readlines() if ln.strip()]
    except Exception as e:
        return False, f"Cannot read file: {e}"

    if not raw_lines:
        return False, "Empty file"

    out_lines = []
    for lineno, raw in enumerate(raw_lines, start=1):
        # split by whitespace into tokens. If only one token present it might itself be concatenated.
        tokens = raw.strip().split()
        if len(tokens) == 0:
            continue

        converted_tokens = []
        # If there is a single token that is a concatenation of many elements
        if len(tokens) == 1:
            tok = tokens[0].strip()
            # remove stray spaces (none) and validate binary
            tok_clean = "".join(tok.split())
            if not is_binary_string(tok_clean):
                return False, f"Line {lineno}: non-binary characters found"
            if len(tok_clean) == element_bits:
                # single element
                try:
                    converted_tokens.append(bin_token_to_padded_hex(tok_clean, element_bits))
                except ValueError as ex:
                    return False, f"Line {lineno}: {ex}"
            elif len(tok_clean) % element_bits == 0:
                # split into chunks
                chunks = split_into_chunks(tok_clean, element_bits)
                try:
                    for ch in chunks:
                        converted_tokens.append(bin_token_to_padded_hex(ch, element_bits))
                except ValueError as ex:
                    return False, f"Line {lineno}: {ex}"
            else:
                return False, f"Line {lineno}: token length {len(tok_clean)} not divisible by element_bits {element_bits}"
        else:
            # Multiple tokens on the line - assume each is one or multiple elements
            for t in tokens:
                t_clean = "".join(t.split())
                if not is_binary_string(t_clean):
                    return False, f"Line {lineno}: token contains non-binary characters"
                if len(t_clean) == element_bits:
                    try:
                        converted_tokens.append(bin_token_to_padded_hex(t_clean, element_bits))
                    except ValueError as ex:
                        return False, f"Line {lineno}: {ex}"
                elif len(t_clean) % element_bits == 0:
                    chunks = split_into_chunks(t_clean, element_bits)
                    try:
                        for ch in chunks:
                            converted_tokens.append(bin_token_to_padded_hex(ch, element_bits))
                    except ValueError as ex:
                        return False, f"Line {lineno}: {ex}"
                else:
                    return False, f"Line {lineno}: token length {len(t_clean)} not divisible by element_bits {element_bits}"

        # join converted tokens with single space (Option B)
        out_lines.append(" ".join(converted_tokens))

    # Write output file
    base, ext = os.path.splitext(inpath)
    outpath = f"{base}{out_suffix}"
    try:
        with open(outpath, 'w') as fo:
            for ol in out_lines:
                fo.write(ol + "\\n")
    except Exception as e:
        return False, f"Failed to write output: {e}"

    return True, f"Wrote {outpath} ({len(out_lines)} lines)"

def find_mem_files(path: str, recursive: bool=True) -> List[str]:
    files = []
    if os.path.isfile(path):
        if path.lower().endswith('.mem'):
            files.append(path)
        return files
    for root, dirs, filenames in os.walk(path):
        for fn in filenames:
            if fn.lower().endswith('.mem'):
                files.append(os.path.join(root, fn))
        if not recursive:
            break
    return files

def main():
    parser = argparse.ArgumentParser(description="Batch convert binary .mem files to space-separated HEX *_hex.mem files")
    parser.add_argument('path', help="File or directory to process (if directory, processed recursively by default)")
    parser.add_argument('--element-bits', type=int, default=16,
                        help="Bit width of each element (default: 16). Must be >0 and divisible by 4 ideally.")
    parser.add_argument('--no-recursive', dest='recursive', action='store_false',
                        help="Do not recurse into subdirectories (only top-level files)")
    parser.add_argument('--out-suffix', default='_hex.mem', help="Suffix to append to base filename for output (default: '_hex.mem')")
    parser.add_argument('--overwrite', action='store_true', help="Overwrite existing *_hex.mem files if present")
    parser.add_argument('--verbose', action='store_true', help="Print verbose progress")
    args = parser.parse_args()

    p = args.path
    element_bits = args.element_bits
    recursive = args.recursive
    out_suffix = args.out_suffix
    overwrite = args.overwrite
    verbose = args.verbose

    if element_bits <= 0:
        print("element-bits must be positive integer.")
        sys.exit(2)
    if element_bits % 1 != 0:
        print("element-bits must be integer.")
        sys.exit(2)
    # hex digit width note
    if element_bits % 4 != 0:
        print("Warning: element_bits is not a multiple of 4; hex digits will be padded to (element_bits+3)//4 digits.")

    mem_files = find_mem_files(p, recursive=recursive)
    if not mem_files:
        print("No .mem files found at path:", p)
        return

    print(f"Found {len(mem_files)} .mem files (recursive={recursive}). element_bits={element_bits}")
    success_count = 0
    fail_count = 0
    for fn in mem_files:
        outpath = os.path.splitext(fn)[0] + out_suffix
        if os.path.exists(outpath) and not overwrite:
            print(f"Skipping (exists): {outpath}")
            continue
        if verbose:
            print(f"Processing: {fn}")
        ok, msg = process_file(fn, element_bits, out_suffix)
        if ok:
            success_count += 1
            print(f"[OK] {fn} -> {os.path.splitext(fn)[0] + out_suffix}")
            if verbose:
                print("     ", msg)
        else:
            fail_count += 1
            print(f"[FAIL] {fn} : {msg}")

    print(f"Done. Success: {success_count}, Failed: {fail_count}")

if __name__ == '__main__':
    main()

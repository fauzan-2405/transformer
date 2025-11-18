# mem_processor_v2.py
# Recursively process .mem files in a directory OR a single .mem file
# Automatically detect core/row modes + linear-projection mem patterns
# Clean each file and display values in int/float/binary formats

# How to use:
# python mem_processor_v2.py exports/ --total_bits 16 --frac_bits 8 --display float


import os
import argparse
from typing import List

class FixedPointConverter:
    """Handles fixed-point number conversion and binary cleanup."""
    def __init__(self, total_bits: int, fractional_bits: int, is_signed: bool = True):
        self.total_bits = total_bits
        self.fractional_bits = fractional_bits
        self.is_signed = is_signed

    def clean_line(self, line: str) -> str:
        """Remove all whitespace inside a line."""
        return ''.join(line.split())

    def binary_to_int(self, binary_str: str) -> int:
        """Convert a fixed-width binary string to signed or unsigned integer."""
        if len(binary_str) != self.total_bits:
            raise ValueError(
                f"Binary string length {len(binary_str)} does not match total bits {self.total_bits}"
            )

        if self.is_signed and binary_str[0] == '1':
            return int(binary_str, 2) - (1 << self.total_bits)
        return int(binary_str, 2)

    def binary_to_float(self, binary_str: str) -> float:
        """Convert fixed-point binary string to floating point."""
        return self.binary_to_int(binary_str) / (1 << self.fractional_bits)


# ------------------------------------------------------------
# FILE TYPE DETECTION
# ------------------------------------------------------------

def detect_mem_type(filename: str) -> str:
    """
    Detect whether a file is row-mode or core-mode.

    Rules:
    - If the filename contains "_row": treat as row-mode.
    - If filename contains "_core": treat as core-mode.
    - If filename starts with: mem_input, mem_q, mem_k, mem_v, mem_out → treat as core-mode.
    - Otherwise: assume core-mode (safe default for FPGA BRAM).
    """

    lower = filename.lower()

    if "_row" in lower:
        return "row"
    if "_core" in lower:
        return "core"

    # New LP file types: treat as core-mode
    base = os.path.basename(lower)
    if base.startswith("mem_input"):
        return "core"
    if base.startswith("mem_q"):
        return "core"
    if base.startswith("mem_k"):
        return "core"
    if base.startswith("mem_v"):
        return "core"
    if base.startswith("mem_out"):
        return "core"

    # Default
    return "core"


# ------------------------------------------------------------
# PROCESS A SINGLE FILE
# ------------------------------------------------------------

def process_mem_file(file_path: str, converter: FixedPointConverter,
                     display_format: str, output_dir: str):
    """Process a single .mem file and output cleaned + displayed values."""

    file_type = detect_mem_type(file_path)
    filename = os.path.basename(file_path)

    # Read lines
    with open(file_path, "r") as f:
        raw_lines = [ln.strip() for ln in f.readlines() if ln.strip()]

    if not raw_lines:
        print(f"[WARNING] File is empty: {filename}")
        return

    # Determine matrix display shape from file content (Option C)
    num_lines = len(raw_lines)
    num_tokens = len(raw_lines[0].split())

    print("\n==============================================")
    print(f"Processing file: {filename}")
    print(f"Detected type     : {file_type}-mode")
    print(f"Lines in file     : {num_lines}")
    print(f"Tokens per line   : {num_tokens}")
    print(f"Display format    : {display_format}")
    print("----------------------------------------------")

    # Create cleaned version
    os.makedirs(output_dir, exist_ok=True)
    cleaned_path = os.path.join(
        output_dir, f"{os.path.splitext(filename)[0]}_cleaned.mem"
    )

    with open(cleaned_path, "w") as f_out:
        for line in raw_lines:
            f_out.write(converter.clean_line(line) + "\n")

    # Display file content according to chosen representation
    print("File content:")
    for line in raw_lines:
        tokens = line.split()

        if display_format == "binary":
            print(line)
            continue

        # Convert binary to int or float
        vals = []
        for tok in tokens:
            if display_format == "int":
                vals.append(converter.binary_to_int(tok))

            elif display_format == "float":
                vals.append(converter.binary_to_float(tok))

        # Pretty-print
        if display_format == "int":
            print(" ".join(f"{v:6d}" for v in vals))
        else:
            print(" ".join(f"{v:9.4f}" for v in vals))

    print(f"\n[Saved cleaned file]  {cleaned_path}")


# ------------------------------------------------------------
# RECURSIVE DIRECTORY SEARCH
# ------------------------------------------------------------

def find_all_mem_files(path: str) -> List[str]:
    """Recursively find all .mem files under a directory."""
    mem_files = []
    for root, _, files in os.walk(path):
        for fname in files:
            if fname.lower().endswith(".mem"):
                mem_files.append(os.path.join(root, fname))
    return mem_files


# ------------------------------------------------------------
# MAIN
# ------------------------------------------------------------


def main():
    parser = argparse.ArgumentParser(description="Recursive .mem cleaner and decoder")

    parser.add_argument("path", type=str,
                        help="Path to a .mem file OR a directory containing .mem files")

    parser.add_argument("--total_bits", type=int, required=True,
                        help="Total fixed-point bit width")

    parser.add_argument("--frac_bits", type=int, required=True,
                        help="Fractional bits for fixed-point format")

    parser.add_argument("--signed", action="store_true",
                        help="Interpret values as signed two's complement")

    parser.add_argument("--display", choices=["binary", "int", "float"], default="int",
                        help="Format for displaying decoded values")

    parser.add_argument("--output_dir", type=str, default="exports",
                        help="Directory to store cleaned files")

    args = parser.parse_args()

    converter = FixedPointConverter(args.total_bits, args.frac_bits, args.signed)

    # Determine file vs directory
    if os.path.isfile(args.path):
        # Single file
        process_mem_file(
            args.path, converter, args.display, args.output_dir
        )

    elif os.path.isdir(args.path):
        # Directory → recursive search
        mem_files = find_all_mem_files(args.path)
        if not mem_files:
            print("[ERROR] No .mem files found in directory.")
            return

        print(f"[INFO] Found {len(mem_files)} .mem files")

        for mem_file in mem_files:
            process_mem_file(
                mem_file, converter, args.display, args.output_dir
            )

    else:
        print("[ERROR] Path is neither a file nor a directory.")


if __name__ == "__main__":
    main()

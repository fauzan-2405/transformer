# This used to clean the inputted matrix_*_core.mem or matrix_*_row.mem 

# How to use:
# python mem_processor.py matrix_B_core.mem --total_bits 16 --frac_bits 8 --rows 6 --cols 8 --display float
# python mem_processor.py matrix_A_row.mem --total_bits 16 --frac_bits 8 --rows 12 --cols 6 --display int

import os
import argparse
import numpy as np
from typing import Tuple

class FixedPointConverter:
    """Handles fixed-point number conversion with explicit format specification"""
    def __init__(self, total_bits: int, fractional_bits: int, is_signed: bool = True):
        self.total_bits = total_bits
        self.fractional_bits = fractional_bits
        self.is_signed = is_signed

    def clean_line(self, line: str) -> str:
        """Remove spaces from a line of binary values"""
        return ''.join(line.split())

    def binary_to_int(self, binary_str: str) -> int:
        """Convert binary string to fixed-point integer"""
        if len(binary_str) != self.total_bits:
            raise ValueError(f"Binary string length ({len(binary_str)}) doesn't match total bits ({self.total_bits})")
            
        if self.is_signed and binary_str[0] == '1':
            # Two's complement conversion
            return int(binary_str, 2) - (1 << self.total_bits)
        return int(binary_str, 2)
    
    def binary_to_float(self, binary_str: str) -> float:
        """Convert binary string to float"""
        val = self.binary_to_int(binary_str)
        return val / (1 << self.fractional_bits)

def detect_file_type_and_dimensions(file_path: str, real_rows: int, real_cols: int) -> Tuple[str, int, int]:
    """Detect whether the file is row or core mode and return display dimensions"""
    filename = os.path.basename(file_path).lower()
    
    if '_row.' in filename:
        # Row mode: lines = rows, elements per line = cols
        return 'row', real_rows, real_cols
    elif '_core.' in filename:
        # Core mode: display exactly as in file (lines x elements_per_line)
        with open(file_path, 'r') as f:
            first_line = f.readline()
            if not first_line:
                raise ValueError("Empty file")
            elements_per_line = len(first_line.strip().split())
        return 'core', len(list(open(file_path))), elements_per_line
    else:
        raise ValueError("Cannot determine file type (should contain '_row' or '_core' in filename)")

def process_mem_file(file_path: str, converter: FixedPointConverter, 
                   display_format: str, output_dir: str,
                   real_rows: int, real_cols: int):
    """Process a .mem file with automatic row/core detection"""
    # Detect file type and display dimensions
    try:
        file_type, display_rows, display_cols = detect_file_type_and_dimensions(file_path, real_rows, real_cols)
    except ValueError as e:
        print(f"Error: {e}")
        return
    
    print(f"\nProcessing {file_type}-mode file: {os.path.basename(file_path)}")
    print(f"Original matrix dimensions: {real_rows}x{real_cols}")
    print(f"Display dimensions: {display_rows}x{display_cols}")
    print(f"Fixed-point format: {converter.total_bits} bits ({converter.fractional_bits} fractional)")
    print(f"Display format: {display_format}")

    # Read and process file content
    with open(file_path, 'r') as f:
        lines = [line.strip() for line in f.readlines() if line.strip()]
    
    if not lines:
        print("File is empty")
        return
    
    # Create cleaned file
    cleaned_path = os.path.join(output_dir, f"{os.path.splitext(os.path.basename(file_path))[0]}_cleaned.mem")
    with open(cleaned_path, 'w') as f_out:
        for line in lines:
            f_out.write(converter.clean_line(line) + '\n')
    
    # Display content in original format
    print("\nFile content:")
    for line in lines:
        if display_format == 'binary':
            print(line)
        else:
            values = []
            for bin_str in line.split():
                if display_format == 'int':
                    values.append(converter.binary_to_int(bin_str))
                else:  # float
                    values.append(converter.binary_to_float(bin_str))
            
            # Format the line appropriately
            if display_format == 'int':
                print(" ".join(f"{val:6}" for val in values))
            else:  # float
                print(" ".join(f"{val:8.4f}" for val in values))
    
    print(f"\nCleaned file saved to: {cleaned_path}")

def main():
    # How to use:
    # python mem_processor.py matrix_B_core.mem --total_bits 16 --frac_bits 8 --rows 6 --cols 8 --display float
    # python mem_processor.py matrix_A_row.mem --total_bits 16 --frac_bits 8 --rows 12 --cols 6 --display int

    parser = argparse.ArgumentParser(description='Process matrix memory files with automatic row/core detection')
    parser.add_argument('file', type=str, help='Path to the .mem file to process')
    parser.add_argument('--total_bits', type=int, required=True, help='Total bits for fixed-point representation')
    parser.add_argument('--frac_bits', type=int, required=True, help='Fractional bits for fixed-point representation')
    parser.add_argument('--signed', action='store_true', help='Use signed fixed-point representation')
    parser.add_argument('--display', choices=['int', 'float', 'binary'], default='int', 
                       help='Display format for the .mem file contents')
    parser.add_argument('--rows', type=int, required=True, help='Original number of rows in the matrix')
    parser.add_argument('--cols', type=int, required=True, help='Original number of columns in the matrix')
    parser.add_argument('--output_dir', type=str, default='exports', help='Directory to save cleaned file')
    
    args = parser.parse_args()
    
    # Create converter with explicit specifications
    converter = FixedPointConverter(args.total_bits, args.frac_bits, args.signed)
    
    # Process the file
    process_mem_file(
        args.file,
        converter,
        args.display,
        args.output_dir,
        args.rows,
        args.cols
    )

if __name__ == "__main__":
    main()
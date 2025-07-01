import os
import argparse
import numpy as np
import re

class FixedPointConverter:
    """Handles fixed-point number conversion with dimension detection"""
    def __init__(self, total_bits: int = None, fractional_bits: int = None, is_signed: bool = True):
        self.total_bits = total_bits
        self.fractional_bits = fractional_bits
        self.is_signed = is_signed

    def detect_format(self, first_line: str):
        """Detect fixed-point format from first line of .mem file"""
        # Clean line and get binary strings
        bin_strs = self.split_binary_strings(first_line)
        if not bin_strs:
            return None
            
        # Detect bit length from first binary string
        first_bits = len(bin_strs[0])
        self.total_bits = first_bits
        
        # Default fractional bits (configurable by user)
        self.fractional_bits = self.fractional_bits or first_bits // 2
        
        return first_bits

    def split_binary_strings(self, line: str):
        """Split line into individual binary strings handling spaces"""
        # Remove all spaces and split into chunks
        clean_line = line.replace(" ", "").strip()
        if not clean_line:
            return []
            
        # If total_bits is known, split into chunks of that size
        if self.total_bits:
            return [clean_line[i:i+self.total_bits] 
                    for i in range(0, len(clean_line), self.total_bits)]
        
        # Otherwise, try to detect natural boundaries
        return re.findall(r'[01]{8,}', clean_line)  # Look for 8+ bit sequences

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

def process_mem_file(file_path: str, converter: FixedPointConverter, display_format: str, 
                   output_dir: str, rows: int = None, cols: int = None):
    """Process a .mem file with flexible reshaping options"""
    # Read file content
    with open(file_path, 'r') as f:
        lines = [line.strip() for line in f.readlines() if line.strip()]
    
    if not lines:
        print(f"File {file_path} is empty")
        return
    
    # Create output filename for cleaned version
    file_name = os.path.basename(file_path)
    base_name, ext = os.path.splitext(file_name)
    cleaned_path = os.path.join(output_dir, f"{base_name}_cleaned{ext}")
    
    # Detect format if not provided
    first_line_bits = converter.detect_format(lines[0])
    if first_line_bits is None:
        print(f"Could not detect format from {file_path}")
        return
    
    # Process data
    all_values = []
    for line in lines:
        bin_strs = converter.split_binary_strings(line)
        all_values.extend(bin_strs)
    
    # Create cleaned file
    with open(cleaned_path, 'w') as f_out:
        # Write cleaned lines (original lines without spaces)
        for line in lines:
            cleaned_line = line.replace(" ", "")
            f_out.write(cleaned_line + '\n')
    
    # Convert to numbers based on display format
    if display_format == 'int':
        values = [converter.binary_to_int(b) for b in all_values]
    elif display_format == 'float':
        values = [converter.binary_to_float(b) for b in all_values]
    else:  # binary
        values = all_values
    
    # Determine display dimensions
    total_elements = len(values)
    if rows and cols:
        # User-specified dimensions
        if rows * cols != total_elements:
            print(f"Warning: {rows}x{cols} ({rows*cols}) doesn't match element count {total_elements}")
            reshape = False
        else:
            matrix = np.array(values).reshape(rows, cols)
            reshape = True
    elif '_row' in file_name:
        # Row-mode: lines = rows, elements per line = cols
        elements_per_line = len(converter.split_binary_strings(lines[0]))
        if total_elements % len(lines) == 0:
            matrix = np.array(values).reshape(len(lines), -1)
            reshape = True
        else:
            reshape = False
    else:
        # Core-mode: unknown original dimensions
        reshape = False
    
    # Display results
    print(f"\nFile: {file_name}")
    print(f"Total elements: {total_elements}")
    print(f"Fixed-point: {converter.total_bits} bits ({converter.fractional_bits} fractional)")
    print(f"Display format: {display_format}")
    
    if reshape:
        print("\nReshaped matrix:")
        if display_format == 'float':
            for row in matrix:
                print(" ".join(f"{val:8.4f}" for val in row))
        elif display_format == 'int':
            for row in matrix:
                print(" ".join(f"{val:6}" for val in row))
        else:  # binary
            # For binary, we need to reconstruct the original lines
            elements_per_line = matrix.shape[1]
            bin_values = np.array(all_values).reshape(matrix.shape)
            for row in bin_values:
                print(" ".join(row))
    else:
        print("\nFlat data (no reshaping):")
        if display_format == 'float':
            print(" ".join(f"{val:8.4f}" for val in values))
        elif display_format == 'int':
            print(" ".join(f"{val:6}" for val in values))
        else:  # binary
            print(" ".join(values))
    
    print(f"\nCleaned file saved to: {cleaned_path}")

def main():
    parser = argparse.ArgumentParser(description='Process .mem files from matrix multiplier')
    parser.add_argument('--dir', type=str, default='exports',
                        help='Directory containing .mem files')
    parser.add_argument('--display', choices=['int', 'float', 'binary'], default='int',
                        help='Display format for .mem file contents')
    parser.add_argument('--total_bits', type=int, default=None,
                        help='Total bits for fixed-point representation (auto-detected if not provided)')
    parser.add_argument('--frac_bits', type=int, default=None,
                        help='Fractional bits for fixed-point representation (default: total_bits//2)')
    parser.add_argument('--signed', action='store_true',
                        help='Use signed fixed-point representation')
    parser.add_argument('--rows', type=int, default=None,
                        help='Number of rows for reshaping')
    parser.add_argument('--cols', type=int, default=None,
                        help='Number of columns for reshaping')
    args = parser.parse_args()
    
    # Create converter with possible auto-detection
    converter = FixedPointConverter(args.total_bits, args.frac_bits, args.signed)
    
    # Process all .mem files in the directory
    for file_name in os.listdir(args.dir):
        if file_name.endswith('.mem') and '_cleaned' not in file_name:
            file_path = os.path.join(args.dir, file_name)
            process_mem_file(
                file_path, 
                converter, 
                args.display, 
                args.dir,
                args.rows,
                args.cols
            )

if __name__ == "__main__":
    main()
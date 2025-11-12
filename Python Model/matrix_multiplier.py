# This is used to produce random matrix multiplication
# Files produced are matrix_*_core.mem, matrix_*_row.mem 
# To clean it, use mem_processor.py
# How to use
# python matrix_multiplier.py --display float --integers --min_val 0 --max_val 100 --cores_a 1 --cores_b 1

import numpy as np
import os
import argparse
from typing import Tuple

class FixedPointConverter:
    """Handles fixed-point number conversion and arithmetic"""
    def __init__(self, total_bits: int, fractional_bits: int, is_signed: bool = True):
        self.total_bits = total_bits
        self.fractional_bits = fractional_bits
        self.integer_bits = total_bits - fractional_bits
        self.is_signed = is_signed
        
        # Calculate value ranges
        if is_signed:
            self.max_val = (1 << (self.integer_bits - 1)) - 1 / (1 << fractional_bits)
            self.min_val = -(1 << (self.integer_bits - 1))
            self.max_int = (1 << (total_bits - 1)) - 1
            self.min_int = -(1 << (total_bits - 1))
        else:
            self.max_val = (1 << self.integer_bits) - 1 / (1 << fractional_bits)
            self.min_val = 0
            self.max_int = (1 << total_bits) - 1
            self.min_int = 0

    def float_to_fixed(self, val: float) -> int:
        """Convert float to fixed-point integer representation"""
        scaled = round(val * (1 << self.fractional_bits))
        clamped = np.clip(scaled, self.min_int, self.max_int)
        
        # Handle two's complement for negative values
        if self.is_signed and clamped < 0:
            return (1 << self.total_bits) + clamped
        return int(clamped)
    
    def fixed_to_float(self, val: int) -> float:
        """Convert fixed-point integer to float"""
        if self.is_signed and val >= (1 << (self.total_bits - 1)):
            val = val - (1 << self.total_bits)
        return val / (1 << self.fractional_bits)
    
    def int_to_binary(self, val: int) -> str:
        """Convert fixed-point integer to binary string"""
        if self.is_signed and val < 0:
            val = (1 << self.total_bits) + val
        return format(val, f'0{self.total_bits}b')

class MatrixProcessor:
    """Handles matrix creation, multiplication, and export"""
    def __init__(self):
        self.matrices = {'A': None, 'B': None, 'C': None}
        self.converters = {'A': None, 'B': None, 'C': None}
        self.cores_a = 1
        self.cores_b = 1
    
    def create_matrix(self, rows: int, cols: int, min_val: float, max_val: float, 
                     converter: FixedPointConverter, integers_only: bool = False) -> np.ndarray:
        """Generate random matrix with fixed-point conversion"""
        if integers_only:
            data = np.random.randint(int(min_val), int(max_val) + 1, (rows, cols))
        else:
            data = np.random.uniform(min_val, max_val, (rows, cols))
        
        # Convert to fixed-point integers
        vec_converter = np.vectorize(converter.float_to_fixed)
        return vec_converter(data)
    
    def multiply_matrices(self, A: np.ndarray, B: np.ndarray, 
                         converter_A: FixedPointConverter, 
                         converter_B: FixedPointConverter,
                         converter_C: FixedPointConverter) -> np.ndarray:
        """Fixed-point matrix multiplication with intermediate conversion"""
        # Convert to float for precise multiplication
        to_float_A = np.vectorize(converter_A.fixed_to_float)
        to_float_B = np.vectorize(converter_B.fixed_to_float)
        
        A_float = to_float_A(A)
        B_float = to_float_B(B)
        C_float = np.matmul(A_float, B_float)
        
        # Convert back to fixed-point
        to_fixed_C = np.vectorize(converter_C.float_to_fixed)
        return to_fixed_C(C_float)
    
    def print_matrix(self, matrix: np.ndarray, converter: FixedPointConverter, 
                    name: str, display_format: str = 'int'):
        """Print matrix in specified format"""
        print(f"\n{name}:")
        for row in matrix:
            line = []
            for val in row:
                int_val = int(val)
                if display_format == 'float':
                    float_val = converter.fixed_to_float(int_val)
                    line.append(f"{float_val:8.4f}")
                else:  # 'int' format
                    line.append(f"{int_val:6}")
            print(" ".join(line))
    
    def export_matrix(self, matrix: np.ndarray, converter: FixedPointConverter, 
                     filename: str, mode: str = 'row', 
                     block_size: int = 2, num_cores: int = 1,
                     matrix_type: str = 'A'):
        """Export matrix in specified format"""
        rows, cols = matrix.shape
        
        if mode == 'row':
            self._export_row_mode(matrix, converter, filename)
        elif mode == 'core':
            if matrix_type == 'A':
                self._export_core_mode_A(matrix, converter, filename, block_size, num_cores)
            elif matrix_type == 'B':
                self._export_core_mode_B(matrix, converter, filename, block_size, num_cores)
            elif matrix_type == 'C':
                self._export_core_mode_C(matrix, converter, filename, block_size)
    
    def _export_row_mode(self, matrix: np.ndarray, 
                        converter: FixedPointConverter, filename: str):
        """Export matrix row by row in binary"""
        with open(filename, 'w') as f:
            for row in matrix:
                bin_row = [converter.int_to_binary(int(x)) for x in row]
                f.write(" ".join(bin_row) + '\n')
    
    def _export_core_mode_A(self, matrix: np.ndarray, 
                          converter: FixedPointConverter, filename: str,
                          block_size: int, num_cores: int):
        """
        Export matrix A in core block format (horizontal access)
        Pattern: Process block rows horizontally, left to right
        """
        rows, cols = matrix.shape
        
        # Validate dimensions
        if rows % (num_cores * block_size) != 0:
            raise ValueError(f"Matrix A: Rows ({rows}) must be divisible by cores×block_size ({num_cores}×{block_size})")
        if cols % block_size != 0:
            raise ValueError(f"Matrix A: Columns ({cols}) must be divisible by block_size ({block_size})")
        
        # Calculate parameters
        total_elements = rows * cols
        elements_per_line = num_cores * (block_size * block_size)
        total_lines = total_elements // elements_per_line
        
        # Group processing
        row_groups = rows // (num_cores * block_size)
        blocks_per_row = cols // block_size
        
        with open(filename, 'w') as f:
            for group_idx in range(row_groups):
                group_start_row = group_idx * num_cores * block_size
                
                for block_col in range(blocks_per_row):
                    col_start = block_col * block_size
                    line = []
                    
                    # Process all cores in this group
                    for core_idx in range(num_cores):
                        row_start = group_start_row + core_idx * block_size
                        
                        # Extract block
                        block = matrix[row_start:row_start+block_size, 
                                      col_start:col_start+block_size]
                        
                        # Flatten block in row-major order
                        for r in range(block_size):
                            for c in range(block_size):
                                line.append(converter.int_to_binary(int(block[r, c])))
                    
                    f.write(" ".join(line) + '\n')
    
    def _export_core_mode_B(self, matrix: np.ndarray, 
                          converter: FixedPointConverter, filename: str,
                          block_size: int, num_cores: int):
        """
        Export matrix B in core block format (vertical access)
        Pattern: Process block columns vertically, top to bottom
        """
        rows, cols = matrix.shape
        
        # Validate dimensions
        if cols % (num_cores * block_size) != 0:
            raise ValueError(f"Matrix B: Columns ({cols}) must be divisible by cores×block_size ({num_cores}×{block_size})")
        if rows % block_size != 0:
            raise ValueError(f"Matrix B: Rows ({rows}) must be divisible by block_size ({block_size})")
        
        # Calculate parameters
        total_elements = rows * cols
        elements_per_line = num_cores * (block_size * block_size)
        total_lines = total_elements // elements_per_line
        
        # Group processing
        col_groups = cols // (num_cores * block_size)
        blocks_per_col = rows // block_size
        
        with open(filename, 'w') as f:
            for group_idx in range(col_groups):
                group_start_col = group_idx * num_cores * block_size
                
                for block_row in range(blocks_per_col):
                    row_start = block_row * block_size
                    line = []
                    
                    # Process all cores in this group
                    for core_idx in range(num_cores):
                        col_start = group_start_col + core_idx * block_size
                        
                        # Extract block
                        block = matrix[row_start:row_start+block_size, 
                                      col_start:col_start+block_size]
                        
                        # Flatten block in column-major order
                        for c in range(block_size):
                            for r in range(block_size):
                                line.append(converter.int_to_binary(int(block[r, c])))
                    
                    f.write(" ".join(line) + '\n')
    
    def _export_core_mode_C(self, matrix: np.ndarray, 
                      converter: FixedPointConverter, filename: str,
                      block_size: int):
        """Export matrix C in core block format using the correct pattern"""
        rows, cols = matrix.shape
        
        # Validate dimensions
        if rows % (self.cores_a * block_size) != 0:
            raise ValueError(f"Matrix C: Rows ({rows}) must be divisible by cores_a×block_size ({self.cores_a}×{block_size})")
        if cols % (self.cores_b * block_size) != 0:
            raise ValueError(f"Matrix C: Columns ({cols}) must be divisible by cores_b×block_size ({self.cores_b}×{block_size})")
        
        # Calculate parameters
        row_groups = rows // (self.cores_a * block_size)
        col_groups = cols // (self.cores_b * block_size)
        
        with open(filename, 'w') as f:
            # Process each combination of row group and column group
            for row_group in range(row_groups):
                row_start = row_group * self.cores_a * block_size
                
                for col_group in range(col_groups):
                    col_start = col_group * self.cores_b * block_size
                    line = []
                    
                    # For each column subgroup within the column group
                    for col_subgroup in range(self.cores_b):
                        col_sub_start = col_start + col_subgroup * block_size
                        
                        # For each row subgroup within the row group  
                        for row_subgroup in range(self.cores_a):
                            row_sub_start = row_start + row_subgroup * block_size
                            
                            # Extract the 2x2 block
                            block = matrix[row_sub_start:row_sub_start+block_size,
                                        col_sub_start:col_sub_start+block_size]
                            
                            # Flatten in row-major order
                            for r in range(block_size):
                                for c in range(block_size):
                                    line.append(converter.int_to_binary(int(block[r, c])))
                    
                    f.write(" ".join(line) + '\n')

def main():
    # How to use
    # python matrix_multiplier.py --display float --integers --min_val 0 --max_val 100 --block_size 4 --cores_a 1 --cores_b 1
    
    # Parse command-line arguments
    parser = argparse.ArgumentParser(description='Fixed-Point Matrix Multiplier')
    parser.add_argument('--display', choices=['int', 'float'], default='int',
                        help='Display format for matrices (int or float)')
    parser.add_argument('--min_val', type=float, default=0.0,
                        help='Minimum value for matrix elements')
    parser.add_argument('--max_val', type=float, default=2.0,
                        help='Maximum value for matrix elements')
    parser.add_argument('--integers', action='store_true',
                        help='Use integer-only values')
    parser.add_argument('--block_size', type=int, default=2,
                        help='Block size for core-mode export')
    parser.add_argument('--cores_a', type=int, default=2,
                        help='Number of cores for matrix A')
    parser.add_argument('--cores_b', type=int, default=2,
                        help='Number of cores for matrix B')
    args = parser.parse_args()
    
    # Matrix dimensions
    ROWS_A, COLS_A = 8, 6
    COLS_B = 8
    
    # Fixed-point configurations (total_bits, fractional_bits, signed)
    fp_config_A = (16, 8, True)   
    fp_config_B = (16, 8, True)   
    fp_config_C = (16, 8, True)  
    
    processor = MatrixProcessor()
    processor.cores_a = args.cores_a
    processor.cores_b = args.cores_b
    
    # Create converters
    conv_A = FixedPointConverter(*fp_config_A)
    conv_B = FixedPointConverter(*fp_config_B)
    conv_C = FixedPointConverter(*fp_config_C)
    
    # Create matrices
    A = processor.create_matrix(ROWS_A, COLS_A, args.min_val, args.max_val, conv_A, args.integers)
    B = processor.create_matrix(COLS_A, COLS_B, args.min_val, args.max_val, conv_B, args.integers)
    
    # Perform multiplication
    C = processor.multiply_matrices(A, B, conv_A, conv_B, conv_C)
    
    # Print matrices with specified format
    processor.print_matrix(A, conv_A, "Matrix A", args.display)
    processor.print_matrix(B, conv_B, "Matrix B", args.display)
    processor.print_matrix(C, conv_C, "Matrix C (A x B)", args.display)
    
    # Export matrices
    os.makedirs("exports", exist_ok=True)
    
    # Export in row mode
    processor.export_matrix(A, conv_A, "exports/matrix_A_row.mem", 'row')
    processor.export_matrix(B, conv_B, "exports/matrix_B_row.mem", 'row')
    processor.export_matrix(C, conv_C, "exports/matrix_C_row.mem", 'row')
    
    # Export in core mode
    processor.export_matrix(A, conv_A, "exports/matrix_A_core.mem", 'core', 
                           args.block_size, args.cores_a, 'A')
    processor.export_matrix(B, conv_B, "exports/matrix_B_core.mem", 'core', 
                           args.block_size, args.cores_b, 'B')
    # For matrix C, use special handling with custom block size
    processor.export_matrix(C, conv_C, "exports/matrix_C_core.mem", 'core', 
                           args.block_size, 0, 'C')
    
    print("\nExports saved to 'exports' directory")

if __name__ == "__main__":
    main()
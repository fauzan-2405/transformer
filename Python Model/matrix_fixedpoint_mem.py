import numpy as np
import os
import random
from typing import Tuple, List, Union

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
    
    def fixed_to_readable(self, val: int) -> str:
        """Convert fixed-point to human-readable format"""
        float_val = self.fixed_to_float(val)
        return f"{int(val)} ({float_val:.4f})"

class MatrixProcessor:
    """Handles matrix creation, multiplication, and export"""
    def __init__(self):
        self.matrices = {'A': None, 'B': None, 'C': None}
        self.converters = {'A': None, 'B': None, 'C': None}
    
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
    
    def print_matrix(self, matrix: np.ndarray, name: str):
        """Print matrix in integer/float format"""
        print(f"\n{name}:")
        for row in matrix:
            print(" ".join([f"{int(x):4}" for x in row]))
    
    def export_matrix(self, matrix: np.ndarray, converter: FixedPointConverter, 
                     filename: str, mode: str = 'row', 
                     block_size: int = 2, num_cores: int = 1):
        """Export matrix in specified format"""
        rows, cols = matrix.shape
        
        if mode == 'row':
            self._export_row_mode(matrix, converter, filename)
        elif mode == 'core':
            self._export_core_mode_A(matrix, converter, filename, block_size, num_cores)
    
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
        """Export matrix A in core block format with correct pattern"""
        rows, cols = matrix.shape
        
        # Validate dimensions
        if rows % (num_cores * block_size) != 0:
            raise ValueError(f"Rows ({rows}) must be divisible by cores×block_size ({num_cores}×{block_size})")
        if cols % block_size != 0:
            raise ValueError(f"Columns ({cols}) must be divisible by block_size ({block_size})")
        
        # Calculate parameters
        total_elements = rows * cols
        block_area = block_size * block_size
        elements_per_line = num_cores * block_area
        total_lines = total_elements // elements_per_line
        
        # Group processing
        row_groups = rows // (num_cores * block_size)
        blocks_per_group = cols // block_size
        
        with open(filename, 'w') as f:
            for group_idx in range(row_groups):
                group_start = group_idx * num_cores * block_size
                
                for block_col in range(blocks_per_group):
                    col_start = block_col * block_size
                    line = []
                    
                    # Process all cores in this group
                    for core_idx in range(num_cores):
                        row_start = group_start + core_idx * block_size
                        
                        # Extract block
                        block = matrix[row_start:row_start+block_size, 
                                      col_start:col_start+block_size]
                        
                        # Flatten block in row-major order
                        for r in range(block_size):
                            for c in range(block_size):
                                line.append(converter.int_to_binary(int(block[r, c])))
                    
                    f.write(" ".join(line) + '\n')

def main():
    # Example configuration - adjust as needed
    ROWS_A, COLS_A = 12, 6
    COLS_B = 8
    MIN_VAL, MAX_VAL = 0, 2
    BLOCK_SIZE = 2
    NUM_CORES_A = 3
    NUM_CORES_B = 1
    INTEGER_ONLY = False
    
    # Fixed-point configurations (total_bits, fractional_bits, signed)
    fp_config_A = (8, 4, True)   # Q7.8 format
    fp_config_B = (8, 4, True)   # Q7.8 format
    fp_config_C = (16, 8, True)  # Q15.16 format
    
    processor = MatrixProcessor()
    
    # Create converters
    conv_A = FixedPointConverter(*fp_config_A)
    conv_B = FixedPointConverter(*fp_config_B)
    conv_C = FixedPointConverter(*fp_config_C)
    
    # Create matrices
    A = processor.create_matrix(ROWS_A, COLS_A, MIN_VAL, MAX_VAL, conv_A, INTEGER_ONLY)
    B = processor.create_matrix(COLS_A, COLS_B, MIN_VAL, MAX_VAL, conv_B, INTEGER_ONLY)
    
    # Perform multiplication
    C = processor.multiply_matrices(A, B, conv_A, conv_B, conv_C)
    
    # Print matrices (in integer format)
    processor.print_matrix(A, "Matrix A")
    processor.print_matrix(B, "Matrix B")
    processor.print_matrix(C, "Matrix C (A x B)")
    
    # Export matrices
    os.makedirs("exports", exist_ok=True)
    
    # Export in row mode
    processor.export_matrix(A, conv_A, "exports/matrix_A_row.mem", 'row')
    processor.export_matrix(B, conv_B, "exports/matrix_B_row.mem", 'row')
    processor.export_matrix(C, conv_C, "exports/matrix_C_row.mem", 'row')
    
    # Export in core mode
    processor.export_matrix(A, conv_A, "exports/matrix_A_core.mem", 'core', BLOCK_SIZE, NUM_CORES_A)
    processor.export_matrix(B, conv_B, "exports/matrix_B_core.mem", 'core', BLOCK_SIZE, NUM_CORES_B)
    
    print("\nExports saved to 'exports' directory")

if __name__ == "__main__":
    main()
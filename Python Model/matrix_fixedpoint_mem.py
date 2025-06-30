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
        """Convert fixed-point integer to binary string with proper grouping"""
        if self.is_signed and val < 0:
            val = (1 << self.total_bits) + val
        
        # Format as binary with leading zeros
        binary_str = format(val, f'0{self.total_bits}b')
        
        # Add space between integer and fractional parts if needed
        if self.fractional_bits > 0:
            int_part = binary_str[:-self.fractional_bits]
            frac_part = binary_str[-self.fractional_bits:]
            return f"{int_part} {frac_part}"
        return binary_str
    
    def fixed_to_readable(self, val: int) -> str:
        """Convert fixed-point to human-readable format (Q notation)"""
        float_val = self.fixed_to_float(val)
        binary = self.int_to_binary(val)
        return f"{binary} = {float_val:.4f}"

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
    
    def print_matrix(self, matrix: np.ndarray, converter: FixedPointConverter, name: str):
        """Print matrix with fixed-point representation"""
        print(f"\n{name} (Fixed-Point Q{converter.integer_bits}.{converter.fractional_bits}):")
        for row in matrix:
            for val in row:
                print(converter.fixed_to_readable(int(val)), end=" | ")
            print()
    
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
                self._export_core_mode_C(matrix, converter, filename, block_size, num_cores)
            else:
                raise ValueError(f"Unsupported matrix type for core mode: {matrix_type}")
    
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
        """Export matrix A in core block format (matrix A algorithm)"""
        rows, cols = matrix.shape
        
        # Validate dimensions
        if rows % (num_cores * block_size) != 0:
            raise ValueError("For matrix A core mode: rows must be divisible by num_cores * block_size")
        if cols % block_size != 0:
            raise ValueError("For matrix A core mode: columns must be divisible by block_size")
        
        total_block_rows = rows // block_size
        total_block_cols = cols // block_size
        blocks_per_core = total_block_cols
        cores_per_group = num_cores
        groups = total_block_rows // num_cores
        
        with open(filename, 'w') as f:
            # Process in groups (each group has num_cores block-rows)
            for group in range(groups):
                # For each block column
                for block_col in range(total_block_cols):
                    line = []
                    # For each core in the group
                    for core in range(num_cores):
                        # Calculate absolute block row index
                        block_row = group * num_cores + core
                        # Calculate starting position in matrix
                        start_row = block_row * block_size
                        start_col = block_col * block_size
                        
                        # Extract block
                        block = matrix[start_row:start_row+block_size, 
                                      start_col:start_col+block_size]
                        
                        # Flatten block in row-major order
                        for r in range(block_size):
                            for c in range(block_size):
                                line.append(converter.int_to_binary(int(block[r, c])))
                    
                    # Write line with all blocks
                    f.write(" ".join(line) + '\n')
    
    def _export_core_mode_B(self, matrix: np.ndarray, 
                          converter: FixedPointConverter, filename: str,
                          block_size: int, num_cores: int):
        """Export matrix B in core block format (matrix B algorithm)"""
        rows, cols = matrix.shape
        
        # Validate dimensions
        if rows % (num_cores * block_size) != 0:
            raise ValueError("For matrix B core mode: rows must be divisible by num_cores * block_size")
        
        # Calculate parameters
        blocks_per_core = rows // (num_cores * block_size)
        elements_per_line = block_size * cols * num_cores
        
        with open(filename, 'w') as f:
            # Process each block position
            for block_idx in range(blocks_per_core):
                line = []
                # For each core
                for core in range(num_cores):
                    # Calculate starting row for this core's block
                    start_row = (core * blocks_per_core + block_idx) * block_size
                    # Extract block (block_size x cols)
                    block = matrix[start_row:start_row+block_size, :]
                    
                    # Flatten block in row-major order
                    for r in range(block_size):
                        for c in range(cols):
                            line.append(converter.int_to_binary(int(block[r, c])))
                
                # Write line with all blocks
                f.write(" ".join(line) + '\n')
    
    def _export_core_mode_C(self, matrix: np.ndarray, 
                          converter: FixedPointConverter, filename: str,
                          block_size: int, num_cores: int):
        """Export matrix C in core block format (matrix C algorithm)"""
        # Implementation for matrix C would be similar to A but with different core organization
        # For now, use matrix A's algorithm as placeholder
        self._export_core_mode_A(matrix, converter, filename, block_size, num_cores)

def main():
    # Example configuration - adjust as needed
    ROWS_A, COLS_A = 12, 6
    COLS_B = 8
    MIN_VAL, MAX_VAL = 0, 2.0
    BLOCK_SIZE = 2
    NUM_CORES_A = 2
    NUM_CORES_B = 2  # Changed to 2 to match example
    INTEGER_ONLY = False
    
    # Fixed-point configurations (total_bits, fractional_bits, signed)
    fp_config_A = (8, 4, True)  # total,fracs
    fp_config_B = (8, 4, True)  
    fp_config_C = (16, 8, True)  
    
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
    
    # Print matrices with fixed-point representation
    processor.print_matrix(A, conv_A, "Matrix A")
    processor.print_matrix(B, conv_B, "Matrix B")
    processor.print_matrix(C, conv_C, "Matrix C (A x B)")
    
    # Export matrices
    os.makedirs("exports", exist_ok=True)
    
    # Export in row mode
    processor.export_matrix(A, conv_A, "exports/matrix_A_row.mem", 'row')
    processor.export_matrix(B, conv_B, "exports/matrix_B_row.mem", 'row')
    processor.export_matrix(C, conv_C, "exports/matrix_C_row.mem", 'row')
    
    # Export in core mode with different algorithms for each matrix
    processor.export_matrix(A, conv_A, "exports/matrix_A_core.mem", 'core', 
                           BLOCK_SIZE, NUM_CORES_A, 'A')
    processor.export_matrix(B, conv_B, "exports/matrix_B_core.mem", 'core', 
                           BLOCK_SIZE, NUM_CORES_B, 'B')
    # For matrix C, num_cores = NUM_CORES_A * NUM_CORES_B
    processor.export_matrix(C, conv_C, "exports/matrix_C_core.mem", 'core', 
                           BLOCK_SIZE, NUM_CORES_A * NUM_CORES_B, 'C')
    
    print("\nExports saved to 'exports' directory")

if __name__ == "__main__":
    main()
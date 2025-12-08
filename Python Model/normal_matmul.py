import numpy as np

def load_matrix(filename):
    """Load a space-separated matrix from a text file."""
    with open(filename, 'r') as f:
        lines = f.readlines()
    matrix = [list(map(float, line.split())) for line in lines if line.strip()]
    return np.array(matrix)

def main():
    # Load matrices
    A = load_matrix(r"d:/DATA\Documents\Xirka Internship\PME\Transformer\transformer\Python Model\A.txt")
    B = load_matrix(r"d:/DATA\Documents\Xirka Internship\PME\Transformer\transformer\Python Model\B.txt")

    # Check dimension compatibility
    if A.shape[1] != B.shape[0]:
        raise ValueError(f"Incompatible dimensions: A is {A.shape}, B is {B.shape}")

    # Multiply
    result = A @ B

    # Print result nicely
    print("Result of A × B:\n")
    for row in result:
        print(" ".join(f"{x:g}" for x in row))

if __name__ == "__main__":
    main()

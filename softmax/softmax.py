import numpy as np

def softmax(x):
    """Compute softmax values for each set of scores in x."""
    e_x = np.exp(x - np.max(x))  # subtract max for numerical stability
    return e_x / e_x.sum(axis=0)

def main():
    # Ask user for input
    user_input = input("Enter numbers separated by spaces: ")
    
    # Convert input string to list of floats
    values = np.array([float(num) for num in user_input.split()])
    
    # Compute softmax
    result = softmax(values)
    
    print("Softmax values:", result)

if __name__ == "__main__":
    main()

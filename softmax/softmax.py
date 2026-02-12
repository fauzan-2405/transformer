import numpy as np

def softmax(x):
    """Compute softmax values for each set of scores in x."""
    e_x = np.exp(x - np.max(x))  # subtract max for numerical stability
    return e_x / e_x.sum(axis=0)

def main():
    # Ask user for input
    user_input = input("Enter numbers separated by spaces: ")

    try:
        values = np.array([float(num) for num in user_input.split()])
    except ValueError:
        print("Error: Please enter valid numbers.")
        return

    # Ask user if they want to divide by 16
    divide_option = input("Divide all numbers by 16? (y/n): ").lower()

    if divide_option == 'y':
        values = values / 16
        print("After dividing by 16:", values)

    # Compute softmax
    result = softmax(values)

    print("Softmax values:", result)

if __name__ == "__main__":
    main()

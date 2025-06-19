import numpy as np

def softmax(x):
    """Compute the real softmax using numpy."""
    e_x = np.exp(x - np.max(x))  # numerical stability
    return e_x / np.sum(e_x)

def softmax_approx(x, order=1):
    """Approximate softmax using Taylor expansions."""
    x = np.clip(x, -8.0, 8.0)

    if order == 1:
        exp_approx = 1 + x
    elif order == 2:
        exp_approx = 1 + x + 0.5 * x**2
    else:
        raise ValueError("Only first- and second-order supported.")

    exp_approx = np.clip(exp_approx, 0, None)  # prevent negatives
    return exp_approx / np.sum(exp_approx)

def main():
    np.random.seed(0)
    input_vec = np.random.uniform(-10, 10, size=10)
    input_clipped = np.clip(input_vec, -8.0, 8.0)

    real = softmax(input_clipped)
    approx1 = softmax_approx(input_clipped, order=1)
    approx2 = softmax_approx(input_clipped, order=2)

    print("Input (clipped):")
    print(input_clipped)
    print("\nReal Softmax:")
    print(np.round(real, 5))
    print("\nFirst-Order Approx:")
    print(np.round(approx1, 5))
    print("\nSecond-Order Approx:")
    print(np.round(approx2, 5))

    error1 = np.sum(np.abs(real - approx1))
    error2 = np.sum(np.abs(real - approx2))

    print(f"\nTotal Error (First-Order): {error1:.6f}")
    print(f"Total Error (Second-Order): {error2:.6f}")

if __name__ == "__main__":
    main()

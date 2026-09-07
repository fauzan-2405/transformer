"""
Generate a PRBS7 (127-bit maximal-length sequence) NRZ bit pattern
and export it as an LTspice-compatible PWL stimulus file.

Polynomial: x^7 + x^6 + 1  (standard PRBS7, ITU-T O.150)

Usage:
    python generate_prbs_pwl.py

Output:
    prbs7_100ns.pwl  -- load this into LTspice's voltage source
                        "PWL FILE" option in place of PULSE_GEN.
"""

BIT_PERIOD_NS = 100      # matches your 10 Mbps target
V_LOW = 0.0               # logic 0 level (V)
V_HIGH = 5.0               # logic 1 level (V) -- match your gate drive rail
EDGE_NS = 1                # fast idealized edge; the BSS123/driver model
                            # will add its own realistic delay/slew on top
N_REPEATS = 1               # set >1 to repeat the 127-bit sequence

def generate_prbs7():
    """Generate one period (127 bits) of PRBS7 using an LFSR."""
    reg = 0b1111111  # any nonzero 7-bit seed
    bits = []
    for _ in range(127):
        bits.append(reg & 1)
        feedback = ((reg >> 0) ^ (reg >> 6)) & 1  # taps: bit0 xor bit6
        reg = (reg >> 1) | (feedback << 6)
    return bits

def write_pwl(bits, filename):
    t_ns = 0
    lines = []
    lines.append(f"0 {V_LOW if bits[0]==0 else V_HIGH}")
    for i, b in enumerate(bits):
        v = V_HIGH if b else V_LOW
        # rising/falling edge starts EDGE_NS before the bit boundary ends,
        # holds flat for the rest of the bit period
        edge_start = t_ns
        edge_end = t_ns + EDGE_NS
        lines.append(f"{edge_start}n {V_HIGH if (i>0 and bits[i-1]) else V_LOW}")
        lines.append(f"{edge_end}n {v}")
        t_ns += BIT_PERIOD_NS
    with open(filename, "w") as f:
        f.write("\n".join(lines) + "\n")

if __name__ == "__main__":
    seq = generate_prbs7() * N_REPEATS
    write_pwl(seq, "/mnt/user-data/outputs/prbs7_100ns.pwl")
    print(f"Generated {len(seq)} bits -> prbs7_100ns.pwl")
    print(f"Total duration: {len(seq)*BIT_PERIOD_NS} ns = {len(seq)*BIT_PERIOD_NS/1000:.2f} us")
    print("First 20 bits:", seq[:20])
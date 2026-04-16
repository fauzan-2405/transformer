import argparse

"""
python softmax.py --input data.txt --input_format float --output_format hex
"""
# ==============================
# Fixed-point configuration
# ==============================
WIDTH = 32
FRAC = 16
MASK32 = 0xFFFFFFFF

def to_signed32(x):
    x &= MASK32
    return x if x < (1 << 31) else x - (1 << 32)

def wrap32(x):
    return to_signed32(x)

# ==============================
# Conversion
# ==============================
def float_to_q16(x):
    return wrap32(int(round(x * (1 << FRAC))))

def q16_to_float(x):
    return float(to_signed32(x)) / (1 << FRAC)

def hex_to_q16(h):
    return to_signed32(int(h, 16))

def q16_to_hex(x):
    return f"{(x & MASK32):08X}"

# ==============================
# EXP LUTs (from your RTL)
# ==============================
lutA = [
0x0001228C,0x00017512,0x0001DF09,0x00026717,0x000315CB,0x0003F61D,0x00051626,0x000687FE,
0x000862E1,0x000AC4A6,0x000DD39B,0x0011C0F2,0x0016CBD3,0x001D4559,0x002595A6,0x00304271,
0x003DF76B,0x004F9108,0x00662A5A,0x00832EDB,0x00A8713D,0x00D848C4,0x0115B6E7,0x016497AA,
0x01C9DFAE,0x024BEBEA,0x02F2E7FC,0x03C95199,0x04DCA141,0x063E22EC,0x08040C3B,0x0A4AE1AA,
0x0000E248,0x0000B03A,0x0000893F,0x00006AE3,0x0000533E,0x000040D5,0x0000327D,0x00002752,
0x00001EA0,0x000017DA,0x00001293,0x00000E77,0x00000B44,0x000008C6,0x000006D5,0x00000552,
0x00000425,0x0000033A,0x00000284,0x000001F5,0x00000186,0x00000130,0x000000ED,0x000000B8,
0x00000090,0x00000070,0x00000057,0x00000044,0x00000035,0x00000029,0x00000020,0x00000019
]

lutC = [
0x0000FE8A,0x0000E991,0x0000B426,0x00004D8A,0xFFFF9E1D,0xFFFE84C9,0xFFFCD38A,0xFFFA4AC9,
0xFFF6930A,0xFFF13489,0xFFE98BE6,0xFFDEBB0E,0xFFCF9512,0xFFBA8343,0xFF9D6165,0xFF754E1B,
0xFF3E6BAD,0xFEF38C29,0xFE8DC242,0xFE03CE1E,0xFD495AB4,0xFC4DFC79,0xFAFBDD9B,0xF935FDA1,
0xF6D5E22D,0xF3A88BE1,0xEF6A7469,0xE9C24843,0xE239F6D9,0xD8359409,0xCAE75D17,0xB93FFD33,
0x0000FECE,0x0000F280,0x0000DF2B,0x0000C887,0x0000B0FB,0x00009A0A,0x00008497,0x00007117,
0x00005FBB,0x00005085,0x0000435A,0x00003812,0x00002E7C,0x00002665,0x00001F9C,0x000019F3,
0x0000153F,0x0000115A,0x00000E24,0x00000B81,0x00000957,0x00000792,0x00000621,0x000004F4,
0x000003FF,0x00000339,0x00000298,0x00000216,0x000001AD,0x00000159,0x00000114,0x000000DD
]

# ==============================
# EXP function (RTL equivalent)
# ==============================
def exp_q16(x):
    x = to_signed32(x)

    absX = -x if x < 0 else x
    Ytemp = (absX << 2) & MASK32

    if (Ytemp >> 21) != 0:
        base_idx = 31
    else:
        base_idx = (Ytemp >> 16) & 0x1F

    idx = base_idx + 32 if x < 0 else base_idx

    A = to_signed32(lutA[idx])
    C = to_signed32(lutC[idx])

    prod = (x * A) >> FRAC
    prod = to_signed32(prod)

    return to_signed32(prod + C)

# ==============================
# LNU (your PWL ln)
# ==============================
a_lut = [
0x0000E480,0x0000BAB3,0x00009DDA,0x000088BC,0x0000789C,0x00006BE4,0x00006199,0x0000591A,
0x000051F7,0x00004BE3,0x000046A6,0x00004216,0x00003E14,0x00003A88,0x0000375D,0x00003486,
0x000031F6,0x00002FA3,0x00002D85,0x00002B95,0x000029CD,0x00002829,0x000026A5,0x0000253E,
0x000023EF,0x000022B7,0x00002194,0x00002083
]

b_lut = [
0xFFFF1B80,0xFFFF4FC1,0xFFFF7B06,0xFFFF9FF9,0xFFFFC03A,0xFFFFDCD9,0xFFFFF694,0x00000DF2,
0x0000235B,0x0000371B,0x00004970,0x00005A8B,0x00006A93,0x000079A8,0x000087E7,0x00009565,
0x0000A236,0x0000AE6A,0x0000BA10,0x0000C534,0x0000CFE1,0x0000DA21,0x0000E3FB,0x0000ED78,
0x0000F69E,0x0000FF74,0x000107FD,0x00011040
]

def lnu_q16(x):
    if x < 0x00010000:
        idx = 0
    elif x >= 0x00080000:
        idx = 27
    else:
        Ytemp = (x - 0x00010000) << 2
        idx = (Ytemp >> 16) & 0x1F

    a = to_signed32(a_lut[idx])
    b = to_signed32(b_lut[idx])

    mult = (a * x) >> 16
    return to_signed32(mult + b)

# ==============================
# Softmax (row-wise)
# ==============================
def softmax_row_q16(row):
    # PASS 0: max
    max_val = max(row)

    # PASS 1: exp + sum
    exp_vals = [exp_q16(x - max_val) for x in row]
    sum_exp = sum(exp_vals)

    # LN
    ln_sum = lnu_q16(sum_exp)

    # PASS 2: final
    out = [exp_q16(x - max_val - ln_sum) for x in row]

    return out

# ==============================
# File IO
# ==============================
def read_matrix(file, fmt):
    mat = []
    with open(file) as f:
        for line in f:
            vals = line.strip().split()
            if not vals:
                continue
            if fmt == "float":
                mat.append([float_to_q16(float(v)) for v in vals])
            else:
                mat.append([hex_to_q16(v) for v in vals])
    return mat

def write_matrix(mat, fmt):
    for row in mat:
        if fmt == "hex":
            print(" ".join(q16_to_hex(v) for v in row))
        else:
            print(" ".join(f"{q16_to_float(v):.6f}" for v in row))

# ==============================
# MAIN
# ==============================
if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--input_format", default="hex", choices=["hex","float"])
    parser.add_argument("--output_format", default="hex", choices=["hex","float"])
    args = parser.parse_args()

    mat = read_matrix(args.input, args.input_format)
    out = [softmax_row_q16(row) for row in mat]

    write_matrix(out, args.output_format)
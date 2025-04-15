def concatenate_lines(mem_file, output_file, group_size):
    # Read the memory file
    with open(mem_file, 'r') as file:
        lines = file.readlines()

    # Clean lines and remove line numbers if present
    clean_lines = []
    for line in lines:
        parts = line.strip().split()
        if len(parts) > 1:
            clean_lines.append(parts[1])
        else:
            clean_lines.append(parts[0])

    # Check if number of lines is divisible by group size
    if len(clean_lines) % group_size != 0:
        raise ValueError(f"Number of lines ({len(clean_lines)}) is not divisible by group size ({group_size}).")

    # Group and concatenate with reverse order
    concatenated_lines = []
    for i in range(0, len(clean_lines), group_size):
        group = clean_lines[i:i + group_size]
        reversed_group = reversed(group)
        concatenated = ''.join(reversed_group)
        concatenated_lines.append(concatenated)

    # Write result to output file
    with open(output_file, 'w') as file:
        for line in concatenated_lines:
            file.write(line + '\n')

    print(f"Done! Output written to {output_file}")

# === Example usage ===
mem_file = 'A.mem'
output_file = 'A_rev.mem'
group_size = 2  # ← You can set this to any grouping size

concatenate_lines(mem_file, output_file, group_size)

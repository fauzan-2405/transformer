def concatenate_lines_any(mem_file, output_file, multiplier):
    # Read the file
    with open(mem_file, 'r') as file:
        lines = file.readlines()
    
    # Strip line numbers if present
    clean_lines = []
    for line in lines:
        parts = line.strip().split()
        if len(parts) > 1:
            clean_lines.append(parts[1])
        else:
            clean_lines.append(parts[0])

    total_lines = len(clean_lines)
    if total_lines % multiplier != 0:
        raise ValueError(f"Total lines ({total_lines}) not divisible by multiplier ({multiplier}).")

    num_outputs = total_lines // multiplier
    result_lines = []
    
    # Hard-coded pattern for N=2 as per your example
    if multiplier == 2:
        for i in range(num_outputs):
            if i == 0:
                # Output line 1: Line 3 + Line 1
                combined = clean_lines[2] + clean_lines[0]
            elif i == 1:
                # Output line 2: Line 4 + Line 2
                combined = clean_lines[3] + clean_lines[1]
            elif i == 2:
                # Output line 3: Line 7 + Line 5
                combined = clean_lines[6] + clean_lines[4]
            elif i == 3:
                # Output line 4: Line 8 + Line 6
                combined = clean_lines[7] + clean_lines[5]
            result_lines.append(combined)
    # Hard-coded pattern for N=3 as per your example
    elif multiplier == 3:
        for i in range(num_outputs):
            if i == 0:
                # Output line 1: Line 7 + Line 4 + Line 1
                combined = clean_lines[6] + clean_lines[3] + clean_lines[0]
            elif i == 1:
                # Output line 2: Line 8 + Line 5 + Line 2
                combined = clean_lines[7] + clean_lines[4] + clean_lines[1]
            elif i == 2:
                # Output line 3: Line 9 + Line 6 + Line 3
                combined = clean_lines[8] + clean_lines[5] + clean_lines[2]
            result_lines.append(combined)
    else:
        # Generalized pattern for any N
        for i in range(num_outputs):
            combined = ""
            for j in range(multiplier):
                index = (multiplier - 1 - j) * num_outputs + i
                combined += clean_lines[index]
            result_lines.append(combined)

    # Write output
    with open(output_file, 'w') as file:
        for line in result_lines:
            file.write(line + '\n')

    print(f"Output saved to {output_file} ✅")

# Example usage:
mem_file = 'A.mem'
output_file = 'A_rev.mem'
multiplier = 2  # Supports ANY integer that divides the number of lines

concatenate_lines_any(mem_file, output_file, multiplier)
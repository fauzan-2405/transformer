def concatenate_lines(mem_file, output_file, group_size):
    # Read the memory file
    with open(mem_file, 'r') as file:
        lines = file.readlines()

    # Clean up the lines (strip out newlines and remove line numbers if they exist)
    clean_lines = []
    for line in lines:
        # Remove line numbers and dots if present
        parts = line.strip().split()
        if len(parts) > 1:
            clean_lines.append(parts[1])
        else:
            clean_lines.append(parts[0])

    # Check if the file has the correct number of lines
    if len(clean_lines) % group_size != 0:
        raise ValueError(f"The number of lines ({len(clean_lines)}) is not a multiple of the group size ({group_size}).")

    # Prepare a list to store the concatenated lines
    concatenated_lines = []

    # Process the lines in chunks of 'group_size'
    for i in range(0, len(clean_lines), group_size):
        # Concatenate the lines in the current group
        concatenated = ''.join(clean_lines[i:i + group_size])
        concatenated_lines.append(concatenated)

    # Write the concatenated lines to the output file
    with open(output_file, 'w') as file:
        for line in concatenated_lines:
            file.write(line + '\n')

    print(f"Concatenated lines have been written to {output_file}")

# Example usage
mem_file = 'A.mem'
output_file = 'A_rev.mem'
group_size = 4  # You can change this to any integer

concatenate_lines(mem_file, output_file, group_size)

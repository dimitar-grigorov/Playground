import sys
import re
import argparse

def main(input_file, output_file=None):
    """
    Removes lines starting with // or /// (with optional leading spaces or tabs),
    lines containing non-printable characters, and empty lines from the input file.
    Writes the cleaned content to the output file. If the output file is not specified,
    the script generates the output file name by appending '-stripped' to the 
    input file name.
    
    Arguments:
    input_file -- the path to the input file
    output_file -- the path to the output file (optional)
    """
    
    # If output_file is not specified, generate it by adding '-stripped' to the input file name
    if output_file is None:
        output_file = re.sub(r'(\.\w+)$', r'-stripped\1', input_file)

    with open(input_file, 'r', encoding='utf-8') as infile:
        lines = infile.readlines()
    
    cleaned_lines = []
    
    for line in lines:
        trimmed_line = line.lstrip()
        
        # Skip lines that start with // or ///
        if re.match(r'^(//|///)', trimmed_line):
            continue
        
        # Skip lines containing non-printable characters
        if not all(32 <= ord(char) <= 126 or char in '\t\n\r' for char in line):
            continue
        
        # Skip empty lines
        if not trimmed_line.strip():
            continue
        
        cleaned_lines.append(line)
    
    with open(output_file, 'w', encoding='utf-8') as outfile:
        outfile.writelines(cleaned_lines)
    
    print(f'Processed {input_file} and saved to {output_file}')

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Strip comments, non-printable lines, and empty lines from a file.")
    parser.add_argument('-i', '--input', required=True, help="The path to the input file")
    parser.add_argument('-o', '--output', help="The path to the output file (optional)")
    
    args = parser.parse_args()
    
    input_file = args.input
    output_file = args.output
    
    main(input_file, output_file)

import base64
import os
import argparse

def convert_to_base64(input_file):
    # Read the content of the input file
    with open(input_file, 'r') as file:
        content = file.read()

    # Encode the content to base64
    base64_content = base64.b64encode(content.encode('utf-8')).decode('utf-8')

    # Create the output file name
    base_name = os.path.splitext(input_file)[0]
    output_file = f"{base_name}_64.txt"

    # Write the base64 content to the output file
    with open(output_file, 'w') as file:
        file.write(base64_content)

    print(f"File {input_file} has been converted to base64 and saved as {output_file}")

def main():
    # Set up argument parser
    parser = argparse.ArgumentParser(description='Convert a text file to base64 format.')
    parser.add_argument('input_file', type=str, help='The path to the input text file')

    # Parse arguments
    args = parser.parse_args()

    # Convert the file to base64
    convert_to_base64(args.input_file)

if __name__ == "__main__":
    main()
# This script converts a text file to base64 format and saves it with a "_64" suffix.
# Usage: python convert_to_base64.py input.txt  
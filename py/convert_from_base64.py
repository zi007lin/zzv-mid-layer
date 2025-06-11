import base64
import os
import argparse

def convert_from_base64(input_file):
    # Read the content of the input file
    with open(input_file, 'r') as file:
        base64_content = file.read()

    # Decode the base64 content
    content = base64.b64decode(base64_content.encode('utf-8')).decode('utf-8')

    # Create the output file name by dropping '_64'
    output_file = input_file.replace('_64.txt', '.txt')

    # Write the decoded content to the output file
    with open(output_file, 'w') as file:
        file.write(content)

    print(f"File {input_file} has been decoded from base64 and saved as {output_file}")

def main():
    # Set up argument parser
    parser = argparse.ArgumentParser(description='Convert a base64 encoded text file back to its original format.')
    parser.add_argument('input_file', type=str, help='The path to the input base64 encoded text file')

    # Parse arguments
    args = parser.parse_args()

    # Convert the file from base64
    convert_from_base64(args.input_file)

if __name__ == "__main__":
    main()  
# This script converts a base64 encoded text file back to its original format and saves it without the "_64" suffix.
# Usage: python convert_from_base64.py input_64.txt

import base64
import sys

def convert_to_base64(input_file):
    with open(input_file, "rb") as file:
        encoded_string = base64.b64encode(file.read()).decode('utf-8')

    output_file = input_file + ".64.txt"
    with open(output_file, "w") as file:
        file.write(encoded_string)

    print(f"File {input_file} has been converted to Base64 and saved as {output_file}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python convert_to_base64.py <input_file>")
    else:
        convert_to_base64(sys.argv[1])
# This script converts a file to Base64 encoding and saves it with a ".64.txt" suffix.
# Usage: python convert_to_base64.py input.txt
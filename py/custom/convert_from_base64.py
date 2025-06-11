import base64
import sys

def convert_from_base64(input_file):
    with open(input_file, "r") as file:
        encoded_string = file.read()

    output_file = input_file.replace(".64.txt", "")
    with open(output_file, "wb") as file:
        file.write(base64.b64decode(encoded_string))

    print(f"File {input_file} has been converted from Base64 and saved as {output_file}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python convert_from_base64.py <input_file>")
    else:
        convert_from_base64(sys.argv[1])
# This script converts a Base64 encoded file back to its original binary format.
# Usage: python convert_from_base64.py input.64.txt
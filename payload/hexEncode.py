#simple script that takes an executable file and hex encodes it into a C string in a header file for use as a runtime binary payload
#usage: python3 hexEncode.py <executable file> <output file>

import sys
import os
import binascii

#check for correct number of arguments
if len(sys.argv) != 3:
    print("Usage: python3 hexEncode.py <binary file> <output file>")
    sys.exit()

#check if input file exists
if not os.path.isfile(sys.argv[1]):
    print("Input file does not exist")
    sys.exit()

#open input file
input_file = open(sys.argv[1], "rb")

#read input file
input_file_bytes = input_file.read()

#close input file
input_file.close()

#open output file
output_file = open(sys.argv[2], "w")

#write header file preamble
output_file.write("#ifndef PAYLOAD_H\n#define PAYLOAD_H\n\n")

#write header file array declaration
output_file.write("unsigned char payload[] = {\n")

#write data as string of hex values
output_file.write("\"" + binascii.hexlify(input_file_bytes).decode("utf-8") + "\"")

#write header file postamble
output_file.write("\n};\n\n#endif")

#close output file
output_file.close()

#exit
sys.exit()
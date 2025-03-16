import sys
from functools import partial

if len(sys.argv) != 3:
    sys.exit("Usage: %s <file> <symbol>" % sys.argv[0])
filename = sys.argv[1]
symbol = sys.argv[2]

print("const uint8_t " + symbol + "[] = {")
n = 0
with open(filename, "rb") as in_file:
    for c in iter(partial(in_file.read, 1), b""):
        print("0x%02X," % ord(c), end="")
        n += 1
        if n % 16 == 0:
            print()
print("};")

print("const size_t " + symbol + "_len = sizeof(" + symbol + ");")

from PIL import Image
import sys

bytes = Image.open(sys.argv[1]).resize(size=(128, 128)).convert("RGBA").tobytes()
print("extern const unsigned char icon_data[];")
print("const unsigned char icon_data[] = {")
print(", ".join([str(b) for b in bytes]))
print("};")






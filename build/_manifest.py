import sys

for v in sys.argv[1:]:
    first = True
    while v:
        print(("" if first else " ") + v[:70])
        v = v[70:]
        first = False

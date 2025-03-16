#!/usr/bin/python3

from os.path import *
import argparse
import os
from zipfile import ZipFile


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("-z", "--zipfile")
    parser.add_argument("-v", "--verbose", action="store_true")
    parser.add_argument("-f", "--file", nargs=2, action="append")
    args = parser.parse_args()

    assert args.zipfile, "You must specify a zipfile to create"

    with ZipFile(args.zipfile, mode="w") as zf:
        for zipname, filename in args.file:
            if args.verbose:
                print(filename, "->", zipname)
            zf.write(filename, arcname=zipname)


main()

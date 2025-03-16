#!/usr/bin/python3

from os.path import *
import argparse
import os
import shutil


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("-s", "--sandbox")
    parser.add_argument("-v", "--verbose", action="store_true")
    parser.add_argument("-l", "--link", action="store_true")
    parser.add_argument("-e", "--export", action="store_true")
    parser.add_argument("files", nargs="*")
    args = parser.parse_args()

    assert args.sandbox, "You must specify a sandbox directory"
    assert args.link ^ args.export, "You can't link and export at the same time"

    if args.link:
        os.makedirs(args.sandbox, exist_ok=True)
        for f in args.files:
            sf = join(args.sandbox, f)
            if args.verbose:
                print("link", sf)
            os.makedirs(dirname(sf), exist_ok=True)
            try:
                os.link(abspath(f), sf)
            except PermissionError:
                shutil.copy(f, sf)

    if args.export:
        for f in args.files:
            sf = join(args.sandbox, f)
            if args.verbose:
                print("export", sf)
            df = dirname(f)
            if df:
                os.makedirs(df, exist_ok=True)
            os.rename(sf, f)


main()

#!/bin/bash
set -e -o pipefail
echo "extern const unsigned char icon_data[];"
echo "const unsigned char icon_data[] = {"
convert extras/icon.png -resize 128x128 -depth 8 rgba:- | xxd -i
echo "};"

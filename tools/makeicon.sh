#!/bin/sh
echo "const unsigned char icon_data[] = {"
convert extras/icon.png -resize 128x128 -depth 8 rgba:- | xxd -i
echo "};"


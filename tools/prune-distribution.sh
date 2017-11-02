#!/bin/sh

input=$1
output=$2

if [ "$input" = "" -o "$output" = "" ]; then
    echo "Syntax: prune-distribution.sh input.tar.gz output.tar.xz"
    exit 1
fi

zcat $input | tar -v --wildcards \
    --delete "*/c/emu/*" \
    --delete "*.dictionary" \
    | xz -z > $output

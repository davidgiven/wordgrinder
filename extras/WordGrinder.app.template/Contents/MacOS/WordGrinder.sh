#!/bin/sh
dir=`dirname "$0"`
cd "$dir"
export DYLD_FALLBACK_LIBRARY_PATH=../Resources:/opt/local/lib
exec ./wordgrinder "$@"

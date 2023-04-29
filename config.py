import subprocess
import os
import platform

FILEFORMAT = 8
VERSION = "0.9"

if platform.system() == "Windows":
    TEST_BINARY = "src/c+wordgrinder-wincon"
else:
    TEST_BINARY = "src/c+wordgrinder-ncurses"

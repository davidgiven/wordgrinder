import subprocess
import os
import platform
from datetime import date

FILEFORMAT = 8
VERSION = "0.9"
DATE = date.today().strftime("%-d %B %Y")

if platform.system() == "Windows":
    TEST_BINARY = "src/c+wordgrinder-wincon"
else:
    TEST_BINARY = "src/c+wordgrinder-ncurses"

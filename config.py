import subprocess
import os
import platform
from datetime import date

FILEFORMAT = 8
VERSION = "0.9"
DATE = date.today().strftime("%-d %B %Y")
BUILD_TYPE = os.getenv("BUILD_TYPE")

IS_WINDOWS = BUILD_TYPE in {"windows", "wincon-only"}
HAS_XWORDGRINDER = BUILD_TYPE == "unix"
HAS_OSX = BUILD_TYPE == "osx"
HAS_NCURSES = BUILD_TYPE in {"unix", "unix-ncurses-only"}
HAS_GLFW = BUILD_TYPE in {"windows", "unix", "osx"}

if IS_WINDOWS:
    TEST_BINARY = "src/c/+wordgrinder-wincon"
else:
    TEST_BINARY = "src/c/+wordgrinder-ncurses"

import subprocess
import os
import platform
from datetime import date

FILEFORMAT = 8
VERSION = "0.9"
DATE = date.today().strftime("%-d %B %Y")
BUILDTYPE = os.getenv("BUILDTYPE")

IS_WINDOWS = BUILDTYPE in {"windows", "wincon-only"}
HAS_XWORDGRINDER = BUILDTYPE == "unix"
HAS_OSX = BUILDTYPE == "osx"
HAS_NCURSES = BUILDTYPE in {"unix", "osx", "haiku", "unix-ncurses-only"}
HAS_GLFW = BUILDTYPE in {"windows", "unix", "osx", "haiku"}
HAS_HAIKU = BUILDTYPE in {"haiku"}

if IS_WINDOWS:
    TEST_BINARY = "src/c/+wordgrinder-wincon"
else:
    TEST_BINARY = "src/c/+wordgrinder-ncurses"

DEFAULT_DICTIONARY_PATH = "/usr/share/dict/words"

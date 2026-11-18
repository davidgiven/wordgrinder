import platform
from build.ab import G

_is_windows = (platform.system() == "Windows")

class Toolchain:
    PREFIX = ""
    EXE = G.EXT


class HostToolchain(Toolchain):
    PREFIX = "HOST"
    EXE = ".exe" if _is_windows else ""

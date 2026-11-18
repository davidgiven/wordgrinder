import platform

_is_windows = (platform.system() == "Windows")

class Toolchain:
    PREFIX = ""
    EXE = ".exe" if _is_windows else ""


class HostToolchain(Toolchain):
    PREFIX = "HOST"

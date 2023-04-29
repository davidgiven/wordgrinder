from build.ab2 import Rule
import os
import subprocess

_package_present = {}
_package_cflags = {}
_package_ldflags = {}


def has_package(name):
    global _package_present
    if name not in _package_present:
        r = subprocess.run(
            f"$PKG_CONFIG --exists {name}", shell=True, capture_output=True
        )
        _package_present[name] = True if r.returncode == 0 else False
    return _package_present[name]


def get_cflags(name):
    global _package_cflags
    if name not in _package_cflags:
        r = subprocess.run(
            f"$PKG_CONFIG --cflags {name}", shell=True, capture_output=True
        )
        _package_cflags[name] = r.stdout.decode("utf-8").strip()
    return _package_cflags[name]


def get_ldflags(name):
    global _package_ldflags
    if name not in _package_ldflags:
        r = subprocess.run(
            f"$PKG_CONFIG --libs {name}", shell=True, capture_output=True
        )
        _package_ldflags[name] = r.stdout.decode("utf-8").strip()
    return _package_ldflags[name]


@Rule
def package(self, name, package=None):
    if has_package(package):
        self.exportvars = {
            "+cflags": [get_cflags(package)],
            "+cxxflags": [get_cflags(package)],
            "+ldflags": [get_ldflags(package)],
        }

    self.outs = []

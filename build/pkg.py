from build.ab import Rule, emit, Target, filenamesof
from types import SimpleNamespace
import os
import subprocess

emit(
    """
PKG_CONFIG ?= pkg-config
PACKAGES := $(shell $(PKG_CONFIG) --list-all | cut -d' ' -f1 | sort)

HOST_PKG_CONFIG ?= pkg-config
HOST_PACKAGES := $(shell $(HOST_PKG_CONFIG) --list-all | cut -d' ' -f1 | sort)
"""
)


def _package(self, name, package, fallback, prefix=""):
    emit(f"ifeq ($(filter {package}, $({prefix}PACKAGES)),)")
    if fallback:
        emit(f"{prefix}PACKAGE_DEPS_{package} := ", *filenamesof([fallback]))
        emit(
            f"{prefix}PACKAGE_CFLAGS_{package} :=",
            *fallback.args.get("caller_cflags", []),
        )
        emit(
            f"{prefix}PACKAGE_LDFLAGS_{package} := ",
            *fallback.args.get("caller_ldflags", []),
            f"$(filter %.a, $({prefix}PACKAGE_DEPS_{package}))",
        )
    else:
        emit(f"$(error Required package '{package}' not installed.)")
    emit("else")
    emit(
        f"{prefix}PACKAGE_CFLAGS_{package} := $(shell $({prefix}PKG_CONFIG) --cflags {package})"
    )
    emit(
        f"{prefix}PACKAGE_LDFLAGS_{package} := $(shell $({prefix}PKG_CONFIG) --libs {package})"
    )
    emit(f"{prefix}PACKAGE_DEPS_{package} :=")
    emit("endif")
    emit(f"{self.name}:")

    self.args["caller_cflags"] = [f"$({prefix}PACKAGE_CFLAGS_{package})"]
    self.args["caller_ldflags"] = [f"$({prefix}PACKAGE_LDFLAGS_{package})"]
    self.traits.add("clibrary")
    self.traits.add("cheaders")

    self.ins = []
    self.outs = [f"$({prefix}PACKAGE_DEPS_{package})"]


@Rule
def package(self, name, package=None, fallback: Target = None):
    _package(self, name, package, fallback)


@Rule
def hostpackage(self, name, package=None, fallback: Target = None):
    _package(self, name, package, fallback, "HOST_")

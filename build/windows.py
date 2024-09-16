from build.ab import (
    Rule,
    Targets,
    simplerule,
)
from os.path import *


@Rule
def windres(self, name, srcs: Targets, deps: Targets = [], label="WINDRES"):
    simplerule(
        replaces=self,
        ins=srcs,
        deps=deps,
        outs=[f"={self.localname}.o"],
        label=label,
        commands=["$(WINDRES) {ins[0]} {outs[0]}"],
    )


@Rule
def makensis(
    self, name, srcs: Targets, deps: Targets = [], defs={}, label="MAKENSIS"
):
    d = ""
    for k in defs:
        d += f" -d{k}={defs[k]}"

    simplerule(
        replaces=self,
        ins=srcs,
        deps=deps,
        outs=[f"={self.localname}.exe"],
        label=label,
        commands=[
            "$(MAKENSIS) -nocd -v2 " + d + " -dOUTFILE={outs[0]} {ins[0]}"
        ],
    )

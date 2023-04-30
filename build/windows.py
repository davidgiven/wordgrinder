from build.ab2 import (
    Rule,
    Targets,
    normalrule,
)
from os.path import *

@Rule
def windres(self, name, srcs: Targets, deps: Targets=[], label="WINDRES"):
    normalrule(
        replaces=self,
        ins=srcs,
        deps=deps,
        outs=[name+".o"],
        label=label,
        commands=["$(WINDRES) {ins[0]} {outs[0]}"]
    )

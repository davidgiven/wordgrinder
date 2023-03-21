from build.ab2 import normalrule, Rule, Targets
from build.c import cxxprogram


@Rule
def multibin(self, name, symbol, srcs: Targets = []):
    normalrule(
        replaces=self,
        ins=srcs,
        outs=[symbol + ".h"],
        commands=["sh tools/multibin2c.sh " + symbol + " {ins} > {outs}"],
        label="MULTIBIN",
    )


cxxprogram(
    name="typechecker", srcs=["./typechecker.cc"], deps=["third_party/luau"]
)

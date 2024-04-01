from build.ab import normalrule, Rule, Targets
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

normalrule(
    name="icon_cc",
    ins=["extras/icon.png"],
    outs=["icon.cc"],
    commands=["png2ico {out[0]} {ins[0]}"],
    label="MAKEICON",
)

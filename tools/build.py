from build.ab import simplerule, Rule, Targets
from build.c import cxxprogram


@Rule
def multibin(self, name, symbol, srcs: Targets = []):
    simplerule(
        replaces=self,
        ins=srcs,
        outs=[f"={symbol}.h"],
        deps=["tools/multibin2c.sh", "build/_objectify.py"],
        commands=["sh tools/multibin2c.sh " + symbol + " $[ins] > $[outs]"],
        label="MULTIBIN",
    )


cxxprogram(
    name="typechecker", srcs=["./typechecker.cc"], deps=["third_party/luau"]
)

simplerule(
    name="icon_cc",
    ins=["./makeicon.py", "extras/icon.png"],
    outs=["=icon.cc"],
    commands=["python3 $[ins[0]] $[ins[1]] > $[outs[0]]"],
    label="MAKEICON",
)

from build.ab2 import normalrule, Rule, Targets


@Rule
def multibin(self, name, symbol, srcs: Targets = []):
    normalrule(
        replaces=self,
        ins=srcs,
        outs=[symbol + ".h"],
        commands=["sh tools/multibin2c.sh " + symbol + " {ins} > {outs}"],
        label="MULTIBIN",
    )

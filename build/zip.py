from build.ab import (
    Rule,
    simplerule,
    TargetsMap,
    filenameof,
)


@Rule
def zip(
    self, name, flags="", items: TargetsMap = {}, extension="zip", label="ZIP"
):
    cs = ["$(PYTHON) build/_zip.py -z $[outs]"]

    ins = []
    for k, v in items.items():
        cs += [f"-f {k} {filenameof(v)}"]
        ins += [v]

    simplerule(
        replaces=self,
        ins=ins,
        deps=["build/_zip.py"],
        outs=[f"={self.localname}." + extension],
        commands=[" ".join(cs)],
        label=label,
    )

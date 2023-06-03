from build.ab2 import normalrule, Rule, Target
from config import DATE, VERSION


@Rule
def manpage(self, name, outfile, date, version, src: Target):
    normalrule(
        replaces=self,
        ins=[src],
        outs=[outfile],
        commands=[
            "sed 's/@@@DATE@@@/"
            + date
            + "/g; s/@@@VERSION@@@/"
            + version
            + "/g' {ins} > {outs}"
        ],
        label="MANPAGE",
    )


manpage(
    name="xwordgrinder.1",
    outfile="xwordgrinder.1",
    date=DATE,
    version=VERSION,
    src="wordgrinder.man",
)

manpage(
    name="wordgrinder.1",
    outfile="wordgrinder.1",
    date=DATE,
    version=VERSION,
    src="xwordgrinder.man",
)

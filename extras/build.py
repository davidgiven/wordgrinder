from build.ab import simplerule, Rule, Target
from config import DATE, VERSION


@Rule
def manpage(self, name, date, version, src: Target):
    simplerule(
        replaces=self,
        ins=[src],
        outs=[f"={self.localname}"],
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
    date=DATE,
    version=VERSION,
    src="wordgrinder.man",
)

manpage(
    name="wordgrinder.1",
    date=DATE,
    version=VERSION,
    src="xwordgrinder.man",
)

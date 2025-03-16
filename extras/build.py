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
            + "/g' $[ins] > $[outs]"
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

simplerule(
    name="wordgrinder_iconset",
    ins=["./icon.png"],
    outs=["=wordgrinder.iconset"],
    commands=[
        "mkdir -p $[outs[0]]",
        "sips -z 64 64 $[ins[0]] --out $[outs[0]]/icon_32x32@2x.png > /dev/null",
    ],
    label="ICONSET",
)

simplerule(
    name="wordgrinder_icns",
    ins=[".+wordgrinder_iconset"],
    outs=["=wordgrinder.icns"],
    commands=["iconutil -c icns -o $[outs[0]] $[ins[0]]"],
    label="ICONUTIL",
)

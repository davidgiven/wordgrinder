"""Build and run JVM tests with JUnit4, sharing the runner dependencies."""

from pathlib import Path
import re

from build.ab import Rule, Targets, TargetsMap, error
from build.java import javalibrary, mavenjar
from build.utils import collectattrs, filenamesmatchingof, test


JUNIT = mavenjar(name="junit4", artifact="junit:junit:4.13.2", cwd="build")
HAMCREST = mavenjar(name="hamcrest", artifact="org.hamcrest:hamcrest-core:1.3", cwd="build")


@Rule
def junit4(self, name, srcitems: TargetsMap = {}, deps: Targets = [], testclasses=None):
    """Compile srcitems and run their *Test.java classes through JUnitCore.

    Helpers can be included in srcitems without being run. Set testclasses explicitly
    for other class names or generated sources. Runtime dependencies, including
    transitive Java libraries and Maven artifacts, are taken from javalibrary.
    """
    if testclasses is None:
        testclasses = []
        for filename in sorted(filenamesmatchingof(srcitems.values(), "*Test.java")):
            source = Path(filename).read_text()
            package = re.search(r"^\s*package\s+([\w.]+)\s*;", source, re.MULTILINE)
            prefix = package.group(1) + "." if package else ""
            testclasses.append(prefix + Path(filename).stem)
    if not testclasses:
        error("junit4 requires at least one *Test.java source or explicit testclasses")

    classes = javalibrary(
        name=self.localname + "_classes",
        srcitems=srcitems,
        deps=deps + [JUNIT, HAMCREST],
    )
    classes.materialise()
    classpath = collectattrs(targets=[classes], name="caller_deps", initial=[classes])

    test(
        replaces=self,
        ins=classpath,
        commands=[
            "$(JAVA) -cp '$[\":\".join(filenamesof(ins))]' "
            "org.junit.runner.JUnitCore " + " ".join(testclasses),
        ],
    )

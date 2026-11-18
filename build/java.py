from build.ab import (
    simplerule,
    error,
    Rule,
    Targets,
    TargetsMap,
    filenamesof,
    filenameof,
    emit,
    G,
)
from build.utils import targetswithtraitsof, collectattrs, filenamesmatchingof
from build.zip import zip
from os.path import *
import re

G.setdefault("JAR", "jar")
G.setdefault("JAVA", "java")
G.setdefault("JFLAGS", "")


def _batched(items, n):
    return (items[pos : pos + n] for pos in range(0, len(items), n))


@Rule
def jar(self, name, items: TargetsMap = {}):
    zip(replaces=self, items=items, extension="jar", flags="-0", label="JAR")


@Rule
def srcjar(self, name, items: TargetsMap = {}):
    zip(
        replaces=self,
        items=items,
        extension="srcjar",
        flags="-0",
        label="SRCJAR",
    )


@Rule
def externaljar(self, name, paths):
    for f in paths:
        if isfile(f):
            simplerule(
                replaces=self,
                commands=[],
                label="EXTERNALJAR",
                args={"jar": f, "caller_deps": [self]},
            )
            return
    error(f"None of {paths} exist")


@Rule
def mavenjar(self, name, artifact, repo="https://repo.maven.apache.org/maven2"):
    # Artifact name looks like this:
    # 'org.apache.felix:org.apache.felix.framework:7.0.5'
    # Which gets mapped to a URL like this:
    # https: // repo.maven.apache.org/maven2/org/apache/felix/org.apache.felix.framework/7.0.5/org.apache.felix.framework-7.0.5.jar

    values = artifact.split(":")
    if len(values) == 3:
        group, artifact, version = values
        domain = group.replace(".", "/")
        path = f"{repo}/{domain}/{artifact}/{version}/{artifact}-{version}.jar"
        localname = f"{artifact}-{version}.jar"
    elif len(values) == 2:
        group, artifact = values
        domain = group.replace(".", "/")
        path = f"{repo}/{domain}/{artifact}/{artifact}.jar"
        localname = f"{artifact}.jar"
    else:
        assert (
            False
        ), "only artifact IDs with 2 or 3 elements are supported so far"

    r = simplerule(
        replaces=self,
        ins=[],
        outs=[f"={localname}"],
        commands=["curl --location -s -S -o $[outs[0]] " + path],
        label="MAVENDOWNLOAD",
        args={"caller_deps": [self]},
    )
    r.materialise()
    r.args["jar"] = filenameof(r.outs[0])
    r.traits.add("externaljar")


@Rule
def httpjar(self, name, url):
    r = simplerule(
        replaces=self,
        ins=[],
        outs=[f"={self.localname}.jar"],
        commands=[
            "curl --location --fail-with-body -s -S -o $[outs[0]] " + url
        ],
        label="HTTPDOWNLOAD",
        args={"caller_deps": [self]},
    )
    r.materialise()
    r.args["jar"] = filenameof(r.outs[0])
    r.traits.add("externaljar")


@Rule
def javalibrary(
    self,
    name,
    srcitems: TargetsMap = {},
    dataitems: TargetsMap = {},
    deps: Targets = [],
):
    alldeps = collectattrs(targets=deps, name="caller_deps", initial=deps)
    externaldeps = targetswithtraitsof(alldeps, "externaljar")
    externaljars = [t.args["jar"] for t in externaldeps]
    internaldeps = targetswithtraitsof(alldeps, "javalibrary")
    srcdeps = targetswithtraitsof(alldeps, "srcjar")

    classpath = filenamesof(internaldeps) + externaljars
    srcfiles = filenamesmatchingof(srcitems.values(), "*.java")

    command = " ".join(
        [
            "$(JAVA) build/JavaSrcC.java $(JFLAGS) -o $[outs[0]] ",
            (" -cp " + ":".join(classpath)) if classpath else "",
        ]
        + [abspath(f) for f in filenamesof(srcdeps)]
        + [abspath(f) for f in filenamesof(srcfiles)]
    )

    simplerule(
        replaces=self,
        ins=externaljars + srcdeps + srcfiles + deps + ["build/JavaSrcC.java"],
        outs=[f"={self.localname}.jar"],
        commands=[command],
        label="JAVALIBRARY",
        args={"caller_deps": externaldeps + internaldeps},
    )


@Rule
def javalink(
    self,
    name,
    srcitems: TargetsMap = {},
    deps: Targets = [],
    mainclass=None,
    manifest={},
):
    alldeps = collectattrs(targets=deps, name="caller_deps", initial=deps)
    externaldeps = targetswithtraitsof(alldeps, "externaljar")
    externaljars = [t.args["jar"] for t in externaldeps]
    internaldeps = targetswithtraitsof(alldeps, "javalibrary")

    assert mainclass, "a main class must be specified for javaprogram"
    if srcitems:
        j = javalibrary(
            name=name + "_mainlib",
            srcitems=srcitems,
            deps=deps,
            cwd=self.cwd,
        )
        j.materialise()
        internaldeps += [j]
        alldeps += [j]

    mf = (
        [
            "Manifest-Version: 1.0",
            "Created-By: ab",
            "Main-Class: " + mainclass,
        ]
        + (
            []
            if not externaljars
            else [
                "Class-Path: " + " ".join([f"$(CWD)/{f}" for f in externaljars])
            ]
        )
        + [f"{k}={v}" for k, v in manifest.items()]
    )

    simplerule(
        replaces=self,
        ins=alldeps + ["build/_manifest.py"],
        outs=[f"={self.localname}.jar"],
        commands=[
            "rm -rf $[dir]/objs $[dir]/manifest.mf",
            "mkdir -p $[dir]/objs",
        ]
        + [
            f"$(PYTHON) build/_manifest.py "
            + " ".join([v.replace(" ", "\\ ") for v in mf])
            + " > $[dir]/manifest.mf"
        ]
        + [
            f"(cd $[dir]/objs && $(JAR) xf {abspath(j)})"
            for j in filenamesof(internaldeps)
        ]
        + [
            "$(JAR) --create --file=$[outs[0]] --manifest=$[dir]/manifest.mf -C $[dir]/objs ."
        ],
        label="JAVAPROGRAM",
    )


@Rule
def javaprogram(
    self,
    name,
    srcitems: TargetsMap = {},
    deps: Targets = [],
    mainclass=None,
    manifest={},
    vmflags=[],
):
    jar = javalink(
        name=f"{self.localname}.jar",
        srcitems=srcitems,
        deps=deps,
        mainclass=mainclass,
        manifest=manifest,
    )

    flags = " ".join(vmflags)
    simplerule(
        replaces=self,
        ins=[jar],
        outs=[f"={self.localname}"],
        commands=[
            f"echo '#!/usr/bin/env -S java {flags} -jar' > $[outs[0]]",
            "cat $[ins[0]] >> $[outs[0]]",
            "chmod a+rx $[outs[0]]",
        ],
        label="JAVAEXE",
    )

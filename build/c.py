from build.ab2 import (
    DefaultVars,
    Rule,
    Targets,
    filenameof,
    filenamesof,
    flatten,
    normalrule,
    stripext,
)
from os.path import *


def cfileimpl(
    self, name, srcs, deps, vars, suffix, commands, label
):
    if not name:
        name = filenamesof(srcs)[1]

    dirs = []
    for d in deps:
        for f in filenamesof(d):
            if f.endswith(".h"):
                dirs += [dirname(f)]

        exportvars = getattr(d, "exportvars", None)
        if exportvars:
            vars = vars + exportvars

        try:
            dirs += d.clibrary.dirs
        except:
            pass

    includeflags = set(["-I" + f for f in filenamesof(dirs)])
    vars = vars + {"+includes": flatten(includeflags)}

    outleaf = stripext(basename(name)) + suffix

    normalrule(
        replaces=self,
        ins=srcs,
        deps=deps,
        outs=[outleaf],
        label=label,
        vars=vars,
        commands=commands,
    )


@Rule
def cfile(
    self,
    name,
    srcs: Targets = [],
    deps: Targets = [],
    vars=DefaultVars,
    suffix=".o",
    commands=["$(CC) -c -o {outs[0]} {ins[0]} {vars.cflags} {vars.includes}"],
    label="CC",
):
    cfileimpl(
        self, name, srcs, deps, vars, suffix, commands, label
    )


@Rule
def cxxfile(
    self,
    name,
    srcs: Targets = [],
    deps: Targets = [],
    vars=DefaultVars,
    suffix=".o",
    commands=["$(CXX) -c -o {outs[0]} {ins[0]} {vars.cxxflags} {vars.includes}"],
    label="CXX",
):
    cfileimpl(
        self,
        name,
        srcs,
        deps,
        vars,
        suffix,
        commands,
        label
    )


def findsources(name, srcs, deps, vars):
    ins = []
    for f in filenamesof(srcs):
        if f.endswith(".c") or f.endswith(".cc") or f.endswith(".cpp"):
            handler = cxxfile
            if f.endswith(".c"):
                handler = cfile

            ins += [
                handler(
                    name=name + "/" + basename(filenamesof(f)[0]),
                    srcs=[f],
                    deps=deps,
                    vars=vars,
                )
            ]
    return ins


@Rule
def clibrary(
    self,
    name,
    srcs: Targets = [],
    deps: Targets = [],
    hdrs: Targets = [],
    vars=DefaultVars,
    exportvars={},
    commands=["$(AR) cqs {outs[0]} {ins}"],
    label="AR",
):
    for f in filenamesof(srcs):
        if f.endswith(".h"):
            deps += [f]

    normalrule(
        replaces=self,
        ins=findsources(name, srcs, deps, vars),
        outs=[basename(name) + ".a"],
        label=label,
        commands=commands,
        vars=vars,
    )

    dirs = set([dirname(f) for f in filenamesof(hdrs)])

    self.clibrary.hdrs = hdrs
    self.clibrary.dirs = dirs
    self.clibrary.deps = [
        d.outs + d.clibrary.deps for d in deps if hasattr(d, "clibrary")
    ]
    self.exportvars = exportvars


def programimpl(self, name, srcs, deps, vars, commands, label, filerule, kind):
    libraries = [
        d.outs + d.clibrary.deps for d in deps if hasattr(d, "clibrary")
    ]

    for f in filenamesof(srcs):
        if f.endswith(".h"):
            deps += [f]

    for d in deps:
        exportvars = getattr(d, "exportvars", None)
        if exportvars:
            vars = vars + exportvars

    normalrule(
        replaces=self,
        ins=findsources(name, srcs, deps, vars),
        outs=[basename(name)],
        deps=deps,
        label=label,
        commands=commands,
        vars=vars + {"libs": libraries},
    )


@Rule
def cprogram(
    self,
    name,
    srcs: Targets = [],
    deps: Targets = [],
    vars=DefaultVars,
    commands=["$(CC) -o {outs[0]} {ins} {vars.libs} {vars.ldflags}"],
    label="CLINK",
):
    programimpl(
        self, name, srcs, deps, vars, commands, label, cfile, "cprogram"
    )


@Rule
def cxxprogram(
    self,
    name,
    srcs: Targets = [],
    deps: Targets = [],
    vars=DefaultVars,
    commands=["$(CXX) -o {outs[0]} {ins} {vars.libs} {vars.ldflags}"],
    label="CXXLINK",
):
    programimpl(
        self, name, srcs, deps, vars, commands, label, cxxfile, "cxxprogram"
    )

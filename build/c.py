from build.ab import (
    Rule,
    Targets,
    TargetsMap,
    filenameof,
    filenamesof,
    flatten,
    simplerule,
)
from build.utils import (
    filenamesmatchingof,
    stripext,
    targetswithtraitsof,
    collectattrs,
)
from os.path import *


class Toolchain:
    label = ""
    cfile = ["$(CC) -c -o {outs[0]} {ins[0]} $(CFLAGS) {cflags}"]
    cxxfile = ["$(CXX) -c -o {outs[0]} {ins[0]} $(CFLAGS) {cflags}"]
    clibrary = ["$(AR) cqs {outs[0]} {ins}"]
    cxxlibrary = ["$(AR) cqs {outs[0]} {ins}"]
    cprogram = ["$(CC) -o {outs[0]} {ins} {ldflags} $(LDFLAGS)"]
    cxxprogram = ["$(CXX) -o {outs[0]} {ins} {ldflags} $(LDFLAGS)"]


class HostToolchain:
    label = "HOST "
    cfile = ["$(HOSTCC) -c -o {outs[0]} {ins[0]} $(HOSTCFLAGS) {cflags}"]
    cxxfile = ["$(HOSTCXX) -c -o {outs[0]} {ins[0]} $(HOSTCFLAGS) {cflags}"]
    clibrary = ["$(HOSTAR) cqs {outs[0]} {ins}"]
    cxxlibrary = ["$(HOSTAR) cqs {outs[0]} {ins}"]
    cprogram = ["$(HOSTCC) -o {outs[0]} {ins} {ldflags} $(HOSTLDFLAGS)"]
    cxxprogram = ["$(HOSTCXX) -o {outs[0]} {ins} {ldflags} $(HOSTLDFLAGS)"]


def cfileimpl(self, name, srcs, deps, suffix, commands, label, kind, cflags):
    outleaf = "=" + stripext(basename(filenameof(srcs[0]))) + suffix

    cflags = collectattrs(targets=deps, name="caller_cflags", initial=cflags)

    t = simplerule(
        replaces=self,
        ins=srcs,
        deps=deps,
        outs=[outleaf],
        label=label,
        commands=commands,
        args={"cflags": cflags},
    )


@Rule
def cfile(
    self,
    name,
    srcs: Targets = None,
    deps: Targets = None,
    cflags=[],
    suffix=".o",
    toolchain=Toolchain,
    commands=None,
    label=None,
):
    if not label:
        label = toolchain.label + "CC"
    if not commands:
        commands = toolchain.cfile
    cfileimpl(self, name, srcs, deps, suffix, commands, label, "cfile", cflags)


@Rule
def cxxfile(
    self,
    name,
    srcs: Targets = None,
    deps: Targets = None,
    cflags=[],
    suffix=".o",
    toolchain=Toolchain,
    commands=None,
    label=None,
):
    if not label:
        label = toolchain.label + "CXX"
    if not commands:
        commands = toolchain.cxxfile
    cfileimpl(
        self, name, srcs, deps, suffix, commands, label, "cxxfile", cflags
    )


def findsources(name, srcs, deps, cflags, toolchain, filerule, cwd):
    headers = filenamesmatchingof(srcs, "*.h")
    cflags = cflags + ["-I" + dirname(h) for h in headers]
    deps = deps + headers

    objs = []
    for s in flatten(srcs):
        objs += [
            filerule(
                name=join(name, f.removeprefix("$(OBJ)/")),
                srcs=[f],
                deps=deps,
                cflags=cflags,
                toolchain=toolchain,
                cwd=cwd,
            )
            for f in filenamesof([s])
            if f.endswith(".c")
            or f.endswith(".cc")
            or f.endswith(".cpp")
            or f.endswith(".S")
            or f.endswith(".s")
        ]
        if any(f.endswith(".o") for f in filenamesof([s])):
            objs += [s]

    return objs


@Rule
def cheaders(
    self,
    name,
    hdrs: TargetsMap = None,
    caller_cflags=[],
    deps: Targets = None,
):
    cs = []
    ins = list(hdrs.values())
    outs = []
    i = 0
    for dest, src in hdrs.items():
        s = filenamesof([src])
        assert (
            len(s) == 1
        ), "the target of a header must return exactly one file"

        cs += ["cp {ins[" + str(i) + "]} {outs[" + str(i) + "]}"]
        outs += ["=" + dest]
        i = i + 1

    r = simplerule(
        replaces=self,
        ins=ins,
        outs=outs,
        commands=cs,
        deps=deps,
        label="CHEADERS",
        args={"caller_cflags": caller_cflags + ["-I" + self.dir]},
    )


def libraryimpl(
    self,
    name,
    srcs,
    deps,
    hdrs,
    caller_cflags,
    caller_ldflags,
    cflags,
    ldflags,
    toolchain,
    commands,
    label,
    kind,
):
    hr = None
    if hdrs and not srcs:
        cheaders(
            replaces=self,
            hdrs=hdrs,
            deps=targetswithtraitsof(deps, "cheaders"),
            caller_cflags=caller_cflags,
        )
        return
    if hdrs:
        hr = cheaders(
            name=self.localname + "_hdrs",
            hdrs=hdrs,
            deps=targetswithtraitsof(deps, "cheaders"),
            caller_cflags=caller_cflags,
        )
        hr.materialise()
        deps = deps + [hr]

    objs = findsources(
        self.localname,
        srcs,
        targetswithtraitsof(deps, "cheaders"),
        cflags,
        toolchain,
        kind,
        self.cwd,
    )

    simplerule(
        replaces=self,
        ins=objs,
        outs=[f"={self.localname}.a"],
        label=label,
        commands=commands,
        args={
            "caller_cflags": collectattrs(
                targets=deps + ([hr] if hr else []), name="caller_cflags"
            ),
            "caller_ldflags": collectattrs(
                targets=deps, name="caller_ldflags", initial=caller_ldflags
            ),
        },
        traits={"cheaders"},
    )
    self.outs = self.outs + (hr.outs if hr else [])


@Rule
def clibrary(
    self,
    name,
    srcs: Targets = None,
    deps: Targets = None,
    hdrs: TargetsMap = None,
    caller_cflags=[],
    caller_ldflags=[],
    cflags=[],
    ldflags=[],
    toolchain=Toolchain,
    commands=None,
    label=None,
    cfilerule=cfile,
):
    if not label:
        label = toolchain.label + "LIB"
    if not commands:
        commands = toolchain.clibrary
    libraryimpl(
        self,
        name,
        srcs,
        deps,
        hdrs,
        caller_cflags,
        caller_ldflags,
        cflags,
        ldflags,
        toolchain,
        commands,
        label,
        cfilerule,
    )


@Rule
def cxxlibrary(
    self,
    name,
    srcs: Targets = None,
    deps: Targets = None,
    hdrs: TargetsMap = None,
    caller_cflags=[],
    caller_ldflags=[],
    cflags=[],
    ldflags=[],
    toolchain=Toolchain,
    commands=None,
    label=None,
):
    if not label:
        label = toolchain.label + "LIB"
    if not commands:
        commands = toolchain.clibrary
    libraryimpl(
        self,
        name,
        srcs,
        deps,
        hdrs,
        caller_cflags,
        caller_ldflags,
        cflags,
        ldflags,
        toolchain,
        commands,
        label,
        cxxfile,
    )


def programimpl(
    self,
    name,
    srcs,
    deps,
    cflags,
    ldflags,
    toolchain,
    commands,
    label,
    filerule,
    kind,
):
    ars = filenamesmatchingof(deps, "*.a")

    cfiles = findsources(
        self.localname, srcs, deps, cflags, toolchain, filerule, self.cwd
    )
    simplerule(
        replaces=self,
        ins=cfiles + ars + ars,
        outs=[f"={self.localname}$(EXT)"],
        deps=deps,
        label=toolchain.label + label,
        commands=commands,
        args={
            "ldflags": collectattrs(
                targets=deps, name="caller_ldflags", initial=ldflags
            )
        },
    )


@Rule
def cprogram(
    self,
    name,
    srcs: Targets = None,
    deps: Targets = None,
    cflags=[],
    ldflags=[],
    toolchain=Toolchain,
    commands=None,
    label="CLINK",
    cfilerule=cfile,
    cfilekind="cprogram",
):
    if not commands:
        commands = toolchain.cprogram
    programimpl(
        self,
        name,
        srcs,
        deps,
        cflags,
        ldflags,
        toolchain,
        commands,
        label,
        cfilerule,
        cfilekind,
    )


@Rule
def cxxprogram(
    self,
    name,
    srcs: Targets = None,
    deps: Targets = None,
    cflags=[],
    ldflags=[],
    toolchain=Toolchain,
    commands=None,
    label="CXXLINK",
):
    if not commands:
        commands = toolchain.cxxprogram
    programimpl(
        self,
        name,
        srcs,
        deps,
        cflags,
        ldflags,
        toolchain,
        commands,
        label,
        cxxfile,
        "cxxprogram",
    )

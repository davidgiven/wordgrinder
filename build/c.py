from build.ab import (
    Rule,
    Targets,
    TargetsMap,
    filenameof,
    filenamesof,
    flatten,
    simplerule,
    emit,
)
from build.utils import filenamesmatchingof, stripext, collectattrs
from os.path import *

emit(
    """
ifeq ($(OSX),no)
STARTGROUP ?= -Wl,--start-group
ENDGROUP ?= -Wl,--end-group
endif
"""
)


def _indirect(deps, name):
    r = set()
    for d in deps:
        r.update(d.args.get(name, {d}))
    return r


def cfileimpl(self, name, srcs, deps, suffix, commands, label, kind, cflags):
    outleaf = "=" + stripext(basename(filenameof(srcs[0]))) + suffix

    hdr_deps = _indirect(deps, "cheader_deps")
    cflags = collectattrs(
        targets=hdr_deps, name="caller_cflags", initial=cflags
    )

    t = simplerule(
        replaces=self,
        ins=srcs,
        deps=sorted(_indirect(hdr_deps, "cheader_files")),
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
    commands=["$(CC) -c -o {outs[0]} {ins[0]} $(CFLAGS) {cflags}"],
    label="CC",
):
    cfileimpl(self, name, srcs, deps, suffix, commands, label, "cfile", cflags)


@Rule
def cxxfile(
    self,
    name,
    srcs: Targets = None,
    deps: Targets = None,
    cflags=[],
    suffix=".o",
    commands=["$(CXX) -c -o {outs[0]} {ins[0]} $(CFLAGS) {cflags}"],
    label="CXX",
):
    cfileimpl(
        self, name, srcs, deps, suffix, commands, label, "cxxfile", cflags
    )


def findsources(name, srcs, deps, cflags, filerule, cwd):
    for f in filenamesof(srcs):
        if f.endswith(".h") or f.endswith(".hh"):
            cflags = cflags + [f"-I{dirname(f)}"]

    objs = []
    for s in flatten(srcs):
        objs += [
            filerule(
                name=join(name, f.removeprefix("$(OBJ)/")),
                srcs=[f],
                deps=deps,
                cflags=sorted(set(cflags)),
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
    commands,
    label,
    kind,
):
    hdr_deps = _indirect(deps, "cheader_deps") | {self}
    lib_deps = _indirect(deps, "clibrary_deps") | {self}

    hr = None
    hf = []
    ar = None
    if hdrs:
        cs = []
        ins = hdrs.values()
        outs = []
        i = 0
        for dest, src in hdrs.items():
            s = filenamesof([src])
            assert (
                len(s) == 1
            ), "the target of a header must return exactly one file"

            cs += ["$(CP) {ins[" + str(i) + "]} {outs[" + str(i) + "]}"]
            outs += ["=" + dest]
            i = i + 1

        hr = simplerule(
            name=f"{self.localname}_hdr",
            ins=ins,
            outs=outs,
            commands=cs,
            label="CHEADERS",
        )
        hr.materialise()
        hf = [f"-I{hr.dir}"]

    if srcs:
        objs = findsources(
            self.localname,
            srcs,
            deps + ([hr] if hr else []),
            cflags + hf,
            kind,
            self.cwd,
        )

        ar = simplerule(
            name=f"{self.localname}_lib",
            ins=objs,
            outs=[f"={self.localname}.a"],
            label=label,
            commands=commands,
        )
        ar.materialise()

    self.outs = ([hr] if hr else []) + ([ar] if ar else [])
    self.deps = self.outs
    self.args["cheader_deps"] = hdr_deps
    self.args["clibrary_deps"] = lib_deps
    self.args["cheader_files"] = [hr] if hr else []
    self.args["clibrary_files"] = [ar] if ar else []
    self.args["caller_cflags"] = caller_cflags + hf
    self.args["caller_ldflags"] = caller_ldflags


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
    commands=["rm -f {outs[0]} && $(AR) cqs {outs[0]} {ins}"],
    label="LIB",
    cfilerule=cfile,
):
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
    commands=["rm -f {outs[0]} && $(AR) cqs {outs[0]} {ins}"],
    label="CXXLIB",
    cxxfilerule=cxxfile,
):
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
        commands,
        label,
        cxxfilerule,
    )


def programimpl(
    self,
    name,
    srcs,
    deps,
    cflags,
    ldflags,
    commands,
    label,
    filerule,
    kind,
):
    cfiles = findsources(self.localname, srcs, deps, cflags, filerule, self.cwd)

    lib_deps = set()
    for d in deps:
        lib_deps.update(d.args.get("clibrary_deps", {d}))
    libs = sorted(filenamesmatchingof(lib_deps, "*.a"))
    ldflags = collectattrs(
        targets=lib_deps, name="caller_ldflags", initial=ldflags
    )

    simplerule(
        replaces=self,
        ins=cfiles + libs,
        outs=[f"={self.localname}$(EXT)"],
        deps=sorted(_indirect(lib_deps, "clibrary_files")),
        label=label,
        commands=commands,
        args={
            "ldflags": collectattrs(
                targets=lib_deps, name="caller_ldflags", initial=ldflags
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
    commands=[
        "$(CC) -o {outs[0]} $(STARTGROUP) {ins} {ldflags} $(LDFLAGS) $(ENDGROUP)"
    ],
    label="CLINK",
):
    programimpl(
        self,
        name,
        srcs,
        deps,
        cflags,
        ldflags,
        commands,
        label,
        cfile,
        "cprogram",
    )


@Rule
def cxxprogram(
    self,
    name,
    srcs: Targets = None,
    deps: Targets = None,
    cflags=[],
    ldflags=[],
    commands=[
        "$(CXX) -o {outs[0]} $(STARTGROUP) {ins} {ldflags} $(LDFLAGS) $(ENDGROUP)"
    ],
    label="CXXLINK",
):
    programimpl(
        self,
        name,
        srcs,
        deps,
        cflags,
        ldflags,
        commands,
        label,
        cxxfile,
        "cxxprogram",
    )

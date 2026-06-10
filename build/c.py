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
from build.toolchain import Toolchain, HostToolchain
from os.path import *

emit(
    """
ifeq ($(OSX),no)
STARTGROUP ?= -Wl,--start-group
ENDGROUP ?= -Wl,--end-group
endif
"""
)

Toolchain.CC = ["$(CC) -c -o $[outs[0]] $[ins[0]] $(CFLAGS) $[cflags]"]
Toolchain.CPP = ["$(CC) -E -P -o $[outs] $[cflags] -x c $[ins]"]
Toolchain.CXX = ["$(CXX) -c -o $[outs[0]] $[ins[0]] $(CFLAGS) $[cflags]"]
Toolchain.AR = ["$(AR) cqs $[outs[0]] $[ins]"]
Toolchain.ARXX = ["$(AR) cqs $[outs[0]] $[ins]"]
Toolchain.CLINK = [
    "$(CC) -o $[outs[0]] $(STARTGROUP) $[ins] $[ldflags] $(LDFLAGS) $(ENDGROUP)"
]
Toolchain.CXXLINK = [
    "$(CXX) -o $[outs[0]] $(STARTGROUP) $[ins] $[ldflags] $(LDFLAGS) $(ENDGROUP)"
]

Toolchain.is_source_file = (
    lambda f: f.endswith(".c")
    or f.endswith(".cc")
    or f.endswith(".cpp")
    or f.endswith(".S")
    or f.endswith(".s")
    or f.endswith(".m")
    or f.endswith(".mm")
)


# Given a set of dependencies, finds the set of relevant library targets (i.e.
# contributes *.a files) for compiling C programs.  The actual list of libraries
# is in dep.clibrary_files.
def _toolchain_find_library_targets(deps):
    lib_deps = []
    for d in deps:
        lib_deps = _combine(lib_deps, d.args.get("clibrary_deps", []))
    return lib_deps


Toolchain.find_c_library_targets = _toolchain_find_library_targets


# Given a set of dependencies, finds the set of relevant header targets (i.e.
# contributes *.h files) for compiling C programs.  The actual list of libraries
# is in dep.cheader_files.
def _toolchain_find_header_targets(deps, initial=[]):
    hdr_deps = initial
    for d in deps:
        hdr_deps = _combine(hdr_deps, d.args.get("cheader_deps", []))
    return hdr_deps


Toolchain.find_c_header_targets = _toolchain_find_header_targets


HostToolchain.CC = [
    "$(HOSTCC) -c -o $[outs[0]] $[ins[0]] $(HOSTCFLAGS) $[cflags]"
]
HostToolchain.CPP = ["$(HOSTCC) -E -P -o $[outs] $[cflags] -x c $[ins]"]
HostToolchain.CXX = [
    "$(HOSTCXX) -c -o $[outs[0]] $[ins[0]] $(HOSTCFLAGS) $[cflags]"
]
HostToolchain.AR = ["$(HOSTAR) cqs $[outs[0]] $[ins]"]
HostToolchain.ARXX = ["$(HOSTAR) cqs $[outs[0]] $[ins]"]
HostToolchain.CLINK = [
    "$(HOSTCC) -o $[outs[0]] $(STARTGROUP) $[ins] $[ldflags] $(HOSTLDFLAGS) $(ENDGROUP)"
]
HostToolchain.CXXLINK = [
    "$(HOSTCXX) -o $[outs[0]] $(STARTGROUP) $[ins] $[ldflags] $(HOSTLDFLAGS) $(ENDGROUP)"
]


def _combine(list1, list2):
    r = list(list1)
    for i in list2:
        if i not in r:
            r.append(i)
    return r


def _indirect(deps, name):
    r = []
    for d in deps:
        r = _combine(r, d.args.get(name, [d]))
    return r


def cfileimpl(
    self, name, srcs, deps, suffix, commands, label, toolchain, cflags
):
    outleaf = "=" + stripext(basename(filenameof(srcs[0]))) + suffix

    hdr_deps = toolchain.find_c_header_targets(deps)
    other_deps = [
        d
        for d in deps
        if ("cheader_deps" not in d.args) and ("clibrary_deps" not in d.args)
    ]
    hdr_files = collectattrs(targets=hdr_deps, name="cheader_files")
    cflags = collectattrs(
        targets=hdr_deps, name="caller_cflags", initial=cflags
    )

    t = simplerule(
        replaces=self,
        ins=srcs,
        deps=other_deps + hdr_files,
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
    label="CC",
):
    cfileimpl(
        self,
        name,
        srcs,
        deps,
        suffix,
        toolchain.CC,
        toolchain.PREFIX + label,
        toolchain,
        cflags,
    )


@Rule
def cxxfile(
    self,
    name,
    srcs: Targets = None,
    deps: Targets = None,
    cflags=[],
    suffix=".o",
    toolchain=Toolchain,
    label="CXX",
):
    cfileimpl(
        self,
        name,
        srcs,
        deps,
        suffix,
        toolchain.CXX,
        toolchain.PREFIX + label,
        toolchain,
        cflags,
    )


def _removeprefix(self, prefix):
    if self.startswith(prefix):
        return self[len(prefix) :]
    else:
        return self[:]


def findsources(self, srcs, deps, cflags, filerule, toolchain, cwd):
    for f in filenamesof(srcs):
        if not toolchain.is_source_file(f):
            cflags = cflags + [f"-I{dirname(f)}"]
            deps = deps + [f]

    objs = []
    for s in flatten(srcs):
        objs += [
            filerule(
                name=join(self.localname, _removeprefix(f, "$(OBJ)/")),
                srcs=[f],
                deps=deps,
                cflags=sorted(set(cflags)),
                toolchain=toolchain,
                cwd=cwd,
                args=getattr(self, "explicit_args", {}),
            )
            for f in filenamesof([s])
            if toolchain.is_source_file(f)
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
    toolchain,
    commands,
    label,
    filerule,
):
    hdr_deps = toolchain.find_c_header_targets(deps) + [self]
    lib_deps = toolchain.find_c_library_targets(deps) + [self]

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

            cs += [f"$(CP) $[ins[{i}]] $[outs[{i}]]"]
            outs += ["=" + dest]
            i = i + 1

        hr = simplerule(
            name=f"{self.localname}_hdr",
            ins=ins,
            outs=outs,
            commands=cs,
            label=toolchain.PREFIX + "CHEADERS",
        )
        hr.args["cheader_deps"] = [hr]
        hr.args["cheader_files"] = [hr]
        hf = [f"-I{hr.dir}"]

    if srcs:
        # Can't depend on the current target to get the library headers, because
        # if we do it'll cause a dependency loop.
        objs = findsources(
            self,
            srcs,
            deps + ([hr] if hr else []),
            cflags + hf,
            filerule,
            toolchain,
            self.cwd,
        )

        ar = simplerule(
            name=f"{self.localname}_lib",
            ins=objs,
            outs=[f"={self.localname}.a"],
            deps=deps,
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
    toolchain=Toolchain,
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
        toolchain,
        toolchain.AR,
        toolchain.PREFIX + label,
        cfilerule,
    )


@Rule
def hostclibrary(
    self,
    name,
    srcs: Targets = None,
    deps: Targets = None,
    hdrs: TargetsMap = None,
    caller_cflags=[],
    caller_ldflags=[],
    cflags=[],
    ldflags=[],
    toolchain=HostToolchain,
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
        toolchain,
        toolchain.AR,
        toolchain.PREFIX + label,
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
        toolchain,
        toolchain.ARXX,
        toolchain.PREFIX + label,
        cxxfilerule,
    )


@Rule
def hostcxxlibrary(
    self,
    name,
    srcs: Targets = None,
    deps: Targets = None,
    hdrs: TargetsMap = None,
    caller_cflags=[],
    caller_ldflags=[],
    cflags=[],
    ldflags=[],
    toolchain=HostToolchain,
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
        toolchain,
        toolchain.ARXX,
        toolchain.PREFIX + label,
        cxxfilerule,
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
):
    cfiles = findsources(
        self, srcs, deps, cflags, filerule, toolchain, self.cwd
    )

    lib_deps = toolchain.find_c_library_targets(deps)
    libs = collectattrs(targets=lib_deps, name="clibrary_files")
    ldflags = collectattrs(
        targets=lib_deps, name="caller_ldflags", initial=ldflags
    )

    simplerule(
        replaces=self,
        ins=cfiles + libs,
        outs=[f"={self.localname}$(EXT)"],
        deps=deps,
        label=label,
        commands=commands,
        args={"ldflags": ldflags},
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
    label="CLINK",
    cfilerule=cfile,
):
    programimpl(
        self,
        name,
        srcs,
        deps,
        cflags,
        ldflags,
        toolchain,
        toolchain.CLINK,
        toolchain.PREFIX + label,
        cfilerule,
    )


@Rule
def hostcprogram(
    self,
    name,
    srcs: Targets = None,
    deps: Targets = None,
    cflags=[],
    ldflags=[],
    toolchain=HostToolchain,
    label="CLINK",
    cfilerule=cfile,
):
    programimpl(
        self,
        name,
        srcs,
        deps,
        cflags,
        ldflags,
        toolchain,
        toolchain.CLINK,
        toolchain.PREFIX + label,
        cfilerule,
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
    label="CXXLINK",
    cxxfilerule=cxxfile,
):
    programimpl(
        self,
        name,
        srcs,
        deps,
        cflags,
        ldflags,
        toolchain,
        toolchain.CXXLINK,
        toolchain.PREFIX + label,
        cxxfilerule,
    )


@Rule
def hostcxxprogram(
    self,
    name,
    srcs: Targets = None,
    deps: Targets = None,
    cflags=[],
    ldflags=[],
    toolchain=HostToolchain,
    label="CXXLINK",
    cxxfilerule=cxxfile,
):
    programimpl(
        self,
        name,
        srcs,
        deps,
        cflags,
        ldflags,
        toolchain,
        toolchain.CXXLINK,
        toolchain.PREFIX + label,
        cxxfilerule,
    )


def _cppfileimpl(self, name, srcs, deps, cflags, toolchain):
    hdr_deps = _indirect(deps, "cheader_deps")
    cflags = collectattrs(
        targets=hdr_deps, name="caller_cflags", initial=cflags
    )

    simplerule(
        replaces=self,
        ins=srcs,
        outs=[f"={self.localname}"],
        deps=deps,
        commands=toolchain.CPP,
        args={"cflags": cflags},
        label=toolchain.PREFIX + "CPPFILE",
    )


@Rule
def cppfile(
    self,
    name,
    srcs: Targets = [],
    deps: Targets = [],
    cflags=[],
    toolchain=Toolchain,
):
    _cppfileimpl(self, name, srcs, deps, cflags, toolchain)


@Rule
def hostcppfile(
    self,
    name,
    srcs: Targets = [],
    deps: Targets = [],
    cflags=[],
    toolchain=HostToolchain,
):
    _cppfileimpl(self, name, srcs, deps, cflags, toolchain)

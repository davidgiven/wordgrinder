from build.ab import (
    Rule,
    Target,
    Targets,
    filenameof,
    filenamesof,
    getcwd,
    error,
    simplerule,
    G,
)
from os.path import relpath, splitext, join, basename, isfile, normpath
from os import walk
from glob import iglob
import fnmatch
import subprocess
import shutil
import re
import functools


def filenamesmatchingof(xs, pattern):
    return fnmatch.filter(filenamesof(xs), pattern)


def stripext(path):
    return splitext(path)[0]


def targetswithtraitsof(xs, trait):
    return [t for t in xs if trait in t.traits]


def collectattrs(*, targets, name, initial=[]):
    s = set(initial)
    for a in [t.args.get(name, []) for t in targets]:
        s.update(a)
    return sorted(s)


@functools.cache
def _glob_to_re(glob_str):
    if glob_str.startswith("./"):
        glob_str = normpath(join(getcwd(), glob_str))

    opts = re.compile("([.]|[*][*]/|[*]|[?])|(.)")
    out = ""
    for pattern_match, literal_text in opts.findall(glob_str):
        if pattern_match == ".":
            out += "[.]"
        elif pattern_match == "**/":
            out += "(?:.*/)?"
        elif pattern_match == "*":
            out += "[^/]*"
        elif pattern_match == "?":
            out += "."
        elif literal_text:
            out += literal_text
    return re.compile(out)


def _glob_filter(paths, pattern):
    r = _glob_to_re(pattern)
    for f in paths:
        if r.match(f):
            yield f


def _glob_matches(path, pattern):
    r = _glob_to_re(pattern)
    return r.match(path)


def glob(include=["*"], exclude=[], dir=None, relative_to="."):
    if not dir:
        dir = getcwd()
    if dir.startswith("./"):
        dir = normpath(join(getcwd(), dir))
    if relative_to.startswith("./"):
        relative_to = normpath(join(getcwd(), relative_to))

    def iterate():
        for dirpath, dirnames, filenames in walk(
            dir, topdown=True, followlinks=True
        ):
            dirpath = relpath(dirpath, relative_to)
            filenames = [normpath(join(dirpath, f)) for f in filenames]
            matching = set()
            for p in include:
                matching.update([f for f in _glob_filter(filenames, p)])
            for p in exclude:
                matching = [n for n in matching if not _glob_matches(n, p)]
            for f in matching:
                yield f

    return list(iterate())


def itemsof(pattern, root=None, cwd=None):
    if not cwd:
        cwd = getcwd()
    if not root:
        root = "."

    pattern = join(cwd, pattern)
    root = join(cwd, root)

    result = {}
    for f in iglob(pattern, recursive=True):
        try:
            if isfile(f):
                result[relpath(f, root)] = f
        except ValueError:
            error(f"file '{f}' is not in root '{root}'")
    return result


def does_command_exist(cmd):
    basecmd = cmd.strip().split()[0]
    return shutil.which(basecmd)


def shell(cmd):
    r = subprocess.check_output([G.SHELL, "-c", cmd])
    return r.decode("utf-8").strip()


@Rule
def objectify(self, name, src: Target, symbol):
    simplerule(
        replaces=self,
        ins=["build/_objectify.py", src],
        outs=[f"={basename(filenameof(src))}.h"],
        commands=["$(PYTHON) $[ins[0]] $[ins[1]] " + symbol + " > $[outs]"],
        label="OBJECTIFY",
    )


@Rule
def test(
    self,
    name,
    command: Target = None,
    commands=None,
    ins: Targets = None,
    deps: Targets = None,
    label="TEST",
):
    if command:
        simplerule(
            replaces=self,
            ins=[command],
            outs=["=sentinel"],
            commands=["$[ins[0]]", "touch $[outs[0]]"],
            deps=deps,
            label=label,
        )
    else:
        simplerule(
            replaces=self,
            ins=ins,
            outs=["=sentinel"],
            commands=commands + ["touch $[outs[0]]"],
            deps=deps,
            label=label,
        )

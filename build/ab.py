from os.path import *
from pathlib import Path
from typing import Iterable
import argparse
import builtins
from copy import copy
import functools
import importlib
import importlib.abc
import importlib.util
from importlib.machinery import (
    SourceFileLoader,
    PathFinder,
    ModuleSpec,
)
import inspect
import string
import sys
import hashlib

verbose = False
quiet = False
cwdStack = [""]
targets = {}
unmaterialisedTargets = {}  # dict, not set, to get consistent ordering
materialisingStack = []
defaultGlobals = {}

sys.path += ["."]
old_import = builtins.__import__


class PathFinderImpl(PathFinder):
    def find_spec(self, fullname, path, target=None):
        if not path:
            path = ["."]
        if len(path) != 1:
            return None

        try:
            path = relpath(path[0])
        except ValueError:
            return None

        realpath = fullname.replace(".", "/")
        buildpath = realpath + ".py"
        if isfile(buildpath):
            spec = importlib.util.spec_from_file_location(
                name=fullname,
                location=buildpath,
                loader=BuildFileLoaderImpl(fullname=fullname, path=buildpath),
                submodule_search_locations=[],
            )
            return spec
        if isdir(realpath):
            return ModuleSpec(fullname, None, origin=realpath, is_package=True)
        return None


class BuildFileLoaderImpl(SourceFileLoader):
    def exec_module(self, module):
        sourcepath = relpath(module.__file__)

        if not quiet:
            print("loading", sourcepath)
        cwdStack.append(dirname(sourcepath))
        super(SourceFileLoader, self).exec_module(module)
        cwdStack.pop()


sys.meta_path.insert(0, PathFinderImpl())


class ABException(BaseException):
    pass


def error(message):
    raise ABException(message)


def Rule(func):
    sig = inspect.signature(func)

    @functools.wraps(func)
    def wrapper(*, name=None, replaces=None, **kwargs):
        cwd = None
        if "cwd" in kwargs:
            cwd = kwargs["cwd"]
            del kwargs["cwd"]

        if not cwd:
            if replaces:
                cwd = replaces.cwd
            else:
                cwd = cwdStack[-1]

        if name:
            if name[0] != "+":
                name = "+" + name
            t = Target(cwd, join(cwd, name))

            assert (
                t.name not in targets
            ), f"target {t.name} has already been defined"
            targets[t.name] = t
        elif replaces:
            t = replaces
        else:
            raise ABException("you must supply either 'name' or 'replaces'")

        t.cwd = cwd
        t.types = func.__annotations__
        t.callback = func
        t.traits.add(func.__name__)
        if "args" in kwargs:
            t.args |= kwargs["args"]
            del kwargs["args"]
        if "traits" in kwargs:
            t.traits |= kwargs["traits"]
            del kwargs["traits"]

        t.binding = sig.bind(name=name, self=t, **kwargs)
        t.binding.apply_defaults()

        unmaterialisedTargets[t] = None
        if replaces:
            t.materialise(replacing=True)
        return t

    defaultGlobals[func.__name__] = wrapper
    return wrapper


def _isiterable(xs):
    return isinstance(xs, Iterable) and not isinstance(
        xs, (str, bytes, bytearray)
    )


class Target:
    def __init__(self, cwd, name):
        if verbose:
            print("rule('%s', cwd='%s'" % (name, cwd))
        self.name = name
        self.localname = self.name.rsplit("+")[-1]
        self.traits = set()
        self.dir = join("$(OBJ)", name)
        self.ins = []
        self.outs = []
        self.deps = []
        self.materialised = False
        self.args = {}

    def __eq__(self, other):
        return self.name is other.name

    def __lt__(self, other):
        return self.name < other.name

    def __hash__(self):
        return id(self)

    def __repr__(self):
        return f"Target('{self.name}')"

    def templateexpand(selfi, s):
        class Formatter(string.Formatter):
            def get_field(self, name, a1, a2):
                return (
                    eval(name, selfi.callback.__globals__, selfi.args),
                    False,
                )

            def format_field(self, value, format_spec):
                if not value:
                    return ""
                if type(value) == str:
                    return value
                if _isiterable(value):
                    value = list(value)
                if type(value) != list:
                    value = [value]
                return " ".join(
                    [selfi.templateexpand(f) for f in filenamesof(value)]
                )

        return Formatter().format(s)

    def materialise(self, replacing=False):
        if self not in unmaterialisedTargets:
            return

        if not replacing and self in materialisingStack:
            print("Found dependency cycle:")
            for i in materialisingStack:
                print(f"  {i.name}")
            print(f"  {self.name}")
            sys.exit(1)
        materialisingStack.append(self)

        # Perform type conversion to the declared rule parameter types.

        try:
            for k, v in self.binding.arguments.items():
                if k != "kwargs":
                    t = self.types.get(k, None)
                    if t:
                        v = t.convert(v, self)
                    self.args[k] = copy(v)
                else:
                    for kk, vv in v.items():
                        t = self.types.get(kk, None)
                        if t:
                            vv = t.convert(v, self)
                        self.args[kk] = copy(vv)
            self.args["name"] = self.name
            self.args["dir"] = self.dir
            self.args["self"] = self

            # Actually call the callback.

            cwdStack.append(self.cwd)
            if "kwargs" in self.binding.arguments.keys():
                # If the caller wants kwargs, return all arguments except the standard ones.
                cbargs = {
                    k: v for k, v in self.args.items() if k not in {"dir"}
                }
            else:
                # Otherwise, just call the callback with the ones it asks for.
                cbargs = {}
                for k in self.binding.arguments.keys():
                    if k != "kwargs":
                        try:
                            cbargs[k] = self.args[k]
                        except KeyError:
                            error(
                                f"invocation of {self} failed because {k} isn't an argument"
                            )
            self.callback(**cbargs)
            cwdStack.pop()
        except BaseException as e:
            print(f"Error materialising {self}: {self.callback}")
            print(f"Arguments: {self.args}")
            raise e

        if self.outs is None:
            raise ABException(f"{self.name} didn't set self.outs")

        if self in unmaterialisedTargets:
            del unmaterialisedTargets[self]
        materialisingStack.pop()
        self.materialised = True

    def convert(value, target):
        if not value:
            return None
        return target.targetof(value)

    def targetof(self, value):
        if isinstance(value, str) and (value[0] == "="):
            value = join(self.dir, value[1:])

        return targetof(value, self.cwd)


def _filetarget(value, cwd):
    if value in targets:
        return targets[value]

    t = Target(cwd, value)
    t.outs = [value]
    targets[value] = t
    return t


def targetof(value, cwd=None):
    if not cwd:
        cwd = cwdStack[-1]
    if isinstance(value, Path):
        value = value.as_posix()
    if isinstance(value, Target):
        t = value
    else:
        assert (
            value[0] != "="
        ), "can only use = for targets associated with another target"

        if value.startswith("."):
            # Check for local rule.
            if value.startswith(".+"):
                value = normpath(join(cwd, value[1:]))
            # Check for local path.
            elif value.startswith("./"):
                value = normpath(join(cwd, value))
        # Explicit directories are always raw files.
        elif value.endswith("/"):
            return _filetarget(value, cwd)
        # Anything starting with a variable expansion is always a raw file.
        elif value.startswith("$"):
            return _filetarget(value, cwd)

        # If this is not a rule lookup...
        if "+" not in value:
            # ...and if the value is pointing at a directory without a trailing /,
            # it's a shorthand rule lookup.
            if isdir(value):
                value = value + "+" + basename(value)
            # Otherwise it's an absolute file.
            else:
                return _filetarget(value, cwd)

        # At this point we have the fully qualified name of a rule.

        (path, target) = value.rsplit("+", 1)
        value = join(path, "+" + target)
        if value not in targets:
            # Load the new build file.

            path = join(path, "build.py")
            try:
                loadbuildfile(path)
            except ModuleNotFoundError:
                error(
                    f"no such build file '{path}' while trying to resolve '{value}'"
                )
            assert (
                value in targets
            ), f"build file at '{path}' doesn't contain '+{target}' when trying to resolve '{value}'"

        t = targets[value]

    t.materialise()
    return t


class Targets:
    def convert(value, target):
        if not value:
            return []
        assert _isiterable(value), "cannot convert non-list to Targets"
        return [target.targetof(x) for x in flatten(value)]


class TargetsMap:
    def convert(value, target):
        if not value:
            return {}
        output = {k: target.targetof(v) for k, v in value.items()}
        for k, v in output.items():
            assert (
                len(filenamesof([v])) == 1
            ), f"targets of a TargetsMap used as an argument of {target} with key '{k}' must contain precisely one output file, but was {filenamesof([v])}"
        return output


def loadbuildfile(filename):
    filename = filename.replace("/", ".").removesuffix(".py")
    builtins.__import__(filename)


def flatten(items):
    def generate(xs):
        for x in xs:
            if _isiterable(x):
                yield from generate(x)
            else:
                yield x

    return list(generate(items))


def targetnamesof(items):
    assert _isiterable(items), "argument of filenamesof is not a collection"

    return [t.name for t in items]


def filenamesof(items):
    assert _isiterable(items), "argument of filenamesof is not a collection"

    def generate(xs):
        for x in xs:
            if isinstance(x, Target):
                yield from generate(x.outs)
            else:
                yield x

    return list(generate(items))


def filenameof(x):
    xs = filenamesof(x.outs)
    assert (
        len(xs) == 1
    ), f"tried to use filenameof() on {x} which does not have exactly one output: {x.outs}"
    return xs[0]


def emit(*args, into=None):
    s = " ".join(args) + "\n"
    if into is not None:
        into += [s]
    else:
        outputFp.write(s)


def emit_rule(name, ins, outs, cmds=[], label=None):
    fins = filenamesof(ins)
    fouts = filenamesof(outs)
    nonobjs = [f for f in fouts if not f.startswith("$(OBJ)")]

    emit("")

    lines = []
    if nonobjs:
        emit("clean::", into=lines)
        emit("\t$(hide) rm -f", *nonobjs, into=lines)

    emit(".PHONY:", name, into=lines)
    if outs:
        emit(name, ":", *fouts, into=lines)
        emit(*fouts, "&:" if len(fouts) > 1 else ":", *fins, "\x01", into=lines)

        if label:
            emit("\t$(hide)", "$(ECHO) $(PROGRESSINFO)", label, into=lines)
        for c in cmds:
            emit("\t$(hide)", c, into=lines)
    else:
        assert len(cmds) == 0, "rules with no outputs cannot have commands"
        emit(name, ":", *fins, into=lines)

    cmd = "".join(lines)
    hash = hashlib.sha1(bytes(cmd, "utf-8")).hexdigest()

    outputFp.write(cmd.replace("\x01", f"$(OBJ)/.hashes/{hash}"))

    if outs:
        emit(f"$(OBJ)/.hashes/{hash}:")
        emit(
            f"\t$(hide) mkdir -p $(OBJ)/.hashes && touch $(OBJ)/.hashes/{hash}"
        )
    emit("")


@Rule
def simplerule(
    self,
    name,
    ins: Targets = [],
    outs: Targets = [],
    deps: Targets = [],
    commands=[],
    label="RULE",
):
    self.ins = ins
    self.outs = outs
    self.deps = deps

    dirs = []
    cs = []
    for out in filenamesof(outs):
        dir = dirname(out)
        if dir and dir not in dirs:
            dirs += [dir]

        cs = [("mkdir -p %s" % dir) for dir in dirs]

    for c in commands:
        cs += [self.templateexpand(c)]

    emit_rule(
        name=self.name,
        ins=ins + deps,
        outs=outs,
        label=self.templateexpand("{label} {name}") if label else None,
        cmds=cs,
    )


@Rule
def export(self, name=None, items: TargetsMap = {}, deps: Targets = []):
    ins = []
    outs = []
    for dest, src in items.items():
        dest = self.targetof(dest)
        outs += [dest]

        destf = filenameof(dest)

        srcs = filenamesof([src])
        assert (
            len(srcs) == 1
        ), "a dependency of an exported file must have exactly one output file"

        subrule = simplerule(
            name=f"{self.localname}/{destf}",
            cwd=self.cwd,
            ins=[srcs[0]],
            outs=[destf],
            commands=["$(CP) %s %s" % (srcs[0], destf)],
            label="",
        )
        subrule.materialise()

    simplerule(
        replaces=self,
        ins=outs + deps,
        outs=["=sentinel"],
        commands=["touch {outs[0]}"],
        label="EXPORT",
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("-v", "--verbose", action="store_true")
    parser.add_argument("-q", "--quiet", action="store_true")
    parser.add_argument("-o", "--output")
    parser.add_argument("files", nargs="+")
    args = parser.parse_args()

    global verbose
    verbose = args.verbose

    global quiet
    quiet = args.quiet

    global outputFp
    outputFp = open(args.output, "wt")

    for k in ["Rule"]:
        defaultGlobals[k] = globals()[k]

    global __name__
    sys.modules["build.ab"] = sys.modules[__name__]
    __name__ = "build.ab"

    for f in args.files:
        loadbuildfile(f)

    while unmaterialisedTargets:
        t = next(iter(unmaterialisedTargets))
        t.materialise()
    emit("AB_LOADED = 1\n")


main()

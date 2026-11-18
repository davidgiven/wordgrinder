from collections import namedtuple
from copy import copy
from importlib.machinery import SourceFileLoader, PathFinder, ModuleSpec
from os.path import *
from pathlib import Path
from typing import Iterable
import argparse
import ast
import builtins
import functools
import hashlib
import importlib
import importlib.util
import inspect
import json
import os
import re
import string
import sys
import types
import shlex

VERBOSE_NINJA_FILE = False

quiet = False
cwdStack = [""]
targets = {}
unmaterialisedTargets = {}  # dict, not set, to get consistent ordering
materialisingStack = []
defaultGlobals = {}
outputTargets = set()
commandsDb = []

RE_FORMAT_SPEC = re.compile(
    r"(?:(?P<fill>[\s\S])?(?P<align>[<>=^]))?"
    r"(?P<sign>[- +])?"
    r"(?P<pos_zero>z)?"
    r"(?P<alt>#)?"
    r"(?P<zero_padding>0)?"
    r"(?P<width_str>\d+)?"
    r"(?P<grouping>[_,])?"
    r"(?:(?P<decimal>\.)(?P<precision_str>\d+))?"
    r"(?P<type>[bcdeEfFgGnosxX%])?"
)

CommandFormatSpec = namedtuple(
    "CommandFormatSpec", RE_FORMAT_SPEC.groupindex.keys()
)

sys.path += ["."]
old_import = builtins.__import__


class Environment(types.SimpleNamespace):
    def setdefault(self, name, value):
        if not hasattr(self, name):
            setattr(self, name, value)


G = Environment()


class PathFinderImpl(PathFinder):
    def find_spec(self, fullname, path, target=None):
        # The second test here is needed for Python 3.9.
        if not path or not path[0]:
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


def _undo_escaped_dollar(s, op):
    return s.replace(f"$${op}", f"${op}")


class BracketedFormatter(string.Formatter):
    def parse(self, format_string):
        return self._parse_cached(format_string)

    @staticmethod
    @functools.lru_cache(maxsize=4096)
    def _parse_cached(format_string):
        # Cache a reusable tuple, rather than an exhaustible generator. Parsing
        # is target-independent; expression values must still be evaluated live.
        return tuple(BracketedFormatter._parse_parts(format_string))

    @staticmethod
    def _parse_parts(format_string):
        while format_string:
            m = re.search(f"(?:[^$]|^)()\\$\\[()", format_string)
            if not m:
                yield (
                    _undo_escaped_dollar(format_string, "["),
                    None,
                    None,
                    None,
                )
                break
            left = format_string[: m.start(1)]
            right = format_string[m.end(2) :]

            offset = len(right) + 1
            try:
                ast.parse(right)
            except SyntaxError as e:
                if not str(e).startswith(f"unmatched ']'"):
                    raise e
                offset = e.offset

            expr = right[0 : offset - 1]
            format_string = right[offset:]

            yield (
                _undo_escaped_dollar(left, "[") if left else None,
                expr,
                None,
                None,
            )


class GlobalFormatter(string.Formatter):
    def parse(self, format_string):
        return self._parse_cached(format_string)

    @staticmethod
    @functools.lru_cache(maxsize=4096)
    def _parse_cached(format_string):
        return tuple(GlobalFormatter._parse_parts(format_string))

    @staticmethod
    def _parse_parts(format_string):
        while format_string:
            m = re.search(f"(?:[^$]|^)()\\$\\(([^)]*)\\)()", format_string)
            if not m:
                yield (
                    format_string,
                    None,
                    None,
                    None,
                )
                break
            left = format_string[: m.start(1)]
            var = m[2]
            format_string = format_string[m.end(3) :]

            yield (
                left if left else None,
                var,
                None,
                None,
            )

    def get_field(self, name, a1, a2):
        return (
            getattr(G, name),
            False,
        )

    def format_field(self, value, format_spec):
        if not value:
            return ""
        return str(value)


globalFormatter = GlobalFormatter()


def substituteGlobalVariables(value):
    if "$(" not in value:
        return value
    while True:
        oldValue = value
        value = globalFormatter.format(value)
        if value == oldValue:
            return _undo_escaped_dollar(value, "(")


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
            t.explicit_args = kwargs["args"]
            t.args.update(t.explicit_args)
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


@functools.lru_cache(maxsize=4096)
def _compile_expression(expression):
    # eval(str) skips leading spaces and tabs before compiling its expression.
    return compile(expression.lstrip(" \t"), "<string>", "eval")


class TargetFormatter(BracketedFormatter):
    def __init__(self, target):
        self.target = target

    def get_field(self, name, a1, a2):
        return (
            eval(
                _compile_expression(name),
                self.target.callback.__globals__,
                self.target.args,
            ),
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
            [self.target.templateexpand(f) for f in filenamesof(value)]
        )


class Target:
    def __init__(self, cwd, name):
        self.name = name
        self.localname = self.name.rsplit("+")[-1]
        self.traits = set()
        self.dir = join(G.OBJ, name)
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

    def templateexpand(self, s):
        if "$[" not in s:
            return substituteGlobalVariables(s)
        s = TargetFormatter(self).format(s)
        return substituteGlobalVariables(s)

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


def getcwd():
    return cwdStack[-1]


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
        if value.endswith("/"):
            return _filetarget(value, cwd)
        # Anything in .obj is a raw file.
        elif value.startswith(outputdir) or value.startswith(G.OBJ):
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

        path, target = value.rsplit("+", 1)
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


def _removesuffix(self, suffix):
    # suffix='' should not call self[:-0].
    if suffix and self.endswith(suffix):
        return self[: -len(suffix)]
    else:
        return self[:]


def loadbuildfile(filename):
    modulename = _removesuffix(filename.replace("/", "."), ".py")
    if modulename not in sys.modules:
        spec = importlib.util.spec_from_file_location(
            name=modulename,
            location=filename,
            loader=BuildFileLoaderImpl(fullname=modulename, path=filename),
            submodule_search_locations=[],
        )
        module = importlib.util.module_from_spec(spec)
        sys.modules[modulename] = module
        spec.loader.exec_module(module)


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
                x.materialise()
                yield from generate(x.outs)
            else:
                yield x

    return list(generate(items))


def filenameof(x):
    x = targetof(x)
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
        ninjaFp.write(s)


def shell(*args):
    s = "".join(args) + "\n"
    shellFp.write(s)


def add_commanddb_entry(commands, file):
    global commandsDb
    commandsDb += [
        {
            "directory": os.getcwd(),
            "command": (" && ".join(commands)),
            "file": file,
        }
    ]


def emit_rule(self, ins, outs, cmds=[], label=None):
    name = self.name
    fins = [self.templateexpand(f) for f in set(filenamesof(ins))]
    fouts = [self.templateexpand(f) for f in filenamesof(outs)]

    global outputTargets
    outputTargets.update(fouts)
    outputTargets.add(name)

    emit("")
    if VERBOSE_NINJA_FILE:
        for k, v in self.args.items():
            emit(f"# {k} = {v}")

    if outs:
        os.makedirs(self.dir, exist_ok=True)

        # Write the actual commands to a shell script.

        rule = []
        for c in cmds:
            emit(f"( {c} )", into=rule)
        ruletext = "".join(rule)
        rulehash = hashlib.sha1(ruletext.encode()).hexdigest()

        rulef = join(self.dir, f"rule-{rulehash}.sh")
        with open(rulef, "wt") as fp:
            fp.write("set -e\n")
            fp.write(ruletext)

        # Generate the invocation of the shell script, either directly or through bubblewrap.

        rule = []
        if G.AB_SANDBOX == "yes":
            bwrap = join(self.dir, "bwrap.args")
            with open(bwrap, "wb") as fp:
                cwd = os.getcwd()

                def robind(f):
                    ff = join(cwd, f)
                    ffb = f"{ff}\0".encode("utf-8")
                    fp.write(b"--ro-bind\0")
                    fp.write(ffb)
                    fp.write(ffb)

                fp.write(b"--dev-bind\0/\0/\0")
                fp.write(b"--bind\0")
                fp.write(f"{cwd}/{self.dir}/sandbox".encode("utf-8") + b"\0")
                fp.write(f"{cwd}".encode("utf-8") + b"\0")
                for f in fins + [rulef]:
                    robind(f)
            emit(f"rm -rf ", f"{self.dir}/sandbox", into=rule)
            emit(f"mkdir -p ", f"{self.dir}/sandbox", into=rule)

            emit(G.BWRAP, f"--args 3 3<", bwrap, "sh", rulef, into=rule)
            for f in fouts:
                emit(f"cp {self.dir}/sandbox/{f} {f}", into=rule)
        else:
            emit(f"sh", rulef, into=rule)

        # Now generate the ninja build rule.

        emit("build", *fouts, ":rule", *fins)
        emit(
            " command=",
            "&&".join([s.strip() for s in rule]).replace("$", "$$"),
        )
        if label:
            emit(" description=", label)
        emit("build", name, ":phony", *fouts)
    else:
        assert len(cmds) == 0, "rules with no outputs cannot have commands"
        emit("build", name, ":phony", *fins)

    emit("")


@Rule
def simplerule(
    self,
    name,
    ins: Targets = [],
    outs: Targets = [],
    deps: Targets = [],
    commands=[],
    add_to_commanddb=False,
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

    coreCommands = []
    for c in commands:
        coreCommands += [self.templateexpand(c)]
    cs += coreCommands

    if add_to_commanddb:
        infiles = filenamesof(ins)
        if len(infiles) > 0:
            global commandsDb
            commandsDb += [
                {
                    "directory": os.getcwd(),
                    "command": (" && ".join(coreCommands)),
                    "file": infiles[0],
                }
            ]

    emit_rule(
        self=self,
        ins=ins + deps,
        outs=outs,
        label=self.templateexpand("$[label] $[name]") if label else None,
        cmds=cs,
    )


@Rule
def export(self, name=None, items: TargetsMap = {}, deps: Targets = []):
    ins = []
    outs = []
    for dest, src in items.items():
        dest = self.targetof(dest)
        outs += [dest]

        destf = self.templateexpand(filenameof(dest))
        outputTargets.update([destf])

        srcs = filenamesof([src])
        assert (
            len(srcs) == 1
        ), "a dependency of an exported file must have exactly one output file"
        srcf = self.templateexpand(srcs[0])

        subrule = simplerule(
            name=f"{self.localname}/{destf}",
            cwd=self.cwd,
            ins=[srcs[0]],
            outs=[destf],
            commands=["$(CP) -H %s %s" % (srcf, destf)],
            label="EXPORT",
        )
        subrule.materialise()

    self.ins = []
    self.outs = deps + outs
    outputTargets.add(name)

    emit("")
    emit(
        "build",
        name,
        ":phony",
        *[self.templateexpand(f) for f in filenamesof(outs + deps)],
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("-q", "--quiet", action="store_true")
    parser.add_argument("-v", "--varfile")
    parser.add_argument("-o", "--outputdir")
    parser.add_argument("-D", "--define", action="append", default=[])
    parser.add_argument("files", nargs="+")
    args = parser.parse_args()

    global quiet
    quiet = args.quiet

    vardefs = args.define
    if args.varfile:
        with open(args.varfile, "rt") as fp:
            vardefs = vardefs + list(fp)

    for line in vardefs:
        if "=" in line:
            name, value = line.split("=", 1)
            G.setdefault(name.strip(), value.strip())
    G.setdefault("AB_SANDBOX", "yes")

    global ninjaFp, shellFp, jsonFp, outputdir
    outputdir = args.outputdir
    G.setdefault("OBJ", outputdir)
    ninjaFp = open(outputdir + "/build.ninja", "wt")
    ninjaFp.write(f"include build/ab.ninja\n")

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

    with open(outputdir + "/build.targets", "wt") as fp:
        fp.write("ninja-targets =")
        fp.write(substituteGlobalVariables(" ".join(outputTargets)))

    with open(outputdir + "/compile_commands.json", "wt") as fp:
        json.dump(commandsDb, fp)


main()

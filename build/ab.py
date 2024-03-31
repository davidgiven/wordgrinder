from collections.abc import Iterable, Sequence
from os.path import *
from types import SimpleNamespace
import argparse
import functools
import importlib
import importlib.abc
import importlib.util
import inspect
import re
import sys
import builtins
import string
import fnmatch
import traceback

defaultGlobals = {}
targets = {}
unmaterialisedTargets = set()
materialisingStack = []
outputFp = None
cwdStack = [""]

sys.path += ["."]
old_import = builtins.__import__


def new_import(name, *args, **kwargs):
    if name not in sys.modules:
        path = name.replace(".", "/") + ".py"
        if isfile(path):
            sys.stderr.write(f"loading {path}\n")
            loader = importlib.machinery.SourceFileLoader(name, path)

            spec = importlib.util.spec_from_loader(
                name, loader, origin="built-in"
            )
            module = importlib.util.module_from_spec(spec)
            sys.modules[name] = module
            cwdStack.append(dirname(path))
            spec.loader.exec_module(module)
            cwdStack.pop()

    return old_import(name, *args, **kwargs)


builtins.__import__ = new_import


class ABException(BaseException):
    pass


class Invocation:
    name = None
    callback = None
    types = None
    ins = None
    outs = None
    binding = None
    traits = None
    attr = None
    attrdeps = None

    def __init__(self):
        self.attr = SimpleNamespace()
        self.attrdeps = SimpleNamespace()
        self.traits = set()

    def __eq__(self, other):
        return self.name is other.name

    def __hash__(self):
        return id(self.name)

    def materialise(self, replacing=False):
        if self in unmaterialisedTargets:
            if not replacing and (self in materialisingStack):
                print("Found dependency cycle:")
                for i in materialisingStack:
                    print(f"  {i.name}")
                print(f"  {self.name}")
                sys.exit(1)

            materialisingStack.append(self)

            # Perform type conversion to the declared rule parameter types.

            try:
                self.args = {}
                for k, v in self.binding.arguments.items():
                    if k != "kwargs":
                        t = self.types.get(k, None)
                        if t:
                            v = t(v).convert(self)
                        self.args[k] = v
                    else:
                        for kk, vv in v.items():
                            t = self.types.get(kk, None)
                            if t:
                                vv = t(vv).convert(self)
                            self.args[kk] = vv

                # Actually call the callback.

                cwdStack.append(self.cwd)
                self.callback(**self.args)
                cwdStack.pop()
            except BaseException as e:
                print(f"Error materialising {self}: {self.callback}")
                print(f"Arguments: {self.args}")
                raise e

            if self.outs is None:
                raise ABException(f"{self.name} didn't set self.outs")

            if self in unmaterialisedTargets:
                unmaterialisedTargets.remove(self)

            materialisingStack.pop()

    def bubbleattr(self, attr, xs):
        xs = targetsof(xs, cwd=self.cwd)
        a = set()
        if hasattr(self.attrdeps, attr):
            a = getattr(self.attrdeps, attr)

        for x in xs:
            a.add(x)
        setattr(self.attrdeps, attr, a)

    def __repr__(self):
        return "'%s'" % self.name


def Rule(func):
    sig = inspect.signature(func)

    @functools.wraps(func)
    def wrapper(*, name=None, replaces=None, **kwargs):
        cwd = None
        if name:
            if ("+" in name) and not name.startswith("+"):
                (cwd, _) = name.split("+", 1)
        if not cwd:
            cwd = cwdStack[-1]

        if name:
            i = Invocation()
            if name.startswith("./"):
                name = join(cwd, name)
            elif "+" not in name:
                name = join(cwd, "+" + name)

            i.name = name
            i.localname = name.split("+")[-1]

            if name in targets:
                raise ABException(f"target {i.name} has already been defined")
            targets[name] = i
        elif replaces:
            i = replaces
            name = i.name
        else:
            raise ABException("you must supply either 'name' or 'replaces'")

        i.cwd = cwd
        i.sentinel = "$(OBJ)/.sentinels/" + name + ".mark"
        i.types = func.__annotations__
        i.callback = func
        i.traits.add(func.__name__)

        i.binding = sig.bind(name=name, self=i, **kwargs)
        i.binding.apply_defaults()

        unmaterialisedTargets.add(i)
        if replaces:
            i.materialise(replacing=True)
        return i

    defaultGlobals[func.__name__] = wrapper
    return wrapper


class Type:
    def __init__(self, value):
        self.value = value


class List(Type):
    def convert(self, invocation):
        value = self.value
        if not value:
            return []
        if type(value) is str:
            return [value]
        return list(value)


class Targets(Type):
    def convert(self, invocation):
        value = self.value
        if not value:
            return []
        if type(value) is str:
            value = [value]
        if type(value) is list:
            value = targetsof(value, cwd=invocation.cwd)
        return value


class Target(Type):
    def convert(self, invocation):
        value = self.value
        if not value:
            return None
        return targetof(value, cwd=invocation.cwd)


class TargetsMap(Type):
    def convert(self, invocation):
        value = self.value
        if not value:
            return {}
        if type(value) is dict:
            return {
                k: targetof(v, cwd=invocation.cwd) for k, v in value.items()
            }
        raise ABException(f"wanted a dict of targets, got a {type(value)}")


def flatten(*xs):
    def recurse(xs):
        for x in xs:
            if isinstance(x, Iterable) and not isinstance(x, (str, bytes)):
                yield from recurse(x)
            else:
                yield x

    return list(recurse(xs))


def fileinvocation(s):
    i = Invocation()
    i.name = s
    i.outs = [s]
    targets[s] = i
    return i


def targetof(s, cwd=None):
    if isinstance(s, Invocation):
        s.materialise()
        return s

    if type(s) != str:
        raise ABException("parameter of targetof is not a single target")

    if s in targets:
        t = targets[s]
        t.materialise()
        return t

    if s.startswith("."):
        if cwd == None:
            raise ABException(
                "relative target names can't be used in targetof without supplying cwd"
            )
        if s.startswith(".+"):
            s = cwd + s[1:]
        elif s.startswith("./"):
            s = normpath(join(cwd, s))

    elif s.endswith("/"):
        return fileinvocation(s)
    elif s.startswith("$"):
        return fileinvocation(s)

    if "+" not in s:
        if isdir(s):
            s = s + "+" + basename(s)
        else:
            return fileinvocation(s)

    (path, target) = s.split("+", 2)
    s = join(path, "+" + target)
    loadbuildfile(join(path, "build.py"))
    if not s in targets:
        raise ABException(
            f"build file at {path} doesn't contain +{target} when trying to resolve {s}"
        )
    i = targets[s]
    i.materialise()
    return i


def targetsof(*xs, cwd=None):
    return flatten([targetof(x, cwd) for x in flatten(xs)])


def filenamesof(*xs):
    s = []
    for t in flatten(xs):
        if type(t) == str:
            t = normpath(t)
            s += [t]
        else:
            s += [f for f in [normpath(f) for f in filenamesof(t.outs)]]
    return s


def filenamesmatchingof(xs, pattern):
    return fnmatch.filter(filenamesof(xs), pattern)


def targetswithtraitsof(xs, trait):
    return [target for target in targetsof(xs) if trait in target.traits]


def targetnamesof(*xs):
    s = []
    for x in flatten(xs):
        if type(x) == str:
            x = normpath(x)
            if x not in s:
                s += [x]
        else:
            if x.name not in s:
                s += [x.name]
    return s


def filenameof(x):
    xs = filenamesof(x)
    if len(xs) != 1:
        raise ABException("expected a single item")
    return xs[0]


def bubbledattrsof(x, attr):
    x = targetsof(x)
    alltargets = set()
    pending = set(x) if isinstance(x, Iterable) else {x}
    while pending:
        t = pending.pop()
        if t not in alltargets:
            alltargets.add(t)
            if hasattr(t.attrdeps, attr):
                pending.update(getattr(t.attrdeps, attr))

    values = []
    for t in alltargets:
        if hasattr(t.attr, attr):
            values += getattr(t.attr, attr)
    return values


def stripext(path):
    return splitext(path)[0]


def emit(*args):
    outputFp.write(" ".join(flatten(args)))
    outputFp.write("\n")


def templateexpand(s, invocation):
    class Formatter(string.Formatter):
        def get_field(self, name, a1, a2):
            return (
                eval(name, invocation.callback.__globals__, invocation.args),
                False,
            )

        def format_field(self, value, format_spec):
            if type(self) == str:
                return value
            return " ".join(
                [templateexpand(f, invocation) for f in filenamesof(value)]
            )

    return Formatter().format(s)


def emitter_rule(rule, ins, outs, deps=[]):
    emit("")
    emit(".PHONY:", rule.name)
    emit(rule.name, ":", rule.sentinel)

    emit(
        rule.sentinel,
        # filenamesof(outs) if outs else [],
        ":",
        filenamesof(ins),
        filenamesof(deps),
    )


def emitter_endrule(rule, outs):
    emit("\t$(hide) mkdir -p", dirname(rule.sentinel))
    emit("\t$(hide) touch", rule.sentinel)

    for f in filenamesof(outs):
        emit(".SECONDARY:", f)
        emit(f, ":", rule.sentinel, ";")


def emitter_label(s):
    emit("\t$(hide)", "$(ECHO)", s)


def emitter_exec(cs):
    for c in cs:
        emit("\t$(hide)", c)


def unmake(*ss):
    return [
        re.sub(r"\$\(([^)]*)\)", r"$\1", s) for s in flatten(filenamesof(ss))
    ]


@Rule
def simplerule(
    self,
    name,
    ins: Targets = None,
    outs: List = [],
    deps: Targets = None,
    commands: List = [],
    label="RULE",
    **kwargs,
):
    self.ins = ins
    self.outs = outs
    self.deps = deps
    emitter_rule(self, ins + deps, outs)
    emitter_label(templateexpand("{label} {name}", self))

    dirs = []
    cs = []
    for out in filenamesof(outs):
        dir = dirname(out)
        if dir and dir not in dirs:
            dirs += [dir]

        cs = [("mkdir -p %s" % dir) for dir in dirs]

    for c in commands:
        cs += [templateexpand(c, self)]

    emitter_exec(cs)
    emitter_endrule(self, outs)


@Rule
def normalrule(
    self,
    name=None,
    ins: Targets = None,
    deps: Targets = None,
    outs: List = [],
    label="RULE",
    objdir=None,
    commands: List = [],
    **kwargs,
):
    objdir = objdir or join("$(OBJ)", name)

    self.attr.objdir = objdir
    simplerule(
        replaces=self,
        ins=ins,
        deps=deps,
        outs=[join(objdir, f) for f in outs],
        label=label,
        commands=commands,
        **kwargs,
    )


@Rule
def export(self, name=None, items: TargetsMap = {}, deps: Targets = None):
    cs = []
    self.ins = []
    self.outs = []
    for dest, src in items.items():
        destf = filenameof(dest)
        dir = dirname(destf)

        srcs = filenamesof(src)
        if len(srcs) != 1:
            raise ABException(
                "a dependency of an export must have exactly one output file"
            )

        subrule = simplerule(
            name=self.name + "/+" + destf,
            ins=[srcs[0]],
            outs=[destf],
            commands=["cp %s %s" % (srcs[0], destf)],
            label="CP",
        )
        subrule.materialise()
        emit("clean::")
        emit("\t$(hide) rm -f", destf)

        self.ins += [subrule]

    emitter_rule(
        self,
        self.ins,
        self.outs,
        [(d.outs if d.outs else d.sentinel) for d in deps],
    )
    emitter_endrule(self, self.outs)


def loadbuildfile(filename):
    filename = filename.replace("/", ".").removesuffix(".py")
    builtins.__import__(filename)


def load(filename):
    loadbuildfile(filename)
    callerglobals = inspect.stack()[1][0].f_globals
    for k, v in defaultGlobals.items():
        callerglobals[k] = v


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("-o", "--output")
    parser.add_argument("files", nargs="+")
    parser.add_argument("-t", "--targets", action="append")
    args = parser.parse_args()
    if not args.targets:
        raise ABException("no targets supplied")

    global outputFp
    outputFp = open(args.output, "wt")

    for k in ("Rule", "Targets", "load", "filenamesof", "stripext"):
        defaultGlobals[k] = globals()[k]

    global __name__
    sys.modules["build.ab"] = sys.modules[__name__]
    __name__ = "build.ab"

    for f in args.files:
        loadbuildfile(f)

    for t in flatten([a.split(",") for a in args.targets]):
        (path, target) = t.split("+", 2)
        s = join(path, "+" + target)
        if s not in targets:
            raise ABException("target %s is not defined" % s)
        targets[s].materialise()
    emit("AB_LOADED = 1\n")


main()

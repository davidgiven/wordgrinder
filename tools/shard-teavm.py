import hashlib
import json
import re
import sys
from pathlib import Path, PurePosixPath


DIRECTIVE = re.compile(r"^\s*#\s*(\w+)\s*(.*)")
QUOTED_HEADER = re.compile(r'^"([^"]+)"')


def expand(source_dir, path, output, seen, active, unconditional=True):
    # Translate pragma once to a guard that also works inside conditional includes.
    relative = path.relative_to(source_dir).as_posix()
    lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
    once = "#pragma once" in {line.strip() for line in lines}
    if path in seen or (once and path in active):
        return
    if path in active:
        raise ValueError(f"Recursive generated include in {relative}")
    if once and unconditional:
        seen.add(path)

    # Preserve original source locations and leave system and adapter headers to cc.
    active.add(path)
    guard = "WG_TEAVM_" + hashlib.sha256(relative.encode()).hexdigest().upper()
    if once:
        output.write(f"#ifndef {guard}\n#define {guard}\n")
    source_name = json.dumps(relative, ensure_ascii=False)
    output.write(f"#line 1 {source_name}\n")
    depth = 0
    for number, line in enumerate(lines, 1):
        directive = DIRECTIVE.match(line)
        if directive:
            kind, argument = directive.groups()
            if kind in {"if", "ifdef", "ifndef"}:
                depth += 1
            elif kind == "endif":
                depth -= 1
            elif kind == "pragma" and argument.strip() == "once":
                output.write("\n")
                continue
            elif kind == "include" and (header := QUOTED_HEADER.match(argument)):
                for directory in (path.parent, source_dir):
                    included = (directory / header[1]).resolve()
                    if included.is_relative_to(source_dir) and included.is_file():
                        expand(source_dir, included, output, seen, active, unconditional and depth == 0)
                        output.write(f"#line {number + 1} {source_name}\n")
                        break
                else:
                    output.write(line)
                continue
        output.write(line.rstrip("\n") + "\n")
    if once:
        output.write("#endif\n")
    active.remove(path)


def main(source_dir, outputs):
    source_dir = source_dir.resolve()
    # Keep TeaVM's feature macros without overriding compiler definitions.
    prologue = []
    for line in (source_dir / "all.c").read_text(encoding="utf-8").splitlines():
        if line.startswith("#define "):
            name = line.split()[1]
            prologue.append(f"#ifndef {name}\n{line}\n#endif\n")
    shards = [[] for _ in outputs]

    # TeaVM escapes the JVM's dollar sign as @d in C filenames.
    # Sort the manifest so TeaVM's enumeration order cannot alter a shard.
    manifest = (source_dir / "all.txt").read_text(encoding="utf-8")
    for filename in sorted(manifest.splitlines()):
        if not filename:
            continue
        path = PurePosixPath(filename)
        if path.parts[0] == "classes":
            outer = path.stem.split("@d", 1)[0].split("$", 1)[0]
            key = str(path.with_name(outer + path.suffix))
        else:
            key = filename
        digest = hashlib.sha256(key.encode("utf-8")).digest()
        shards[digest[0] % len(shards)].append(source_dir / filename)

    # Emit every shard, including empty ones, in the order declared by the build.
    for path, sources in zip(outputs, shards):
        with path.open("w", encoding="utf-8", newline="\n") as output:
            output.writelines(prologue)
            seen = set()
            for source in sources:
                expand(source_dir, source, output, seen, set())


if __name__ == "__main__":
    main(Path(sys.argv[1]), [Path(arg) for arg in sys.argv[2:]])

from build.ab2 import export

export(
    name="all",
    items={"bin/wordgrinder": "src/c+wordgrinder"},
    deps=["tests", "src/lua+typecheck"],
)

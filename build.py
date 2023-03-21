from build.ab2 import export
from config import TEST_BINARY

export(
    name="all",
    items={
        "bin/wordgrinder": TEST_BINARY,
        "bin/xwordgrinder": "src/c+wordgrinder-glfw",
    },
    deps=["tests", "src/lua+typecheck"],
)

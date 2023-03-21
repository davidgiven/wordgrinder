from build.ab2 import DefaultVars
from build.c import clibrary
from build.pkg import package

package(name="libglfw3", package="glfw3")
package(name="opengl", package="opengl")

clibrary(
    name="glfw",
    srcs=["./font.cc", "./main.cc", "./utils.cc"],
    vars=DefaultVars + {"+cflags": ["-I./src/c"]},
    deps=["src/c+globals", "third_party/libstb", "+libglfw3", "+opengl"],
)

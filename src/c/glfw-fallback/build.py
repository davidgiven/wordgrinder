from build.ab import simplerule

r = simplerule(
    name="glfw-fallback",
    ins=[],
    outs=[
        "=glfw-3.4.bin.WIN32/include/GLFW/glfw3.h",
        "=glfw-3.4.bin.WIN32/include/GLFW/glfw3native.h",
        "=glfw-3.4.bin.WIN32/lib-mingw-w64/libglfw3.a",
    ],
    commands=[
        "curl -Ls https://github.com/glfw/glfw/releases/download/3.4/glfw-3.4.bin.WIN32.zip -o {dir}/glfw.zip",
        "cd {dir} && unzip -q glfw.zip",
    ],
    label="CURLLIBRARY",
    traits={"clibrary", "cheaders"},
    args={"caller_cflags": ["-I{dir}/glfw-3.4.bin.WIN32/include"]},
)

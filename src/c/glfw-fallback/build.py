from build.ab import normalrule

r = normalrule(
    name="glfw-fallback",
    ins=[],
    outs=[
        "glfw-3.4.bin.WIN32/include/GLFW/glfw3.h",
        "glfw-3.4.bin.WIN32/include/GLFW/glfw3native.h",
        "glfw-3.4.bin.WIN32/lib-mingw-w64/libglfw3.a",
    ],
    commands=[
        "curl -Ls https://github.com/glfw/glfw/releases/download/3.4/glfw-3.4.bin.WIN32.zip -o {self.attr.objdir}/glfw.zip",
        "cd {self.attr.objdir} && unzip -q glfw.zip",
    ],
    label="CURLLIBRARY",
)
r.traits.add("clibrary")
r.traits.add("cheaders")
r.materialise()
r.attr.caller_cflags = ["-I" + r.attr.objdir + "/glfw-3.4.bin.WIN32/include"]

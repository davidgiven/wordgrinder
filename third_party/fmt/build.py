from build.c import cxxlibrary

cxxlibrary(
    name="fmt",
    srcs=[
        "./src/format.cc",
        "./src/os.cc",
    ],
    cflags=["-Ithird_party/fmt/include"],
    hdrs={
        "fmt/args.h": "./include/fmt/args.h",
        "fmt/chrono.h": "./include/fmt/chrono.h",
        "fmt/core.h": "./include/fmt/core.h",
        "fmt/format.h": "./include/fmt/format.h",
        "fmt/ostream.h": "./include/fmt/ostream.h",
        "fmt/ranges.h": "./include/fmt/ranges.h",
    },
)

from build.java import javalibrary

# Backend-independent APIs shared by the application and forms.
javalibrary(
    name="nativeinterface",
    srcitems={
        f"com/cowlark/wordgrinder/nativeinterface/{f}": f"./{f}"
        for f in ["Colour.java", "Clipboard.java", "Display.java", "Screen.java", "System.java"]
    },
    deps=["third_party+org_jspecify_jspecify"],
)

from build.ab import simplerule, Rule, Target, export
from config import TEST_BINARY
from glob import glob

TESTS = [
    "apply-markup",
    "argument-parser",
    "change-paragraph-style",
    "clipboard",
    "delete-selection",
    "escape-strings",
    "export-to-html",
    "export-to-latex",
    "export-to-markdown",
    "export-to-opendocument",
    "export-to-org",
    "export-to-text",
    "export-to-troff",
    "filesystem",
    "find-and-replace",
    "get-style-from-word",
    "heading-styles",
    "immutable-paragraphs",
    "import-from-html",
    "import-from-markdown",
    "import-from-opendocument",
    "import-from-text",
    "insert-space-with-style-hint",
    "line-down-into-style",
    "line-up",
    "line-wrapping",
    "load-0.1",
    "load-0.2",
    "load-0.3.3",
    "load-0.4.1",
    "load-0.5.3",
    "load-0.6",
    "load-0.6-v6",
    "load-0.7.2",
    "load-0.8.crlf",
    "load-0.8",
    "load-failed",
    "lowlevelclipboard",
    "move-while-selected",
    "numbered-lists",
    "parse-string-into-words",
    "save-format-escaped-strings",
    "simple-editing",
    "smartquotes-selection",
    "smartquotes-typing",
    "spellchecker",
    "tableio",
    "type-while-selected",
    "undo",
    "utf8",
    "utils",
    "weirdness-cannot-save-settings",
    "weirdness-combining-words",
    "weirdness-delete-word",
    "weirdness-deletion-with-multiple-spaces",
    "weirdness-documentset-default-name",
    "weirdness-end-of-lines",
    "weirdness-forward-delete",
    "weirdness-globals-applied-on-startup",
    "weirdness-missing-clipboard",
    "weirdness-replacing-words",
    "weirdness-save-new-document",
    "weirdness-splitting-lines-before-space",
    "weirdness-stray-control-char-in-export",
    "weirdness-style-bleeding-on-deletion",
    "weirdness-styled-clipboard",
    "weirdness-styling-unicode",
    "weirdness-upgrade-0.6-with-clipboard",
    "weirdness-word-left-from-end-of-line",
    "weirdness-word-left-on-first-word-in-doc",
    "weirdness-word-right-to-last-word-in-doc",
    "windows-installdir",
    "word",
    "xpattern",
]


@Rule
def test(self, name, exe: Target = None):
    simplerule(
        replaces=self,
        ins=["./" + self.localname + ".lua", exe],
        outs=["=log"],
        deps=["./testsuite.lua"] + glob("testdocs/*"),
        commands=[
            "$[ins[1]] --lua $[ins[0]] >$[outs] 2>&1 || (cat $[outs] && rm -f $[outs] && false)"
        ],
        label="TEST",
    )


tests = [test(name=t, exe=TEST_BINARY) for t in TESTS]

export(name="tests", deps=tests)

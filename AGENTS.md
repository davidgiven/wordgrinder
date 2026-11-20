# Java conventions

- Do not use `@NonNull` annotations.
- Do not use `Objects.requireNonNull` to enforce non-null contracts.
- Place Java tests under top-level `javatests/`, mirroring the package paths under `java/` (Bazel style).
- Use JUnit4 for Java tests, with a package-local `build.py` calling `build.junit4.junit4`, which compiles and runs them through a `test()` rule.
- In all Java build rules, including `javalibrary` and `junit4`, use a dictionary comprehension over an explicit list of relative Java source paths for `srcitems`, rather than `itemsof` globs. Use package paths as keys and build-file-relative source paths as values, even for a single source file.
- Divide code into logical paragraphs separated by blank lines, with a comment before each paragraph explaining its purpose.
- Prefer `/* ... */` block comments over `//` line comments.
- Use British English in comments, documentation, and user-facing text.
- Run exactly one JUnit test class per `junit4()` invocation, using explicit source maps rather than `itemsof`.

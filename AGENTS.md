# Java conventions

- Express non-null contracts with `org.jspecify.annotations.NonNull` (`@NonNull`).
- Do not use `Objects.requireNonNull`; use annotations instead of explicit runtime null checks for these contracts.
- Place Java tests under top-level `javatests/`, mirroring the package paths under `java/` (Bazel style).
- Use JUnit4 for Java tests, with a package-local `build.py` calling `build.junit4.junit4`, which compiles and runs them through a `test()` rule.
- Use `build.utils.itemsof` with repository-relative patterns for Java `srcitems`, e.g. `itemsof("java/com/cowlark/wordgrinder/eventbus/*.java", cwd="")`, instead of manual source lists or relative-root arguments.
- Divide code into logical paragraphs separated by blank lines, with a comment before each paragraph explaining its purpose.
- Prefer `/* ... */` block comments over `//` line comments.
- Use British English in comments, documentation, and user-facing text.

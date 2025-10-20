In all programming languages:

- Always use 2-space indentation unless stated otherwise.
- Always sort literal dictionary keys and interface members alphabetically.
- Avoid single-use local variables, single-use helper functions, and single-use type definitions. Prefer to simply inline them instead.
- Prefer to log before performing actions ("Doing thing...") rather than afterward ("Did thing").
- Never run linters or code formatters. I'll do that myself.

In TypeScript and JavaScript source code:

- Always use arrow functions instead of the `function` keyword.
- Always use spread syntax instead of `Array.from`.
- Prefer `for ... of` loops instead of the `forEach` function.
- Prefer `fetch` for HTTP requests (unless the codebase is already using a library such as Axios).
- Prefer Makefile targets instead of npm scripts.
- Always pin exact dependency versions inside package.json, e.g. never use `^`.
- Prefer double quotes (unless the string contains double quotes).

In Python source code:

- Always use 4-space indentation.
- Always use `re.search` instead of `re.match`.
- Prefer double quotes (unless the string contains double quotes).

In Bash source code:

- Prefer single quotes (unless the string contains an interpolation).
- Always use lowercase snake_case for non-environment variable names.
- Always use `[[` instead of `[`.
- Always include curly braces when interpolating variables, e.g. `${foo}` instead of `$foo`.
- Always include this shebang line: `#!/usr/bin/env bash`

In C# source code:

- Always use K&R-style braces instead of Allman-style braces.

In Makefile source code:

- Always place each `.PHONY` label directly above its corresponding target instead of collecting them all into a single `.PHONY` statement at the top of the file.

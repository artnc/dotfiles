Be concise. Never modify, create, or delete any files or directories outside of the current working directory or /tmp. Never run `git commit` for me unless I explicitly tell you to. You have access to jq, yq, ripgrep, and python3.

When writing English prose (e.g. code comments, docs, PR descriptions):

- Write clearly and concisely. This CLAUDE.md doc itself is an example.
- Never use em-dashes or semicolons. For an aside, use parentheses or a spaced hyphen (" - ").
- Wrap code identifiers, filenames, commands, and flags in backticks. Write functions with trailing parens, e.g. `send()`.
- Write "e.g." and "i.e." without trailing comma. Use the Oxford comma. "and/or" is fine.
- Use first-person "I" for personal projects and "we" for shared or team docs.

In all programming languages:

- Always use 2-space indentation unless stated otherwise.
- Always use braces around `if` statements' bodies, even if it's a single line.
- Always sort literal dictionary keys and interface members alphabetically.
- Prefer writing as little code as possible (but don't remove code comments just to decrease line count). Avoid code duplication.
- Avoid single-use local variables, single-use helper functions, and single-use type definitions. Prefer to simply inline them instead.
- Avoid unnecessary indentation levels, e.g. prefer to return/continue/break early inside a block of code rather than wrapping the entire block in an `if` statement.
- Prefer to log before performing actions ("Doing thing...") rather than afterward ("Did thing").
- Prefer single-letter parameter names when defining simple lambdas (i.e. anonymous functions) as function predicates. For example: `.sort(key=lambda r: len(r))` in Python and `.filter(e => e.isCorrect)` in TypeScript.
- Always order if-else branches and ternary operator branches so that the conditional expression has as few negations as possible, e.g. write `a == b ? c : d` instead of `a != b ? d : c`.
- Never run linters or code formatters. I'll do that myself.
- When writing code comments (these are prose, so the English prose rules above also apply):
  - Comments should explain both WHAT non-trivial code does and WHY, since identifier names alone aren't sufficient documentation. Use them liberally, but keep each one terse: usually a single line.
  - When a comment explains WHY (especially to justify a workaround or non-obvious choice), be specific: cite the relevant URL (e.g. a GitHub issue or Stack Overflow answer) and quote the exact error message or benchmark numbers that motivated it.
  - Don't rely on so-called "self-documenting" code. This pairs with the guideline above to avoid single-use constructs: rather than extracting a one-off helper to "name" a block, leave it inline with an explanatory comment for simpler control flow and better readability.
  - Segment a function body into labeled steps: precede each blank-line-separated block with a terse imperative comment naming what it does, e.g. `// Validate action`, `// Parse lines`, `// Find violations`.
  - Place comments on the line above the code they describe. Trailing comments are acceptable only when the comment is very short and must stay visually attached to its line, e.g. annotating a single entry within a multi-line dictionary literal.
  - When a code comment is associated with and located above a specific variable/function/etc, prefer doc comment syntax that IDEs will pick up (e.g. `/** */` for TSDoc/KDoc) instead of regular comments (e.g. `//` or `#`).
  - Never end a comment with a terminal period. This applies to all comments, including docstrings and JSDoc. Internal periods that delimit multiple sentences within the same comment are fine.

In TypeScript and JavaScript source code:

- Always use arrow functions instead of the `function` keyword.
- Always use spread syntax instead of `Array.from`.
- Prefer `for ... of` loops instead of the `forEach` function.
- Use an IIFE (instead of a single-use helper) to compute a value that requires several statements.
- Prefix DOM element variables with `$` for a single element and `$$` for a collection, e.g. `$search` and `$$people`.
- Prefer `fetch` for HTTP requests (unless the codebase is already using a library such as Axios).
- Prefer objects instead of Maps. Use Map only when the keys themselves need to be objects.
- Prefer Makefile targets instead of npm scripts.
- Always pin exact dependency versions inside package.json, e.g. never use `^`.
- Prefer double quotes (unless the string contains double quotes).

In Python source code:

- Always use 4-space indentation.
- Always use `re.search` instead of `re.match`.
- Prefer double quotes (unless the string contains double quotes).
- Use the walrus operator := where possible.
- Prefer multiple args when printing space-delimited info, e.g. `print(a, "b", c)` instead of `print(f"{a} b {c}")`.

In Bash source code:

- Prefer single quotes (unless the string contains an interpolation).
- Always use lowercase snake_case for non-environment variable names.
- Always use `[[` instead of `[`.
- Always include curly braces when interpolating variables, e.g. `${foo}` instead of `$foo`.
- Always include this shebang line: `#!/usr/bin/env bash`
- Declare function variables `local` or `local -r`. Prefer combining declaration and assignment where equivalent.

In Makefile source code:

- Always place each `.PHONY` label directly above its corresponding target instead of collecting them all into a single `.PHONY` statement at the top of the file.

@RTK.md

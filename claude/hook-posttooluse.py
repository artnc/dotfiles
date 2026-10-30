#!/usr/bin/env python3

import json
import sys

# Read hook input
tool_input = json.load(sys.stdin)["tool_input"]
file = tool_input["file_path"]

# Pick column limit and comment markers by language. Formatters reflow code
# but leave over-long comments untouched, so we only flag comment lines
js = file.endswith((".cjs", ".js", ".jsx", ".mjs", ".ts", ".tsx"))
limit = 80 if js else 100
markers = ("//", "/*", "*") if js else ("#",)

# Read edit text, written file text, or zero-based line numbers from patch tools
new_text = tool_input.get("new_string") or ""
written = tool_input.get("content")
touched_lines = tool_input.get("touched_lines", [])
if not (new_text or written or touched_lines):
    sys.exit(0)

# Read the post-edit file
try:
    content = open(file, encoding="utf-8").read()
except OSError:
    sys.exit(0)
lines = content.split("\n")

# Check every line of a fully written file because a formatter can rewrite its
# text before this hook runs
touched = set(range(len(lines)) if written else touched_lines)

# Map every occurrence of the new text (replace_all can write several) onto the
# full file lines it overlaps. Using whole lines means a fragment swapped into
# an already-long line still flags that line by its resulting length
pos = -1
while new_text and (pos := content.find(new_text, pos + 1)) != -1:
    first = content.count("\n", 0, pos)
    last = content.count("\n", 0, pos + len(new_text) - 1)
    touched.update(range(first, last + 1))

# Find violations among touched comment lines
violations = [
    f"  L{i + 1} ({len(lines[i])} cols)"
    for i in sorted(touched)
    if 0 <= i < len(lines) and len(lines[i]) > limit and lines[i].lstrip().startswith(markers)
]
if violations:
    print(
        f"Found code comment lines over {limit} cols in {file}! Reflow these comment lines (and ONLY these lines) now to prevent the code formatter from crudely chopping them and creating orphans:",
        *violations,
        sep="\n",
        file=sys.stderr,
    )
    sys.exit(2)

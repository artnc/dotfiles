#!/usr/bin/env bash

set -eu

# Determine column limit based on extension
file="$(jq -r '.tool_input.file_path')"
case "${file}" in
  *.ts | *.tsx | *.js | *.jsx | *.mjs | *.cjs) limit=80 ;;
  *) limit=100 ;;
esac

# Find lines that are too long
violations="$(awk -v m="${limit}" \
  'length > m { printf "  L%d (%d cols)\n", NR, length }' "${file}" 2> /dev/null)"
if [[ -n ${violations} ]]; then
  printf 'Lines over %d cols in %s! Rewrap before the formatter reflows and orphans them:\n%s\n' \
    "${limit}" "${file}" "${violations}" >&2
  exit 2
fi

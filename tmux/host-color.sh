#!/usr/bin/env bash
# Pick a color deterministically from the hostname.
# Default is a dark variant (dark enough for WCAG AA contrast against white
# status-bar text); pass 'bright' for a lighter variant of the same hue,
# e.g. for the active pane border against a near-black background.
dark=(
  '#145220' # pine
  '#5C4400' # amber
  '#6B1A1A' # crimson
  '#401A6B' # violet
  '#1A5A5A' # teal
  '#1A276B' # navy
  '#6B1A4D' # plum
  '#6B3A1A' # sienna
)
bright=(
  '#3CB371' # pine
  '#D4A017' # amber
  '#D94545' # crimson
  '#9B59D0' # violet
  '#3CB8B8' # teal
  '#5571E0' # navy
  '#D14A99' # plum
  '#D4823C' # sienna
)
if [[ ${1} == 'bright' ]]; then
  colors=("${bright[@]}")
else
  colors=("${dark[@]}")
fi
n=${#colors[@]}
hostname=$(cat /etc/hostname 2> /dev/null || hostname)
hash=$(printf '%s' "${hostname}" | cksum | cut -d' ' -f1)
echo "${colors[$((hash % n))]}"

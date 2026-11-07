#!/usr/bin/env bash
# Pick a color deterministically from the hostname, in one of three tiers of the
# same hue: the default 'dark', a saturated 'mid' tone, and a 'light' pastel.
# Hex must be lowercase because tmux 3.8 expands styles as formats, e.g.
# '#F08C8C' becomes '*08C8C' since '#F' is the `window_flags` alias
dark=(
  '#145220' # pine
  '#5c4400' # amber
  '#6b1a1a' # crimson
  '#401a6b' # violet
  '#1a5a5a' # teal
  '#1a276b' # navy
  '#6b1a4d' # plum
  '#6b3a1a' # sienna
)
mid=(
  '#3cb371' # pine
  '#d4a017' # amber
  '#d94545' # crimson
  '#9b59d0' # violet
  '#3cb8b8' # teal
  '#5571e0' # navy
  '#d14a99' # plum
  '#d4823c' # sienna
)
light=(
  '#87dda5' # pine
  '#ebcb5e' # amber
  '#f08c8c' # crimson
  '#c9a0e8' # violet
  '#80dada' # teal
  '#9db0f2' # navy
  '#e89ac8' # plum
  '#ebac7b' # sienna
)
case ${1} in
  light) colors=("${light[@]}") ;;
  mid) colors=("${mid[@]}") ;;
  *) colors=("${dark[@]}") ;;
esac
n=${#colors[@]}
hostname=$(cat /etc/hostname 2> /dev/null || hostname)
hash=$(printf '%s' "${hostname}" | cksum | cut -d' ' -f1)
echo "${colors[$((hash % n))]}"

#!/usr/bin/env bash
# Pick a color deterministically from the hostname, in one of three tiers of the
# same hue: the default 'dark', a saturated 'mid' tone, and a 'light' pastel
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
mid=(
  '#3CB371' # pine
  '#D4A017' # amber
  '#D94545' # crimson
  '#9B59D0' # violet
  '#3CB8B8' # teal
  '#5571E0' # navy
  '#D14A99' # plum
  '#D4823C' # sienna
)
light=(
  '#87DDA5' # pine
  '#EBCB5E' # amber
  '#F08C8C' # crimson
  '#C9A0E8' # violet
  '#80DADA' # teal
  '#9DB0F2' # navy
  '#E89AC8' # plum
  '#EBAC7B' # sienna
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

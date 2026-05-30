#!/usr/bin/env bash
# Pick a dark status-bar color deterministically from the hostname.
# All colors are dark enough for WCAG AA contrast against white text.
colors=(
  '#145220' # pine
  '#5C4400' # amber
  '#6B1A1A' # crimson
  '#401A6B' # violet
  '#1A5A5A' # teal
  '#1A276B' # navy
  '#6B1A4D' # plum
  '#6B3A1A' # sienna
)
n=${#colors[@]}
hostname=$(cat /etc/hostname 2> /dev/null || hostname)
hash=$(printf '%s' "${hostname}" | cksum | cut -d' ' -f1)
echo "${colors[$((hash % n))]}"

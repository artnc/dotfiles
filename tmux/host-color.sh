#!/usr/bin/env bash
# Pick a dark status-bar color deterministically from the hostname.
# All colors are dark enough for WCAG AA contrast against white text.
colors=(
  '#6B1A1A' # crimson
  '#1A276B' # navy
  '#1A6B2A' # forest
  '#401A6B' # violet
  '#1A5A5A' # teal
  '#6B3A1A' # sienna
  '#6B1A4D' # plum
  '#4D4D1A' # olive
)
n=${#colors[@]}
hostname=$(cat /etc/hostname 2> /dev/null || hostname)
hash=$(printf '%s' "${hostname}" | cksum | cut -d' ' -f1)
echo "${colors[$((hash % n))]}"

#!/usr/bin/env bash
# Toggle: open micro on left half, scale existing window layout into right half
# (preserving structure). Re-invoking restores the original layout

set -e

# Window-local state stores "<original-layout>|<micro-pane-id>" while active, so
# the next invocation knows what to tear down and restore
state_var='@micro_wrap_state'
saved=$(tmux show -wqv "${state_var}")

# Restore path: state present => micro is already open, so kill it and replay
# the saved layout. kill-pane may fail if the user closed micro manually; in
# that case skip the layout restore (it would target a vanished pane)
if [[ -n ${saved} ]]; then
  saved_layout="${saved%%|*}"
  micro_pane_id="${saved##*|}"
  if tmux kill-pane -t "${micro_pane_id}" 2> /dev/null; then
    tmux select-layout "${saved_layout}" 2> /dev/null || true
  fi
  tmux set -wu "${state_var}"
  exit 0
fi

# Activation path: split off a new pane running micro, then shove it to the
# absolute left of the window (split-window alone places it adjacent to the
# active pane, not necessarily at the window edge)
orig_layout=$(tmux display -p '#{window_layout}')
first_pane=$(tmux list-panes -F '#{pane_id}' | head -1)
micro_pane_id=$(tmux split-window -hP -c '#{pane_current_path}' -F '#{pane_id}' micro)
tmux move-pane -bh -s "${micro_pane_id}" -t "${first_pane}"
micro_idx="${micro_pane_id#%}"

# The split above lets tmux pick the dimensions, which usually mangles any
# pre-existing multi-pane layout on the right. Recompute the layout ourselves:
# shrink the original tree to fit the right half, wrap it with the micro pane on
# the left, and emit a string with the checksum prefix tmux requires
new_layout=$(
  python3 - "${orig_layout}" "${micro_idx}" << 'PY'
import re
import sys


# tmux prefixes every layout string with a 4-hex checksum. If it doesn't match
# the body, tmux silently rejects select-layout, so we replicate the algorithm
# from tmux's layout-custom.c: bit-rotate-then-add over the UTF-8 bytes
def checksum(s):
    cs = 0
    for c in s.encode():
        cs = ((cs >> 1) | ((cs & 1) << 15)) & 0xFFFF
        cs = (cs + c) & 0xFFFF
    return cs


# tmux layout grammar (sans checksum):
#   node      := WxH,X,Y ( hsplit | vsplit | ",pane_index" )
#   hsplit    := "{" node ("," node)* "}"
#   vsplit    := "[" node ("," node)* "]"
# Returned tree nodes: t = "p" (leaf), "h" (horiz split), "v" (vert split);
#   w/h/x/y geometry, i = pane index for leaves, k = children for splits.
def parse(s, i=0):
    m = re.search(r"(\d+)x(\d+),(\d+),(\d+)", s[i:])
    w, h, x, y = map(int, m.groups())
    i += m.end()
    if i < len(s) and s[i] in "{[":
        opener = s[i]
        closer = "}" if opener == "{" else "]"
        i += 1
        children = []
        while True:
            c, i = parse(s, i)
            children.append(c)
            if i < len(s) and s[i] == ",":
                i += 1
            else:
                break
        if i < len(s) and s[i] == closer:
            i += 1
        return {"h": h, "k": children, "t": "h" if opener == "{" else "v", "w": w, "x": x, "y": y}, i
    m = re.search(r",(\d+)", s[i:])
    idx = int(m.group(1))
    i += m.end()
    return {"h": h, "i": idx, "t": "p", "w": w, "x": x, "y": y}, i


def serialize(n):
    base = f"{n['w']}x{n['h']},{n['x']},{n['y']}"
    if n["t"] == "p":
        return f"{base},{n['i']}"
    o, c = ("{", "}") if n["t"] == "h" else ("[", "]")
    return base + o + ",".join(serialize(x) for x in n["k"]) + c


# Rewrite a subtree's horizontal extent. Vertical splits inherit the new bounds
# uniformly; horizontal splits divvy the width proportionally to original sizes.
# The (count - 1) terms account for the 1-column divider tmux draws between
# horizontally-adjacent panes — that column isn't usable by any pane but is
# included in the parent's width, so we subtract it before distributing
def rescale_x(n, new_x, new_w):
    orig_w = n["w"]
    n["x"] = new_x
    n["w"] = new_w
    if n["t"] == "p":
        return
    if n["t"] == "v":
        for c in n["k"]:
            rescale_x(c, new_x, new_w)
        return
    children = n["k"]
    count = len(children)
    new_pane_total = max(0, new_w - (count - 1))
    orig_pane_total = max(1, orig_w - (count - 1))
    run_x = new_x
    assigned = 0
    for idx, c in enumerate(children):
        # Last child absorbs the remainder so widths sum exactly to
        # new_pane_total (rounding the proportional split would otherwise drift
        # off by 1)
        if idx == count - 1:
            child_w = new_pane_total - assigned
        else:
            child_w = c["w"] * new_pane_total // orig_pane_total
            assigned += child_w
        rescale_x(c, run_x, child_w)
        run_x += child_w + 1


# Strip the checksum off the input layout, parse the rest, and split the window
# in half: micro on the left (left_w cols), original tree on the right (w -
# left_w - 1 cols, leaving 1 col for the divider between halves)
orig = sys.argv[1].split(",", 1)[1]
micro_idx = int(sys.argv[2])
root, _ = parse(orig)
w, h = root["w"], root["h"]
left_w = w // 2
rescale_x(root, left_w + 1, w - left_w - 1)
new_root = {
    "h": h,
    "k": [
        {"h": h, "i": micro_idx, "t": "p", "w": left_w, "x": 0, "y": 0},
        root,
    ],
    "t": "h",
    "w": w,
    "x": 0,
    "y": 0,
}
out = serialize(new_root)
print(f"{checksum(out):04x},{out}")
PY
)

# Apply the recomputed layout, persist state for the next (toggle-off) call, and
# focus micro so the user can start typing immediately
tmux select-layout "${new_layout}"
tmux set -w "${state_var}" "${orig_layout}|${micro_pane_id}"
tmux select-pane -t "${micro_pane_id}"

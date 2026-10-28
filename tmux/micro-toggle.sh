#!/usr/bin/env bash
# Toggle: open micro on left half, scale existing window layout into right half
# (preserving structure). Re-invoking restores the original layout

set -e

# Window-local state stores "<original-layout>|<micro-pane-id>" while active, so
# the next invocation knows what to tear down and restore
state_var='@micro_wrap_state'
saved=$(tmux show -wqv "${state_var}")

# Restore path: state present and saved pane still exists => micro is open, so
# kill it and replay the saved layout. If the saved pane is gone (user quit
# micro manually), the state is stale: clear it and fall through to activation
# so a single keypress reopens micro instead of just clearing state
if [[ -n ${saved} ]]; then
  saved_layout="${saved%%|*}"
  micro_pane_id="${saved##*|}"
  if tmux list-panes -F '#{pane_id}' | grep -qx "${micro_pane_id}"; then
    tmux kill-pane -t "${micro_pane_id}"
    tmux select-layout "${saved_layout}" 2> /dev/null || true
    tmux set -wu "${state_var}"
    exit 0
  fi
  tmux set -wu "${state_var}"
fi

# Activation path: open micro in a full-height pane at the far left of the
# window, capped at 109 cols so that it doesn't dominate wide windows. tmux 3.8+
# shrinks the existing layout proportionally to fit the right side (preserving
# structure and floating panes), so we don't need to compute a custom layout.
# Target a tiled pane because splitting a floating pane creates another floating
# pane. `-c` is pre-expanded because `split-window` would otherwise expand it
# against the target pane instead of the active one. `split-window` focuses the
# new pane so that the user can start typing immediately
orig_layout=$(tmux display -p '#{window_layout}')
window_w=$(tmux display -p '#{window_width}')
micro_pane_id=$(tmux split-window -bfhP -l "$((window_w / 2 < 109 ? window_w / 2 : 109))" -t "$(tmux list-panes -f '#{!:#{pane_floating_flag}}' -F '#{pane_id}' | head -1)" -c "$(tmux display -p '#{pane_current_path}')" -F '#{pane_id}' micro)

# Persist state for the next (toggle-off) call
tmux set -w "${state_var}" "${orig_layout}|${micro_pane_id}"

#!/usr/bin/env bash

set -eu

# Show notification and play sound
dir_name="$(basename "${PWD}")"
if [[ "$(uname)" == Darwin ]]; then
  osascript -e "display notification \"${dir_name}\" with title \"Claude finished\""
else
  # Ignore failure on headless sessions, e.g. "GDBus.Error:org.freedesktop.DBus.Error.
  # ServiceUnknown: The name is not activatable"
  notify-send "Claude finished" "${dir_name}" 2> /dev/null || true
fi
if [[ -n ${TMUX:-} ]]; then
  # Target the hook's own pane since without `-t`, tmux resolves to whichever
  # pane the most recently active client is viewing
  printf '\a' > "$(tmux display-message -p -t "${TMUX_PANE}" '#{pane_tty}')" 2> /dev/null || true
else
  printf '\a' > /dev/tty 2> /dev/null || true
fi

# Transfer Claude permission declarations from local repo to global settings
global_settings="${HOME}/.claude/settings.json"
local_settings=".claude/settings.local.json"
if [[ -f ${local_settings} ]]; then
  yq -i ". *+ load(\"${local_settings}\")" "${global_settings}"
  rm "${local_settings}"
fi

# Sort Claude settings
new_json="$(jq -S 'walk(if type == "array" then sort else . end)' "${global_settings}")"
echo "${new_json}" > "${global_settings}"

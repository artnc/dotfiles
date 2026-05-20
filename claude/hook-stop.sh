#!/usr/bin/env bash

set -eu

# Show notification and play sound
if [[ "$(uname)" == Darwin ]]; then
  osascript -e 'display notification "Claude finished" with title "Claude Code" sound name "default"'
else
  notify-send 'Claude Code' 'Claude finished'
  paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2> /dev/null || true
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

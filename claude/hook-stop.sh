#!/usr/bin/env bash

set -eu

# Title the notification by event, since the Notification hook also runs this
# script for permission prompts and MCP forms
if [[ "$(jq -r .hook_event_name)" == Notification ]]; then
  title='Claude needs input'
else
  title='Claude finished'
fi

# Show notification and play sound
dir_name="$(basename "${PWD}")"
if [[ "$(uname)" == Darwin ]]; then
  osascript -e "display notification \"${dir_name}\" with title \"${title}\""
else
  # Ignore failure on headless sessions, e.g. "GDBus.Error:org.freedesktop.DBus.Error.
  # ServiceUnknown: The name is not activatable"
  notify-send "${title}" "${dir_name}" 2> /dev/null || true
  # Play sound here since Ghostty's GTK bell can't decode audio without extra
  # GStreamer plugins. Run in background to avoid blocking the hook
  paplay "${BASH_SOURCE[0]%/*}/bell.mp3" &> /dev/null &
fi
# Ring the bell via Claude Code, since hooks have no controlling terminal and
# writes to `/dev/tty` fail. This must be the script's only stdout
# https://code.claude.com/docs/en/hooks#emit-terminal-notifications
echo '{"terminalSequence": "\u0007"}'

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

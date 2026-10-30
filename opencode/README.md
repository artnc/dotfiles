# OpenCode

`install.sh` symlinks the shared `opencode.json` and a hostname-selected work or personal profile as `opencode.jsonc`.

CLI preferences need different handling because OpenCode replaces `cli.json` atomically, which breaks a file symlink. The installer merges this repo's `cli.json` into the live file. The local `settings-sync` TUI plugin syncs fields changed in the UI back into this repo, preserving unrelated repo edits without copying runtime or credential files.

Run `./install.sh` after editing the tracked CLI settings. Restart the TUI after adding the sync plugin so that it starts watching saves. Run `make -C opencode test` from the repo root to test the plugins.

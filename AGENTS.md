## Colors

- Prioritize clarity and contrast over a consistent palette across apps. Aim for 7:1 contrast on text (WCAG AAA).
- Prefer white text on black. Avoid blue-tinted palettes (e.g. Iceberg), off-white text (e.g. Twilight's `#ffffd4`), and oversaturated colors (e.g. xterm's ANSI palette).
- Avoid large areas of bright color. Fill backgrounds (e.g. notifications) with dark, intense colors under white text.
- Modus Vivendi fits these rules. Ghostty uses it, and config comments say which other apps do and why.

## Fonts

- Use the same fonts in every app: Adwaita Sans for UI text, and DejaVu Sans Mono where proportional text would shift, misalign, or look smaller beside monospace (e.g. terminal apps and all of Waybar). Never fall back to an app's default monospace font (e.g. fuzzel and swaynag).
- Use 10pt or larger everywhere.
- Use the fonts most websites are designed around: Times New Roman as the default serif, and Arial as sans serif in Firefox only.

## Configs

- Apply changes with reload commands (e.g. `swaymsg reload`, `dunstctl reload`, `pkill -USR2 waybar`, `tmux source ~/.tmux.conf`, or Ghostty's Ctrl+Shift+,), not by logging out or restarting Sway. Test risky changes in a headless Sway (`WLR_BACKENDS=headless WLR_RENDERER=pixman sway -c ...`) with `grim` screenshots.
- Put setup outside the repo (symlinks, `gsettings`, packages) in `install.sh` instead of one-off commands, so that a `git reset` leaves no stale state. Keep it idempotent and compatible with `DRY_RUN=1`. List any `sudo` steps for me to run.
- Make changes work on Arch Linux with Sway, macOS, and GitHub Codespaces, e.g. `ghostty/config-base` is shared, while `config-linux` and `config-macos` are per OS.
- Sort config keys alphabetically within each section, with any comment on the line above its key.

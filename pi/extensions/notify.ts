/**
 * Port of opencode/plugins/notify.js: show a desktop notification and ring
 * the terminal bell when pi finishes a turn. Pi has no permission prompts, so
 * unlike the opencode version there is no "needs input" case
 */
import { basename } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default (pi: ExtensionAPI) => {
  // `agent_end` can still be followed by retries, compaction, or queued
  // follow-ups, so wait for `agent_settled`
  pi.on("agent_settled", async (_event, ctx) => {
    // Skip in `-p` and RPC modes where nobody is waiting at a terminal
    if (!ctx.hasUI) {
      return;
    }

    // Show the notification and ring the bell (which makes tmux flag the
    // window even when it's unfocused) at the same time
    const dir = basename(ctx.cwd);
    await Promise.all([
      process.platform === "darwin"
        ? // Escape the dir name, since a `"` or `\` in it breaks the script
          pi.exec("osascript", [
            "-e",
            `display notification "${dir.replace(/["\\]/g, "\\$&")}" with title "pi finished"`,
          ])
        : pi.exec("notify-send", ["pi finished", dir]),
      pi.exec("sh", [
        "-c",
        process.env.TMUX
          ? `printf '\\a' > "$(tmux display-message -p '#{pane_tty}')"`
          : `printf '\\a' > /dev/tty`,
      ]),
    ]);
  });
};

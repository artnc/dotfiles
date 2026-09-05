/**
 * Port of opencode/plugins/rtk.js: rewrite bash commands through rtk (Rust
 * Token Killer) to cut token usage. rtk has no native pi hook, but `rtk hook
 * check` dry-runs the same rewrite engine as its Claude Code hook and prints
 * the resulting command, e.g. `git status` -> `rtk git status`
 */
import {
  type ExtensionAPI,
  isToolCallEventType,
} from "@earendil-works/pi-coding-agent";

export default (pi: ExtensionAPI) => {
  pi.on("tool_call", async (event, ctx) => {
    if (!isToolCallEventType("bash", event) || !event.input.command) {
      return;
    }
    // Cap the call and forward the signal so a hung rtk can't wedge the bash
    // tool past an Esc. A throw here would block the tool, not just skip rtk
    const result = await pi.exec(
      "rtk",
      ["hook", "check", event.input.command],
      { signal: ctx.signal, timeout: 5000 },
    );
    const rewritten = result.stdout.trim();
    // Keep the original command if rtk is missing or prints nothing. `killed`
    // matters because pi reports a signalled process as exit code 0, so a
    // timed-out rtk would otherwise hand back a truncated command
    if (!result.killed && result.code === 0 && rewritten) {
      event.input.command = rewritten;
    }
  });
};

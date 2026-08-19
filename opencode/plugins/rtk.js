/**
 * Port of the Claude Code PreToolUse `rtk hook claude` hook: rewrite bash
 * commands through rtk (Rust Token Killer) to cut token usage. rtk has no
 * native opencode hook, but `rtk hook check` dry-runs the same rewrite
 * engine and prints the resulting command, e.g. `git status` -> `rtk git
 * status`
 */
export const Rtk = async ({ $ }) => ({
  "tool.execute.before": async (input, output) => {
    if (input.tool !== "bash" || !output.args?.command) {
      return;
    }
    const result = await $`rtk hook check ${output.args.command}`
      .quiet()
      .nothrow();
    const rewritten = result.stdout.toString().trim();
    // Keep the original command if rtk is missing or prints nothing
    if (result.exitCode === 0 && rewritten) {
      output.args.command = rewritten;
    }
  },
});

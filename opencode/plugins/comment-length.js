/**
 * Port of the Claude Code PostToolUse hook: after each edit/write, flag
 * over-long comment lines so the model reflows them itself instead of letting
 * the code formatter chop them. Reuses claude/hook-posttooluse.py by feeding
 * it a Claude-style JSON payload on stdin
 */
export const CommentLength = async ({ $ }) => {
  // opencode's after-hook doesn't expose tool args, so stash them by callID
  const argsByCall = {};
  return {
    "tool.execute.after": async input => {
      const args = argsByCall[input.callID];
      if (!args) {
        return;
      }
      delete argsByCall[input.callID];
      const payload = JSON.stringify({
        tool_input: {
          content: args.content,
          file_path: args.filePath,
          new_string: args.newString,
        },
      });
      const result =
        await $`${process.env.HOME}/git/dotfiles/claude/hook-posttooluse.py < ${new Response(payload)}`
          .quiet()
          .nothrow();
      // Exit code 2 means violations; throw so the model sees the line list
      if (result.exitCode === 2) {
        throw new Error(result.stderr.toString());
      }
    },
    "tool.execute.before": async (input, output) => {
      if (input.tool === "edit" || input.tool === "write") {
        argsByCall[input.callID] = output.args;
      }
    },
  };
};

import { spawnSync } from "node:child_process";

/** Rewrite shell tool commands through RTK to reduce tool output */
export default {
  id: "rtk",
  setup: async ctx => {
    // Rewrite before tool execution so that permissions check the final command
    await ctx.tool.hook("execute.before", event => {
      if (event.tool !== "shell" || !event.input?.command) {
        return;
      }

      // Bound RTK's runtime so that a hung helper can't freeze the shared server
      const result = spawnSync("rtk", ["hook", "check", event.input.command], {
        encoding: "utf8",
        killSignal: "SIGKILL",
        timeout: 5000,
      });

      // Keep the original command if RTK is missing, fails, or times out
      const rewritten = result.stdout?.trim();
      if (result.status === 0 && rewritten) {
        event.input.command = rewritten;
      }
    });
  },
};

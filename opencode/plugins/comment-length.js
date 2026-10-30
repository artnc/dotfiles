import { spawnSync } from "node:child_process";
import { realpathSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

/** Find the shared checker relative to this repo, wherever it's cloned */
const checker = resolve(
  realpathSync(dirname(fileURLToPath(import.meta.url))),
  "../../claude/hook-posttooluse.py"
);

/** Reuse the Claude Code comment check after successful file changes */
export default {
  id: "comment-length",
  setup: async ctx => {
    // Inspect V2's completed input directly instead of caching tool arguments
    await ctx.tool.hook("execute.after", event => {
      if (
        event.status !== "completed" ||
        !["edit", "patch", "write"].includes(event.tool)
      ) {
        return;
      }

      // Use diff line numbers because formatters can rewrite edited text and
      // patch output can trim common indentation
      const inputs =
        event.tool === "write"
          ? [
              {
                content: event.input.content,
                file_path: resolve(
                  ctx.location.directory,
                  event.input.path.replace(/^~(?=\/|$)/, homedir())
                ),
              },
            ]
          : (event.result.output?.files ?? [])
              .filter(f => f.status !== "deleted")
              .map(f => {
                let line;
                const touched = [];
                for (const text of f.patch.split("\n")) {
                  const hunk = /^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@/.exec(
                    text
                  );
                  if (hunk) {
                    line = Number(hunk[1]) - 1;
                    continue;
                  }
                  if (line === undefined) {
                    continue;
                  }
                  if (text.startsWith("+")) {
                    touched.push(line++);
                  } else if (text.startsWith(" ")) {
                    line++;
                  }
                }
                return {
                  file_path: resolve(ctx.location.directory, f.file),
                  touched_lines: touched,
                };
              });

      // Check each file with a hard timeout so that helpers can't stall sessions
      const violations = inputs.flatMap(input => {
        const result = spawnSync(checker, [], {
          encoding: "utf8",
          input: JSON.stringify({ tool_input: input }),
          killSignal: "SIGKILL",
          timeout: 5000,
        });
        return result.status === 2 ? [result.stderr.trim()] : [];
      });
      if (violations.length === 0) {
        return;
      }

      // Show violations without misreporting an already-applied change as failed
      event.result = {
        ...event.result,
        content: [
          ...(typeof event.result.content === "string"
            ? [{ text: event.result.content, type: "text" }]
            : (event.result.content ?? [])),
          { text: violations.join("\n"), type: "text" },
        ],
      };
    });
  },
};

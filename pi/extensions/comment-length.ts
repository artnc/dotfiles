/**
 * Port of opencode/plugins/comment-length.js: after each edit/write, flag
 * over-long comment lines so the model reflows them itself instead of letting
 * the code formatter chop them. Reuses claude/hook-posttooluse.py by feeding
 * it Claude-style JSON payloads on stdin
 */
import { spawnSync } from "node:child_process";
import { homedir } from "node:os";
import { resolve } from "node:path";
import {
  type EditToolInput,
  type ExtensionAPI,
  type WriteToolInput,
  isEditToolResult,
  isWriteToolResult,
} from "@earendil-works/pi-coding-agent";

export default (pi: ExtensionAPI) => {
  pi.on("tool_result", (event, ctx) => {
    // Collect the text each tool wrote (one entry per edit, since pi's edit
    // tool applies several replacements per call)
    const written = isEditToolResult(event)
      ? (event.input as EditToolInput).edits.map(e => e.newText)
      : isWriteToolResult(event)
        ? [(event.input as WriteToolInput).content]
        : [];
    if (event.isError || written.length === 0) {
      return;
    }

    // Expand `~` the way pi's own resolveToCwd() does (it isn't exported), or
    // the hook would stat a path like `<cwd>/~/foo.ts` and silently pass
    const file = resolve(
      ctx.cwd,
      (event.input.path as string).replace(/^~(?=\/|$)/, homedir()),
    );

    // Run the Claude hook once per distinct write (exit code 2 means
    // violations). Deduped because the hook rescans the whole file for each
    // text, so repeated newTexts would report the same lines twice. spawnSync
    // instead of pi.exec() because the latter ignores stdin, and it blocks the
    // event loop, so cap how long one hung hook can freeze the TUI
    const violations = [...new Set(written)].flatMap(text => {
      const result = spawnSync(
        `${homedir()}/git/dotfiles/claude/hook-posttooluse.py`,
        {
          encoding: "utf8",
          input: JSON.stringify({
            tool_input: { file_path: file, new_string: text },
          }),
          timeout: 5000,
        },
      );
      return result.status === 2 ? [result.stderr.trim()] : [];
    });
    if (violations.length === 0) {
      return;
    }

    // Append the line list to the tool result so the model sees and fixes it
    return {
      content: [
        ...event.content,
        { text: violations.join("\n"), type: "text" },
      ],
    };
  });
};

/**
 * Port of opencode.json's `instructions` key: append my global Claude Code
 * instructions and the IT-synced Duolingo team rules to pi's system prompt.
 * Pi only auto-loads ~/.pi/agent/AGENTS.md and has no `@file` include syntax,
 * so this reuses the Claude files instead of duplicating their prose
 */
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, resolve } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

/** Read a file, or return "" if it's missing */
const read = (file: string) => {
  try {
    return readFileSync(file, "utf8");
  } catch {
    return "";
  }
};

export default (pi: ExtensionAPI) => {
  pi.on("before_agent_start", event => ({
    systemPrompt: [
      event.systemPrompt,
      // Expand Claude-style `@path` include lines one level deep
      ...[
        `${homedir()}/.claude/CLAUDE.md`,
        `${homedir()}/.config/opencode/AGENTS.md`,
      ].map(file =>
        read(file).replace(/^@(\S+)$/gm, (_, ref) =>
          read(resolve(dirname(file), ref)),
        ),
      ),
    ]
      .filter(Boolean)
      .join("\n\n"),
  }));
};

/**
 * Hide TUI noise that pi has no settings for: tool call rows (Ctrl+O only
 * collapses them), the italic "Thinking..." placeholder that
 * `hideThinkingBlock` leaves behind for each run of hidden thinking blocks,
 * and the footer's branch name and token counters (only the cost matters).
 * Overriding tools by name via `pi.registerTool()` would be fragile (for
 * package tools the first registration wins, so it depends on extension load
 * order), so instead patch the components pi renders with. They're exported
 * publicly and resolve to the same module instance pi runs
 */
import {
  type AgentSession,
  type AssistantMessage,
  AssistantMessageComponent,
  FooterComponent,
  ToolExecutionComponent,
} from "@earendil-works/pi-coding-agent";

/** Rows for these tools are noise, failed or not, so hide them */
const HIDDEN_TOOLS = [
  "bash",
  "codemode",
  "edit",
  "fetch_content",
  "find",
  "get_search_content",
  "grep",
  "list_mcp_resource_templates",
  "list_mcp_resources",
  "ls",
  "read",
  "read_mcp_resource",
  "source_check",
  "tool_search",
  "web_search",
  "write",
];

/** Marks the prototypes as patched. Symbol keys never show up in `for...in` */
const PATCHED = Symbol.for("dotfiles/quiet-tui");

// The patches below need `this` to read private component fields (they exist
// at runtime but not in the type definitions), so they can't be arrow functions
export default () => {
  // Pi reruns this on `/reload` and on every session switch, and wrapping an
  // already-wrapped method would grow the call chain without bound
  const patched = ToolExecutionComponent.prototype as unknown as Record<
    symbol,
    boolean
  >;
  if (patched[PATCHED]) {
    return;
  }
  patched[PATCHED] = true;

  // Hide MCP calls by prefix instead of enumerating every server's tools
  const render = ToolExecutionComponent.prototype.render;
  ToolExecutionComponent.prototype.render = function (width) {
    const { toolName } = this as unknown as { toolName: string };
    return HIDDEN_TOOLS.includes(toolName) || toolName.startsWith("mcp")
      ? []
      : render.call(this, width);
  };

  // Drop thinking blocks before rendering so a thinking-only turn renders zero
  // lines instead of the placeholder. Only while hidden, and restore the full
  // message afterward, so Ctrl+T can still reveal thinking on demand
  const updateContent = AssistantMessageComponent.prototype.updateContent;
  AssistantMessageComponent.prototype.updateContent = function (
    message,
    isStreaming,
  ) {
    const self = this as unknown as {
      hideThinkingBlock: boolean;
      lastMessage?: AssistantMessage;
    };
    updateContent.call(
      this,
      self.hideThinkingBlock
        ? {
            ...message,
            content: message.content.filter(c => c.type !== "thinking"),
          }
        : message,
      isStreaming,
    );
    self.lastMessage = message;
  };

  // Hide the footer's branch name, `↑ ↓ R W CH` token counters, and `(auto)`
  // compaction flag but keep the cost. The built-in render sums usage from
  // `session.sessionManager.getEntries()` and only shows each counter when its
  // total is nonzero, so render against a view of the session whose entries
  // have every token count zeroed. This keeps pi's own layout, colors, and
  // right alignment. `getContextUsage()` reads `getBranch()`, which the view
  // leaves untouched, so context % is still accurate
  const footerRender = FooterComponent.prototype.render;
  FooterComponent.prototype.render = function (width) {
    const { footerData, session } = this as unknown as {
      footerData: { getGitBranch: () => string | null };
      session: AgentSession;
    };
    const zeroed = { cacheRead: 0, cacheWrite: 0, input: 0, output: 0 };
    let totalCost = 0;
    const entries = session.sessionManager.getEntries().map(e => {
      if ("usage" in e && e.usage) {
        totalCost += e.usage.cost.total;
        return { ...e, usage: { ...e.usage, ...zeroed } };
      }
      if (e.type === "message" && "usage" in e.message && e.message.usage) {
        totalCost += e.message.usage.cost.total;
        return {
          ...e,
          message: { ...e.message, usage: { ...e.message.usage, ...zeroed } },
        };
      }
      return e;
    });
    const sessionManager = Object.create(session.sessionManager, {
      getEntries: { value: () => entries },
    });
    const lines = footerRender.call(
      Object.create(this, {
        autoCompactEnabled: { value: false },
        footerData: {
          value: Object.create(footerData, {
            getGitBranch: { value: () => null },
          }),
        },
        session: {
          value: Object.create(session, {
            sessionManager: { value: sessionManager },
          }),
        },
      }),
      width,
    );

    // Round the raw total so Pi's three-decimal output can't double-round it
    const match = lines[1]?.match(/\$\d+\.\d{3}/);
    if (!match) {
      return lines;
    }
    const cost = `$${totalCost.toFixed(2)}`;
    lines[1] = lines[1].replace(match[0], cost);

    // Reclaim removed digits in the padding so the model stays right-aligned
    const removedWidth = match[0].length - cost.length;
    const padding = lines[1].indexOf(
      "  ",
      (match.index ?? 0) + match[0].length,
    );
    if (removedWidth > 0 && padding !== -1) {
      lines[1] = `${lines[1].slice(0, padding)}${" ".repeat(removedWidth)}${lines[1].slice(padding)}`;
    }
    return lines;
  };
};

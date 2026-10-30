import assert from "node:assert/strict";
import { test } from "node:test";
import hideActivitySummary from "../plugins/hide-activity-summary/tui.js";

/** Model the OpenTUI tree boundary without starting a terminal */
const node = (children = [], options = {}) => {
  const result = {
    add: child => {
      children.push(child);
      child.parent = result;
    },
    getChildren: () => [...children],
    getChildrenCount: () => children.length,
    getPadding: () => ({ value: 0 }),
    isDestroyed: false,
    marginTop: 0,
    visible: true,
    ...options,
  };
  for (const child of children) {
    child.parent = result;
  }
  return result;
};

/** Reproduce ActivityGroup's summary and its two layout wrappers in V2.2.2 */
const summaryRow = (label = "5 commands, 1 thought, 3 reads, 12 tools") => {
  const header = node(
    [node([node([], { plainText: "+" }), node([], { plainText: label })])],
    { getPadding: () => ({ value: 3 }) },
  );
  const group = node([header]);
  return { group, header, row: node([group], { marginTop: 1 }) };
};

/** Reproduce AssistantFooter's colored spans and Solid's invisible markers */
const footerRow = () => {
  const footer = node(
    [
      node([], {
        getTextChildren: () => [],
        textNode: {
          children: [
            { children: ["Build"] },
            { children: [" · GPT-6.1 Sol"] },
            { children: [" · 2m 53s"] },
            { children: [], visible: false },
          ],
        },
      }),
    ],
    { getPadding: () => ({ value: 3 }) },
  );
  return {
    footer,
    row: node([footer, node([], { visible: false })], { marginTop: 1 }),
  };
};

/** Reproduce the native session column surrounding our custom footer */
const footerColumn = () => {
  const footer = node([], { id: "prompt.footer.compact" });
  const column = node([node([footer])], {
    paddingBottom: 1,
    paddingLeft: 2,
    paddingRight: 2,
  });
  column.getPadding = edge => ({
    value:
      edge === 3
        ? column.paddingBottom
        : edge === 0
          ? column.paddingLeft
          : edge === 2
            ? column.paddingRight
            : 0,
  });
  return { column, footer };
};

/** Run setup, frames, and cleanup without command or preference APIs */
const start = (
  children,
  route = { sessionID: "root", type: "session" },
  version = "2.2.2",
) => {
  const callbacks = new Set();
  const root = node(children);
  const cleanup = hideActivitySummary.setup({
    app: { version },
    data: {
      location: {
        model: {
          list: () => [
            {
              id: "gpt-6.1-sol",
              name: "GPT-6.1 Sol",
              providerID: "duolingo-openai",
            },
          ],
        },
      },
      session: {
        message: { list: () => [{ agent: "build", type: "assistant" }] },
      },
    },
    renderer: {
      removeFrameCallback: callback => callbacks.delete(callback),
      requestRender: () => {},
      root,
      setFrameCallback: callback => callbacks.add(callback),
    },
    ui: {
      model: {
        current: () => ({
          modelID: "gpt-6.1-sol",
          providerID: "duolingo-openai",
        }),
      },
      router: { current: () => route },
    },
  });
  return {
    callbacks,
    cleanup,
    frame: async () => {
      for (const callback of callbacks) {
        await callback();
      }
    },
    root,
  };
};

test("count summaries and their empty spacing disappear without hiding messages", async () => {
  const { row } = summaryRow();
  const message = node([], { plainText: "Normal assistant text" });
  const app = start([row, message]);
  await app.frame();
  assert.equal(row.visible, false);
  assert.equal(message.visible, true);
  app.cleanup();
});

test("summary-like native controls survive in every mounted footer", async () => {
  const first = summaryRow("1 read");
  const second = summaryRow("2 tools");
  const transcript = summaryRow("3 reads");
  const app = start([
    node([first.header, node([], { id: "prompt.footer.compact" })]),
    node([second.header, node([], { id: "prompt.footer.compact" })]),
    transcript.row,
  ]);
  await app.frame();
  assert.equal(first.header.visible, true);
  assert.equal(second.header.visible, true);
  assert.equal(transcript.row.visible, false);
  app.cleanup();
});

test("untested OpenCode versions leave native metadata and layout untouched", async () => {
  const { row } = summaryRow();
  const { column } = footerColumn();
  const app = start([row, column], undefined, "2.2.3");
  await app.frame();
  assert.equal(row.visible, true);
  assert.equal(column.paddingBottom, 1);
  assert.equal(column.paddingLeft, 2);
  assert.equal(app.callbacks.size, 0);
  app.cleanup();
});

test("invisible Solid slot markers don't prevent hiding existing summaries", async () => {
  const { group, header, row } = summaryRow();
  const marker = node([], { visible: false });
  header.add(marker);
  header.getChildren()[0].add(node([], { visible: false }));
  group.add(node([], { visible: false }));
  const app = start([row]);
  await app.frame();
  assert.equal(row.visible, false);
  await app.frame();
  assert.equal(row.visible, false);
  app.cleanup();
  assert.equal(row.visible, true);
  assert.equal(marker.visible, false);
});

test("Solid markers don't hide permission controls or reveal hidden headers", async () => {
  const { group, header, row } = summaryRow();
  const permission = node([], { plainText: "Allow this command?" });
  header.add(node([], { visible: false }));
  group.add(node([], { visible: false }));
  group.add(permission);
  const app = start([row]);
  await app.frame();
  await app.frame();
  assert.equal(row.visible, true);
  assert.equal(header.visible, false);
  assert.equal(permission.visible, true);
  app.cleanup();
  assert.equal(header.visible, true);
});

test("permission controls beside a summary stay visible", async () => {
  const { group, header, row } = summaryRow();
  const permission = node([], { plainText: "Allow this command?" });
  group.add(permission);
  const app = start([row]);
  await app.frame();
  assert.equal(row.visible, true);
  assert.equal(group.visible, true);
  assert.equal(header.visible, false);
  assert.equal(permission.visible, true);
  app.cleanup();
});

test("a permission added to a hidden row makes its controls visible again", async () => {
  const { group, header, row } = summaryRow();
  const app = start([row]);
  await app.frame();
  assert.equal(row.visible, false);
  const permission = node([], { plainText: "Allow this command?" });
  group.add(permission);
  await app.frame();
  assert.equal(row.visible, true);
  assert.equal(header.visible, false);
  assert.equal(permission.visible, true);
  app.cleanup();
});

test("activity summaries stay hidden across frames without UI controls", async () => {
  const { row } = summaryRow();
  const app = start([row]);
  await app.frame();
  assert.equal(row.visible, false);
  await app.frame();
  assert.equal(row.visible, false);
  app.cleanup();
});

test("disabling the plugin restores rows and removes only its frame callback", async () => {
  const { row } = summaryRow();
  const app = start([row]);
  const unrelated = async () => {};
  app.callbacks.add(unrelated);
  await app.frame();
  assert.equal(row.visible, false);
  app.cleanup();
  assert.equal(row.visible, true);
  assert.deepEqual([...app.callbacks], [unrelated]);
});

test("newly mounted history summaries are hidden on the next frame", async () => {
  const app = start([]);
  const { row } = summaryRow("1 read");
  app.root.add(row);
  await app.frame();
  assert.equal(row.visible, false);
  app.cleanup();
});

test("matching words in ordinary messages and unrelated tool rows stay visible", async () => {
  const message = node([], {
    plainText: "5 commands, 1 thought, 3 reads, 12 tools",
  });
  const { header, row } = summaryRow("1 read");
  header.getChildren()[0].getChildren()[0].plainText = "→";
  const app = start([message, row]);
  await app.frame();
  assert.equal(message.visible, true);
  assert.equal(row.visible, true);
  app.cleanup();
});

test("unfamiliar layouts remain unchanged", async () => {
  const { header, row } = summaryRow();
  header.getPadding = () => ({ value: 4 });
  const app = start([row]);
  await app.frame();
  assert.equal(row.visible, true);
  app.cleanup();
});

test("Solid's pending label is recognized before the first native text frame", async () => {
  const { header, row } = summaryRow();
  const label = header.getChildren()[0].getChildren()[1];
  label.getTextChildren = () => [];
  label.plainText = "";
  label.textNode = { children: ["1 ", { children: ["read"] }] };
  const app = start([row]);
  await app.frame();
  assert.equal(row.visible, false);
  app.cleanup();
});

test("counts beside an active spinner are hidden", async () => {
  const { header, row } = summaryRow("2 tools");
  header.getChildren()[0].getChildren()[0].plainText = "";
  header.getChildren()[0].getChildren()[0].add(node());
  const app = start([row]);
  await app.frame();
  assert.equal(row.visible, false);
  app.cleanup();
});

test("counts are hidden when animations are disabled", async () => {
  const header = node([node([], { plainText: "⋯ 2 tools" })], {
    getPadding: () => ({ value: 3 }),
  });
  const app = start([header]);
  await app.frame();
  assert.equal(header.visible, false);
  app.cleanup();
});

test("running status labels remain visible instead of hiding pending commands", async () => {
  const { row } = summaryRow("Running command…");
  const app = start([row]);
  await app.frame();
  assert.equal(row.visible, true);
  app.cleanup();
});

test("navigating away from a session restores its cached rows", async () => {
  const { row } = summaryRow();
  const route = { sessionID: "root", type: "session" };
  const app = start([row], route);
  await app.frame();
  route.type = "home";
  await app.frame();
  assert.equal(row.visible, true);
  app.cleanup();
});

test("cleanup doesn't reveal rows already hidden by another component", async () => {
  const { row } = summaryRow();
  row.visible = false;
  const app = start([row]);
  await app.frame();
  app.cleanup();
  assert.equal(row.visible, false);
});

test("destroyed rows aren't changed during cleanup", async () => {
  const { row } = summaryRow();
  const app = start([row]);
  await app.frame();
  row.isDestroyed = true;
  app.cleanup();
  assert.equal(row.visible, false);
});

test("agent, model, and duration footers disappear without hiding messages", async () => {
  const { row } = footerRow();
  const message = node([], { plainText: "Normal assistant text" });
  const app = start([row, message]);
  await app.frame();
  await app.frame();
  assert.equal(row.visible, false);
  assert.equal(message.visible, true);
  app.cleanup();
  assert.equal(row.visible, true);
});

test("activity summaries and turn footers stay hidden together", async () => {
  const summary = summaryRow();
  const footer = footerRow();
  const app = start([summary.row, footer.row]);
  await app.frame();
  assert.equal(summary.row.visible, false);
  assert.equal(footer.row.visible, false);
  await app.frame();
  assert.equal(footer.row.visible, false);
  assert.equal(summary.row.visible, false);
  app.cleanup();
  assert.equal(summary.row.visible, true);
  assert.equal(footer.row.visible, true);
});

test("errors and retry notices beside a footer stay visible", async () => {
  const { footer, row } = footerRow();
  const error = node([], { plainText: "Error: Request failed" });
  const retry = node([], { plainText: "Retrying…" });
  row.add(error);
  row.add(retry);
  const app = start([row]);
  await app.frame();
  assert.equal(row.visible, true);
  assert.equal(footer.visible, false);
  assert.equal(error.visible, true);
  assert.equal(retry.visible, true);
  app.cleanup();
});

test("an error added to a hidden footer row becomes visible", async () => {
  const { footer, row } = footerRow();
  const app = start([row]);
  await app.frame();
  assert.equal(row.visible, false);
  const error = node([], { plainText: "Error: Request failed" });
  row.add(error);
  await app.frame();
  assert.equal(row.visible, true);
  assert.equal(footer.visible, false);
  assert.equal(error.visible, true);
  app.cleanup();
});

test("ordinary text containing an agent and model isn't treated as a footer", async () => {
  const message = node(
    [node([], { plainText: "Build · GPT-6.1 Sol · 2m 53s" })],
    { getPadding: () => ({ value: 3 }) },
  );
  const app = start([message]);
  await app.frame();
  assert.equal(message.visible, true);
  app.cleanup();
});

test("duplicate prompt metadata disappears without hiding the input", async () => {
  const input = node([], { plainText: "My prompt", submit: () => true });
  const metadata = node(
    [
      node([
        node([], { plainText: "Build" }),
        node([], { plainText: "GPT-6.1 Sol" }),
      ]),
    ],
    { getPadding: edge => ({ value: edge === 1 ? 1 : 0 }) },
  );
  const message = node([], { plainText: "GPT-6.1 Sol" });
  const app = start([
    node([
      node([input, node([], { visible: false }), metadata]),
      node([node([], { id: "prompt.footer.compact" })]),
    ]),
    message,
  ]);
  await app.frame();
  await app.frame();
  assert.equal(metadata.visible, false);
  assert.equal(input.visible, true);
  assert.equal(input.plainText, "My prompt");
  assert.equal(message.visible, true);
  app.cleanup();
  assert.equal(metadata.visible, true);
});

test("shell-mode metadata and unrelated input siblings remain visible", async () => {
  const input = node([], { submit: () => true });
  const metadata = node([node([], { plainText: "Shell" })], {
    getPadding: edge => ({ value: edge === 1 ? 1 : 0 }),
  });
  const app = start([node([input, metadata])]);
  await app.frame();
  assert.equal(metadata.visible, true);
  app.cleanup();
});

test("unfamiliar input layouts aren't hidden", async () => {
  const input = node([], { submit: () => true });
  const metadata = node([node([], { plainText: "GPT-6.1 Sol" })], {
    getPadding: () => ({ value: 2 }),
  });
  const app = start([node([input, metadata])]);
  await app.frame();
  assert.equal(metadata.visible, true);
  app.cleanup();
});

test("the unused row below the custom footer is removed and restored on cleanup", async () => {
  const { column, footer } = footerColumn();
  const outer = node([column], {
    getPadding: () => ({ value: 1 }),
    paddingBottom: 1,
  });
  const app = start([outer]);
  await app.frame();
  assert.equal(column.paddingBottom, 0);
  assert.equal(column.paddingLeft, 0);
  assert.equal(column.paddingRight, 0);
  assert.equal(outer.paddingBottom, 1);
  assert.equal(footer.visible, true);
  await app.frame();
  assert.equal(column.paddingBottom, 0);
  app.cleanup();
  assert.equal(column.paddingBottom, 1);
  assert.equal(column.paddingLeft, 2);
  assert.equal(column.paddingRight, 2);
});

test("bottom padding on unrelated columns and unfamiliar layouts is preserved", async () => {
  const unrelated = footerColumn();
  unrelated.footer.id = "other-footer";
  const unfamiliar = footerColumn();
  unfamiliar.column.paddingBottom = 2;
  const app = start([unrelated.column, unfamiliar.column]);
  await app.frame();
  assert.equal(unrelated.column.paddingBottom, 1);
  assert.equal(unfamiliar.column.paddingBottom, 2);
  app.cleanup();
});

test("cleanup preserves newer bottom-padding changes made by another component", async () => {
  const { column } = footerColumn();
  const app = start([column]);
  await app.frame();
  column.paddingBottom = 2;
  app.cleanup();
  assert.equal(column.paddingBottom, 2);
});

test("viewport gutters stay removed when native responsive insets change", async () => {
  const { column } = footerColumn();
  const app = start([column]);
  await app.frame();
  column.paddingLeft = 1;
  column.paddingRight = 1;
  await app.frame();
  assert.equal(column.paddingLeft, 0);
  assert.equal(column.paddingRight, 0);
  app.cleanup();
  assert.equal(column.paddingLeft, 1);
  assert.equal(column.paddingRight, 1);
});

test("inner message and input padding is preserved", async () => {
  const { column } = footerColumn();
  const inner = node([], { paddingLeft: 2, paddingRight: 2 });
  column.add(inner);
  const app = start([column]);
  await app.frame();
  assert.equal(column.paddingLeft, 0);
  assert.equal(column.paddingRight, 0);
  assert.equal(inner.paddingLeft, 2);
  assert.equal(inner.paddingRight, 2);
  app.cleanup();
});

test("non-native inset changes aren't overwritten during frames or cleanup", async () => {
  const { column } = footerColumn();
  const app = start([column]);
  await app.frame();
  column.paddingLeft = 4;
  await app.frame();
  assert.equal(column.paddingLeft, 4);
  app.cleanup();
  assert.equal(column.paddingLeft, 4);
});

test("interrupted turns keep their footer because they show no error", async () => {
  const { footer, row } = footerRow();
  footer
    .getChildren()[0]
    .textNode.children.push({ children: [" · interrupted"] });
  const app = start([row]);
  await app.frame();
  assert.equal(row.visible, true);
  assert.equal(footer.visible, true);
  app.cleanup();
});

test("auto-accept and usage-limit labels keep prompt metadata visible", async () => {
  const metadataWith = label =>
    node([node([node([], { plainText: "GPT-6.1 Sol" }), label])], {
      getPadding: edge => ({ value: edge === 1 ? 1 : 0 }),
    });
  const auto = metadataWith(node([], { plainText: "auto" }));
  const limit = metadataWith(
    node([], { getMargin: () => ({ value: 1 }), plainText: "90% used" }),
  );
  const app = start([
    node([node([], { submit: () => true }), auto]),
    node([node([], { submit: () => true }), limit]),
    node([node([], { id: "prompt.footer.compact" })]),
  ]);
  await app.frame();
  assert.equal(auto.visible, true);
  assert.equal(limit.visible, true);
  app.cleanup();
});

test("duplicate prompt metadata is hidden on the home screen too", async () => {
  const metadata = node([node([], { plainText: "GPT-6.1 Sol" })], {
    getPadding: edge => ({ value: edge === 1 ? 1 : 0 }),
  });
  const app = start(
    [
      node([node([], { submit: () => true }), metadata]),
      node([node([], { id: "prompt.footer.compact" })]),
    ],
    { type: "home" },
  );
  await app.frame();
  assert.equal(metadata.visible, false);
  app.cleanup();
  assert.equal(metadata.visible, true);
});

test("prompt metadata stays visible while the footer controls are hidden", async () => {
  const metadata = node([node([], { plainText: "GPT-6.1 Sol" })], {
    getPadding: edge => ({ value: edge === 1 ? 1 : 0 }),
  });
  const compact = node([], { id: "prompt.footer.compact", visible: false });
  const app = start([
    node([node([], { submit: () => true }), metadata]),
    node([compact]),
  ]);
  await app.frame();
  assert.equal(metadata.visible, true);
  compact.visible = true;
  await app.frame();
  assert.equal(metadata.visible, false);
  app.cleanup();
});

test("hidden inputs don't hide their first visible sibling", async () => {
  const metadata = node([node([], { plainText: "GPT-6.1 Sol" })], {
    getPadding: edge => ({ value: edge === 1 ? 1 : 0 }),
  });
  const app = start([
    node([metadata, node([], { submit: () => true, visible: false })]),
  ]);
  await app.frame();
  assert.equal(metadata.visible, true);
  app.cleanup();
});

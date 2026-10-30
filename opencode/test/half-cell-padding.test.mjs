import assert from "node:assert/strict";
import { test } from "node:test";
import padding from "../plugins/half-cell-padding/tui.js";

/** Model only the native layout and paint-hook boundary */
const node = (children = [], options = {}) => {
  const result = {
    add: child => {
      children.push(child);
      child.parent = result;
    },
    backgroundColor: { a: 1 },
    border: [],
    borderColor: { a: 1, accent: true },
    getChildren: () => children,
    getPadding: () => ({ value: 0 }),
    height: 3,
    isDestroyed: false,
    visible: true,
    width: 12,
    x: 1,
    y: 2,
    ...options,
  };
  for (const child of children) {
    child.parent = result;
  }
  return result;
};

/** Wrap native padding signatures in their user-message anchor and border */
const messageBox = () => {
  const body = node([], {
    getPadding: edge => ({
      value: edge === 0 ? 2 : edge === 1 || edge === 3 ? 1 : 0,
    }),
  });
  const border = node([body], { border: ["left"], x: 0 });
  return { body, border, row: node([border], { id: "user-message" }) };
};

/** Drive setup, frame reconciliation, and paint through the plugin's API */
const start = (rows, version = "2.2.2") => {
  const callbacks = new Set();
  const cells = [];
  const root = node(rows);
  const cleanup = padding.setup({
    app: { version },
    data: {
      session: {
        message: { list: () => [{ id: "user-message", type: "user" }] },
      },
    },
    renderer: {
      removeFrameCallback: callback => callbacks.delete(callback),
      requestRender: () => {},
      root,
      setFrameCallback: callback => callbacks.add(callback),
    },
    theme: { background: { base: { a: 0 } } },
    ui: {
      router: { current: () => ({ sessionID: "session", type: "session" }) },
    },
  });
  return {
    callbacks,
    cells,
    cleanup,
    frame: async () => {
      for (const callback of callbacks) {
        await callback();
      }
    },
    paint: target =>
      target.renderAfter(
        {
          height: 20,
          setCell: (x, y, glyph, fg, bg) => cells.push({ bg, fg, glyph, x, y }),
          width: 30,
        },
        16,
      ),
    root,
  };
};

test("previous user turns get mirrored half-cell edges without layout changes", async () => {
  const { body, row } = messageBox();
  const app = start([row]);
  await app.frame();
  app.paint(body);
  assert.equal(app.cells.find(c => c.x === 1 && c.y === 2).glyph, "▄");
  assert.equal(app.cells.find(c => c.x === 1 && c.y === 4).glyph, "▀");
  assert.equal(app.cells.find(c => c.x === 0 && c.y === 2).glyph, "╻");
  assert.equal(app.cells.find(c => c.x === 0 && c.y === 4).glyph, "╹");
  assert.equal(app.cells[0].bg.a, 0);
  assert.equal(body.height, 3);
  assert.equal(body.getPadding(1).value, 1);
  app.cleanup();
});

test("untested OpenCode versions keep native paint hooks", async () => {
  const { body, row } = messageBox();
  const app = start([row], "2.2.3");
  await app.frame();
  assert.equal(body.renderAfter, undefined);
  assert.equal(app.callbacks.size, 0);
  app.cleanup();
});

test("the active prompt gets only a new top edge", async () => {
  const input = node([], { submit: () => true });
  const body = node([input], {
    getPadding: edge => ({ value: edge === 0 ? 2 : edge === 1 ? 1 : 0 }),
  });
  const app = start([node([body], { border: ["left"], x: 0 })]);
  await app.frame();
  app.paint(body);
  assert.deepEqual([...new Set(app.cells.map(c => c.y))], [2]);
  assert.equal(
    app.cells.some(c => c.glyph === "▀"),
    false,
  );
  assert.equal(input.visible, true);
  app.cleanup();
});

test("unrelated padded boxes aren't styled as user turns", async () => {
  const { body, row } = messageBox();
  row.id = "assistant-message";
  const app = start([row]);
  await app.frame();
  assert.equal(body.renderAfter, undefined);
  app.cleanup();
});

test("late-mounted history rows are styled without adding duplicate hooks", async () => {
  const app = start([]);
  const { body, row } = messageBox();
  app.root.add(row);
  await app.frame();
  const paint = body.renderAfter;
  await app.frame();
  assert.equal(body.renderAfter, paint);
  app.cleanup();
});

test("existing paint hooks run and are restored on cleanup", async () => {
  const { body, row } = messageBox();
  let calls = 0;
  const before = () => {
    calls++;
  };
  body.renderAfter = before;
  const app = start([row]);
  await app.frame();
  app.paint(body);
  assert.equal(calls, 1);
  app.cleanup();
  assert.equal(body.renderAfter, before);
  assert.equal(app.callbacks.size, 0);
});

test("cleanup doesn't overwrite a newer hook installed by another plugin", async () => {
  const { body, row } = messageBox();
  const app = start([row]);
  await app.frame();
  const newer = () => {};
  body.renderAfter = newer;
  app.cleanup();
  assert.equal(body.renderAfter, newer);
});

test("half-cell colors follow hover and theme updates", async () => {
  const { body, row } = messageBox();
  const app = start([row]);
  await app.frame();
  body.backgroundColor = { a: 1, hovered: true };
  app.paint(body);
  assert.equal(app.cells[0].fg, body.backgroundColor);
  app.cleanup();
});

test("offscreen edges are skipped and horizontal coordinates are clipped", async () => {
  const { body, row } = messageBox();
  body.x = -4;
  body.y = -1;
  const app = start([row]);
  await app.frame();
  app.paint(body);
  assert.equal(
    app.cells.every(c => c.x >= 0 && c.y === 1),
    true,
  );
  assert.equal(app.cells[0].glyph, "▀");
  app.cleanup();
});

test("transparent or hidden boxes retain their original painting", async () => {
  const { body, row } = messageBox();
  body.backgroundColor = { a: 0 };
  const app = start([row]);
  await app.frame();
  assert.equal(body.renderAfter, undefined);
  body.backgroundColor = { a: 1 };
  await app.frame();
  assert.equal(typeof body.renderAfter, "function");
  row.visible = false;
  await app.frame();
  assert.equal(body.renderAfter, undefined);
  app.cleanup();
});

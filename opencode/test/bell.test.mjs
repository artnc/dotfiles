import assert from "node:assert/strict";
import { EventEmitter } from "node:events";
import fs from "node:fs";
import { syncBuiltinESMExports } from "node:module";
import { afterEach, mock, test } from "node:test";
import bell from "../plugins/bell/tui.js";

afterEach(() => {
  mock.restoreAll();
  syncBuiltinESMExports();
});

/** Capture terminal output without ringing the terminal running these tests */
const startBell = (route = { sessionID: "root", type: "session" }) => {
  const events = new EventEmitter();
  const output = [];
  mock.method(fs, "writeSync", (fd, text) => {
    output.push({ fd, text });
    return text.length;
  });
  syncBuiltinESMExports();
  const cleanup = bell.setup({
    data: {
      on: (type, handler) => {
        events.on(type, handler);
        return () => events.off(type, handler);
      },
      session: { get: i => (i === "child" ? { parentID: "root" } : {}) },
    },
    ui: { router: { current: () => route } },
  });
  return { cleanup, events, output };
};

test("completion sends BEL to the TUI's stdout for SSH and tmux", () => {
  const { cleanup, events, output } = startBell();
  events.emit("session.execution.succeeded", { data: { sessionID: "root" } });
  cleanup();
  assert.deepEqual(output, [{ fd: process.stdout.fd, text: "\u0007" }]);
});

test("subagent completion doesn't add terminal bell spam", () => {
  const { cleanup, events, output } = startBell({
    sessionID: "child",
    type: "session",
  });
  events.emit("session.execution.succeeded", { data: { sessionID: "child" } });
  cleanup();
  assert.deepEqual(output, []);
});

test("failed and interrupted sessions also ring the bell", () => {
  const { cleanup, events, output } = startBell();
  events.emit("session.execution.failed", { data: { sessionID: "root" } });
  events.emit("session.execution.started", { data: { sessionID: "root" } });
  events.emit("session.execution.interrupted", { data: { sessionID: "root" } });
  cleanup();
  assert.equal(output.length, 2);
});

test("superseded runs ring only when their replacement finishes", () => {
  const { cleanup, events, output } = startBell();
  events.emit("session.execution.started", { data: { sessionID: "root" } });
  events.emit("session.execution.interrupted", {
    data: { reason: "superseded", sessionID: "root" },
  });
  assert.deepEqual(output, []);
  events.emit("session.execution.succeeded", { data: { sessionID: "root" } });
  cleanup();
  assert.equal(output.length, 1);
});

test("duplicate completion events ring once until the next execution", () => {
  const { cleanup, events, output } = startBell();
  events.emit("session.execution.succeeded", { data: { sessionID: "root" } });
  events.emit("session.execution.failed", { data: { sessionID: "root" } });
  assert.equal(output.length, 1);
  events.emit("session.execution.started", { data: { sessionID: "root" } });
  events.emit("session.execution.succeeded", { data: { sessionID: "root" } });
  cleanup();
  assert.equal(output.length, 2);
});

test("pending permission and question requests ring once each", () => {
  const { cleanup, events, output } = startBell();
  events.emit("permission.asked", {
    data: { id: "permission", sessionID: "root" },
  });
  events.emit("permission.asked", {
    data: { id: "permission", sessionID: "root" },
  });
  events.emit("form.created", {
    data: { form: { id: "question", sessionID: "root" } },
  });
  events.emit("form.created", {
    data: { form: { id: "question", sessionID: "root" } },
  });
  cleanup();
  assert.equal(output.length, 2);
});

test("resolved or cancelled requests can ring again", () => {
  const { cleanup, events, output } = startBell();
  events.emit("permission.asked", {
    data: { id: "permission", sessionID: "root" },
  });
  events.emit("permission.replied", { data: { requestID: "permission" } });
  events.emit("permission.asked", {
    data: { id: "permission", sessionID: "root" },
  });
  events.emit("form.created", {
    data: { form: { id: "question", sessionID: "root" } },
  });
  events.emit("form.replied", { data: { id: "question" } });
  events.emit("form.created", {
    data: { form: { id: "question", sessionID: "root" } },
  });
  events.emit("form.cancelled", { data: { id: "question" } });
  events.emit("form.created", {
    data: { form: { id: "question", sessionID: "root" } },
  });
  cleanup();
  assert.equal(output.length, 5);
});

test("other sessions' completions and input requests don't ring this TUI", () => {
  const { cleanup, events, output } = startBell();
  events.emit("session.execution.succeeded", { data: { sessionID: "other" } });
  events.emit("session.execution.failed", { data: { sessionID: "other" } });
  events.emit("session.execution.interrupted", {
    data: { sessionID: "other" },
  });
  events.emit("permission.asked", {
    data: { id: "permission", sessionID: "other" },
  });
  events.emit("form.created", {
    data: { form: { id: "question", sessionID: "other" } },
  });
  cleanup();
  assert.deepEqual(output, []);
});

test("the home screen doesn't ring for session events", () => {
  const { cleanup, events, output } = startBell({ type: "home" });
  events.emit("session.execution.succeeded", { data: { sessionID: "root" } });
  events.emit("permission.asked", {
    data: { id: "permission", sessionID: "root" },
  });
  events.emit("form.created", {
    data: { form: { id: "question", sessionID: "root" } },
  });
  cleanup();
  assert.deepEqual(output, []);
});

test("switching sessions updates bell ownership without consuming ignored events", () => {
  const route = { sessionID: "root", type: "session" };
  const { cleanup, events, output } = startBell(route);
  events.emit("session.execution.succeeded", { data: { sessionID: "other" } });
  assert.deepEqual(output, []);
  route.sessionID = "other";
  events.emit("session.execution.succeeded", { data: { sessionID: "other" } });
  assert.equal(output.length, 1);
  route.sessionID = "root";
  events.emit("session.execution.succeeded", { data: { sessionID: "root" } });
  cleanup();
  assert.equal(output.length, 2);
});

test("unloading the plugin removes its listeners", () => {
  const { cleanup, events, output } = startBell();
  cleanup();
  events.emit("session.execution.succeeded", { data: { sessionID: "root" } });
  events.emit("permission.asked", {
    data: { id: "permission", sessionID: "root" },
  });
  events.emit("form.created", {
    data: { form: { id: "question", sessionID: "root" } },
  });
  assert.deepEqual(output, []);
});

import assert from "node:assert/strict";
import { test } from "node:test";
import { footerInfo } from "../plugins/prompt-footer/footer.js";

/** Provide the same public data used by the native footer */
const fixture = () => {
  const location = { directory: "/Users/art/git/dotfiles" };
  const selected = { modelID: "gpt-6.1-sol", providerID: "duolingo-openai" };
  const session = { location };
  const models = [
    {
      id: "gpt-6.1-sol",
      limit: { context: 1000000 },
      name: "GPT-6.1 Sol",
      providerID: "duolingo-openai",
      settings: { reasoningEffort: "xhigh" },
    },
  ];
  return {
    ctx: {
      data: {
        location: {
          default: () => location,
          mcp: { server: { list: () => undefined } },
          model: { list: () => models },
        },
        session: { get: () => session },
      },
      location,
      ui: { model: { current: () => selected } },
    },
    models,
    selected,
    session,
  };
};

test("additive footer reads only model, reasoning, and MCP fields", () => {
  const { ctx } = fixture();
  assert.deepEqual(footerInfo(ctx, "session"), {
    effort: "xhigh",
    mcp: undefined,
    model: "GPT-6.1 Sol",
  });
});

test("explicit reasoning selections replace the model's default", () => {
  const { ctx, selected } = fixture();
  selected.variant = "high";
  assert.equal(footerInfo(ctx, "session").effort, "high");
});

test("the model label follows the current selection", () => {
  const { ctx, models, selected } = fixture();
  models.push({
    id: "other",
    limit: { context: 200000 },
    name: "Other Model",
    providerID: "duolingo-openai",
  });
  selected.modelID = "other";
  selected.variant = "low";
  assert.equal(footerInfo(ctx, "session").model, "Other Model");
  assert.equal(footerInfo(ctx, "session").effort, "low");
});

test("new sessions retain the selected model without reading session usage", () => {
  const { ctx } = fixture();
  assert.equal(footerInfo(ctx).model, "GPT-6.1 Sol");
  assert.equal(footerInfo(ctx).effort, "xhigh");
});

test("catalog warmup uses the selected model ID without throwing", () => {
  const { ctx } = fixture();
  ctx.data.location.model.list = () => undefined;
  assert.equal(footerInfo(ctx, "session").model, "gpt-6.1-sol");
  assert.equal(footerInfo(ctx, "session").effort, undefined);
});

test("MCP counts include only connected servers", () => {
  const { ctx } = fixture();
  ctx.data.location.mcp.server.list = () => [
    { name: "one", status: { status: "connected" } },
    { name: "two", status: { status: "connected" } },
    { name: "disabled", status: { status: "disabled" } },
    { name: "failed", status: { status: "failed" } },
    { name: "pending", status: { status: "pending" } },
    { name: "signin", status: { status: "needs_auth" } },
  ];
  assert.equal(footerInfo(ctx, "session").mcp, "2 MCPs");
});

test("one connected server uses the singular MCP label", () => {
  const { ctx } = fixture();
  ctx.data.location.mcp.server.list = () => [
    { name: "one", status: { status: "connected" } },
  ];
  assert.equal(footerInfo(ctx, "session").mcp, "1 MCP");
});

test("zero connected servers is shown instead of hiding the count", () => {
  const { ctx } = fixture();
  ctx.data.location.mcp.server.list = () => [];
  assert.equal(footerInfo(ctx, "session").mcp, "0 MCPs");
});

test("MCP counts use the session's current workspace", () => {
  const { ctx, session } = fixture();
  session.location = { directory: "/Users/art/worktrees/fix-footer" };
  ctx.data.location.mcp.server.list = location => {
    assert.deepEqual(location, session.location);
    return [{ name: "workspace", status: { status: "connected" } }];
  };
  assert.equal(footerInfo(ctx, "session").mcp, "1 MCP");
});

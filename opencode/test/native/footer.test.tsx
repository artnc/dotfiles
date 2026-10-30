import { expect, test } from "bun:test";
import { EventEmitter } from "node:events";
import { readFileSync } from "node:fs";
import { RGBA } from "@opentui/core";
import { testRender } from "@opentui/solid";
import { createStore } from "solid-js/store";
import nativeFooter from "../upstream/packages/tui/src/feature-plugins/prompt/footer.tsx";
import nativeBtw from "../upstream/packages/tui/src/feature-plugins/prompt/btw.tsx";
import { PromptMetadataRow } from "../upstream/packages/tui/src/component/prompt/metadata.tsx";
import { Slot } from "../upstream/packages/tui/src/plugin/render.tsx";
import customFooter from "../custom/prompt-footer/tui.tsx";
import hideMetadata from "../custom/hide-activity-summary/tui.js";
import halfCellPadding from "../custom/half-cell-padding/tui.js";
import { createSlots, setHost } from "./adapters.tsx";
import { NativeHostFooter } from "./host-footer.tsx";

/** Mount our plugins beside unmodified native status components and slots */
const fixture = async (width = 160, version = "2.2.2") => {
  // Provide deterministic backend state without sending real agent prompts
  const [state, setState] = createStore({
    auto: false,
    bindings: { agent: "shift+tab", palette: "ctrl+p" },
    busy: false,
    children: [],
    goal: undefined,
    interrupt: 0,
    limit: undefined,
    location: { directory: "/tmp/native-project" },
    mode: "normal",
    pendingNew: false,
    progress: undefined,
    route: { sessionID: "session", type: "session" },
    shells: [],
    showDetails: true,
    usage: true,
  });
  const registry = createSlots();
  const events = new EventEmitter();
  const goalEvents = new EventEmitter();
  const dialogs = [];
  const dispatched = [];
  const errors = [];
  const layers = [];
  const clicks = { location: 0 };
  let answer;
  const color = RGBA.fromValues(0.7, 0.7, 0.7, 1);
  const theme = {
    background: {
      base: RGBA.fromValues(0, 0, 0, 0),
      raised: { base: RGBA.fromValues(0.1, 0.1, 0.1, 1) },
    },
    decrease: c => c,
    hue: { accent: { 500: color }, interactive: { 200: color } },
    surface: () => theme,
    text: {
      action: { primary: { disabled: color } },
      base: color,
      feedback: {
        error: { base: color },
        success: { base: color },
        warning: { base: color },
      },
      muted: color,
    },
  };
  const models = [
    {
      id: "model",
      limit: { context: 1000 },
      name: "Test Model",
      providerID: "test",
      settings: { reasoningEffort: "high" },
    },
  ];
  const messages = [
    {
      agent: "build",
      id: "assistant",
      model: { id: "model", providerID: "test" },
      tokens: {
        cache: { read: 100, write: 0 },
        input: 200,
        output: 50,
        reasoning: 0,
      },
      type: "assistant",
    },
  ];
  const toast = {
    error: e => errors.push(e),
    show: e => {
      if (e.variant === "error") {
        errors.push(e);
      }
    },
  };
  let app;
  const ctx = {
    app: { channel: "test", version },
    client: {
      rpc: () => ({
        events: {
          on: (name, callback) => {
            goalEvents.on(name, callback);
            return () => goalEvents.off(name, callback);
          },
        },
        get: async () => state.goal,
      }),
      session: {
        generate: () =>
          new Promise(resolve => {
            answer = resolve;
          }),
      },
    },
    data: {
      location: {
        default: () => state.location,
        mcp: {
          server: {
            list: () => [
              { name: "connected", status: { status: "connected" } },
            ],
          },
        },
        model: { list: () => models },
        vcs: { info: () => ({ branch: { current: "main" } }) },
      },
      on: (name, callback) => {
        events.on(name, callback);
        return () => events.off(name, callback);
      },
      session: {
        cost: () => (state.usage ? 1.25 : 0),
        family: () => ["session", ...state.children],
        get: () => ({ agent: "build", location: state.location }),
        message: { list: () => (state.usage ? messages : []) },
        status: id =>
          id === "session" ? (state.busy ? "running" : "idle") : "running",
      },
      shell: { list: () => state.shells },
    },
    keymap: {
      dispatch: id => dispatched.push(id),
      layer: factory => layers.push(factory),
      shortcuts: id =>
        id === "command.palette.show"
          ? [state.bindings.palette]
          : id === "session.child.first"
            ? ["down"]
            : [state.bindings.agent],
    },
    get location() {
      return state.location;
    },
    get renderer() {
      return app?.renderer;
    },
    theme,
    ui: {
      dialog: {
        prompt: async () => undefined,
        set: () => {},
        show: render => dialogs.push(render),
      },
      model: {
        current: () => ({
          modelID: "model",
          providerID: "test",
          variant: "high",
        }),
      },
      router: { current: () => state.route },
      toast,
    },
  };
  const context = owner => ({
    ...ctx,
    get renderer() {
      return app.renderer;
    },
    ui: { ...ctx.ui, slot: claim => registry.slot(owner, claim) },
  });
  setHost({
    ctx,
    layers,
    plugins: { markdown: () => undefined, slots: registry.slots },
    state,
    toast,
  });

  // Register real native plugins before our additive controls
  nativeFooter.setup(context("opencode.prompt.footer"));
  nativeBtw.setup(context("opencode.btw"));
  const stopFooter = customFooter.setup(context("prompt-footer"));
  app = await testRender(
    () => (
      <box height="100%" paddingBottom={1} paddingLeft={2} paddingRight={2}>
        <box flexGrow={1} minHeight={0} />
        <box border={["left"]} borderColor={color}>
          <box
            backgroundColor={theme.background.raised.base}
            paddingLeft={2}
            paddingRight={2}
            paddingTop={1}
          >
            <textarea
              initialValue="Fixture input"
              maxHeight={4}
              minHeight={1}
              width="100%"
            />
            <box id="native.metadata" paddingTop={1}>
              <PromptMetadataRow
                agent="Build"
                agentAlpha={1}
                auto={state.auto}
                highlight={color}
                limit={state.limit}
                mode={state.mode}
                model="Test Model"
                modelAlpha={1}
                muted={false}
                provider="Test Provider"
                variant="high"
                variantAlpha={1}
              />
            </box>
          </box>
        </box>
        <NativeHostFooter
          config={{ animations: false }}
          editorContextLabelState={() => "none"}
          editorFileLabelDisplay={() => ""}
          footerInput={() => ({
            mode: state.mode,
            sessionID: "session",
            showDetails: state.showDetails,
          })}
          locationActions={{
            hovered: () => false,
            onMouseOut: () => {},
            onMouseOver: () => {},
            onMouseUp: () => {
              clicks.location++;
            },
          }}
          locationLabelDisplay={() => `${state.location.directory}:main`}
          move={{
            creatingDots: () => 0,
            pendingNew: () => state.pendingNew,
            progress: () => state.progress,
          }}
          setLocationWidth={() => {}}
          spinnerDef={() => ({ color, frames: [] })}
          status={() => (state.busy ? "running" : "idle")}
          store={state}
          theme={theme}
        />
        <Slot path="app" />
      </box>
    ),
    { height: 14, width },
  );
  await app.renderOnce();
  const baseline = app.captureCharFrame();
  const stopMetadata = hideMetadata.setup(ctx);
  const stopPadding = halfCellPadding.setup(ctx);

  // Drive native RPC events and inspect real rendered output and hit targets
  return {
    answer: result => answer(result),
    app,
    baseline,
    clicks,
    command: id =>
      layers
        .flatMap(factory => factory().commands ?? [])
        .find(c => c.id === id),
    context,
    dialogs,
    dispatched,
    goal: value => {
      setState("goal", value);
      goalEvents.emit("changed", {
        data: { goal: value, sessionID: "session" },
      });
    },
    registry,
    restoreMetadata: stopMetadata,
    setState,
    stop: async () => {
      stopPadding();
      stopMetadata();
      stopFooter();
      await app.dispose();
      expect(errors).toEqual([]);
    },
    text: () => app.captureCharFrame(),
    textNode: value => {
      const nodes = [app.renderer.root];
      while (nodes.length) {
        const node = nodes.pop();
        if (node.plainText?.includes(value)) {
          return node;
        }
        nodes.push(...node.getChildren());
      }
      throw new Error(`Native text wasn't mounted: ${value}`);
    },
  };
};

test("the tracked configuration leaves the bundled footer enabled", () => {
  const config = JSON.parse(
    readFileSync(new URL("./cli.json", import.meta.url), "utf8"),
  );
  expect(config.plugins ?? []).not.toContain("-opencode.prompt.footer");
});

test("only standalone keyboard hints are hidden, including custom bindings", async () => {
  const f = await fixture();
  try {
    expect(f.baseline).toContain("ctrl+p commands");
    await f.app.renderOnce();
    expect(f.text()).not.toContain("ctrl+p commands");
    f.setState("usage", false);
    await f.app.renderOnce();
    expect(f.text()).not.toContain("shift+tab agents");
    f.setState("bindings", "palette", "ctrl+k");
    f.setState("bindings", "agent", "alt+a");
    await f.app.renderOnce();
    expect(f.text()).not.toContain("ctrl+k commands");
    expect(f.text()).not.toContain("alt+a agents");
    f.restoreMetadata();
    await f.app.renderOnce();
    expect(f.text()).toContain("ctrl+k commands");
    expect(f.text()).toContain("alt+a agents");
  } finally {
    await f.stop();
  }
});

test("hint-like labels with unfamiliar structure remain visible", async () => {
  const f = await fixture();
  const remove = f
    .context("future-native-feature")
    .ui.slot({
      append: "prompt.footer",
      render: () => <text id="future.literal-hint">ctrl+p commands</text>,
    });
  try {
    await f.app.renderOnce();
    expect(
      f.app.renderer.root.findDescendantById("future.literal-hint").visible,
    ).toBe(true);
    expect(f.text()).toContain("ctrl+p commands");
  } finally {
    remove();
    await f.stop();
  }
});

test("untested versions retain their native keyboard hints", async () => {
  const f = await fixture(160, "2.2.3");
  try {
    await f.app.renderOnce();
    expect(f.text()).toContain("ctrl+p commands");
  } finally {
    await f.stop();
  }
});

test("native goal status, state updates, and its dialog stay available", async () => {
  const f = await fixture();
  try {
    f.goal({ objective: "Finish the task", status: "active" });
    await f.app.waitForFrame(s => s.includes("◎ goal"));
    expect(f.text()).toContain("Test Model");
    const target = f.textNode("◎ goal");
    await f.app.mockMouse.click(target.x, target.y);
    expect(f.dialogs).toHaveLength(1);
    f.goal({ objective: "Finish the task", status: "paused" });
    await f.app.waitForFrame(s => s.includes("goal paused"));
    f.goal({ objective: "Finish the task", status: "complete" });
    await f.app.waitForFrame(s => s.includes("goal met"));
    expect(
      f.registry
        .claims()
        .some(
          c => c.plugin === "prompt-footer" && c.placement.kind === "replace",
        ),
    ).toBe(false);
  } finally {
    await f.stop();
  }
});

test("the native /btw pending indicator remains visible until its answer arrives", async () => {
  const f = await fixture();
  try {
    await f.app.renderOnce();
    const running = f.command("session.aside").run("What changed?");
    await f.app.waitForFrame(s => s.includes("/btw"));
    expect(f.text()).toContain("/tmp/native-project:main");
    f.answer({ text: "Native answer" });
    await running;
    await f.app.renderOnce();
    expect(f.text()).not.toContain("/btw");
    expect(f.dialogs).toHaveLength(1);
  } finally {
    await f.stop();
  }
});

test("native worktree progress, pending state, and location callbacks survive", async () => {
  const f = await fixture();
  try {
    f.setState("progress", "Creating worktree");
    await f.app.waitForFrame(s => s.includes("Creating worktree"));
    f.setState("progress", "Creating session");
    await f.app.waitForFrame(s => s.includes("Creating session"));
    f.setState("progress", undefined);
    f.setState("pendingNew", true);
    await f.app.waitForFrame(s => s.includes("(new worktree)"));
    f.setState("pendingNew", false);
    await f.app.waitForFrame(s => s.includes("/tmp/native-project:main"));
    const target = f.app.renderer.root.findDescendantById(
      "prompt.footer.location",
    );
    await f.app.mockMouse.click(target.x, target.y);
    expect(f.clicks.location).toBe(1);
  } finally {
    await f.stop();
  }
});

test("native activity counts and shell exit hints remain native-owned", async () => {
  const f = await fixture();
  try {
    f.setState("children", ["child"]);
    f.setState("shells", [{ metadata: { sessionID: "session" } }]);
    await f.app.waitForFrame(
      s => s.includes("1 subagent") && s.includes("1 shell"),
    );
    const target = f.textNode("1 subagent");
    await f.app.mockMouse.click(target.x, target.y);
    expect(f.dispatched).toContain("session.child.first");
    f.setState("mode", "shell");
    await f.app.waitForFrame(s => s.includes("exit shell mode"));
    expect(f.text()).not.toContain("Test Model");
    expect(f.text()).not.toContain("1 MCP");
  } finally {
    await f.stop();
  }
});

test("native interrupt prompts retain their normal and armed states", async () => {
  const f = await fixture();
  try {
    f.setState("busy", true);
    await f.app.waitForFrame(s => s.includes("esc interrupt"));
    f.setState("interrupt", 1);
    await f.app.waitForFrame(s => s.includes("esc again to interrupt"));
    f.setState("interrupt", 0);
    await f.app.waitForFrame(
      s => s.includes("esc interrupt") && !s.includes("again"),
    );
  } finally {
    await f.stop();
  }
});

test("supplemental fields yield to native goal status in narrow terminals", async () => {
  const f = await fixture(60);
  try {
    f.goal({ objective: "Keep native UI", status: "active" });
    await f.app.waitForFrame(s => s.includes("◎ goal"));
    expect(f.text()).not.toContain("1 MCP");
    expect(f.text()).toContain("Test Model");
    f.setState("mode", "shell");
    await f.app.waitForFrame(s => s.includes("exit shell mode"));
  } finally {
    await f.stop();
  }
});

test("unknown native status contributions aren't hidden by our plugin", async () => {
  const f = await fixture();
  const remove = f.context("future-native-feature").ui.slot({
    append: "prompt.footer.status",
    render: () => (
      <box flexDirection="row" flexShrink={0}>
        <text>NEW NATIVE STATUS</text>
        <box paddingLeft={3}>
          <box flexDirection="row">
            <text>+</text>
            <text>1 read</text>
          </box>
        </box>
      </box>
    ),
  });
  try {
    await f.app.waitForFrame(s => s.includes("NEW NATIVE STATUS"));
    expect(f.text()).toContain("1 read");
    expect(f.text()).toContain("Test Model");
  } finally {
    remove();
    await f.stop();
  }
});

test("native auto-accept and usage-limit metadata aren't suppressed", async () => {
  const f = await fixture();
  try {
    await f.app.renderOnce();
    expect(
      f.app.renderer.root.findDescendantById("native.metadata").visible,
    ).toBe(false);
    f.setState("auto", true);
    await f.app.waitForFrame(s => s.includes("auto"));
    expect(
      f.app.renderer.root.findDescendantById("native.metadata").visible,
    ).toBe(true);
    f.setState("auto", false);
    f.setState("limit", { danger: true, text: "10% left" });
    await f.app.waitForFrame(s => s.includes("10% left"));
  } finally {
    await f.stop();
  }
});

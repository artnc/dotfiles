import assert from "node:assert/strict";
import childProcess from "node:child_process";
import { EventEmitter, once } from "node:events";
import fs from "node:fs";
import { syncBuiltinESMExports } from "node:module";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, beforeEach, mock, test } from "node:test";
import { fileURLToPath } from "node:url";
import commentLength from "../plugins/comment-length.js";
import rtk from "../plugins/rtk.js";
import settingsSync from "../plugins/settings-sync/tui.js";

const spawnSync = childProcess.spawnSync;
const commentHook = fileURLToPath(
  new URL("../../claude/hook-posttooluse.py", import.meta.url),
);
let directory;
let configHome;

beforeEach(() => {
  directory = fs.mkdtempSync(join(tmpdir(), "dotfiles-opencode-"));
  configHome = process.env.XDG_CONFIG_HOME;
});

afterEach(() => {
  mock.restoreAll();
  syncBuiltinESMExports();
  if (configHome === undefined) {
    delete process.env.XDG_CONFIG_HOME;
  } else {
    process.env.XDG_CONFIG_HOME = configHome;
  }
  fs.rmSync(directory, { force: true, recursive: true });
});

/** Capture the callback registered through the public plugin setup API */
const registerHook = async plugin => {
  let callback;
  await plugin.setup({
    location: { directory },
    tool: {
      hook: async (_name, handler) => {
        callback = handler;
      },
    },
  });
  return callback;
};

/** Run the real shared checker against temporary files, not the user's home */
const useCommentChecker = () => {
  mock.method(childProcess, "spawnSync", (_command, _args, options) => {
    assert.equal(options.timeout, 5000);
    assert.equal(options.killSignal, "SIGKILL");
    return spawnSync("python3", [commentHook], options);
  });
  syncBuiltinESMExports();
};

test("patch checks added lines across hunks and renamed files without flagging old comments", async () => {
  // Create the post-patch files, including an untouched over-long comment
  const oldComment = `// ${"old ".repeat(30)}`;
  const newComment = `    // ${"new ".repeat(25)}`;
  const pythonComment = `# ${"new ".repeat(30)}`;
  fs.writeFileSync(
    join(directory, "changed.js"),
    `${oldComment}\nconst a = 1;\n${newComment}\nconst b = 2;\n${newComment}\n`,
  );
  fs.writeFileSync(join(directory, "renamed.py"), `${pythonComment}\n`);
  useCommentChecker();

  // Supply V2's structured output, with indentation-trimmed patch text
  const event = {
    input: { patchText: "unused: inspect structured results instead" },
    result: {
      content: "Patch applied",
      metadata: { preserved: true },
      output: {
        files: [
          {
            file: "changed.js",
            patch: `--- changed.js\n+++ changed.js\n@@ -1,2 +1,3 @@\n ${oldComment}\n const a = 1;\n+${newComment.trimStart()}\n@@ -3 +4,2 @@\n const b = 2;\n+${newComment.trimStart()}\n`,
            status: "modified",
          },
          {
            file: "renamed.py",
            patch: `--- old.py\n+++ renamed.py\n@@ -0,0 +1 @@\n+${pythonComment}\n`,
            status: "modified",
          },
          {
            file: "deleted.js",
            patch: "--- deleted.js\n+++ /dev/null\n",
            status: "deleted",
          },
        ],
      },
    },
    status: "completed",
    tool: "patch",
  };
  const output = event.result.output;
  await (
    await registerHook(commentLength)
  )(event);

  // Preserve successful output and report only the newly written comment lines
  assert.deepEqual(event.result.content[0], {
    text: "Patch applied",
    type: "text",
  });
  assert.match(event.result.content[1].text, /L3 \(107 cols\)/);
  assert.match(event.result.content[1].text, /L5 \(107 cols\)/);
  assert.match(event.result.content[1].text, /renamed\.py/);
  assert.doesNotMatch(
    event.result.content[1].text,
    /L1 \(123 cols\)|deleted\.js/,
  );
  assert.deepEqual(event.result.metadata, { preserved: true });
  assert.equal(event.result.output, output);
});

test("removal-only patches don't flag existing long comments", async () => {
  fs.writeFileSync(join(directory, "changed.js"), `// ${"old ".repeat(30)}\n`);
  useCommentChecker();
  const event = {
    result: {
      content: "Patch applied",
      output: {
        files: [
          {
            file: "changed.js",
            patch: "@@ -1,2 +1 @@\n // existing comment\n-const removed = 1;\n",
            status: "modified",
          },
        ],
      },
    },
    status: "completed",
    tool: "patch",
  };
  await (
    await registerHook(commentLength)
  )(event);
  assert.equal(event.result.content, "Patch applied");
});

for (const tool of ["edit", "write"]) {
  test(`${tool} reports over-long comments after the formatter rewrites them`, async () => {
    // Save formatted text that no longer contains the tool's raw input
    const text = `// ${"new ".repeat(30)}`;
    fs.writeFileSync(join(directory, "changed.js"), `${text}\n`);
    useCommentChecker();

    // Supply both tools' result shapes so that each tool reads its own field
    const event = {
      input: {
        content: `  ${text}`,
        newString: `  ${text}`,
        path: "changed.js",
      },
      result: {
        content: [],
        output: {
          files: [
            {
              file: "changed.js",
              patch: `@@ -0,0 +1 @@\n+${text}\n`,
              status: "modified",
            },
          ],
        },
      },
      status: "completed",
      tool,
    };
    await (
      await registerHook(commentLength)
    )(event);
    assert.match(event.result.content[0].text, /L1 \(123 cols\)/);
  });
}

test("a failed patch isn't checked again", async () => {
  mock.method(childProcess, "spawnSync", () => {
    throw new Error("Unexpected checker invocation");
  });
  syncBuiltinESMExports();
  await (
    await registerHook(commentLength)
  )({ status: "error", tool: "patch" });
});

test("checker timeout leaves the successful tool result intact", async () => {
  mock.method(childProcess, "spawnSync", (_command, _args, options) => {
    assert.equal(options.timeout, 5000);
    assert.equal(options.killSignal, "SIGKILL");
    return { error: { code: "ETIMEDOUT" }, signal: "SIGKILL", status: null };
  });
  syncBuiltinESMExports();
  const event = {
    input: { content: "// comment", path: "changed.js" },
    result: { content: "Created file" },
    status: "completed",
    tool: "write",
  };
  await (
    await registerHook(commentLength)
  )(event);
  assert.equal(event.result.content, "Created file");
});

for (const [name, result, expected] of [
  [
    "rewrites successful commands",
    { status: 0, stdout: "rtk git status\n" },
    "rtk git status",
  ],
  [
    "preserves commands on timeout",
    {
      error: { code: "ETIMEDOUT" },
      signal: "SIGKILL",
      status: null,
      stdout: "partial",
    },
    "git status",
  ],
  [
    "preserves commands when RTK is missing",
    { error: { code: "ENOENT" }, status: null },
    "git status",
  ],
  [
    "preserves commands on empty output",
    { status: 0, stdout: "" },
    "git status",
  ],
]) {
  test(`RTK ${name}`, async () => {
    mock.method(childProcess, "spawnSync", (_command, _args, options) => {
      assert.equal(options.timeout, 5000);
      assert.equal(options.killSignal, "SIGKILL");
      return result;
    });
    syncBuiltinESMExports();
    const event = { input: { command: "git status" }, tool: "shell" };
    await (
      await registerHook(rtk)
    )(event);
    assert.equal(event.input.command, expected);
  });
}

/** Use real files and installed symlinks, with a stub for OS watch events */
const startSettingsSync = async (
  live = { prompt: { image_preview: true } },
) => {
  const config = join(directory, "config", "opencode");
  const repo = join(directory, "repo", "opencode");
  fs.mkdirSync(config, { recursive: true });
  fs.mkdirSync(join(repo, "plugins"), { recursive: true });
  fs.symlinkSync(join(repo, "plugins"), join(config, "plugins"));
  fs.writeFileSync(join(config, "cli.json"), `${JSON.stringify(live)}\n`);
  fs.writeFileSync(join(repo, "cli.json"), "{}\n");
  process.env.XDG_CONFIG_HOME = join(directory, "config");
  let changed;
  const watcher = Object.assign(new EventEmitter(), { close: () => {} });
  mock.method(fs, "watch", (path, callback) => {
    assert.equal(path, config);
    changed = callback;
    return watcher;
  });
  syncBuiltinESMExports();
  const cleanup = await settingsSync.setup({
    ui: {
      toast: {
        show: error => {
          throw new Error(error.message);
        },
      },
    },
  });
  return { changed, cleanup, config, repo };
};

test("settings sync captures atomic UI saves without replacing either file with a symlink", async () => {
  const { changed, cleanup, config, repo } = await startSettingsSync();
  assert.equal(fs.readFileSync(join(repo, "cli.json"), "utf8"), "{}\n");
  fs.writeFileSync(
    join(config, "cli.json.tmp"),
    '{"prompt":{"image_preview":false}}\n',
  );
  fs.renameSync(join(config, "cli.json.tmp"), join(config, "cli.json"));
  changed("rename", "cli.json");
  await cleanup();
  assert.deepEqual(
    JSON.parse(fs.readFileSync(join(repo, "cli.json"), "utf8")),
    { prompt: { image_preview: false } },
  );
  assert.equal(fs.lstatSync(join(config, "cli.json")).isSymbolicLink(), false);
  assert.equal(fs.lstatSync(join(repo, "cli.json")).isSymbolicLink(), false);
});

test("settings sync ignores runtime and credential file changes", async () => {
  const { changed, cleanup, repo } = await startSettingsSync();
  changed("rename", "service.json");
  changed("change", "auth.json");
  await cleanup();
  assert.equal(fs.readFileSync(join(repo, "cli.json"), "utf8"), "{}\n");
});

test("settings sync keeps the latest of several queued saves", async () => {
  const { changed, cleanup, config, repo } = await startSettingsSync();
  changed("rename", "cli.json");
  fs.writeFileSync(
    join(config, "cli.json"),
    '{"session":{"sidebar":"auto"}}\n',
  );
  changed("rename", Buffer.from("cli.json"));
  await cleanup();
  assert.deepEqual(
    JSON.parse(fs.readFileSync(join(repo, "cli.json"), "utf8")),
    { session: { sidebar: "auto" } },
  );
});

test("settings sync preserves repo-only keybindings and unrelated session settings", async () => {
  const { changed, cleanup, config, repo } = await startSettingsSync({
    session: { sidebar: "auto" },
  });
  fs.writeFileSync(
    join(repo, "cli.json"),
    JSON.stringify({
      keybinds: { "session.new": "ctrl+n" },
      session: { sidebar: "auto", tps: false },
    }),
  );
  fs.writeFileSync(
    join(config, "cli.json"),
    '{"session":{"sidebar":"hide"}}\n',
  );
  changed("rename", "cli.json");
  await cleanup();
  assert.deepEqual(
    JSON.parse(fs.readFileSync(join(repo, "cli.json"), "utf8")),
    {
      keybinds: { "session.new": "ctrl+n" },
      session: { sidebar: "hide", tps: false },
    },
  );
});

test("settings sync removes fields reset in the UI without removing unrelated fields", async () => {
  const { changed, cleanup, config, repo } = await startSettingsSync({
    attention: { sound: true },
  });
  fs.writeFileSync(
    join(repo, "cli.json"),
    '{"attention":{"sound":true,"volume":0.5}}\n',
  );
  fs.writeFileSync(join(config, "cli.json"), '{"attention":{}}\n');
  changed("rename", "cli.json");
  await cleanup();
  assert.deepEqual(
    JSON.parse(fs.readFileSync(join(repo, "cli.json"), "utf8")),
    { attention: { volume: 0.5 } },
  );
});

test("settings sync sorts object keys recursively without changing array order", async () => {
  const { changed, cleanup, config, repo } = await startSettingsSync();
  fs.writeFileSync(
    join(repo, "cli.json"),
    '{"theme":{"name":"one-dark","mode":"dark"},"plugins":[{"package":"z-plugin","options":{"z":true,"a":false}},{"package":"a-plugin"}],"keybinds":{"session.new":["ctrl+n","<leader>n"]}}',
  );
  fs.writeFileSync(
    join(config, "cli.json"),
    '{"prompt":{"image_preview":false}}\n',
  );
  changed("rename", "cli.json");
  await cleanup();
  assert.equal(
    fs.readFileSync(join(repo, "cli.json"), "utf8"),
    `${JSON.stringify({ keybinds: { "session.new": ["ctrl+n", "<leader>n"] }, plugins: [{ options: { a: false, z: true }, package: "z-plugin" }, { package: "a-plugin" }], prompt: { image_preview: false }, theme: { mode: "dark", name: "one-dark" } }, null, 2)}\n`,
  );
});

test("settings sync observes real atomic saves", { timeout: 5000 }, async t => {
  // Reproduce the installed layout using only temporary files
  const config = join(directory, "config", "opencode");
  const repo = join(directory, "repo", "opencode");
  fs.mkdirSync(config, { recursive: true });
  fs.mkdirSync(join(repo, "plugins"), { recursive: true });
  fs.symlinkSync(join(repo, "plugins"), join(config, "plugins"));
  fs.writeFileSync(join(config, "cli.json"), "{}\n");
  fs.writeFileSync(join(repo, "cli.json"), "{}\n");
  process.env.XDG_CONFIG_HOME = join(directory, "config");

  // Wait for a real destination event instead of a timing-dependent sleep
  const watcher = fs.watch(join(repo, "cli.json"));
  t.after(() => watcher.close());
  const saved = once(watcher, "change");
  const cleanup = await settingsSync.setup({
    ui: {
      toast: {
        show: error => {
          throw new Error(error.message);
        },
      },
    },
  });
  t.after(cleanup);
  fs.writeFileSync(
    join(config, "cli.json.tmp"),
    '{"prompt":{"image_preview":true}}\n',
  );
  fs.renameSync(join(config, "cli.json.tmp"), join(config, "cli.json"));
  await saved;
  await cleanup();
  assert.deepEqual(
    JSON.parse(fs.readFileSync(join(repo, "cli.json"), "utf8")),
    { prompt: { image_preview: true } },
  );
});

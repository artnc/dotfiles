import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import { cp, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

// Render pinned native UI without contacting agent providers

// Keep dependencies, caches, and downloaded upstream files outside the repo
const directory = dirname(fileURLToPath(import.meta.url));
const project = resolve(directory, "../..");
const workspace = await mkdtemp("/tmp/opencode-native-footer-");
console.log("Preparing native footer tests in", workspace);
await writeFile(
  join(workspace, "package.json"),
  JSON.stringify({
    dependencies: {
      "@opentui/core": "0.7.0",
      "@opentui/solid": "0.7.0",
      bun: "1.4.4",
      remeda: "2.26.0",
      "solid-js": "1.9.17",
      // Declare @opentui/core's transitive dependency that adapters.tsx imports
      "string-width": "7.2.0",
    },
    overrides: { "solid-js": "1.9.17" },
    private: true,
    type: "module",
  }),
);

// Reject changed source even if an upstream release tag is moved
await Promise.all(
  Object.entries({
    "packages/client/src/solid/usage.ts":
      "98674c01426cf654e0c211fe00e59a57ddfe0783bd494582b6e222599b5c07a7",
    "packages/tui/src/component/prompt/index.tsx":
      "2e752fecea25493985948ba379695eedd9c15cbbeec46ed895fe21878bc56a48",
    "packages/tui/src/component/prompt/metadata.tsx":
      "efa788e8b536cdb98284d56aa0fe1d2d1c635a2c8baf7e47b5698412fe8c1559",
    "packages/tui/src/context/interactivity.tsx":
      "98c93735767b639ea92a75a489e4e670fdc6edc8d0b8d775f5ce9e4932da33c7",
    "packages/tui/src/feature-plugins/prompt/btw.tsx":
      "2231cdec1356849aa12aecd26b2d855024af0749e07b652b1279b2154ca63a20",
    "packages/tui/src/feature-plugins/prompt/footer.tsx":
      "458119ad1a77670faad8a5a8c7eb8a67a01af0ef7ac2bbfc1e7376d5970bcd36",
    "packages/tui/src/feature-plugins/prompt/goal.tsx":
      "b3767d410bc175d05c9ccc4d4bd7a01c8cb845e76bb780049c99005de3e7a17a",
    "packages/tui/src/plugin/render.tsx":
      "bc1a0eb9624a3287239684f67926e651fc5d891d20c96977624c86b181a1a0b1",
    "packages/tui/src/plugin/structure.ts":
      "14513c9decc897c137a3712de389bbb779ddeaac0c7e12c6669838940e52e753",
    "packages/tui/src/util/locale.ts":
      "9a3061e23c80897fab14c384494f051168a6ad8632ce95b02138acb924a9b7d9",
    "packages/tui/src/util/session.ts":
      "515ece1b418732b0dfe64338845f9e310fdcf6130651f2ae3f99526f1008ede9",
    "packages/util/src/duration.ts":
      "d389c1b8ba9058ef6ab9158817263319ea6092eb4907476db6955b5707ed8a7d",
  }).map(async ([path, expected]) => {
    const response = await fetch(
      `https://raw.githubusercontent.com/anomalyco/opencode/v2.2.2/${path}`,
    );
    if (!response.ok) {
      throw new Error(
        `Couldn't fetch native fixture ${path}: HTTP ${response.status}`,
      );
    }
    const text = await response.text();
    if (createHash("sha256").update(text).digest("hex") !== expected) {
      throw new Error(`Native fixture checksum changed: ${path}`);
    }
    await mkdir(dirname(join(workspace, "upstream", path)), {
      recursive: true,
    });
    await writeFile(join(workspace, "upstream", path), text);
  }),
);

// Extract the actual host footer JSX instead of recreating its state branches
const prompt = await readFile(
  join(workspace, "upstream/packages/tui/src/component/prompt/index.tsx"),
  "utf8",
);
const start = prompt.indexOf(
  '<box width="100%" flexDirection="row" justifyContent="space-between" gap={2}>',
);
const end = prompt.indexOf(
  "\n        </box>\n      </box>\n      <Autocomplete",
  start,
);
if (start < 0 || end < 0) {
  throw new Error("Native prompt footer boundaries changed");
}
const interruptStart = prompt.indexOf("export function PromptInterruptStatus(");
const interruptEnd = prompt.indexOf(
  "\nfunction hasEditorRangeSelection",
  interruptStart,
);
if (interruptStart < 0 || interruptEnd < 0) {
  throw new Error("Native interrupt component boundaries changed");
}
await cp(directory, join(workspace, "native"), { recursive: true });
await cp(join(project, "cli.json"), join(workspace, "native/cli.json"));
await cp(join(project, "plugins"), join(workspace, "custom"), {
  recursive: true,
});
await writeFile(
  join(workspace, "native/host-footer.tsx"),
  `import { createEffect, createMemo, Match, on, Show, Switch } from "solid-js";
import { Slot } from "../upstream/packages/tui/src/plugin/render.tsx";
import { createAnimatable, Spinner, tint, tween } from "./adapters.tsx";
${prompt.slice(interruptStart, interruptEnd)}
export const NativeHostFooter = (input) => {
  const { config, editorContextLabelState, editorFileLabelDisplay, footerInput, locationActions, locationLabelDisplay, move, setLocationWidth, spinnerDef, status, store, theme } = input;
  const animationsEnabled = () => false;
  return (${prompt.slice(start, end + "\n        </box>".length)});
};
`,
);

// Install exact published renderer versions, using OpenCode's Solid version
// Share the npm cache across runs so that each run doesn't refetch its 121 MB
const install = spawnSync(
  "npm",
  [
    "install",
    "--no-audit",
    "--no-fund",
    "--package-lock=false",
    "--cache",
    "/tmp/opencode-native-footer-npm-cache",
  ],
  { cwd: workspace, stdio: "inherit" },
);
if (install.error || install.status !== 0) {
  throw (
    install.error ??
    new Error(`Native test dependencies failed: ${install.status}`)
  );
}

// Resolve native host imports through explicit test-only adapter modules
const adapters = join(workspace, "native/adapters.tsx");
for (const path of [
  "component/spinner",
  "config",
  "context/clipboard",
  "context/keymap",
  "context/route",
  "context/theme",
  "plugin/context",
  "ui/dialog",
  "ui/toast",
  "util/error",
  "util/scroll",
  "util/string-width",
]) {
  const target = join(workspace, "upstream/packages/tui/src", `${path}.tsx`);
  await mkdir(dirname(target), { recursive: true });
  await writeFile(
    target,
    `export * from ${JSON.stringify(relative(dirname(target), adapters))};\n`,
  );
}
for (const [name, entries] of Object.entries({
  "@opencode/client": {
    solid: join(workspace, "upstream/packages/client/src/solid/usage.ts"),
  },
  "@opencode/plugin": { tui: adapters },
  "@opencode/schema": { goal: adapters },
  "@opencode/util": {
    duration: join(workspace, "upstream/packages/util/src/duration.ts"),
  },
})) {
  const target = join(workspace, "node_modules", name);
  await mkdir(target, { recursive: true });
  await writeFile(
    join(target, "package.json"),
    JSON.stringify({
      exports: Object.fromEntries(
        Object.keys(entries).map(k => [`./${k}`, `./${k}.ts`]),
      ),
      name,
      private: true,
      type: "module",
    }),
  );
  for (const [key, source] of Object.entries(entries)) {
    await writeFile(
      join(target, `${key}.ts`),
      `export * from ${JSON.stringify(relative(target, source))};\n`,
    );
  }
}

// Keep test execution hermetic and disable Bun's automatic package installs
const result = spawnSync(
  join(workspace, "node_modules/.bin/bun"),
  [
    "test",
    "--no-install",
    "--conditions=browser",
    "--preload",
    "@opentui/solid/preload",
    "./native/footer.test.tsx",
  ],
  {
    cwd: workspace,
    env: {
      ...process.env,
      BUN_INSTALL_CACHE_DIR: join(workspace, "bun-cache"),
      BUN_RUNTIME_TRANSPILER_CACHE_PATH: join(workspace, "transpiler-cache"),
    },
    stdio: "inherit",
  },
);
if (result.error || result.status !== 0) {
  throw (
    result.error ?? new Error(`Native footer tests failed: ${result.status}`)
  );
}

// Delete the ~300 MB workspace after passing runs, but keep failures to debug
console.log("Removing", workspace);
await rm(workspace, { force: true, recursive: true });

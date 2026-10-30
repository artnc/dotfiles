import { watch } from "node:fs";
import { readFile, realpath, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { isDeepStrictEqual } from "node:util";

const isRecord = value =>
  value !== null && typeof value === "object" && !Array.isArray(value);

/** Apply changed UI fields without discarding unrelated edits in the repo */
const mergeChanges = (current, before, after) => {
  const merged = { ...current };
  for (const key of new Set([...Object.keys(before), ...Object.keys(after)])) {
    if (isDeepStrictEqual(before[key], after[key])) {
      continue;
    }
    if (!Object.hasOwn(after, key)) {
      delete merged[key];
      continue;
    }
    merged[key] =
      isRecord(after[key]) &&
      (before[key] === undefined || isRecord(before[key]))
        ? mergeChanges(
            isRecord(merged[key]) ? merged[key] : {},
            before[key] ?? {},
            after[key]
          )
        : after[key];
  }
  return merged;
};

/** Mirror UI saves into the repo without moving private runtime files */
export default {
  id: "settings-sync",
  setup: async ctx => {
    // Locate the repo through the plugins directory installed as a symlink
    const directory = join(
      process.env.XDG_CONFIG_HOME || join(homedir(), ".config"),
      "opencode"
    );
    const source = join(directory, "cli.json");
    const target = join(
      dirname(await realpath(join(directory, "plugins"))),
      "cli.json"
    );
    let pending = Promise.resolve();
    let previous = JSON.parse(await readFile(source, "utf8"));
    const reportError = error =>
      ctx.ui.toast.show({
        message: `Couldn't sync OpenCode settings to dotfiles: ${error.message}`,
        variant: "error",
      });

    // Watch the directory because OpenCode saves cli.json with an atomic rename
    const watcher = watch(directory, (_event, filename) => {
      // Ignore runtime and credential files
      if (filename?.toString() !== "cli.json") {
        return;
      }

      // Serialize copies so that an older save can't overwrite a newer one
      pending = pending
        .then(async () => {
          const next = JSON.parse(await readFile(source, "utf8"));
          const text = await readFile(target, "utf8");
          const updated = `${JSON.stringify(
            mergeChanges(JSON.parse(text), previous, next),
            (_key, value) =>
              isRecord(value)
                ? Object.fromEntries(
                    Object.keys(value)
                      .sort()
                      .map(k => [k, value[k]])
                  )
                : value,
            2
          )}\n`;
          if (text !== updated) {
            await writeFile(target, updated);
          }
          previous = next;
        })
        .catch(reportError);
    });
    watcher.on("error", reportError);

    // Finish queued copies before unloading the plugin
    return () => {
      watcher.close();
      return pending;
    };
  },
};

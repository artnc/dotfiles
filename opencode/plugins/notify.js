/**
 * Port of claude/hook-stop.sh (minus its Claude-settings maintenance): show
 * a desktop notification and ring the terminal bell when opencode finishes a
 * turn or asks for permission
 */
export const Notify = async ({ $, directory }) => ({
  event: async ({ event }) => {
    if (event.type !== "session.idle" && event.type !== "permission.asked") {
      return;
    }

    // Show notification
    const title =
      event.type === "session.idle"
        ? "opencode finished"
        : "opencode needs input";
    const dir = directory.split("/").pop();
    if (process.platform === "darwin") {
      await $`osascript -e ${`display notification "${dir}" with title "${title}"`}`
        .quiet()
        .nothrow();
    } else {
      await $`notify-send ${title} ${dir}`.quiet().nothrow();
    }

    // Ring the bell so tmux flags the window even when it's unfocused
    const bell = process.env.TMUX
      ? `printf '\\a' > "$(tmux display-message -p '#{pane_tty}')"`
      : `printf '\\a' > /dev/tty`;
    await $`sh -c ${bell}`.quiet().nothrow();
  },
});

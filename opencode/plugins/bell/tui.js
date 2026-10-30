import { writeSync } from "node:fs";

/** Keep terminal bells working through SSH while native alerts handle popups */
export default {
  id: "bell",
  setup: ctx => {
    // Deduplicate terminal events and requests replayed after reconnecting
    const sounded = new Set();
    const ring = (sessionID, key) => {
      // Scope shared events to this TUI's displayed session and skip replays
      const route = ctx.ui.router.current();
      if (
        route.type !== "session" ||
        route.sessionID !== sessionID ||
        sounded.has(key)
      ) {
        return;
      }
      sounded.add(key);

      // Send BEL from the client terminal, not the detached server's tty
      writeSync(process.stdout.fd, "\u0007");
    };
    const completed = event => {
      if (ctx.data.session.get(event.data.sessionID)?.parentID) {
        return;
      }
      ring(event.data.sessionID, `session:${event.data.sessionID}`);
    };

    // Ring for completed work or required input, not intermediate idle states
    const dispose = [
      ctx.data.on("session.execution.started", e =>
        sounded.delete(`session:${e.data.sessionID}`)
      ),
      ctx.data.on("session.execution.succeeded", completed),
      ctx.data.on("session.execution.failed", completed),
      // Skip superseded runs because the replacement run rings when it ends
      ctx.data.on("session.execution.interrupted", e => {
        if (e.data.reason !== "superseded") {
          completed(e);
        }
      }),
      ctx.data.on("permission.asked", e =>
        ring(e.data.sessionID, `permission:${e.data.id}`)
      ),
      ctx.data.on("permission.replied", e =>
        sounded.delete(`permission:${e.data.requestID}`)
      ),
      ctx.data.on("form.created", e =>
        ring(e.data.form.sessionID, `form:${e.data.form.id}`)
      ),
      ctx.data.on("form.replied", e => sounded.delete(`form:${e.data.id}`)),
      ctx.data.on("form.cancelled", e => sounded.delete(`form:${e.data.id}`)),
    ];

    // Remove listeners when the TUI unloads or reloads this plugin
    return () => {
      for (const stop of dispose) {
        stop();
      }
    };
  },
};

/** Paint half-cell edges without moving text, hit targets, or scroll anchors */
export default {
  id: "half-cell-padding",
  setup: ctx => {
    // Keep unknown layouts untouched until their native rendering is validated
    if (ctx.app?.version !== "2.2.2") {
      return () => {};
    }
    // Restore only hooks we still own when rows disappear or the plugin reloads
    const patched = new Map();
    const restore = (node, entry) => {
      if (!node.isDestroyed && node.renderAfter === entry.paint) {
        node.renderAfter = entry.before;
      }
      patched.delete(node);
    };
    const update = async () => {
      // Identify message boxes by native user-message anchors, not their text
      const route = ctx.ui.router.current();
      const users = new Set(
        route.type === "session"
          ? ctx.data.session.message
              .list(route.sessionID)
              .filter(m => m.type === "user")
              .map(m => m.id)
          : []
      );
      const targets = new Map();
      const nodes = [[ctx.renderer.root, false]];
      while (nodes.length) {
        const [node, ancestorIsUser] = nodes.pop();
        if (node.isDestroyed || !node.visible) {
          continue;
        }
        const user = ancestorIsUser || users.has(node.id);
        for (const child of node.getChildren()) {
          nodes.push([child, user]);
        }

        // Match the native prompt's one-row top inset inside its left border
        if (typeof node.submit === "function" && node.parent) {
          const surface = node.parent;
          const owner = surface.parent;
          if (
            surface.getPadding?.(1)?.value === 1 &&
            [1, 2].includes(surface.getPadding?.(0)?.value) &&
            surface.backgroundColor?.a > 0 &&
            Array.isArray(owner?.border) &&
            owner.border.includes("left")
          ) {
            targets.set(surface, false);
          }
        }

        // Match both padded edges of previous turns, leaving nested cards alone
        if (
          user &&
          node.getPadding?.(1)?.value === 1 &&
          node.getPadding?.(3)?.value === 1 &&
          node.getPadding?.(0)?.value === 2 &&
          node.backgroundColor?.a > 0 &&
          Array.isArray(node.parent?.border) &&
          node.parent.border.includes("left")
        ) {
          targets.set(node, true);
        }
      }

      // Drop obsolete hooks without overwriting changes made by another plugin
      for (const [node, entry] of patched) {
        if (!targets.has(node) || targets.get(node) !== entry.bottom) {
          restore(node, entry);
        }
      }
      for (const [node, bottom] of targets) {
        if (patched.has(node)) {
          continue;
        }

        // Paint within native hooks so clipping and dialog z-order still apply
        // https://opencode.ai/v2/docs/build/plugins/cli#theme-and-renderer
        const before = node.renderAfter;
        const paint = (buffer, deltaTime) => {
          before?.call(node, buffer, deltaTime);
          if (
            node.isDestroyed ||
            !node.visible ||
            node.backgroundColor.a === 0
          ) {
            return;
          }
          const background = ctx.theme.background.base;
          const owner = node.parent;
          const edges = [[node.y, "▄", "╻"]];
          if (bottom) {
            edges.push([node.y + node.height - 1, "▀", "╹"]);
          }
          for (const [y, glyph, corner] of edges) {
            if (y < 0 || y >= buffer.height) {
              continue;
            }
            for (
              let x = Math.max(0, node.x);
              x < Math.min(buffer.width, node.x + node.width);
              x++
            ) {
              buffer.setCell(x, y, glyph, node.backgroundColor, background);
            }
            if (
              owner?.x === node.x - 1 &&
              owner.x >= 0 &&
              owner.x < buffer.width &&
              (y === owner.y || y === owner.y + owner.height - 1)
            ) {
              buffer.setCell(owner.x, y, corner, owner.borderColor, background);
            }
          }
        };
        patched.set(node, { before, bottom, paint });
        node.renderAfter = paint;
      }
    };

    // Reconcile mounted history rows before each frame, without polling timers
    ctx.renderer.setFrameCallback(update);
    ctx.renderer.requestRender();
    return () => {
      ctx.renderer.removeFrameCallback(update);
      for (const [node, entry] of patched) {
        restore(node, entry);
      }
      ctx.renderer.requestRender();
    };
  },
};

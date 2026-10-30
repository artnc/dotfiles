/** Hide transcript metadata without changing data or permission controls */
export default {
  id: "hide-activity-summary",
  setup: ctx => {
    // Preserve native UI on versions whose internal layout hasn't been tested
    if (ctx.app?.version !== "2.2.2") {
      return () => {};
    }
    const hidden = new Set();
    const viewportPadding = new Map();
    const edges = [
      [3, "paddingBottom"],
      [0, "paddingLeft"],
      [2, "paddingRight"],
    ];
    /** Ignore Solid's invisible slot markers, but retain our own hidden rows */
    const childrenOf = node =>
      node.getChildren().filter(n => n.visible || hidden.has(n));
    const readText = node => {
      if (typeof node === "string") {
        return node;
      }
      // Read Solid's pending text before OpenTUI composes the next frame
      const children =
        typeof node.getTextChildren === "function"
          ? node.textNode.children
          : node.children;
      return Array.isArray(children) && children.length
        ? children.map(readText).join("")
        : (node.plainText ?? "");
    };
    const update = async () => {
      // Match V2.2.2's InlineToolRow, not arbitrary text with the same words
      // Host nodes aren't stable API. Leave unfamiliar layouts unchanged
      // https://opencode.ai/v2/docs/build/plugins/cli#theme-and-renderer
      const targets = new Set();
      const route = ctx.ui.router.current();
      const session = route.type === "session";
      const hints = Object.fromEntries(
        [
          ["agent.cycle", "agents"],
          ["command.palette.show", "commands"],
        ].flatMap(([command, label]) => {
          const key = ctx.keymap?.shortcuts?.(command)?.[0];
          return key ? [[`${key} ${label}`, label]] : [];
        })
      );
      const agents = new Set(
        session
          ? ctx.data.session.message
              .list(route.sessionID)
              .flatMap(m =>
                m.type === "assistant"
                  ? [m.agent.replace(/\b\w/g, c => c.toUpperCase())]
                  : []
              )
          : []
      );
      const selected = ctx.ui.model?.current();
      const model =
        selected &&
        ctx.data.location.model
          .list(ctx.location)
          ?.find(
            m =>
              m.providerID === selected.providerID && m.id === selected.modelID
          );
      // Protect every mounted footer row (our compact box's parent), including
      // cached session tabs, in one walk instead of an ancestor scan per node
      const nodes = [[ctx.renderer.root, false, false]];
      while (nodes.length) {
        const [node, parentIsFooter, inFooter] = nodes.pop();
        if (node.isDestroyed) {
          continue;
        }
        const isFooter = node
          .getChildren()
          .some(n => n.id === "prompt.footer.compact");
        nodes.push(
          ...node.getChildren().map(n => [n, isFooter, inFooter || isFooter])
        );

        // Hide only the duplicate metadata row immediately below the input
        // Skip hidden inputs, which childrenOf() omits from their siblings
        if (
          model &&
          node.visible &&
          typeof node.submit === "function" &&
          node.parent
        ) {
          const siblings = childrenOf(node.parent);
          const metadata = siblings[siblings.indexOf(node) + 1];
          if (metadata?.getPadding?.(1)?.value === 1) {
            // Keep auto-accept and usage-limit labels, which the footer lacks
            // The usage limit is the row's only text with a left margin
            let duplicate = false;
            let indicator = false;
            const parts = [metadata];
            while (parts.length) {
              const part = parts.pop();
              const text = readText(part);
              duplicate ||= text === model.name;
              indicator ||= text === "auto" || part.getMargin?.(0)?.value === 1;
              parts.push(...part.getChildren());
            }
            // It's only a duplicate while this prompt's footer controls show,
            // and they hide below 100 columns and in shell mode
            const compact = (() => {
              for (let parent = node.parent; parent; parent = parent.parent) {
                const match = parent
                  .getChildren()
                  .flatMap(n => (n.isDestroyed ? [] : n.getChildren()))
                  .find(n => n.id === "prompt.footer.compact");
                if (match) {
                  return match;
                }
              }
            })();
            if (duplicate && !indicator && compact?.visible) {
              targets.add(metadata);
            }
          }
        }

        // Hide only native standalone hint leaves with their known label span
        if (parentIsFooter && typeof node.getTextChildren === "function") {
          const label = hints[readText(node)];
          if (
            typeof label === "string" &&
            node.textNode.children
              .filter(n => typeof n !== "string" && n.visible !== false)
              .map(readText)
              .at(-1) === label
          ) {
            targets.add(node);
          }
        }

        // Leave transcript rows alone outside sessions so that they reappear
        if (!session) {
          continue;
        }

        // Remove only decorative insets on the session viewport's column
        if (node.id === "prompt.footer.compact") {
          for (let parent = node.parent; parent; parent = parent.parent) {
            if (
              viewportPadding.has(parent) ||
              (parent.getPadding?.(3)?.value === 1 &&
                [1, 2].includes(parent.getPadding?.(0)?.value) &&
                parent.getPadding?.(0)?.value === parent.getPadding?.(2)?.value)
            ) {
              const saved = viewportPadding.get(parent) ?? {};
              for (const [edge, property] of edges) {
                const value = parent.getPadding(edge).value;
                // Reapply after native responsive insets change on resize
                if (edge === 3 ? value === 1 : [1, 2].includes(value)) {
                  saved[property] = value;
                  parent[property] = 0;
                }
              }
              viewportPadding.set(parent, saved);
              break;
            }
          }
        }

        // Never interpret native footer/status controls as transcript summaries
        if (inFooter || isFooter) {
          continue;
        }

        // Keep the existing transcript summary and footer matching narrow
        const children = childrenOf(node);
        // Yoga edge 0 is left, and InlineToolRow has a three-cell indent
        if (node.getPadding?.(0)?.value !== 3 || children.length !== 1) {
          continue;
        }

        // Match the footer's agent and metadata spans, not errors or retries
        // Keep interrupted turns because they show no error row
        if (typeof children[0].getTextChildren === "function") {
          const spans = children[0].textNode.children.filter(
            n => typeof n !== "string" && n.visible !== false
          );
          if (
            spans.length >= 2 &&
            agents.has(readText(spans[0])) &&
            spans.slice(1).every(n => readText(n).startsWith(" · ")) &&
            !spans.some(n => readText(n) === " · interrupted")
          ) {
            const row = node.parent;
            targets.add(
              row && childrenOf(row).length === 1 && row.marginTop === 1
                ? row
                : node
            );
            continue;
          }
        }

        const content = childrenOf(children[0]);
        if (
          content.length === 2 &&
          !["+", "−"].includes(readText(content[0])) &&
          childrenOf(content[0]).length !== 1
        ) {
          continue;
        }
        if (content.length !== 2 && !readText(children[0]).startsWith("⋯ ")) {
          continue;
        }
        if (
          !readText(content.length === 2 ? content[1] : children[0])
            .replace(/^⋯ /u, "")
            .split(", ")
            .every(s =>
              /^\d+ (?:command|edit|thought|read|tool|instruction)s?$/.test(s)
            )
        ) {
          continue;
        }

        // Remove the empty row's spacing, but keep pending tools and details
        const group = node.parent;
        const row = group?.parent;
        targets.add(
          group &&
            row &&
            childrenOf(group).length === 1 &&
            childrenOf(row).length === 1 &&
            row.marginTop === 1
            ? row
            : node
        );
      }

      // Forget destroyed nodes without reading freed native layout properties
      for (const [node] of viewportPadding) {
        if (node.isDestroyed) {
          viewportPadding.delete(node);
        }
      }

      // Restore reused rows when pending controls appear
      for (const node of hidden) {
        if (node.isDestroyed || !targets.has(node)) {
          if (!node.isDestroyed) {
            node.visible = true;
          }
          hidden.delete(node);
        }
      }
      for (const node of targets) {
        if (node.visible) {
          node.visible = false;
          hidden.add(node);
        }
      }
    };

    // Keep metadata hidden without adding commands or storing preferences
    ctx.renderer.setFrameCallback(update);
    ctx.renderer.requestRender();

    // Restore host nodes and detach the callback when disabled or reloaded
    return () => {
      ctx.renderer.removeFrameCallback(update);
      for (const node of hidden) {
        if (!node.isDestroyed) {
          node.visible = true;
        }
      }
      hidden.clear();
      for (const [node, saved] of viewportPadding) {
        if (node.isDestroyed) {
          continue;
        }
        for (const [edge, property] of edges) {
          if (node.getPadding(edge).value === 0 && property in saved) {
            node[property] = saved[property];
          }
        }
      }
      viewportPadding.clear();
    };
  },
};

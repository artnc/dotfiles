/** Read additive model and MCP labels without duplicating native status */
export const footerInfo = (ctx, sessionID) => {
  // Follow the session's location, including worktrees and directory changes
  const session = sessionID ? ctx.data.session.get(sessionID) : undefined;
  const location =
    session?.location ?? ctx.location ?? ctx.data.location.default();
  const models = ctx.data.location.model.list(location) ?? [];
  const selected = ctx.ui.model.current();
  const model = models.find(
    m => m.providerID === selected?.providerID && m.id === selected?.modelID
  );
  const connected = ctx.data.location.mcp.server
    .list(location)
    ?.filter(s => s.status.status === "connected").length;

  // Use the configured reasoning default when no explicit variant is selected
  return {
    effort: selected?.variant ?? model?.settings?.reasoningEffort,
    mcp:
      connected === undefined
        ? undefined
        : `${connected} MCP${connected === 1 ? "" : "s"}`,
    model: model?.name ?? selected?.modelID,
  };
};

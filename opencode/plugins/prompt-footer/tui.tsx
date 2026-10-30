import type { Plugin } from "@opencode/plugin/tui";
import { useTerminalDimensions } from "@opentui/solid";
import { Index, Show, createMemo, createSignal } from "solid-js";
import { footerInfo } from "./footer.js";

/** Link footer fields to native commands without breaking text selection */
const FooterField = (props: {
  command?: string;
  ctx: Plugin.Context;
  id: string;
  text?: string;
}) => {
  const [hovered, setHovered] = createSignal(false);
  return (
    <text
      id={`prompt.footer.${props.id}`}
      fg={
        props.command && hovered()
          ? props.ctx.theme.text.base
          : props.ctx.theme.text.muted
      }
      flexShrink={1}
      minWidth={0}
      onMouseOver={() => setHovered(true)}
      onMouseOut={() => setHovered(false)}
      onMouseUp={event => {
        // Ignore passive fields, right-clicks, and text-selection drags
        if (
          !props.command ||
          event.button !== 0 ||
          props.ctx.renderer.getSelection()?.getSelectedText()
        ) {
          return;
        }
        event.stopPropagation();
        props.ctx.keymap.dispatch(props.command);
      }}
      truncate
      wrapMode="none"
    >
      {props.text}
    </text>
  );
};

/** Add model and MCP controls without replacing native operational status */
export default {
  id: "prompt-footer",
  /** Keep supplemental controls beside the unmodified native footer */
  setup: (ctx: Plugin.Context) =>
    ctx.ui.slot({
      append: "prompt.footer",
      render: props => {
        const info = createMemo(() => footerInfo(ctx, props.sessionID));
        const dimensions = useTerminalDimensions();
        // Yield to native status in shell mode and below 100 columns
        return (
          <box
            id="prompt.footer.compact"
            flexDirection="row"
            flexShrink={1}
            minWidth={0}
            overflow="hidden"
            visible={
              props.showDetails &&
              props.mode === "normal" &&
              dimensions().width >= 100
            }
          >
            <Index
              each={[
                { command: "model.list", id: "model", text: info().model },
                { command: "variant.list", id: "effort", text: info().effort },
                // The sidebar toggle only exists in the session layer
                {
                  command: props.sessionID
                    ? "session.sidebar.toggle"
                    : undefined,
                  id: "mcp",
                  text: info().mcp,
                },
              ].filter(f => f.text)}
            >
              {(field, index) => (
                <>
                  <Show when={index > 0}>
                    <text fg={ctx.theme.text.muted} flexShrink={0}>
                      {" "}
                      ·{" "}
                    </text>
                  </Show>
                  <FooterField
                    command={field().command}
                    ctx={ctx}
                    id={field().id}
                    text={field().text}
                  />
                </>
              )}
            </Index>
          </box>
        );
      },
    }),
};

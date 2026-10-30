import { createSignal } from "solid-js";
import { resolveSlots } from "../upstream/packages/tui/src/plugin/structure.ts";

// Adapt backend, theme, dialog hosting, and decorative animation
let current;
export const setHost = host => {
  current = host;
};
export const Plugin = { define: definition => definition };
export const Goal = { Definition: Symbol("native-goal-rpc") };
export const useTheme = () => current.ctx.theme;
export const useConfig = () => ({ data: { animations: false } });
export const useRoute = () => ({ data: current.state.route });
export const useToast = () => current.toast;
export const usePlugin = () => current.plugins;
export const useClipboard = () => ({ write: async () => {} });
export const useThemes = () => ({ currentSyntax: () => undefined });
export const Keymap = { createLayer: factory => current.layers.push(factory) };

export const getScrollAcceleration = () => ({ next: () => 1 });
export const errorMessage = error =>
  error instanceof Error ? error.message : String(error);
export const DIALOG_INSET = 2;
export const DialogBleed = props => props.children;
export const DialogFooter = () => null;
export const DialogHeader = () => null;
export const DialogLayout = props => props.children;
export const Spinner = props => (
  <text fg={props.color} wrapMode="none">
    ⋯ {props.children}
  </text>
);
export const createAnimatable = initial => {
  const [value, setValue] = createSignal(initial);
  return { animate: setValue, jump: setValue, value };
};
export const tint = color => color;
export const tween = () => undefined;

/** Supply provider state to the real native Slot and slot-tree resolver */
export const createSlots = () => {
  const [claims, setClaims] = createSignal([]);
  const [paths, setPaths] = createSignal(new Set());
  const counts = {};
  let serial = 0;
  return {
    claims,
    slot: (owner, claim) => {
      const kind = ["append", "prepend", "replace", "before", "after"].find(
        k => k in claim,
      );
      const entry = {
        key: `claim-${serial++}`,
        placement: { kind, target: claim[kind] },
        plugin: owner,
        render: claim.render,
      };
      setClaims(c => [...c, entry]);
      return () => setClaims(c => c.filter(e => e !== entry));
    },
    slots: {
      register: path => {
        counts[path] = (counts[path] ?? 0) + 1;
        setPaths(new Set(Object.keys(counts)));
        return () => {
          if (--counts[path] === 0) {
            delete counts[path];
            setPaths(new Set(Object.keys(counts)));
          }
        };
      },
      resolved: () => resolveSlots({ claims: claims(), paths: paths() }),
    },
  };
};

export { default as stringWidth } from "string-width";

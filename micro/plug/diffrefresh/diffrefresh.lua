VERSION = "0.1.0"

local os = import("os")
local filepath = import("path/filepath")
local shell = import("micro/shell")

-- The bundled `diff` plugin only sets the git diff base in onBufferOpen, so the
-- gutter goes stale whenever HEAD moves under an already-open buffer (commit,
-- checkout, stash, pull, rebase). Recompute the base on the events it misses
local function refresh_diff_base(buf)
  if not buf.Settings["diffgutter"] or buf.Type.Scratch or buf.Path == "" then
    return
  end
  -- skip buffers whose file doesn't exist on disk yet
  local _, stat_err = os.Stat(buf.AbsPath)
  if stat_err ~= nil then
    return
  end
  local dir_name, file_name = filepath.Split(buf.AbsPath)
  -- mirror the bundled diff plugin: base is the file's contents at git HEAD,
  -- falling back to the buffer itself (no markers) when not under git
  local diff_base, git_err = shell.ExecCommand("git", "-C", dir_name, "show", "HEAD:./" .. file_name)
  if git_err ~= nil then
    diff_base = buf:Bytes()
  end
  buf:SetDiffBase(diff_base)
end

-- refresh after saving (catches HEAD moving while the file stays open)
function onSave(bp)
  refresh_diff_base(bp.Buf)
end

-- refresh when switching to a tab/split (catches commits made elsewhere); drop
-- this hook if the synchronous `git show` ever makes pane switches feel laggy
function onSetActive(bp)
  refresh_diff_base(bp.Buf)
end

-- VSCode-style tab management:
--   * opening a file reuses the current buffer when it's blank, else a new tab
--   * Ctrl-W (smartquit) closes the tab, quitting micro on the last blank tab
--   * Ctrl-Shift-T (reopentab) reopens the most recently closed tab
local micro = import("micro")
local config = import("micro/config")
local buffer = import("micro/buffer")
local shell = import("micro/shell")
local os = import("os")

-- Stack of closed tabs ({abs, path, x, y}), most recent last, for reopentab
local closed = {}

-- A buffer is "blank" (safe to reuse, like VSCode's empty untitled tab) when it
-- has no file, is unmodified, and holds no text
local function isBlank(buf)
  return buf.Path == "" and not buf:Modified() and buf:LinesNum() == 1 and buf:Line(0) == ""
end

-- Open one file the VSCode way: reuse the current blank buffer, otherwise a new
-- tab. Reusing fills the buffer, so any further files in the same call then land
-- in their own tabs
local function smartOpen(bp, file)
  if isBlank(bp.Buf) then
    local buf, err = buffer.NewBufferFromFile(file)
    if err ~= nil then
      micro.InfoBar():Error("Can't open " .. file)
      return
    end
    bp:OpenBuffer(buf)
  else
    bp:NewTabCmd({file})
  end
end

local function openCmd(bp, args)
  for i = 1, #args do
    smartOpen(bp, args[i])
  end
end

-- A bare `tab` keeps its original meaning (a fresh empty tab); with files it
-- follows the same reuse-or-new-tab rule as `open`
local function tabCmd(bp, args)
  if #args == 0 then
    bp:NewTabCmd({})
  else
    openCmd(bp, args)
  end
end

-- Ctrl-P fuzzy finder: pick files with fzf, then open them VSCode-style. Feed
-- fzf from `rg --files` so it honors .gitignore and skips .git: micro's
-- non-interactive subshell never loads our FZF_DEFAULT_COMMAND from .zshrc, and
-- bare fzf's builtin walker ignores .gitignore. sh -c is needed since
-- RunInteractiveShell splits args with shellwords and can't handle a raw pipe
local function fuzzyOpen(bp)
  local output, err = shell.RunInteractiveShell("sh -c \"rg --files --hidden | fzf -m --layout=reverse\"", false, true)
  if err ~= nil or output == "" then
    return
  end
  for file in output:gmatch("[^\r\n]+") do
    smartOpen(bp, file)
  end
end

-- Remember a closing tab's file and cursor so reopentab can bring it back. A
-- close that the save prompt later cancels leaves a stale entry here, which
-- reopenTab skips because the file is still open
local function remember(bp)
  if bp.Buf.AbsPath == "" then
    return
  end
  closed[#closed + 1] = {abs = bp.Buf.AbsPath, path = bp.Buf.Path, x = bp.Cursor.Loc.X, y = bp.Cursor.Loc.Y}
end

-- True when some tab or split currently shows the file at absolute path abs.
-- luar-wrapped Go slices are 1-indexed and don't support ipairs
local function isOpen(abs)
  local tabs = micro.Tabs().List
  for i = 1, #tabs do
    local panes = tabs[i].Panes
    for j = 1, #panes do
      if panes[j].Buf ~= nil and panes[j].Buf.AbsPath == abs then
        return true
      end
    end
  end
  return false
end

-- Ctrl-Shift-T: reopen the most recently closed tab at its old cursor position,
-- like VSCode. Skip entries whose file is open again (the close was canceled, or
-- the user reopened it by hand) or has since been deleted (e.g. a discarded
-- scratch buffer, whose hidden file is removed on close)
local function reopenTab(bp)
  while #closed > 0 do
    local e = table.remove(closed)
    local _, err = os.Stat(e.abs)
    if err == nil and not isOpen(e.abs) then
      -- smartOpen may switch to a new tab, so fetch the pane it landed in
      smartOpen(bp, e.path)
      local pane = micro.CurPane()
      pane.Cursor:GotoLoc(buffer.Loc(e.x, e.y))
      -- Clamp the cursor in case the file shrank, then scroll the view to it
      pane.Cursor:Relocate()
      pane:Relocate()
      return
    end
  end
  micro.InfoBar():Message("No closed tabs to reopen")
end

-- Close the tab, or on the last tab reset it to a blank buffer (VSCode keeps one
-- editor open instead of quitting). Used as the continuation after a scratch
-- buffer is saved or discarded, when there's no more unsaved work to guard
local function closeTab(bp)
  remember(bp)
  if #micro.Tabs().List > 1 then
    bp:ForceQuit()
  else
    bp:OpenBuffer(buffer.NewBuffer("", ""))
  end
end

-- Ctrl-W: a blank buffer falls through to Quit, so closing it also closes the
-- tab and quits micro on the last tab. A nonempty buffer closes its tab when
-- others are open, or (on the last tab) resets to a blank buffer instead of
-- quitting, like closing the only editor in VSCode. Never drop unsaved work
local function smartquit(bp)
  -- Scratch tabs prompt to save or discard first; the scratch plugin closes the
  -- tab via the closeTab continuation once the user answers (esc leaves it open)
  if scratch and scratch.promptClose and scratch.promptClose(bp, function() closeTab(bp) end) then
    return
  end
  if isBlank(bp.Buf) or #micro.Tabs().List > 1 then
    remember(bp)
    bp:Quit()
    return
  end
  if bp.Buf:Modified() then
    micro.InfoBar():Error("Save changes first (Ctrl-S)")
    return
  end
  remember(bp)
  bp:OpenBuffer(buffer.NewBuffer("", ""))
end

-- The builtin Quit (Ctrl-Q) closes tabs too. This hook only fires for the bound
-- action, not for smartquit's bp:Quit() call, so nothing is recorded twice
function preQuit(bp)
  remember(bp)
  return true
end

function init()
  -- Override the builtin open/tab commands so manual usage is smart too
  config.MakeCommand("open", openCmd, buffer.FileComplete)
  config.MakeCommand("tab", tabCmd, buffer.FileComplete)
  config.MakeCommand("fuzzyopen", fuzzyOpen, config.NoComplete)
  config.MakeCommand("smartquit", smartquit, config.NoComplete)
  config.MakeCommand("reopentab", reopenTab, config.NoComplete)
end

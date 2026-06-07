-- VSCode-style tab management:
--   * opening a file reuses the current buffer when it's blank, else a new tab
--   * Ctrl-W (smartquit) closes the tab, quitting micro on the last blank tab
local micro = import("micro")
local config = import("micro/config")
local buffer = import("micro/buffer")
local shell = import("micro/shell")

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

-- Ctrl-P fuzzy finder: pick files with fzf, then open them VSCode-style
local function fuzzyOpen(bp)
  local output, err = shell.RunInteractiveShell("fzf -m", false, true)
  if err ~= nil or output == "" then
    return
  end
  for file in output:gmatch("[^\r\n]+") do
    smartOpen(bp, file)
  end
end

-- Close the tab, or on the last tab reset it to a blank buffer (VSCode keeps one
-- editor open instead of quitting). Used as the continuation after a scratch
-- buffer is saved or discarded, when there's no more unsaved work to guard
local function closeTab(bp)
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
    bp:Quit()
    return
  end
  if bp.Buf:Modified() then
    micro.InfoBar():Error("Save changes first (Ctrl-S)")
    return
  end
  bp:OpenBuffer(buffer.NewBuffer("", ""))
end

function init()
  -- Override the builtin open/tab commands so manual usage is smart too
  config.MakeCommand("open", openCmd, buffer.FileComplete)
  config.MakeCommand("tab", tabCmd, buffer.FileComplete)
  config.MakeCommand("fuzzyopen", fuzzyOpen, config.NoComplete)
  config.MakeCommand("smartquit", smartquit, config.NoComplete)
end

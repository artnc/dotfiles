-- Persistent scratch buffers that survive editor restarts, like VSCode's
-- untitled tabs. Each scratch buffer is a real file; contents auto-save
-- (debounced) and on quit, and scratch buffers reopen as tabs on the next launch
local micro = import("micro")
local config = import("micro/config")
local buffer = import("micro/buffer")
local os = import("os")
local filepath = import("path/filepath")

-- Scratch files are namespaced by micro's launch directory so each directory
-- restores only the buffers created there. The cwd is mirrored as nested subdirs
-- under the root (filepath.Join folds the absolute cwd into path components, and
-- collapses the leading slash), so distinct cwds never collide
local SCRATCH_ROOT = filepath.Join(os.Getenv("HOME"), ".config", "micro", "scratch")
-- Bind to a local first: os.Getwd also returns an error, which would otherwise
-- expand as a stray extra argument to filepath.Join
local cwd = os.Getwd()
local SCRATCH_DIR = filepath.Join(SCRATCH_ROOT, cwd)
local SAVE_NS = 2000000000 -- 2s debounce before flushing edited scratch buffers
local saveGen = 0          -- bumped per keystroke so only the latest timer saves

local function isScratch(buf)
  return buf.AbsPath ~= "" and filepath.Dir(buf.AbsPath) == SCRATCH_DIR
end

-- The N from an "Untitled-N" name, or nil if the name isn't a scratch name
local function scratchNum(name)
  local digits = name:match("^Untitled%-(%d+)$")
  return digits ~= nil and tonumber(digits) or nil
end

-- A "blank" tab (no file, unmodified, empty) is safe to reuse in place, matching
-- VSCode reusing its empty untitled tab; same rule as the tabs plugin
local function isBlank(buf)
  return buf.Path == "" and not buf:Modified() and buf:LinesNum() == 1 and buf:Line(0) == ""
end

-- Scratch tabs show "Untitled-N" instead of the full path
local function setDisplayName(buf)
  buf:SetName(filepath.Base(buf.Path))
end

-- Open a scratch file VSCode-style: reuse the current blank tab, else a new tab
local function openScratch(path)
  local bp = micro.CurPane()
  if isBlank(bp.Buf) then
    local buf, err = buffer.NewBufferFromFile(path)
    if err ~= nil then
      micro.InfoBar():Error(tostring(err))
      return
    end
    bp:OpenBuffer(buf)
  else
    bp:NewTabCmd({path})
    bp = micro.CurPane()
  end
  setDisplayName(bp.Buf)
end

-- Run fn on every open scratch buffer across all tabs/panes. luar-wrapped Go
-- slices are 1-indexed via __len/__index and don't support ipairs
local function eachScratchBuf(fn)
  local tabs = micro.Tabs().List
  for i = 1, #tabs do
    local panes = tabs[i].Panes
    for j = 1, #panes do
      local buf = panes[j].Buf
      if buf ~= nil and isScratch(buf) then
        fn(buf)
      end
    end
  end
end

-- Flush edited scratch buffers; an emptied scratch is discarded (file removed)
-- so blank scratch buffers never persist, matching VSCode untitled tabs
local function saveScratch()
  eachScratchBuf(function(buf)
    if buf:LinesNum() == 1 and buf:Line(0) == "" then
      os.Remove(buf.AbsPath)
    else
      buf:AutoSave()
    end
  end)
end

-- Remove this directory's now-empty scratch dir and any parent dirs it leaves
-- empty, up to (never including) the root. os.Remove only succeeds on an empty
-- dir, so a non-nil error (dir missing or still holding another cwd's files)
-- stops the climb
local function pruneEmptyDirs()
  local dir = SCRATCH_DIR
  while dir ~= SCRATCH_ROOT do
    if os.Remove(dir) ~= nil then
      return
    end
    dir = filepath.Dir(dir)
  end
end

-- Lowest free Untitled-N, reused VSCode-style: a number is taken if a persisted
-- file uses it or an open scratch buffer does (a brand-new one has no file yet)
local function nextNum()
  local used = {}
  local entries = os.ReadDir(SCRATCH_DIR)
  if entries ~= nil then
    for i = 1, #entries do
      local entry = entries[i]
      if not entry:IsDir() then
        local n = scratchNum(entry:Name())
        if n ~= nil then
          used[n] = true
        end
      end
    end
  end
  eachScratchBuf(function(buf)
    local n = scratchNum(filepath.Base(buf.Path))
    if n ~= nil then
      used[n] = true
    end
  end)
  local n = 1
  while used[n] do
    n = n + 1
  end
  return n
end

local function newscratch(bp)
  openScratch(filepath.Join(SCRATCH_DIR, "Untitled-" .. nextNum()))
end

-- Reopen this directory's scratch buffers in numeric order. No mkdir here: the
-- dir is created lazily on first save (AutoSave + mkparents), so directories
-- without scratch buffers don't litter the scratch root
local function restoreScratch()
  local entries, err = os.ReadDir(SCRATCH_DIR)
  if err ~= nil then
    return
  end
  -- Skip files already open so re-running on a config reload (which re-invokes
  -- init) doesn't duplicate tabs: NewBufferFromFile dedups the buffer, but
  -- NewTabCmd still adds a second tab pointing at it
  local open = {}
  eachScratchBuf(function(buf)
    open[buf.AbsPath] = true
  end)
  -- Entries also include child mirror-dirs of deeper cwds; keep only this dir's
  -- own Untitled-N files
  local nums = {}
  for i = 1, #entries do
    local entry = entries[i]
    local n = not entry:IsDir() and scratchNum(entry:Name())
    if n then
      nums[#nums + 1] = n
    end
  end
  table.sort(nums)
  for _, n in ipairs(nums) do
    local path = filepath.Join(SCRATCH_DIR, "Untitled-" .. n)
    if not open[path] then
      openScratch(path)
    end
  end
end

-- Debounced auto-save: while editing a scratch buffer, (re)arm a 2s timer that
-- only the most recent keystroke's closure gets to act on
function onAnyEvent()
  local bp = micro.CurPane()
  if bp == nil or bp.Buf == nil or not isScratch(bp.Buf) or not bp.Buf:Modified() then
    return
  end
  saveGen = saveGen + 1
  local myGen = saveGen
  micro.After(SAVE_NS, function()
    if myGen == saveGen then
      saveScratch()
    end
  end)
end

-- Flush before a single tab close (preQuit) or a full quit (preQuitAll), then
-- reclaim the scratch dir if this left it empty
function preQuit(bp)
  saveScratch()
  pruneEmptyDirs()
  return true
end

preQuitAll = preQuit

-- Prompt Save As for a scratch pane (VSCode untitled behavior). On success drop
-- the hidden backing file and clear the Untitled name so it becomes an ordinary
-- file; `andThen` runs after, to chain prompts in Save All
local function promoteScratch(pane, andThen)
  local oldPath = pane.Buf.AbsPath
  pane:SaveAsCB("Save", function()
    os.Remove(oldPath)
    pane.Buf:SetName("")
    if andThen ~= nil then
      andThen()
    end
  end)
end

-- A manual save (Ctrl-S) of a scratch buffer must not write the hidden scratch
-- file. Returning false cancels that default; promoteScratch prompts for a real
-- path instead. Our debounced persistence uses Buffer:AutoSave, not this action,
-- so it isn't intercepted
function preSave(bp)
  if not isScratch(bp.Buf) then
    return true
  end
  promoteScratch(bp)
  return false
end

-- Save All: VSCode prompts Save As for each untitled. Save real files directly,
-- then chain a Save-As prompt per scratch buffer (the InfoBar shows one prompt
-- at a time); cancel the native Save All so scratch buffers aren't dumped to
-- their hidden path
function preSaveAll(bp)
  local scratchPanes = {}
  local seen = {}
  local tabs = micro.Tabs().List
  for i = 1, #tabs do
    local panes = tabs[i].Panes
    for j = 1, #panes do
      local pane = panes[j]
      local buf = pane.Buf
      if buf ~= nil and isScratch(buf) and not seen[buf.AbsPath] then
        seen[buf.AbsPath] = true
        scratchPanes[#scratchPanes + 1] = pane
      elseif buf ~= nil and buf.Path ~= "" and buf:Modified() then
        buf:Save()
      end
    end
  end
  local function promptNext(k)
    if k <= #scratchPanes then
      promoteScratch(scratchPanes[k], function()
        promptNext(k + 1)
      end)
    end
  end
  promptNext(1)
  return false
end

function init()
  config.MakeCommand("newscratch", newscratch, config.NoComplete)
  restoreScratch()
end

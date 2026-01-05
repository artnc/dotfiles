VERSION = "0.1.0"

local micro = import("micro")
local config = import("micro/config")
local shell = import("micro/shell")
local util = import("micro/util")
local buffer = import("micro/buffer")
local fmt = import("fmt")
local go_os = import("os")
local filepath = import("path/filepath")

-- State
local cmd = nil
local msgId = 0
local message = ""
local pendingCallbacks = {}
local initialized = false
local authenticated = false
local documentVersion = {}
local documentOpened = {}

-- JSON parser (minimal implementation)
local json = {}

local function parseStr(str, pos)
  local val = ""
  pos = pos + 1
  while pos <= #str do
    local c = str:sub(pos, pos)
    if c == '"' then return val, pos + 1 end
    if c == '\\' then
      pos = pos + 1
      local esc = str:sub(pos, pos)
      local escMap = {b = '\b', f = '\f', n = '\n', r = '\r', t = '\t'}
      val = val .. (escMap[esc] or esc)
    else
      val = val .. c
    end
    pos = pos + 1
  end
  return val, pos
end

local function parseNum(str, pos)
  local numStr = str:match('^-?%d+%.?%d*[eE]?[+-]?%d*', pos)
  return tonumber(numStr), pos + #numStr
end

function json.parse(str, pos)
  pos = pos or 1
  pos = pos + #str:match('^%s*', pos)
  if pos > #str then return nil, pos end
  local c = str:sub(pos, pos)
  if c == '{' then
    local obj = {}
    pos = pos + 1
    while true do
      pos = pos + #str:match('^%s*', pos)
      if str:sub(pos, pos) == '}' then return obj, pos + 1 end
      local key
      key, pos = json.parse(str, pos)
      if key == nil then return obj, pos end
      pos = pos + #str:match('^%s*', pos)
      if str:sub(pos, pos) == ':' then pos = pos + 1 end
      obj[key], pos = json.parse(str, pos)
      pos = pos + #str:match('^%s*', pos)
      if str:sub(pos, pos) == ',' then pos = pos + 1 end
    end
  elseif c == '[' then
    local arr = {}
    pos = pos + 1
    while true do
      pos = pos + #str:match('^%s*', pos)
      if str:sub(pos, pos) == ']' then return arr, pos + 1 end
      local val
      val, pos = json.parse(str, pos)
      if val == nil then return arr, pos end
      arr[#arr + 1] = val
      pos = pos + #str:match('^%s*', pos)
      if str:sub(pos, pos) == ',' then pos = pos + 1 end
    end
  elseif c == '"' then
    return parseStr(str, pos)
  elseif c == '-' or c:match('%d') then
    return parseNum(str, pos)
  elseif str:sub(pos, pos + 3) == 'true' then
    return true, pos + 4
  elseif str:sub(pos, pos + 4) == 'false' then
    return false, pos + 5
  elseif str:sub(pos, pos + 3) == 'null' then
    return nil, pos + 4
  end
  return nil, pos
end

-- Helper functions
local function escapeJson(s)
  return s:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t')
end

local function getUri(buf)
  return fmt.Sprintf("file://%s", buf.AbsPath)
end

local function send(method, params, isNotification, callback)
  if cmd == nil then return end
  local idPart = ""
  if not isNotification then
    idPart = fmt.Sprintf('"id": %.0f, ', msgId)
    if callback then
      pendingCallbacks[msgId] = callback
    end
    msgId = msgId + 1
  end
  local msg = fmt.Sprintf('{"jsonrpc": "2.0", %s"method": "%s", "params": %s}', idPart, method, params)
  msg = fmt.Sprintf("Content-Length: %.0f\r\n\r\n%s", #msg, msg)
  micro.Log("Copilot >>> " .. method)
  shell.JobSend(cmd, msg)
end

local function onStdout(text)
  if text:sub(1, 15) == "Content-Length:" then
    message = text
  else
    message = message .. text
  end
  if not message:match('}%s*$') then return end
  local start = message:find('\n%s*\n')
  if not start then return end
  local body = message:sub(start):match('^%s*(.+)%s*$')
  if not body then return end
  local data = json.parse(body)
  if not data then
    micro.Log("Copilot: parse failed")
    return
  end
  micro.Log("Copilot <<< " .. (data.method or "response"))

  -- Handle responses with callbacks
  if data.id and pendingCallbacks[data.id] then
    pendingCallbacks[data.id](data)
    pendingCallbacks[data.id] = nil
  elseif data.method == "didChangeStatus" then
    -- Status update from server
    if data.params and data.params.status then
      micro.Log("Copilot status: " .. data.params.status)
    end
  elseif data.method == "window/logMessage" or data.method == "window/showMessage" then
    if data.params and data.params.message then
      micro.InfoBar():Message("Copilot: " .. data.params.message)
    end
  end
  message = ""
end

local function onStderr(text)
  micro.Log("Copilot stderr: " .. text)
end

local function onExit(str)
  micro.Log("Copilot exited: " .. (str or ""))
  cmd = nil
  initialized = false
  authenticated = false
  documentOpened = {}
  documentVersion = {}
end

local function doInitialize()
  local wd, _ = go_os.Getwd()
  local rootUri = fmt.Sprintf("file://%s", wd)
  local params = fmt.Sprintf([[{
    "processId": %.0f,
    "rootUri": "%s",
    "workspaceFolders": [{"name": "workspace", "uri": "%s"}],
    "capabilities": {
      "textDocument": {
        "inlineCompletion": {
          "dynamicRegistration": true
        }
      }
    },
    "initializationOptions": {
      "editorInfo": {"name": "micro", "version": "%s"},
      "editorPluginInfo": {"name": "copilot.lua", "version": "%s"}
    }
  }]], go_os.Getpid(), rootUri, rootUri, VERSION, VERSION)

  send("initialize", params, false, function(data)
    if data.result then
      micro.Log("Copilot initialized")
      send("initialized", "{}", true)
      initialized = true
      checkAuth()
    end
  end)
end

function checkAuth()
  send("checkStatus", '{"localChecksOnly": false}', false, function(data)
    if data.result then
      if data.result.status == "OK" or data.result.status == "MaybeOk" then
        authenticated = true
        micro.InfoBar():Message("Copilot: Authenticated")
      else
        micro.InfoBar():Message("Copilot: Not authenticated. Run 'copilot.signin'")
      end
    end
  end)
end

function startServer()
  if cmd ~= nil then return end
  local serverPath = filepath.Join(go_os.Getenv("HOME"), ".local/share/copilot-language-server/copilot-language-server")
  local _, err = go_os.Stat(serverPath)
  if err ~= nil then
    micro.InfoBar():Error("Copilot server not found at " .. serverPath)
    return
  end
  micro.Log("Starting Copilot server: " .. serverPath)
  cmd = shell.JobSpawn(serverPath, {"--stdio"}, onStdout, onStderr, onExit, {})
  if cmd then
    doInitialize()
  end
end

function signIn()
  if cmd == nil then
    startServer()
    micro.After(1000000000, function() signIn() end) -- retry after 1s
    return
  end
  send("signIn", "{}", false, function(data)
    if data.result then
      if data.result.status == "OK" or data.result.status == "AlreadySignedIn" then
        authenticated = true
        micro.InfoBar():Message("Copilot: Already signed in")
      elseif data.result.userCode then
        micro.InfoBar():Message("Copilot: Enter code " .. data.result.userCode .. " at " .. (data.result.verificationUri or "https://github.com/login/device"))
        -- Wait for user to complete auth
        micro.After(5000000000, function() checkAuth() end)
      end
    elseif data.error then
      micro.InfoBar():Error("Copilot sign-in error: " .. (data.error.message or "unknown"))
    end
  end)
end

function signOut()
  send("signOut", "{}", false, function(data)
    authenticated = false
    micro.InfoBar():Message("Copilot: Signed out")
  end)
end

function notifyDidOpen(buf)
  if cmd == nil or not initialized then return false end
  local uri = getUri(buf)
  if documentOpened[uri] then return true end
  local content = escapeJson(util.String(buf:Bytes()))
  local filetype = buf:FileType()
  if filetype == "unknown" then filetype = "text" end
  documentVersion[uri] = 1
  documentOpened[uri] = true
  local params = fmt.Sprintf('{"textDocument": {"uri": "%s", "languageId": "%s", "version": 1, "text": "%s"}}',
    uri, filetype, content)
  send("textDocument/didOpen", params, true)
  micro.Log("Copilot: Opened document " .. uri)
  return true
end

function ensureDocumentOpen(buf)
  if cmd == nil or not initialized then return false end
  local uri = getUri(buf)
  if not documentOpened[uri] then
    return notifyDidOpen(buf)
  end
  return true
end

function notifyDidChange(buf)
  if cmd == nil or not initialized then return end
  if not ensureDocumentOpen(buf) then return end
  local uri = getUri(buf)
  local content = escapeJson(util.String(buf:Bytes()))
  documentVersion[uri] = (documentVersion[uri] or 0) + 1
  local params = fmt.Sprintf('{"textDocument": {"uri": "%s", "version": %.0f}, "contentChanges": [{"text": "%s"}]}',
    uri, documentVersion[uri], content)
  send("textDocument/didChange", params, true)
end

function requestCompletion(bp)
  if cmd == nil then
    startServer()
    return
  end
  if not initialized then
    micro.InfoBar():Message("Copilot: Initializing...")
    return
  end
  if not authenticated then
    micro.InfoBar():Message("Copilot: Not authenticated. Run 'copilot.signin'")
    return
  end

  local buf = bp.Buf
  local uri = getUri(buf)
  local cur = buf:GetActiveCursor()
  local line = cur.Y
  local col = cur.X

  -- Ensure document is opened and synced
  if not ensureDocumentOpen(buf) then
    micro.InfoBar():Message("Copilot: Failed to open document")
    return
  end
  notifyDidChange(buf)

  local params = fmt.Sprintf([[{
    "textDocument": {"uri": "%s", "version": %.0f},
    "position": {"line": %.0f, "character": %.0f},
    "context": {"triggerKind": 1}
  }]], uri, documentVersion[uri] or 1, line, col)

  micro.InfoBar():Message("Copilot: Requesting completion...")

  send("textDocument/inlineCompletion", params, false, function(data)
    if data.result and data.result.items and #data.result.items > 0 then
      local item = data.result.items[1]
      local text = item.insertText
      if text and #text > 0 then
        -- If range is provided, replace that range; otherwise insert at cursor
        local startCol, startLine, endCol, endLine = col, line, col, line
        if item.range then
          startLine = item.range.start.line
          startCol = item.range.start.character
          endLine = item.range["end"].line
          endCol = item.range["end"].character
        end
        -- Delete the range first if it's non-empty
        if startCol ~= endCol or startLine ~= endLine then
          buf:Remove(buffer.Loc(startCol, startLine), buffer.Loc(endCol, endLine))
        end
        -- Insert the completion text
        buf:Insert(buffer.Loc(startCol, startLine), text)
        micro.InfoBar():Message("Copilot: Inserted completion")
      else
        micro.InfoBar():Message("Copilot: Empty completion")
      end
    elseif data.error then
      micro.InfoBar():Error("Copilot error: " .. (data.error.message or "unknown"))
    else
      micro.InfoBar():Message("Copilot: No completions")
    end
  end)
end

-- Plugin initialization
function init()
  config.MakeCommand("copilot.complete", function(bp)
    requestCompletion(bp)
  end, config.NoComplete)

  config.MakeCommand("copilot.signin", function(bp)
    signIn()
  end, config.NoComplete)

  config.MakeCommand("copilot.signout", function(bp)
    signOut()
  end, config.NoComplete)

  config.MakeCommand("copilot.status", function(bp)
    if cmd == nil then
      micro.InfoBar():Message("Copilot: Server not running")
    elseif not initialized then
      micro.InfoBar():Message("Copilot: Initializing...")
    elseif not authenticated then
      micro.InfoBar():Message("Copilot: Not authenticated")
    else
      micro.InfoBar():Message("Copilot: Ready")
    end
  end, config.NoComplete)

  -- Bind Ctrl-Space to request completion
  config.TryBindKey("CtrlSpace", "command:copilot.complete", false)

  micro.Log("Copilot plugin loaded")
end

-- Auto-start server and track document opens
function onBufferOpen(buf)
  if cmd == nil then
    startServer()
  end
  micro.After(500000000, function()
    notifyDidOpen(buf)
  end)
end

-- Track document changes for sync
function onRune(bp, r)
  if cmd and initialized then
    notifyDidChange(bp.Buf)
  end
end

function onSave(bp)
  if cmd and initialized then
    local uri = getUri(bp.Buf)
    send("textDocument/didSave", fmt.Sprintf('{"textDocument": {"uri": "%s"}}', uri), true)
  end
end

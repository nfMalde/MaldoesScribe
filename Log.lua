local ADDON, ns = ...

--[[
Error handling and logs.

  ns.Safe(fn)        wraps a function: an error inside is caught, recorded with its stack and
                     reported once, and the rest of the addon keeps running
  ns.NewFrame(...)   CreateFrame whose SetScript/HookScript wrap every handler with ns.Safe
  ns.After(s, fn)    C_Timer.After with ns.Safe
  ns.Debug(...)      a line for the log; also printed to chat while debug mode is on
  ns.Warn(...)       the same for something that went wrong but was handled
  ns.ShowReport()    opens the copy window with a report (version, settings, errors, log) to
                     paste into a GitHub issue

The log and the errors are kept in the saved settings, so a report can still be made after a
reload or the next login. The report contains no character or account names and no chat text.
]]

local MAX_LINES = 200
local MAX_ERRORS = 20
local REPORT_LINES = 80

local lines = {} -- the log; becomes MaldoesScribeDB.log once the settings are loaded
local errors = {} -- distinct errors; becomes MaldoesScribeDB.errors
local announced = {} -- errors already reported in this session
local inErrorHandler = false

local function Text(value)
    if issecretvalue ~= nil and issecretvalue(value) then return "<secret>" end
    return tostring(value)
end

local function Join(...)
    local parts = {}
    for index = 1, select("#", ...) do
        parts[index] = Text((select(index, ...)))
    end
    return table.concat(parts, " ")
end

local function AddLine(level, text)
    lines[#lines + 1] = date("%H:%M:%S") .. " " .. level .. " " .. text
    while #lines > MAX_LINES do
        table.remove(lines, 1)
    end
end

local function DebugEnabled()
    return ns.db ~= nil and ns.db.debug == true
end

function ns.Debug(...)
    local text = Join(...)
    AddLine("DBG", text)
    if DebugEnabled() then
        DEFAULT_CHAT_FRAME:AddMessage("|cff7d7166Scribe debug:|r |cffb9ada1" .. text .. "|r")
    end
end

function ns.Warn(...)
    local text = Join(...)
    AddLine("WRN", text)
    if DebugEnabled() then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffa463Scribe warning:|r " .. text)
    end
end

-- ---------------------------------------------------------------------------
-- Errors
-- ---------------------------------------------------------------------------

local function RecordError(message, stack)
    local now = date("%Y-%m-%d %H:%M:%S")
    local entry
    for _, known in ipairs(errors) do
        if known.message == message then
            entry = known
            break
        end
    end
    if entry then
        entry.count = (entry.count or 1) + 1
        entry.last = now
    else
        entry = { message = message, stack = stack, count = 1, first = now, last = now }
        errors[#errors + 1] = entry
        while #errors > MAX_ERRORS do
            table.remove(errors, 1)
        end
        AddLine("ERR", message)
    end

    -- Tell the player once per error and session, not on every frame.
    if not announced[message] then
        announced[message] = true
        DEFAULT_CHAT_FRAME:AddMessage("|cffff8a3dMaldö's Scribe|r: |cfffb4868" .. ns.L.ERROR_CAPTURED .. "|r")
        -- Also hand it to the game's own error handler (the error window, BugSack and the like).
        local handler = geterrorhandler and geterrorhandler()
        if type(handler) == "function" then pcall(handler, message) end
    end
end

local function OnError(err)
    local message = Text(err)
    -- An error while recording an error must not loop.
    if inErrorHandler then return message end
    inErrorHandler = true
    local stack = ""
    if debugstack then
        local ok, result = pcall(debugstack, 2, 14, 0)
        if ok and type(result) == "string" then stack = result end
    end
    pcall(RecordError, message, stack)
    inErrorHandler = false
    return message
end

local function Finish(ok, ...)
    if ok then return ... end
    return nil
end

--- Returns fn wrapped so that an error is caught and recorded instead of breaking the caller.
function ns.Safe(fn)
    if type(fn) ~= "function" then return fn end
    return function(...)
        return Finish(xpcall(fn, OnError, ...))
    end
end

--- Records an error that was caught elsewhere (for example by pcall).
function ns.ReportError(message)
    pcall(RecordError, Text(message), "")
end

local function Protect(frame)
    local setScript, hookScript = frame.SetScript, frame.HookScript
    frame.SetScript = function(self, script, handler)
        return setScript(self, script, ns.Safe(handler))
    end
    frame.HookScript = function(self, script, handler)
        return hookScript(self, script, ns.Safe(handler))
    end
    return frame
end

--- CreateFrame for all frames of the addon: every script handler set later is error-safe.
function ns.NewFrame(...)
    return Protect(CreateFrame(...))
end

function ns.After(seconds, fn)
    C_Timer.After(seconds, ns.Safe(fn))
end

-- ---------------------------------------------------------------------------
-- Settings, report
-- ---------------------------------------------------------------------------

local function AddonVersion()
    local read = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local ok, version = pcall(read, ADDON, "Version")
    return ok and version or "?"
end

--- Called once the saved settings are loaded: continues the log of the last session.
function ns.InitLog()
    local db = ns.db
    local early = lines
    lines = type(db.log) == "table" and db.log or {}
    db.log = lines
    local version, build, _, interface = GetBuildInfo()
    AddLine("---", "session " .. date("%Y-%m-%d") .. ", addon " .. AddonVersion() .. ", client "
        .. Text(version) .. " (" .. Text(build) .. ") interface " .. Text(interface))
    for _, line in ipairs(early) do
        lines[#lines + 1] = line
    end
    while #lines > MAX_LINES do
        table.remove(lines, 1)
    end

    local earlyErrors = errors
    errors = type(db.errors) == "table" and db.errors or {}
    db.errors = errors
    for _, entry in ipairs(earlyErrors) do
        errors[#errors + 1] = entry
    end
end

function ns.ClearLog()
    wipe(lines)
    wipe(errors)
    wipe(announced)
end

function ns.ErrorCount()
    return #errors
end

local function Try(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g, h = pcall(fn, ...)
    if ok then return a, b, c, d, e, f, g, h end
    return nil
end

-- Other addons that touch the chat or tooltips: listed in the report, because a conflict
-- with one of them is the first thing to check.
local NEIGHBOURS = { "EllesmereUIChat", "ChatCopyPaste", "Prat-3.0", "Chatter", "ElvUI", "TipTac", "BugSack" }

local function LoadedNeighbours()
    local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    local found = {}
    for _, name in ipairs(NEIGHBOURS) do
        if Try(isLoaded, name) then found[#found + 1] = name end
    end
    return #found > 0 and table.concat(found, ", ") or "none"
end

--- The report as Markdown, ready for a GitHub issue. Always English.
function ns.BuildReport()
    local db = ns.db or {}
    local out = {}
    local function add(text) out[#out + 1] = text end

    local version, build, _, interface = GetBuildInfo()
    add("### Maldö's Scribe report")
    add("")
    add("- Addon: " .. AddonVersion())
    add("- Client: " .. Text(version) .. " (" .. Text(build) .. "), interface " .. Text(interface)
        .. ", project " .. Text(WOW_PROJECT_ID) .. ", locale " .. Text(GetLocale()))
    add("- Date: " .. date("%Y-%m-%d %H:%M:%S"))
    add("- Settings: language " .. Text(db.language) .. ", opacity " .. Text(db.opacity) .. ", scale " .. Text(db.scale)
        .. ", text size " .. Text(db.fontSize) .. ", window " .. Text(db.windowWidth) .. "x" .. Text(db.windowHeight))
    add("- Chat: button " .. Text(db.chatButton) .. ", hover " .. Text(db.chatButtonHover) .. ", corner " .. Text(db.chatButtonCorner)
        .. ", max lines " .. Text(db.chatMaxLines) .. ", strip timestamps " .. Text(db.chatStripTimestamps)
        .. ", urls " .. Text(db.chatUrls))
    add("- Buttons: window buttons " .. Text(db.contextButtons) .. ", tooltip hint " .. Text(db.tooltipHint)
        .. ", link modifier " .. Text(db.linkModifier) .. ", menu entry " .. Text(db.menuEntry)
        .. ", debug " .. (db.debug and "on" or "off"))
    add("- Keys: smart " .. Text(Try(GetBindingKey, "MALDOESSCRIBE_SMART"))
        .. ", tooltip " .. Text(Try(GetBindingKey, "MALDOESSCRIBE_TOOLTIP"))
        .. ", chat " .. Text(Try(GetBindingKey, "MALDOESSCRIBE_CHAT")))
    add("- Last copied: " .. Text(ns.lastSourceKind))
    add("- Other addons: " .. LoadedNeighbours())
    add("")

    add("#### Errors (" .. #errors .. ")")
    add("")
    if #errors == 0 then
        add("No errors recorded.")
    else
        add("```")
        for index, entry in ipairs(errors) do
            add(index .. ". x" .. Text(entry.count) .. ", first " .. Text(entry.first) .. ", last " .. Text(entry.last))
            add(Text(entry.message))
            if entry.stack and entry.stack ~= "" then add((entry.stack:gsub("%s+$", ""))) end
            add("")
        end
        add("```")
    end
    add("")

    local first = math.max(1, #lines - REPORT_LINES + 1)
    add("#### Log (last " .. (#lines - first + 1) .. " lines)")
    add("")
    add("```")
    for index = first, #lines do
        add(lines[index])
    end
    add("```")
    return table.concat(out, "\n")
end

--- Shows the report in the copy window (Ctrl+C copies it).
function ns.ShowReport()
    local L = ns.L
    if not (ns.UI and ns.UI.Open) then
        DEFAULT_CHAT_FRAME:AddMessage(ns.BuildReport())
        return
    end
    ns.UI:Open({
        kind = "report",
        title = L.LOG_TITLE,
        hint = L.LOG_HINT,
        variants = { { label = L.LOG_TITLE, build = ns.BuildReport } },
        actions = {
            { label = L.LOG_CLEAR, click = function()
                ns.ClearLog()
                ns.Print(L.LOG_CLEARED)
            end },
        },
    })
end

local ADDON, ns = ...
local L = ns.L

ns.addonName = ADDON
ns.mediaPath = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"

-- Maldö's colours (the GT Toolz theme): espresso black and the amber of the stripes.
ns.colors = {
    bg = { 0.051, 0.039, 0.027 },
    surface = { 0.118, 0.094, 0.071 },
    surfaceHover = { 0.188, 0.149, 0.110 },
    border = { 1, 0.894, 0.784, 0.14 },
    accent = { 1, 0.541, 0.239 },
    accentText = { 1, 0.643, 0.388 },
    onAccent = { 0.086, 0.059, 0.035 },
    text = { 0.945, 0.922, 0.898 },
    textDim = { 0.725, 0.678, 0.631 },
    textFaint = { 0.490, 0.443, 0.400 },
    danger = { 0.984, 0.282, 0.408 },
    good = { 0.204, 0.827, 0.600 },
}

ns.defaults = {
    language = "auto", -- auto | en | de
    opacity = 0.95, -- the copy window is a dialog, so it is nearly opaque
    scale = 1,
    fontSize = 12,
    windowWidth = 560,
    windowHeight = 380,
    chatButton = true, -- the small quill in a corner of each chat window
    chatButtonHover = true, -- only while the mouse is over the chat
    chatButtonCorner = "TOPRIGHT", -- TOPRIGHT | BOTTOMRIGHT
    chatMaxLines = 500,
    chatStripTimestamps = false,
    chatUrls = true, -- web addresses in chat become links that open the copy window
    contextButtons = true, -- the "Copy quest" buttons beside windows
    tooltipHint = true, -- "Key: copy" in item tooltips while a key is bound
    linkModifier = "ALT", -- ALT | CTRL | SHIFT | NONE: modifier-click on a chat link copies it
    menuEntry = true, -- "Copy name" in the right-click menus of players and units
    wowhead = "https://www.wowhead.com/classic/",
    debug = false, -- print debug lines to chat
    -- log, errors: written by Log.lua
    -- position: { point, relativePoint, x, y }
}

function ns.Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cffff8a3dMaldö's Scribe|r: " .. tostring(message))
end

function ns.ApplyLanguage()
    ns.uiLang = ns.ResolveLanguage(ns.db.language)
    ns.ApplyBindingNames()
end

--- Resolves "QuestMapFrame.DetailsFrame" to that frame, or nil when it does not exist.
function ns.ResolveFrame(path)
    local current = _G
    for part in path:gmatch("[^%.]+") do
        if type(current) ~= "table" then return nil end
        current = current[part]
    end
    if type(current) == "table" and type(current.IsVisible) == "function" then return current end
    return nil
end

function ns.FrameVisible(path)
    local frame = ns.ResolveFrame(path)
    return frame ~= nil and frame:IsVisible()
end

--- Opens the copy window for a source; without one, tells the player why there is nothing.
function ns.Copy(source, emptyMessage)
    if source then
        ns.UI:Open(source)
        return true
    end
    if emptyMessage then ns.Print(emptyMessage) end
    return false
end

--- Debug mode prints the debug lines to chat. They are written to the log either way.
function ns.SetDebug(enabled)
    ns.db.debug = enabled and true or false
    ns.Print(ns.db.debug and L.DEBUG_ON or L.DEBUG_OFF)
end

function ns.OpenOptions()
    if InCombatLockdown() then
        ns.Print(L.OPTIONS_COMBAT)
        return
    end
    if Settings and Settings.OpenToCategory and ns.settingsCategory then
        Settings.OpenToCategory(ns.settingsCategory:GetID())
    end
end

function ns.OpenKeyBindings()
    if InCombatLockdown() then
        ns.Print(L.OPTIONS_COMBAT)
        return
    end
    if Settings and Settings.OpenToCategory and Settings.KEYBINDINGS_CATEGORY_ID then
        Settings.OpenToCategory(Settings.KEYBINDINGS_CATEGORY_ID)
    elseif KeyBindingFrame_LoadUI then
        KeyBindingFrame_LoadUI()
        if KeyBindingFrame then ShowUIPanel(KeyBindingFrame) end
    else
        ns.Print(L.OPT_KEYBINDINGS_HINT)
    end
end

-- ---------------------------------------------------------------------------
-- Diagnostics: what is under the mouse
-- ---------------------------------------------------------------------------

local function DescribeFrame(frame)
    local ok, text = pcall(function()
        local name = frame.GetName and frame:GetName() or nil
        local parent = frame.GetParent and frame:GetParent()
        local parentName = parent and parent.GetName and parent:GetName() or nil
        return (name or "(unnamed)")
            .. " [" .. tostring(frame.GetFrameStrata and frame:GetFrameStrata())
            .. " " .. tostring(frame.GetFrameLevel and frame:GetFrameLevel()) .. "]"
            .. " parent " .. (parentName or "(unnamed)")
            .. ", mouse " .. tostring(frame.IsMouseEnabled and frame:IsMouseEnabled())
    end)
    if ok then return text end
    return "(not readable: " .. tostring(text) .. ")"
end

--- Prints and logs the frames under the mouse, top one first. For "the button does not react".
function ns.ReportMouse()
    local frames
    if GetMouseFoci then
        frames = GetMouseFoci()
    elseif GetMouseFocus then
        frames = { GetMouseFocus() }
    end
    if type(frames) ~= "table" or #frames == 0 then
        ns.Print(L.MOUSE_NONE)
        ns.Debug("under mouse: nothing")
        return
    end
    for index, frame in ipairs(frames) do
        local line = index .. ". " .. DescribeFrame(frame)
        ns.Print(line)
        ns.Debug("under mouse:", line)
    end
end

-- ---------------------------------------------------------------------------
-- Start, events
-- ---------------------------------------------------------------------------

local function CopyDefaults(source, destination)
    if type(destination) ~= "table" then destination = {} end
    for key, value in pairs(source) do
        if type(value) == "table" then
            destination[key] = CopyDefaults(value, destination[key])
        elseif destination[key] == nil then
            destination[key] = value
        end
    end
    return destination
end

local events = ns.NewFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        self:UnregisterEvent("ADDON_LOADED")

        MaldoesScribeDB = CopyDefaults(ns.defaults, MaldoesScribeDB)
        ns.db = MaldoesScribeDB
        ns.InitLog()
        ns.ApplyLanguage()
        ns.Debug("loaded: language", ns.uiLang, "| locale", GetLocale())

        self:RegisterEvent("ADDON_ACTION_BLOCKED")
        self:RegisterEvent("ADDON_ACTION_FORBIDDEN")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        -- The mailbox can be open while another addon (TradeSkillMaster) hides the game's mail window.
        self:RegisterEvent("MAIL_SHOW")
        self:RegisterEvent("MAIL_CLOSED")
        ns.UI:Create()
        ns.Buttons:Init()
        ns.Options:Register()
    elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        -- The game refused a protected action and blames an addon: record it when it is this one.
        local blockedFunction = ...
        if arg1 == ADDON then
            ns.ReportError(event .. ": " .. tostring(blockedFunction))
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Chat windows the player had open last time exist by now.
        ns.Buttons:AttachChatButtons()
    elseif event == "MAIL_SHOW" then
        ns.mailboxOpen = true
    elseif event == "MAIL_CLOSED" then
        ns.mailboxOpen = false
    end
end)

-- ---------------------------------------------------------------------------
-- Commands, key bindings, addon compartment
-- ---------------------------------------------------------------------------

local function CopySmart()
    ns.Copy(ns.Sources.Smart(), L.NOTHING_OPEN)
end

local function CopyTooltip()
    ns.Copy(ns.Sources.Tooltip(GameTooltip) or ns.Sources.Tooltip(ItemRefTooltip), L.NO_TOOLTIP)
end

local function ToggleOrSmart()
    if ns.UI:IsShown() then
        ns.UI:Hide()
    else
        CopySmart()
    end
end

SLASH_MALDOESSCRIBE1 = "/scribe"
SLASH_MALDOESSCRIBE2 = "/copy"
SlashCmdList.MALDOESSCRIBE = ns.Safe(function(input)
    local command, argument = string.lower(ns.Trim(input or "")):match("^(%S*)%s*(.-)$")
    local Sources = ns.Sources
    if command == "" then
        ToggleOrSmart()
    elseif command == "chat" then
        local number = tonumber(argument)
        local frame = number and _G["ChatFrame" .. number] or nil
        ns.Copy(Sources.Chat(frame), L.CHAT_EMPTY)
    elseif command == "tooltip" or command == "tip" then
        CopyTooltip()
    elseif command == "quest" then
        ns.Copy(Sources.Quest() or Sources.QuestLog(), L.NO_QUEST)
    elseif command == "gossip" or command == "dialog" or command == "dialogue" then
        ns.Copy(Sources.Gossip(), L.NO_GOSSIP)
    elseif command == "guild" or command == "gilde" then
        ns.Copy(Sources.Guild(), L.NO_GUILD)
    elseif command == "book" or command == "text" or command == "buch" then
        ns.Copy(Sources.ItemText(), L.NO_BOOK)
    elseif command == "mail" or command == "post" then
        ns.Copy(Sources.Mail(), L.NO_MAIL)
    elseif command == "macro" or command == "makro" then
        ns.Copy(Sources.Macro(), L.NO_MACRO)
    elseif command == "group" or command == "gruppe" or command == "raid" or command == "party" then
        ns.Copy(Sources.Group(), L.NO_GROUP)
    elseif command == "options" or command == "config" or command == "optionen" then
        ns.OpenOptions()
    elseif command == "keys" or command == "bind" or command == "bindings" or command == "tasten" then
        ns.OpenKeyBindings()
    elseif command == "reset" then
        ns.UI:ResetPosition()
        ns.Print(L.POSITION_RESET)
    elseif command == "log" or command == "report" or command == "errors" then
        if argument == "clear" then
            ns.ClearLog()
            ns.Print(L.LOG_CLEARED)
        else
            ns.ShowReport()
        end
    elseif command == "debug" then
        ns.SetDebug(not ns.db.debug)
    elseif command == "mouse" then
        ns.Print(L.MOUSE_WAIT)
        ns.After(3, ns.ReportMouse)
    else
        ns.Print(L.HELP)
    end
end)

-- Called by Bindings.xml.
MaldoesScribe_CopySmart = ns.Safe(CopySmart)
MaldoesScribe_CopyTooltip = ns.Safe(CopyTooltip)
MaldoesScribe_CopyChat = ns.Safe(function()
    ns.Copy(ns.Sources.Chat(), L.CHAT_EMPTY)
end)

MaldoesScribe_OnAddonCompartmentClick = ns.Safe(function(_, button)
    if button == "RightButton" then
        ns.OpenOptions()
    else
        ToggleOrSmart()
    end
end)

-- A tiny stand-in for the game's API: enough to load the addon and poke at it.
__NS = {}
unpack = table.unpack
tinsert = table.insert
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
date = os.date
time = os.time
GetTime = function() return os.clock() end
WOW_PROJECT_ID = 18
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
TEST_LOCALE = "deDE"
function GetLocale() return TEST_LOCALE end
function GetBuildInfo() return "1.60.1", "70888", "Nov 1 2026", 16001 end
C_AddOns = {
    GetAddOnMetadata = function() return "1.0.0" end,
    IsAddOnLoaded = function(name) return name == "EllesmereUIChat" end,
}
function geterrorhandler() return function() ERRORS_SEEN = (ERRORS_SEEN or 0) + 1 end end
function debugstack() return "stack" end
function InCombatLockdown() return false end

local keyState = {}
function IsAltKeyDown() return keyState.ALT == true end
function IsControlKeyDown() return keyState.CTRL == true end
function IsShiftKeyDown() return keyState.SHIFT == true end
function SetKey(key, down) keyState[key] = down end
BINDINGS = {}
function GetBindingKey(name) return BINDINGS[name] end
function GetBindingText(key) return key end

UISpecialFrames = {}
SlashCmdList = {}
Enum = { TooltipDataType = { Item = 0 } }
local tooltipPostCalls = {}
TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) tooltipPostCalls[#tooltipPostCalls + 1] = fn end }
function RunTooltipPostCalls(tip) for _, fn in ipairs(tooltipPostCalls) do fn(tip) end end

SECRET = {} -- a value the game keeps secret
function issecretvalue(value) return value == SECRET end

-- Frames ---------------------------------------------------------------------
EVENT_FRAMES = {}
local Frame = {}
local function NewRegion(kind, name, parent)
    local region = setmetatable({
        __kind = kind, __name = name, __parent = parent, __shown = true,
        __scripts = {}, __hooks = {}, __w = 100, __h = 50, __text = "",
    }, Frame)
    if name then _G[name] = region end
    return region
end
Frame.__index = function(_, key)
    local method = rawget(Frame, key)
    if method ~= nil then return method end
    -- Any other method is a no-op; fields (lower case) are nil, as on a real frame.
    if type(key) == "string" and key:match("^%u") then return function() end end
    return nil
end
function Frame.SetScript(self, name, fn) self.__scripts[name] = fn end
function Frame.GetScript(self, name) return self.__scripts[name] end
function Frame.HookScript(self, name, fn)
    local hooks = self.__hooks[name] or {}
    hooks[#hooks + 1] = fn
    self.__hooks[name] = hooks
end
function Frame.Fire(self, name, ...)
    local fn = self.__scripts[name]
    if fn then fn(self, ...) end
    for _, hook in ipairs(self.__hooks[name] or {}) do hook(self, ...) end
end
function Frame.CreateTexture(self) return NewRegion("Texture", nil, self) end
function Frame.CreateFontString(self) return NewRegion("FontString", nil, self) end
function Frame.GetName(self) return self.__name end
function Frame.GetParent(self) return self.__parent end
function Frame.SetParent(self, parent) self.__parent = parent end
function Frame.GetFrameLevel() return 1 end
function Frame.GetFrameStrata() return "MEDIUM" end
function Frame.SetSize(self, w, h) self.__w, self.__h = w, h end
function Frame.SetWidth(self, w) self.__w = w end
function Frame.SetHeight(self, h) self.__h = h end
function Frame.GetWidth(self) return self.__w end
function Frame.GetHeight(self) return self.__h end
function Frame.GetSize(self) return self.__w, self.__h end
function Frame.Show(self) self.__shown = true end
function Frame.Hide(self) self.__shown = false end
function Frame.SetShown(self, shown) self.__shown = shown and true or false end
function Frame.IsShown(self) return self.__shown end
function Frame.IsVisible(self)
    if not self.__shown then return false end
    local parent = self.__parent
    return parent == nil or parent:IsVisible()
end
function Frame.GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
function Frame.SetText(self, text) self.__text = text end
function Frame.GetText(self) return self.__text end
function Frame.GetStringWidth(self) return #tostring(self.__text or "") * 6 end
function Frame.GetStringHeight() return 12 end
function Frame.GetFont() return STANDARD_TEXT_FONT, 12, "" end
function Frame.SetMinMaxValues(self, a, b) self.__min, self.__max = a, b end
function Frame.GetMinMaxValues(self) return self.__min or 0, self.__max or 0 end
function Frame.SetValue(self, value) self.__value = value; self:Fire("OnValueChanged", value) end
function Frame.GetValue(self) return self.__value or 0 end
function Frame.GetVerticalScroll() return 0 end
function Frame.IsMouseOver() return false end
function Frame.GetID() return 1 end
function Frame.NumLines(self) return #(self.__lines or {}) end
function Frame.RegisterEvent(self, event)
    EVENT_FRAMES[event] = EVENT_FRAMES[event] or {}
    table.insert(EVENT_FRAMES[event], self)
end
function Frame.UnregisterEvent(self, event)
    local list = EVENT_FRAMES[event] or {}
    for index = #list, 1, -1 do
        if list[index] == self then table.remove(list, index) end
    end
end
function FireEvent(event, ...)
    for _, frame in ipairs(EVENT_FRAMES[event] or {}) do frame:Fire("OnEvent", event, ...) end
end
function CreateFrame(kind, name, parent) return NewRegion(kind or "Frame", name, parent) end
function CreateFont(name) return NewRegion("Font", name) end

-- Timers
local timers, tickers = {}, {}
C_Timer = {
    After = function(_, fn) timers[#timers + 1] = fn end,
    NewTicker = function(_, fn) tickers[#tickers + 1] = fn end,
}
function RunTimers()
    local list = timers
    timers = {}
    for _, fn in ipairs(list) do fn() end
    for _, fn in ipairs(tickers) do fn() end
end

function hooksecurefunc(a, b, c)
    if type(a) == "table" then
        local original = a[b]
        a[b] = function(...) local results = { original(...) }; c(...); return table.unpack(results) end
    else
        local original = _G[a]
        _G[a] = function(...) local results = { original(...) }; b(...); return table.unpack(results) end
    end
end

-- The game's frames the addon looks for
UIParent = CreateFrame("Frame", "UIParent")
GameTooltip = CreateFrame("GameTooltip", "GameTooltip"); GameTooltip:Hide()
ItemRefTooltip = CreateFrame("GameTooltip", "ItemRefTooltip"); ItemRefTooltip:Hide()
ChatFontNormal = CreateFont("ChatFontNormal")
ChatFrame1 = CreateFrame("ScrollingMessageFrame", "ChatFrame1"); ChatFrame1.name = "Allgemein"
ChatFrame2 = CreateFrame("ScrollingMessageFrame", "ChatFrame2"); ChatFrame2.name = "Kampflog"
rawset(ChatFrame1, "AddMessage", function(_, message) print("CHAT> " .. tostring(message)) end)
DEFAULT_CHAT_FRAME = ChatFrame1
SELECTED_CHAT_FRAME = ChatFrame1
CHAT_FRAMES = { "ChatFrame1", "ChatFrame2" }
GENERAL_CHAT_DOCK = {}
function FCFDock_GetSelectedWindow() return ChatFrame1 end
function FCF_GetChatWindowInfo() return "Allgemein" end
function FCF_OpenNewWindow() end
function FCF_OpenTemporaryWindow() end
function SetItemRef(link) LAST_ITEMREF = link end
FILTERS = {}
function ChatFrame_AddMessageEventFilter(event, fn)
    FILTERS[event] = FILTERS[event] or {}
    table.insert(FILTERS[event], fn)
end

QuestFrame = CreateFrame("Frame", "QuestFrame"); QuestFrame:Hide()
for _, name in ipairs({ "QuestFrameDetailPanel", "QuestFrameProgressPanel", "QuestFrameRewardPanel", "QuestFrameGreetingPanel" }) do
    CreateFrame("Frame", name, QuestFrame):Hide()
end
GossipFrame = CreateFrame("Frame", "GossipFrame"); GossipFrame:Hide()
ItemTextFrame = CreateFrame("Frame", "ItemTextFrame"); ItemTextFrame:Hide()
QuestMapFrame = CreateFrame("Frame", "QuestMapFrame"); QuestMapFrame:Hide()
QuestMapFrame.DetailsFrame = CreateFrame("Frame", nil, QuestMapFrame)

MailFrame = CreateFrame("Frame", "MailFrame"); MailFrame:Hide()
OpenMailFrame = CreateFrame("Frame", "OpenMailFrame", MailFrame); OpenMailFrame:Hide()
SendMailFrame = CreateFrame("Frame", "SendMailFrame", MailFrame); SendMailFrame:Hide()
InboxFrame = { openMailID = 2 }
ATTACHMENTS_MAX_RECEIVE = 16
function GetInboxNumItems() return 2 end
function GetInboxHeaderInfo(index)
    if index == 1 then return nil, nil, "Alice Alder", "Hallo", 12345, 0, 29.5, false end
    return nil, nil, "Bob Baumeister", "Dein |cff00ff00Erz|r", 0, 500, 3.2, true
end
function GetInboxText(index)
    if index == 2 then return "Hier das Erz.\nGruß Bob" end
    return "Hallo!"
end
function GetInboxItem(index, slot)
    if index == 2 and slot == 1 then return "Kupfererz", 2770, "tex", 20, 1, true end
    return nil
end
MacroFrame = CreateFrame("Frame", "MacroFrame"); MacroFrame:Hide()
MacroFrame.selectedMacro = 3
function GetMacroInfo(index)
    if index == 3 then return "Trinken", "tex", "/use Quellwasser\n/say Prost" end
    return nil
end
GROUPED = false
function IsInGroup() return GROUPED end
function IsInRaid() return false end
function GetNumSubgroupMembers() return 1 end
function GetNumGroupMembers() return 2 end
function UnitLevel(unit) return unit == "player" and 37 or 30 end
function UnitClass(unit)
    if unit == "player" then return "Priester", "PRIEST" end
    return "Krieger", "WARRIOR"
end

Settings = {
    KEYBINDINGS_CATEGORY_ID = 99,
    RegisterCanvasLayoutCategory = function(panel) return { panel = panel, GetID = function() return 7 end } end,
    RegisterAddOnCategory = function() end,
    OpenToCategory = function(id) OPENED_CATEGORY = id end,
}

-- Game data
-- WoW Forever (WOW_PROJECT_ID 18): UnitName returns the first name and the surname.
function UnitName(unit)
    if unit == "npc" then return "Questgeber", "" end
    if unit == "target" then return "Grubenlord", "" end
    if unit == "player" then return "Maldö", "Thousandkegs" end
    if unit == "party1" then return "Bob Baumeister", "Baumeister" end
    return "Spieler", ""
end
function UnitIsPlayer(unit) return unit == "player" or unit == "party1" end
function GetNormalizedRealmName() return "Forever" end
function GetRealmName() return "Forever" end
function UnitGUID() return "Creature-0-4234-0-3-14645-00001E2F5A" end
MENUS = {}
Menu = { ModifyMenu = function(tag, fn) MENUS[tag] = fn end }
C_BattleNet = {
    GetAccountInfoByID = function(id)
        if id ~= 58 then return nil end
        return { accountName = "|Kq1|k", battleTag = "Bob#1234", gameAccountInfo = { characterName = "Bobchar", realmName = "Forever" } }
    end,
}
function GetTitleText() return "Die große Quest" end
function GetQuestText() return "Text der Quest mit |cff00ff00Farbe|r." end
function GetObjectiveText() return "Töte 10 Eber." end
function GetRewardText() return "Du erhältst Gold." end
function GetProgressText() return "Hast du die Eber?" end
function GetQuestID() return 123 end
function GetGreetingText() return "Willkommen." end
function GetNumAvailableQuests() return 1 end
function GetAvailableTitle() return "Die große Quest" end
function GetNumActiveQuests() return 0 end
C_GossipInfo = {
    GetText = function() return "Seid gegrüßt, |cffffd100Reisender|r." end,
    GetOptions = function() return { { name = "Ich möchte handeln." } } end,
    GetAvailableQuests = function() return { { title = "Die große Quest", questID = 123 } } end,
    GetActiveQuests = function() return {} end,
}
C_QuestLog = {
    GetSelectedQuest = function() return 456 end,
    GetTitleForQuestID = function() return "Logquest" end,
    GetQuestObjectives = function() return { { text = "Eber getötet: 10/10", finished = true } } end,
}
function GetQuestLogQuestText() return "Beschreibung", "Ziele-Text" end
function ItemTextGetItem() return "Altes Buch" end
function ItemTextGetText() return "<HTML><BODY><P>Erste Zeile<BR/>Zweite</P><P>Absatz</P></BODY></HTML>" end
function ItemTextGetPage() return 1 end
function ItemTextHasNextPage() return false end
function IsInGuild() return true end
C_GuildInfo = { GuildRoster = function() ROSTER_REQUESTED = true end }
function GetGuildInfo() return "Testgilde" end
function GetGuildRosterMOTD() return "Raid um 20 Uhr" end
function GetGuildInfoText() return "Infotext |cff00ff00grün|r" end
function GetNumGuildMembers() return 2 end
function GetGuildRosterInfo(index)
    if index == 1 then return "Alice-Realm", "Offizier", 1, 60, "Magier", "Orgrimmar", "notiz", "", true end
    return "Bob-Realm", "Mitglied", 2, 30, "Krieger", "Durotar", "", "offi", false
end
function Ambiguate(name) return name:match("^([^%-]+)") or name end
TooltipUtil = {
    GetDisplayedItem = function(tip)
        if tip == GameTooltip then return "Thunderfury", "|cffff8000|Hitem:19019::::::::60:::::|h[Thunderfury]|h|r", 19019 end
        return nil
    end,
}

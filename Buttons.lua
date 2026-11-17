local _, ns = ...
local L = ns.L
local C = ns.colors

--[[
The ways into the copy window besides the commands and keys:
  - a small quill in a corner of every chat window
  - a "Copy quest" button beside the quest, dialogue, book, guild and link windows
  - a modifier-click on a chat link
  - web addresses in chat, turned into links that open the window
  - the "Key: copy" line in item tooltips
]]

local Buttons = {}
ns.Buttons = Buttons

-- ---------------------------------------------------------------------------
-- Chat windows
-- ---------------------------------------------------------------------------

local chatButtons = {} -- chat frame -> the quill button in its corner
local HIDE_DELAY = 0.8

local function HideLater(button)
    button.leaveToken = (button.leaveToken or 0) + 1
    local token = button.leaveToken
    ns.After(HIDE_DELAY, function()
        if button.leaveToken ~= token or button.hover then return end
        local chatFrame = button:GetParent()
        if chatFrame and chatFrame.IsMouseOver and chatFrame:IsMouseOver() then return end
        button:Hide()
    end)
end

local function OnChatEnter(chatFrame)
    local button = chatButtons[chatFrame]
    if not button or not ns.db.chatButton then return end
    button.leaveToken = (button.leaveToken or 0) + 1
    button:Show()
end

local function OnChatLeave(chatFrame)
    local button = chatButtons[chatFrame]
    if button and ns.db.chatButtonHover then HideLater(button) end
end

local function PlaceChatButton(chatFrame)
    local button = chatButtons[chatFrame]
    if not button then return end
    local db = ns.db
    local corner = db.chatButtonCorner == "BOTTOMRIGHT" and "BOTTOMRIGHT" or "TOPRIGHT"
    button:ClearAllPoints()
    button:SetPoint(corner, chatFrame, corner, -2, corner == "TOPRIGHT" and -2 or 2)
    button:SetShown(db.chatButton and not db.chatButtonHover)
end

local function CreateChatButton(chatFrame)
    local button = ns.NewFrame("Button", nil, chatFrame)
    button:SetSize(16, 16)
    button:SetFrameLevel(chatFrame:GetFrameLevel() + 5)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button.icon:SetTexture(ns.mediaPath .. "scribe")
    button:SetAlpha(0.6)
    button:SetScript("OnEnter", function(self)
        self.hover = true
        self:SetAlpha(1)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L.PILL_CHAT_TIP, 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self)
        self.hover = false
        self:SetAlpha(0.6)
        GameTooltip:Hide()
        OnChatLeave(chatFrame)
    end)
    button:SetScript("OnClick", function()
        ns.Copy(ns.Sources.Chat(chatFrame), L.CHAT_EMPTY)
    end)
    chatButtons[chatFrame] = button

    -- The chat window tells us when the mouse arrives and leaves.
    chatFrame:HookScript("OnEnter", ns.Safe(function() OnChatEnter(chatFrame) end))
    chatFrame:HookScript("OnLeave", ns.Safe(function() OnChatLeave(chatFrame) end))
    PlaceChatButton(chatFrame)
end

--- Gives every chat window that has none a button. Called again when windows are added.
function Buttons:AttachChatButtons()
    for _, name in ipairs(CHAT_FRAMES or {}) do
        local frame = _G[name]
        if frame and not chatButtons[frame] then CreateChatButton(frame) end
    end
end

--- After an option changed: corner, always shown or on hover, or off.
function Buttons:ApplyChatButtons()
    for chatFrame in pairs(chatButtons) do
        PlaceChatButton(chatFrame)
    end
end

-- ---------------------------------------------------------------------------
-- Buttons beside windows ("pills")
-- ---------------------------------------------------------------------------

--[[
Each entry is one kind of window. A pill is made for every listed frame that exists. It is not
a child of that frame: a child inherits the window's level, clipping and whatever a skin addon
does to the window's children (clicks on a child of CommunitiesFrame never arrived). The pill
lives on UIParent, high up, hangs on the window by its anchor and is shown while the window is
visible (OnShow/OnHide hooks plus a ticker as a safety net). Frames of addons the game loads
later (the guild window) are picked up by the same ticker.
]]
local CONTEXTS = {
    { label = "PILL_QUEST", empty = "NO_QUEST", source = function() return ns.Sources.Quest() end,
        frames = { "QuestFrameDetailPanel", "QuestFrameProgressPanel", "QuestFrameRewardPanel", "QuestFrameGreetingPanel" } },
    { label = "PILL_GOSSIP", empty = "NO_GOSSIP", source = function() return ns.Sources.Gossip() end,
        frames = { "GossipFrame" } },
    { label = "PILL_QUEST", empty = "NO_QUEST", source = function() return ns.Sources.QuestLog() end,
        frames = { "QuestMapFrame.DetailsFrame", "QuestLogDetailFrame", "QuestLogFrame" } },
    { label = "PILL_BOOK", empty = "NO_BOOK", source = function() return ns.Sources.ItemText() end,
        frames = { "ItemTextFrame" } },
    { label = "PILL_GUILD", empty = "NO_GUILD", source = function() return ns.Sources.Guild() end,
        frames = { "CommunitiesFrame", "GuildFrame" } },
    { label = "PILL_LINK", empty = "NO_TOOLTIP", source = function() return ns.Sources.Tooltip(ItemRefTooltip) end,
        frames = { "ItemRefTooltip" } },
    -- The open letter sits to the right of the mailbox, so this pill goes above it.
    { label = "PILL_MAIL", empty = "NO_MAIL", source = function() return ns.Sources.Mail() end,
        frames = { "MailFrame" }, placement = "above" },
    { label = "PILL_MACRO", empty = "NO_MACRO", source = function() return ns.Sources.Macro() end,
        frames = { "MacroFrame" } },
}

local pills = {} -- host frame -> pill
Buttons.pills = pills

--- Shown while its window is visible and the option is on.
local function UpdatePill(pill)
    local host = pill.host
    local visible = host.IsVisible and host:IsVisible()
    pill:SetShown(ns.db.contextButtons and visible and true or false)
end

function Buttons:RelabelPill(pill)
    pill.label:SetText(L[pill.context.label])
    pill:SetWidth(pill.label:GetStringWidth() + 12 + 5 + 4 + 6 + 4)
    pill:Paint()
    UpdatePill(pill)
end

local function CreatePill(host, context)
    local pill = ns.CreateFlatButton(UIParent, "", 10, 20)
    pill.solid = true
    pill.context = context
    pill.host = host
    pill.textColor = C.accentText
    pill:SetFrameStrata("FULLSCREEN_DIALOG")
    pill:SetFrameLevel(50)
    pill:SetClampedToScreen(true)

    pill.icon = pill:CreateTexture(nil, "ARTWORK")
    pill.icon:SetSize(12, 12)
    pill.icon:SetPoint("LEFT", 5, 0)
    pill.icon:SetTexture(ns.mediaPath .. "scribe")
    pill.label:ClearAllPoints()
    pill.label:SetPoint("LEFT", pill.icon, "RIGHT", 4, 0)
    pill.label:SetPoint("RIGHT", -6, 0)
    pill.label:SetJustifyH("LEFT")

    -- Beside the window at its top right, or above it (clear of the portrait at the left).
    if context.placement == "above" then
        pill:SetPoint("BOTTOMLEFT", host, "TOPLEFT", 64, 4)
    else
        pill:SetPoint("TOPLEFT", host, "TOPRIGHT", 4, -6)
    end
    pill:SetScript("OnClick", function(self)
        ns.Debug("pill clicked:", self.context.label)
        ns.Copy(self.context.source(), L[self.context.empty])
    end)
    pill:HookScript("OnEnter", function(self)
        ns.Debug("pill hovered:", self.context.label)
    end)
    -- The window tells the pill when it comes and goes.
    local function Sync() UpdatePill(pill) end
    host:HookScript("OnShow", ns.Safe(Sync))
    host:HookScript("OnHide", ns.Safe(Sync))

    pills[host] = pill
    Buttons:RelabelPill(pill)
    ns.Debug("pill added:", host:GetName() or "?", "for", context.label)
end

--- Makes pills for windows that exist now and keeps every pill in step with its window.
local function ScanContexts()
    for _, context in ipairs(CONTEXTS) do
        for _, path in ipairs(context.frames) do
            local host = ns.ResolveFrame(path)
            if host and not pills[host] then CreatePill(host, context) end
        end
    end
    for _, pill in pairs(pills) do
        UpdatePill(pill)
    end
end

--- After a language change or the option toggled.
function Buttons:ApplyPills()
    for _, pill in pairs(pills) do
        self:RelabelPill(pill)
    end
end

-- ---------------------------------------------------------------------------
-- Chat links and web addresses
-- ---------------------------------------------------------------------------

-- Web addresses found in chat, by number: the link in the chat line carries the number, so
-- the address itself never has to survive the game's link syntax.
local urls, urlCount = {}, 0
local MAX_URLS = 500

local function RememberUrl(url)
    urlCount = urlCount + 1
    urls[urlCount] = url
    urls[urlCount - MAX_URLS] = nil
    return urlCount
end

local function ModifierDown()
    local modifier = ns.db.linkModifier
    if modifier == "ALT" then return IsAltKeyDown() end
    if modifier == "CTRL" then return IsControlKeyDown() end
    if modifier == "SHIFT" then return IsShiftKeyDown() end
    return false
end

--- Runs after the game handled a click on a chat link.
local function OnHyperlink(link, text)
    link = ns.Str(link)
    if not link then return end
    local index = link:match("^mscurl:(%d+)$")
    if index then
        ns.Copy(ns.Sources.Url(urls[tonumber(index)]), L.NOTHING_OPEN)
        return
    end
    if ModifierDown() then
        local source = ns.Sources.Link(link, ns.Str(text))
        if source then ns.UI:Open(source) end
    end
end

local function LinkifyWord(word)
    local url, lead, trail = ns.Text.FindUrl(word)
    if not url then return nil end
    local index = RememberUrl(url)
    return lead .. "|cffffa463|Hmscurl:" .. index .. "|h" .. url .. "|h|r" .. trail
end

--- A chat message filter: web addresses become links. Returns nothing when there is none.
local function UrlFilter(_, _, message, ...)
    if not ns.db.chatUrls or ns.IsSecret(message) or type(message) ~= "string" then return end
    if not message:find("%.%a") then return end
    local changed = 0
    local result = message:gsub("%S+", function(word)
        local replaced = LinkifyWord(word)
        if replaced then changed = changed + 1 end
        return replaced
    end)
    if changed == 0 then return end
    return false, result, ...
end

-- ---------------------------------------------------------------------------
-- "Copy name" in the right-click menus of players and units
-- ---------------------------------------------------------------------------

-- The game's unit menus by name: own portrait, target, party and raid members, names in chat,
-- friends, guild and community members. An unknown name simply never shows a menu.
local UNIT_MENUS = {
    "SELF", "PLAYER", "ENEMY_PLAYER", "TARGET", "FOCUS", "PARTY", "RAID", "RAID_PLAYER",
    "FRIEND", "BN_FRIEND", "GUILD", "GUILD_OFFLINE", "CHAT_ROSTER",
    "COMMUNITIES_WOW_MEMBER", "COMMUNITIES_GUILD_MEMBER", "COMMUNITIES_MEMBER",
    "ARENAENEMY", "BOSS", "VEHICLE", "PET", "OTHERPET", "RAF_RECRUIT",
    "WORLD_STATE_SCORE", "PVP_SCOREBOARD",
}

local function AddMenuEntry(_, root, contextData)
    if not ns.db.menuEntry then return end
    local source = ns.Sources.Unit(contextData)
    if not source then return end
    if root.CreateDivider then root:CreateDivider() end
    root:CreateButton(L.MENU_COPY_NAME, ns.Safe(function()
        ns.Debug("menu: copy name", source.title)
        ns.UI:Open(source)
    end))
end

-- ---------------------------------------------------------------------------
-- Tooltips
-- ---------------------------------------------------------------------------

local function KeyName(binding)
    local key = GetBindingKey and GetBindingKey(binding)
    if not key then return nil end
    if GetBindingText then return GetBindingText(key) end
    return key
end

--- "Key: copy" at the end of item tooltips, while a key is bound.
local function TooltipHint(tooltip)
    if not ns.db.tooltipHint or tooltip ~= GameTooltip then return end
    local key = KeyName("MALDOESSCRIBE_TOOLTIP") or KeyName("MALDOESSCRIBE_SMART")
    if not key then return end
    tooltip:AddLine(L.TOOLTIP_HINT:format(key), C.textFaint[1], C.textFaint[2], C.textFaint[3])
end

-- ---------------------------------------------------------------------------
-- Start
-- ---------------------------------------------------------------------------

function Buttons:Init()
    self:AttachChatButtons()
    -- Windows the player opens later: new tabs and whisper pop-outs.
    local function AttachSoon()
        ns.After(0, function() Buttons:AttachChatButtons() end)
    end
    if type(FCF_OpenNewWindow) == "function" then hooksecurefunc("FCF_OpenNewWindow", AttachSoon) end
    if type(FCF_OpenTemporaryWindow) == "function" then hooksecurefunc("FCF_OpenTemporaryWindow", AttachSoon) end

    -- The buttons beside windows: frames that exist now get one at once, the others when the
    -- game loads them (the guild window is an addon of its own).
    ScanContexts()
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(0.5, ns.Safe(ScanContexts))
    end

    if type(SetItemRef) == "function" then
        hooksecurefunc("SetItemRef", ns.Safe(OnHyperlink))
    end

    if Menu and type(Menu.ModifyMenu) == "function" then
        local handler = ns.Safe(AddMenuEntry)
        for _, which in ipairs(UNIT_MENUS) do
            pcall(Menu.ModifyMenu, "MENU_UNIT_" .. which, handler)
        end
    else
        ns.Warn("no Menu.ModifyMenu on this client: no 'Copy name' entry in the unit menus")
    end

    -- The game would try to show our web links in the link tooltip: swallow them there.
    if ItemRefTooltip and type(ItemRefTooltip.SetHyperlink) == "function" then
        local original = ItemRefTooltip.SetHyperlink
        ItemRefTooltip.SetHyperlink = function(self, link, ...)
            if not ns.IsSecret(link) and type(link) == "string" and link:find("^mscurl:") then return end
            return original(self, link, ...)
        end
    end

    local addFilter = ChatFrame_AddMessageEventFilter or (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter)
    if type(addFilter) == "function" then
        local filter = ns.Safe(UrlFilter)
        for _, event in ipairs(ns.UrlEvents) do
            pcall(addFilter, event, filter)
        end
    else
        ns.Warn("no chat message filter on this client: web addresses stay plain text")
    end

    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType
            and Enum.TooltipDataType.Item then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, ns.Safe(TooltipHint))
    elseif GameTooltip and GameTooltip.HookScript then
        GameTooltip:HookScript("OnTooltipSetItem", ns.Safe(TooltipHint))
    end
end

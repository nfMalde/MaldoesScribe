local _, ns = ...
local L = ns.L
local Text = ns.Text
local Str = ns.Str

--[[
Where the texts come from. Each function returns a source for the copy window, or nil when
there is nothing to copy right now.

A source:
  kind      a word for the log ("chat", "quest", ...)
  title     shown next to the window title
  subtitle  optional, shown dim on the right
  hint      optional, replaces the Ctrl+C hint at the bottom
  note      optional, set while building (for example "3 lines left out")
  variants  one or more { label, build }: build() returns the text. With more than one, the
            window shows the labels as a row of buttons (Text | Name | Wowhead).
  actions   optional extra buttons { label, click }
]]

local Sources = {}
ns.Sources = Sources

local function Variant(label, build)
    return { label = label, build = build }
end

local function Static(text)
    return function() return text end
end

--- pcall for game functions that may be missing on this client: nil instead of an error.
local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g, h, i, j = pcall(fn, ...)
    if ok then return a, b, c, d, e, f, g, h, i, j end
    ns.Warn("call failed:", a)
    return nil
end

local function Clean(value)
    return ns.Trim(Text.Clean(Str(value) or ""))
end

local function AddId(source, kind, id)
    id = tonumber(id)
    if kind and id and id > 0 and ns.IdKinds[kind] then
        source.variants[#source.variants + 1] = Variant(L.VARIANT_ID, Static(kind .. ":" .. id))
    end
end

local function AddWowhead(source, kind, id)
    local url = Text.Wowhead(kind, id)
    if url then
        source.variants[#source.variants + 1] = Variant(L.VARIANT_WOWHEAD, Static(url))
    end
end

-- ---------------------------------------------------------------------------
-- Chat
-- ---------------------------------------------------------------------------

--- The chat window the player is looking at: the selected tab of the main dock.
function ns.ActiveChatFrame()
    local frame
    if FCFDock_GetSelectedWindow and GENERAL_CHAT_DOCK then
        local ok, selected = pcall(FCFDock_GetSelectedWindow, GENERAL_CHAT_DOCK)
        if ok then frame = selected end
    end
    return frame or SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME or ChatFrame1
end

--- The name on the chat tab ("General", "Whispers").
function ns.ChatFrameName(frame)
    local name = Str(frame.name)
    if not name and frame.GetID and FCF_GetChatWindowInfo then
        local ok, windowName = pcall(FCF_GetChatWindowInfo, frame:GetID())
        if ok then name = Str(windowName) end
    end
    return name or (frame.GetName and frame:GetName()) or "Chat"
end

--- Everything a chat window shows, oldest line first, as plain text.
function Sources.Chat(frame)
    frame = frame or ns.ActiveChatFrame()
    if not (frame and frame.GetNumMessages and frame.GetMessageInfo) then return nil end
    local source = { kind = "chat", title = L.SRC_CHAT:format(ns.ChatFrameName(frame)) }
    source.variants = {
        Variant(L.VARIANT_TEXT, function()
            local count = Call(frame.GetNumMessages, frame) or 0
            local first = math.max(1, count - (ns.db.chatMaxLines or 500) + 1)
            local out, skipped = {}, 0
            for index = first, count do
                local ok, message = pcall(frame.GetMessageInfo, frame, index)
                if ok then
                    if ns.IsSecret(message) then
                        skipped = skipped + 1
                    elseif type(message) == "string" then
                        -- Trimmed: a removed icon at the start would leave a blank.
                        local line = ns.Trim(Text.Clean(message))
                        if ns.db.chatStripTimestamps then line = Text.StripTimestamp(line) end
                        out[#out + 1] = line
                    end
                end
            end
            source.note = skipped > 0 and L.CHAT_SECRET_SKIPPED:format(skipped) or nil
            ns.Debug("chat read:", #out, "lines,", skipped, "secret, of", count)
            if #out == 0 then return L.CHAT_EMPTY end
            return table.concat(out, "\n")
        end),
    }
    return source
end

-- ---------------------------------------------------------------------------
-- Quests and dialogues at an NPC
-- ---------------------------------------------------------------------------

local function QuestTitles(countFn, titleFn, heading)
    local titles = {}
    for index = 1, (Call(countFn) or 0) do
        local title = Str(Call(titleFn, index))
        if title then titles[#titles + 1] = "- " .. Text.Clean(title) end
    end
    if #titles == 0 then return nil end
    return heading .. "\n" .. table.concat(titles, "\n")
end

--- The quest window at an NPC: the offer, the progress check, the reward or the greeting list.
function Sources.Quest()
    local panel
    if ns.FrameVisible("QuestFrameDetailPanel") then
        panel = "detail"
    elseif ns.FrameVisible("QuestFrameProgressPanel") then
        panel = "progress"
    elseif ns.FrameVisible("QuestFrameRewardPanel") then
        panel = "reward"
    elseif ns.FrameVisible("QuestFrameGreetingPanel") then
        panel = "greeting"
    else
        return nil
    end

    local source = { kind = "quest", variants = {} }
    if panel == "greeting" then
        local npc = ns.UnitDisplayName("npc") or "?"
        source.title = L.SRC_GOSSIP:format(npc)
        source.variants[1] = Variant(L.VARIANT_TEXT, function()
            return Text.Sections({
                npc,
                Clean(Call(GetGreetingText)),
                QuestTitles(GetNumAvailableQuests, GetAvailableTitle, L.QUEST_AVAILABLE),
                QuestTitles(GetNumActiveQuests, GetActiveTitle, L.QUEST_ACTIVE),
            })
        end)
        source.variants[2] = Variant(L.VARIANT_NAME, Static(npc))
        AddWowhead(source, "npc", Text.NpcID(Call(UnitGUID, "npc")))
        return source
    end

    local title = Str(Call(GetTitleText)) or "?"
    source.title = L.SRC_QUEST:format(title)
    source.variants[1] = Variant(L.VARIANT_TEXT, function()
        if panel == "detail" then
            return Text.Sections({
                title,
                Clean(Call(GetQuestText)),
                Text.Heading(L.QUEST_OBJECTIVES, Call(GetObjectiveText)),
                Text.Heading(L.QUEST_REWARDS, Call(GetRewardText)),
            })
        elseif panel == "progress" then
            return Text.Sections({ title, Clean(Call(GetProgressText)) })
        end
        return Text.Sections({ title, Clean(Call(GetRewardText)) })
    end)
    source.variants[2] = Variant(L.VARIANT_NAME, Static(title))
    local questID = Call(GetQuestID)
    AddId(source, "quest", questID)
    AddWowhead(source, "quest", questID)
    return source
end

--- The dialogue window of an NPC: its text, the options and the quests it offers.
function Sources.Gossip()
    if not ns.FrameVisible("GossipFrame") then return nil end
    local npc = ns.UnitDisplayName("npc") or "?"
    local source = { kind = "gossip", title = L.SRC_GOSSIP:format(npc), variants = {} }
    source.variants[1] = Variant(L.VARIANT_TEXT, function()
        local parts = { npc }
        if C_GossipInfo then
            parts[#parts + 1] = Clean(Call(C_GossipInfo.GetText))
            local lines = {}
            local options = Call(C_GossipInfo.GetOptions)
            if type(options) == "table" then
                for _, option in ipairs(options) do
                    local name = type(option) == "table" and Str(option.name)
                    if name then lines[#lines + 1] = "- " .. Text.Clean(name) end
                end
            end
            if #lines > 0 then parts[#parts + 1] = L.GOSSIP_OPTIONS .. "\n" .. table.concat(lines, "\n") end
            local function Quests(getter, heading)
                local list = Call(getter)
                local titles = {}
                if type(list) == "table" then
                    for _, quest in ipairs(list) do
                        local title = type(quest) == "table" and Str(quest.title)
                        if title then titles[#titles + 1] = "- " .. Text.Clean(title) end
                    end
                end
                if #titles > 0 then parts[#parts + 1] = heading .. "\n" .. table.concat(titles, "\n") end
            end
            Quests(C_GossipInfo.GetAvailableQuests, L.QUEST_AVAILABLE)
            Quests(C_GossipInfo.GetActiveQuests, L.QUEST_ACTIVE)
        else
            parts[#parts + 1] = Clean(Call(GetGossipText))
        end
        return Text.Sections(parts)
    end)
    source.variants[2] = Variant(L.VARIANT_NAME, Static(npc))
    AddWowhead(source, "npc", Text.NpcID(Call(UnitGUID, "npc")))
    return source
end

-- ---------------------------------------------------------------------------
-- Quest log
-- ---------------------------------------------------------------------------

local function SelectedQuest()
    if C_QuestLog and C_QuestLog.GetSelectedQuest then
        local questID = Call(C_QuestLog.GetSelectedQuest)
        if type(questID) == "number" and questID > 0 then
            local title = C_QuestLog.GetTitleForQuestID and Str(Call(C_QuestLog.GetTitleForQuestID, questID))
            return questID, title
        end
    end
    -- Older quest log: the selection is an index into the list.
    if GetQuestLogSelection and GetQuestLogTitle then
        local index = Call(GetQuestLogSelection)
        if type(index) == "number" and index > 0 then
            local title, _, _, isHeader, _, _, _, questID = Call(GetQuestLogTitle, index)
            if not isHeader then return tonumber(questID) or 0, Str(title) end
        end
    end
    return nil
end

--- The quest selected in the quest log.
function Sources.QuestLog()
    local questID, title = SelectedQuest()
    if not questID then return nil end
    title = title or "?"
    local source = { kind = "questlog", title = L.SRC_QUEST:format(title), variants = {} }
    source.variants[1] = Variant(L.VARIANT_TEXT, function()
        local description, objectivesText = Call(GetQuestLogQuestText)
        local lines = {}
        local objectives = C_QuestLog and C_QuestLog.GetQuestObjectives and Call(C_QuestLog.GetQuestObjectives, questID)
        if type(objectives) == "table" then
            for _, objective in ipairs(objectives) do
                local text = type(objective) == "table" and Str(objective.text)
                if text and text ~= "" then
                    local done = ns.Bool(objective.finished)
                    lines[#lines + 1] = (done and "[x] " or "[ ] ") .. Text.Clean(text)
                end
            end
        end
        local objectivesPart
        if #lines > 0 then
            objectivesPart = L.QUEST_OBJECTIVES .. "\n" .. table.concat(lines, "\n")
        else
            objectivesPart = Text.Heading(L.QUEST_OBJECTIVES, objectivesText)
        end
        return Text.Sections({ title, Clean(description), objectivesPart })
    end)
    source.variants[2] = Variant(L.VARIANT_NAME, Static(title))
    AddId(source, "quest", questID)
    AddWowhead(source, "quest", questID)
    return source
end

-- ---------------------------------------------------------------------------
-- Books, plaques, letters (the item text window)
-- ---------------------------------------------------------------------------

function Sources.ItemText()
    if not ns.FrameVisible("ItemTextFrame") then return nil end
    local item = Str(Call(ItemTextGetItem)) or "?"
    local page = Call(ItemTextGetPage)
    local source = { kind = "book", title = L.SRC_BOOK:format(item), variants = {} }
    if type(page) == "number" and (page > 1 or ns.Bool(Call(ItemTextHasNextPage))) then
        source.subtitle = L.BOOK_PAGE:format(page)
    end
    source.variants[1] = Variant(L.VARIANT_TEXT, function()
        local head = item
        if source.subtitle then head = item .. " (" .. source.subtitle .. ")" end
        local body = Text.StripHtml(Clean(Call(ItemTextGetText)))
        return Text.Sections({ head, body })
    end)
    source.variants[2] = Variant(L.VARIANT_NAME, Static(item))
    return source
end

-- ---------------------------------------------------------------------------
-- Guild
-- ---------------------------------------------------------------------------

function Sources.Guild()
    if not ns.Bool(Call(IsInGuild)) then
        return { kind = "guild", title = L.SRC_GUILD:format("-"), variants = { Variant(L.VARIANT_INFO, Static(L.NO_GUILD)) } }
    end
    -- Ask the server for a fresh roster; the game throttles this itself.
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        Call(C_GuildInfo.GuildRoster)
    elseif GuildRoster then
        Call(GuildRoster)
    end

    local name = Str(Call(GetGuildInfo, "player")) or "?"
    local source = { kind = "guild", title = L.SRC_GUILD:format(name), variants = {} }
    local function Motd() return Clean(Call(GetGuildRosterMOTD)) end
    local function Info() return Clean(Call(GetGuildInfoText)) end

    source.variants[1] = Variant(L.VARIANT_INFO, function()
        return Text.Sections({ name, Text.Heading(L.GUILD_MOTD, Motd()), Text.Heading(L.GUILD_INFO, Info()) })
    end)
    source.variants[2] = Variant(L.VARIANT_MOTD, Motd)
    source.variants[3] = Variant(L.VARIANT_ROSTER, function()
        local total = Call(GetNumGuildMembers) or 0
        local rows = { L.GUILD_ROSTER_HEADER }
        for index = 1, total do
            local member, rank, _, level, class, zone, note, officerNote, online = Call(GetGuildRosterInfo, index)
            member = Str(member)
            if member then
                -- "Name-Realm" becomes "Name" on the own realm.
                member = Str(Call(Ambiguate, member, "guild")) or member
                local status = ns.Bool(online)
                rows[#rows + 1] = table.concat({
                    member,
                    Str(rank) or "",
                    Str(level) or "",
                    Str(class) or "",
                    Str(zone) or "",
                    Clean(note),
                    Clean(officerNote),
                    status == nil and "" or (status and L.GUILD_ONLINE or L.GUILD_OFFLINE),
                }, "\t")
            end
        end
        source.note = L.GUILD_MEMBERS:format(#rows - 1)
        return table.concat(rows, "\n")
    end)
    return source
end

-- ---------------------------------------------------------------------------
-- Mail, macros, the group
-- ---------------------------------------------------------------------------

--- "12g 34s 56c", or nil for nothing.
local function Money(copper)
    copper = tonumber(Str(copper))
    if not copper or copper <= 0 then return nil end
    local gold = math.floor(copper / 10000)
    local silver = math.floor(copper / 100) % 100
    local rest = copper % 100
    local parts = {}
    if gold > 0 then parts[#parts + 1] = gold .. "g" end
    if silver > 0 or gold > 0 then parts[#parts + 1] = silver .. "s" end
    parts[#parts + 1] = rest .. "c"
    return table.concat(parts, " ")
end

--- One letter of the inbox: the whole text, its subject and its body.
local function Letter(index)
    local _, _, sender, subject, money, cod, _, hasItem = Call(GetInboxHeaderInfo, index)
    local body = Clean(Call(GetInboxText, index))
    local head = L.MAIL_FROM .. ": " .. (Str(sender) or "?") .. "\n" .. L.MAIL_SUBJECT .. ": " .. Clean(subject)
    local extras = {}
    local moneyText = Money(money)
    if moneyText then extras[#extras + 1] = L.MAIL_MONEY .. ": " .. moneyText end
    local codText = Money(cod)
    if codText then extras[#extras + 1] = L.MAIL_COD .. ": " .. codText end
    if ns.Bool(hasItem) then
        local items = {}
        for slot = 1, (ATTACHMENTS_MAX_RECEIVE or 16) do
            local name, _, _, count = Call(GetInboxItem, index, slot)
            name = Str(name)
            if name then
                count = tonumber(Str(count)) or 1
                items[#items + 1] = "- " .. name .. (count > 1 and (" x" .. count) or "")
            end
        end
        if #items > 0 then extras[#extras + 1] = L.MAIL_ATTACHMENTS .. "\n" .. table.concat(items, "\n") end
    end
    return Text.Sections({ head, body, table.concat(extras, "\n") }), Clean(subject), body
end

--- The inbox as a table: sender, subject, money, items, days left.
local function Inbox()
    local count = Call(GetInboxNumItems) or 0
    local rows = { L.MAIL_INBOX_HEADER }
    for index = 1, count do
        local _, _, sender, subject, money, _, daysLeft, hasItem = Call(GetInboxHeaderInfo, index)
        local days = tonumber(Str(daysLeft))
        rows[#rows + 1] = table.concat({
            Str(sender) or "?",
            Clean(subject),
            Money(money) or "",
            ns.Bool(hasItem) and "x" or "",
            days and string.format("%.1f", days) or "",
        }, "\t")
    end
    return table.concat(rows, "\n"), count
end

--- The mailbox: the open letter, the draft being written, the inbox list. Works while the mailbox
--- is open even when another addon hides the game's mail window (then only the inbox list).
function Sources.Mail()
    if not (ns.FrameVisible("MailFrame") or ns.mailboxOpen) then return nil end
    local source = { kind = "mail", variants = {} }
    local open = ns.FrameVisible("OpenMailFrame") and InboxFrame and tonumber(InboxFrame.openMailID) or nil
    if open and open > 0 then
        local _, subject = Letter(open)
        source.title = L.SRC_MAIL:format(subject or "?")
        source.variants[#source.variants + 1] = Variant(L.VARIANT_TEXT, function() return (Letter(open)) end)
        source.variants[#source.variants + 1] = Variant(L.VARIANT_BODY, function()
            local _, _, body = Letter(open)
            return body
        end)
    else
        source.title = L.SRC_INBOX
    end
    if ns.FrameVisible("SendMailFrame") then
        source.variants[#source.variants + 1] = Variant(L.VARIANT_DRAFT, function()
            local parts = {}
            local subject = SendMailSubjectEditBox and Str(SendMailSubjectEditBox:GetText())
            if subject and subject ~= "" then parts[#parts + 1] = L.MAIL_SUBJECT .. ": " .. subject end
            local body = SendMailBodyEditBox and Str(SendMailBodyEditBox:GetText())
            if body then parts[#parts + 1] = body end
            return Text.Sections(parts)
        end)
    end
    source.variants[#source.variants + 1] = Variant(L.VARIANT_INBOX, function()
        local text, count = Inbox()
        source.note = L.MAIL_COUNT:format(count)
        return text
    end)
    return source
end

--- The macro open in the macro window.
function Sources.Macro()
    if not ns.FrameVisible("MacroFrame") then return nil end
    -- The modern macro window: the selection is an index into the current tab, which
    -- GetMacroDataIndex turns into the index GetMacroInfo wants. Older windows keep selectedMacro.
    local index
    if MacroFrame.GetSelectedIndex and MacroFrame.GetMacroDataIndex then
        local selected = Call(MacroFrame.GetSelectedIndex, MacroFrame)
        if selected then index = tonumber(Call(MacroFrame.GetMacroDataIndex, MacroFrame, selected)) end
    end
    index = index or tonumber(MacroFrame.selectedMacro)
    local name, body
    if index and index > 0 then
        local macroName, _, macroBody = Call(GetMacroInfo, index)
        name, body = Str(macroName), Str(macroBody)
    end
    if not name and MacroFrameSelectedMacroName and MacroFrameSelectedMacroName.GetText then
        name = Str(MacroFrameSelectedMacroName:GetText())
    end
    if not body and MacroFrameText and MacroFrameText.GetText then body = Str(MacroFrameText:GetText()) end
    if not body or body == "" then return nil end
    local source = { kind = "macro", title = L.SRC_MACRO:format(name or "?"), variants = {} }
    source.variants[1] = Variant(L.VARIANT_TEXT, Static(body))
    if name then source.variants[2] = Variant(L.VARIANT_NAME, Static(name)) end
    return source
end

--- The party or raid: names, or a table with level and class.
function Sources.Group()
    if not ns.Bool(Call(IsInGroup)) then return nil end
    local function Units()
        local units = {}
        if ns.Bool(Call(IsInRaid)) then
            for index = 1, (Call(GetNumGroupMembers) or 0) do units[#units + 1] = "raid" .. index end
        else
            units[1] = "player"
            for index = 1, (Call(GetNumSubgroupMembers) or 0) do units[#units + 1] = "party" .. index end
        end
        return units
    end
    local source = { kind = "group", title = L.SRC_GROUP, variants = {} }
    source.variants[1] = Variant(L.VARIANT_NAMES, function()
        local names = {}
        for _, unit in ipairs(Units()) do
            local name = ns.UnitDisplayName(unit)
            if name then names[#names + 1] = name end
        end
        source.note = L.GROUP_MEMBERS:format(#names)
        return table.concat(names, "\n")
    end)
    source.variants[2] = Variant(L.VARIANT_TABLE, function()
        local rows = { L.GROUP_HEADER }
        for _, unit in ipairs(Units()) do
            local name = ns.UnitDisplayName(unit)
            if name then
                rows[#rows + 1] = table.concat({
                    name,
                    Str(Call(UnitLevel, unit)) or "",
                    Str((Call(UnitClass, unit))) or "",
                }, "\t")
            end
        end
        return table.concat(rows, "\n")
    end)
    return source
end

-- ---------------------------------------------------------------------------
-- Tooltips and links
-- ---------------------------------------------------------------------------

local function TooltipLines(tip)
    local name = tip:GetName()
    local out = {}
    if not name then return out end
    local count = Call(tip.NumLines, tip) or 0
    for index = 1, count do
        local left = _G[name .. "TextLeft" .. index]
        local right = _G[name .. "TextRight" .. index]
        local leftText = left and left:IsShown() and Str(left:GetText())
        local rightText = right and right:IsShown() and Str(right:GetText())
        leftText = leftText and ns.Trim(Text.Clean(leftText)) or nil
        rightText = rightText and ns.Trim(Text.Clean(rightText)) or nil
        if leftText and rightText and rightText ~= "" then
            out[#out + 1] = leftText .. "    " .. rightText
        elseif leftText and leftText ~= "" then
            out[#out + 1] = leftText
        elseif rightText and rightText ~= "" then
            out[#out + 1] = rightText
        end
    end
    return out
end

local function ItemID(link)
    link = Str(link)
    return link and tonumber(link:match("item:(%d+)")) or nil
end

--- What a tooltip is about: kind ("item", "spell", "npc"), its name and its id.
local function TooltipSubject(tip)
    if TooltipUtil then
        if TooltipUtil.GetDisplayedItem then
            local name, link, id = Call(TooltipUtil.GetDisplayedItem, tip)
            if Str(name) then return "item", Str(name), tonumber(id) or ItemID(link) end
        end
        if TooltipUtil.GetDisplayedSpell then
            local name, id = Call(TooltipUtil.GetDisplayedSpell, tip)
            if Str(name) then return "spell", Str(name), tonumber(id) end
        end
        if TooltipUtil.GetDisplayedUnit then
            local name, unit, guid = Call(TooltipUtil.GetDisplayedUnit, tip)
            if Str(name) then
                return "npc", Str(name), Text.NpcID(guid or (unit and Call(UnitGUID, unit)))
            end
        end
    end
    if tip.GetItem then
        local name, link = Call(tip.GetItem, tip)
        if Str(name) then return "item", Str(name), ItemID(link) end
    end
    if tip.GetSpell then
        local name, id = Call(tip.GetSpell, tip)
        if Str(name) then return "spell", Str(name), tonumber(id) end
    end
    if tip.GetUnit then
        local name, unit = Call(tip.GetUnit, tip)
        if Str(name) then return "npc", Str(name), Text.NpcID(unit and Call(UnitGUID, unit)) end
    end
    return nil
end

--- A tooltip (the one under the mouse, or the one a chat link opened). The lines are read
--- now, because the tooltip is gone once the mouse moves to the copy window.
function Sources.Tooltip(tip)
    if not (tip and tip.IsVisible and tip:IsVisible()) then return nil end
    local lines = TooltipLines(tip)
    if #lines == 0 then return nil end
    local kind, name, id = TooltipSubject(tip)
    name = name or lines[1]
    local isLink = tip == ItemRefTooltip
    local source = { kind = isLink and "link" or "tooltip", variants = {} }
    source.title = (isLink and L.SRC_LINK or L.SRC_TOOLTIP):format(name)
    source.variants[1] = Variant(L.VARIANT_NAME, Static(name))
    source.variants[2] = Variant(L.VARIANT_TOOLTIP, Static(table.concat(lines, "\n")))
    AddId(source, kind, id)
    AddWowhead(source, kind, id)
    return source
end

-- ---------------------------------------------------------------------------
-- Players and units (right-click menus, names in chat)
-- ---------------------------------------------------------------------------

--[[
WoW Forever characters have a surname: UnitName(unit) returns the first name and, as its second
value, the surname (on other clients the second value is the realm). The game shows them joined
with Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR, a space.
]]
ns.isForever = (WOW_PROJECT_ID == 18)
    or (type(Constants) == "table" and type(Constants.CharacterNameSeparatorConsts) == "table")
local SURNAME_SEP = (type(Constants) == "table" and type(Constants.CharacterNameSeparatorConsts) == "table"
    and Str(Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR)) or " "

--- "First" and "Last" as one name, unless the first already carries the last.
local function JoinSurname(first, surname)
    first, surname = Str(first), Str(surname)
    if not first then return nil end
    if not surname or surname == "" then return first end
    local tail = SURNAME_SEP .. surname
    if first:sub(-#tail) == tail then return first end
    return first .. tail
end

--- A full name split into first name and surname at the separator, or nil, nil.
local function SplitSurname(full)
    if type(full) ~= "string" then return nil end
    local position = full:find(SURNAME_SEP, 1, true)
    if not position or position == 1 or position + #SURNAME_SEP > #full then return nil end
    return full:sub(1, position - 1), full:sub(position + #SURNAME_SEP)
end

--- The name parts of a unit: full name, first name, surname (Forever) and realm (other clients).
local function UnitNames(unit)
    local first, second = Call(UnitNameUnmodified or UnitName, unit)
    first, second = Str(first), Str(second)
    if not first then return nil end
    if ns.isForever then
        local full = JoinSurname(first, second)
        local splitFirst, splitLast = SplitSurname(full)
        return full, splitFirst or first, splitLast or ((second ~= "") and second or nil), nil
    end
    if second == "" then second = nil end
    return first, first, nil, second
end

--- A unit's name as the game shows it ("First Last" on Forever), for titles and NPC texts.
function ns.UnitDisplayName(unit)
    local full = UnitNames(unit)
    return full
end

--[[
A character name. info:
  full       the name as shown ("First Last" on Forever); a protected Battle.net name never
  first/last the parts, when known
  realm      for the "Name-Realm" form other players can whisper (not on Forever)
  isPlayer   false for an NPC: no name parts, the Wowhead page instead
  unit       for the NPC id
  battleTag  a Battle.net friend
]]
function Sources.Player(info)
    info = info or {}
    local isPlayer = info.isPlayer ~= false
    local full = Str(info.full)
    if full then
        if full:find("|K", 1, true) then
            full = nil
        else
            full = ns.Trim(Text.Clean(full))
        end
    end
    if full == "" then full = nil end
    local first, last, realm = Str(info.first), Str(info.last), Str(info.realm)
    if realm == "" then realm = nil end
    if full and isPlayer then
        if not ns.isForever then
            -- "Name-Realm" as one string: take it apart.
            local base, suffix = full:match("^([^%-]+)%-(.+)$")
            if base then
                full = base
                realm = realm or suffix
            end
        elseif not (first and last) then
            first, last = SplitSurname(full)
        end
    end
    if first == "" then first = nil end
    if last == "" then last = nil end
    local battleTag = Str(info.battleTag)
    if not full and not battleTag then return nil end

    local source = { kind = "player", variants = {} }
    source.title = (isPlayer and L.SRC_PLAYER or L.SRC_NPC):format(full or battleTag)
    if full then
        source.variants[1] = Variant(L.VARIANT_NAME, Static(full))
        if isPlayer then
            if first and last and first ~= full then
                source.variants[#source.variants + 1] = Variant(L.VARIANT_FIRST_NAME, Static(first))
                source.variants[#source.variants + 1] = Variant(L.VARIANT_LAST_NAME, Static(last))
            end
            if not ns.isForever then
                realm = realm or Str(Call(GetNormalizedRealmName))
                if realm and realm ~= "" then
                    source.variants[#source.variants + 1] = Variant(L.VARIANT_FULL_NAME, Static(full .. "-" .. realm))
                end
            end
        else
            AddWowhead(source, "npc", Text.NpcID(info.unit and Call(UnitGUID, info.unit)))
        end
    end
    if battleTag then
        source.variants[#source.variants + 1] = Variant(L.VARIANT_BATTLETAG, Static(battleTag))
    end
    return source
end

--- True when a "server" value of the game's menus is the realm and not a Forever surname.
local function IsRealmName(server)
    if not server or server == "" then return true end
    local normalized = Str(Call(GetNormalizedRealmName))
    local plain = Str(Call(GetRealmName))
    return server == normalized or server == plain
end

--- A unit or player from one of the game's right-click menus (their contextData).
function Sources.Unit(data)
    if type(data) ~= "table" then return nil end
    local unit = Str(data.unit)
    local info = { unit = unit }
    if unit then
        local isPlayer = Call(UnitIsPlayer, unit)
        if ns.IsSecret(isPlayer) then isPlayer = nil end
        info.isPlayer = isPlayer ~= false
        info.full, info.first, info.last, info.realm = UnitNames(unit)
    end
    if not info.full then
        local name, server = Str(data.name), Str(data.server)
        if name then
            if ns.isForever then
                -- Forever's menus may hand the surname over in the server field.
                if IsRealmName(server) then
                    info.full = name
                else
                    info.full, info.first, info.last = JoinSurname(name, server), name, server
                end
            else
                info.full, info.realm = name, server
            end
        end
    end
    local account = type(data.accountInfo) == "table" and data.accountInfo or nil
    if account then
        info.battleTag = Str(account.battleTag)
        local game = type(account.gameAccountInfo) == "table" and account.gameAccountInfo or nil
        if not info.full and game then
            info.full = Str(game.characterName)
            if not ns.isForever then info.realm = Str(game.realmName) end
        end
    end
    return Sources.Player(info)
end

--- A Battle.net friend by account id: BattleTag and character, never the real name.
function Sources.BattleNet(id)
    id = tonumber(id)
    if not id then return nil end
    if C_BattleNet and C_BattleNet.GetAccountInfoByID then
        local account = Call(C_BattleNet.GetAccountInfoByID, id)
        if type(account) == "table" then return Sources.Unit({ accountInfo = account }) end
    end
    if BNGetFriendInfoByID then
        local _, _, battleTag = Call(BNGetFriendInfoByID, id)
        return Sources.Player({ battleTag = battleTag })
    end
    return nil
end

--- A hyperlink the player clicked in chat, with the text it showed.
function Sources.Link(link, shown)
    link = Str(link)
    local kind, id, name, data = Text.ParseLink(link, Str(shown))
    if not kind then return nil end
    if kind == "player" then
        -- "player:Name-Realm:lineID:chatType"; the shown text is the name as the chat prints it.
        local field = data and data:match("^([^:]+)") or ""
        local base, realm = field:match("^(.-)%-([^%-]+)$")
        return Sources.Player({ full = name or base or field, realm = realm, isPlayer = true })
    elseif kind == "BNplayer" then
        -- "BNplayer:<protected name>:bnetAccountID:lineID:..."
        return Sources.BattleNet(link:match("BNplayer:[^:]*:(%d+)"))
    end
    name = name or link
    local source = { kind = "link", title = L.SRC_LINK:format(name), variants = {} }
    source.variants[1] = Variant(L.VARIANT_NAME, Static(name))
    AddId(source, kind, id)
    AddWowhead(source, kind, id)
    return source
end

--- A web address from the chat.
function Sources.Url(url)
    url = Str(url)
    if not url then return nil end
    return { kind = "url", title = L.SRC_URL, hint = L.LINK_COPY_HINT, variants = { Variant(L.VARIANT_LINK, Static(url)) } }
end

--- What the player most likely means: the tooltip under the mouse, else an open window, else
--- the chat.
function Sources.Smart()
    local source = Sources.Tooltip(GameTooltip)
    if source then return source end
    source = Sources.Tooltip(ItemRefTooltip)
    if source then return source end
    source = Sources.ItemText() or Sources.Quest() or Sources.Gossip() or Sources.Mail() or Sources.Macro()
    if source then return source end
    if ns.FrameVisible("CommunitiesFrame") or ns.FrameVisible("GuildFrame") then
        source = Sources.Guild()
        if source then return source end
    end
    if ns.FrameVisible("QuestMapFrame.DetailsFrame") or ns.FrameVisible("QuestLogFrame") then
        source = Sources.QuestLog()
        if source then return source end
    end
    return Sources.Chat()
end

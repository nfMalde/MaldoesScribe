local ns = __NS
local failures = 0
local lastErrors = 0

local function check(name, condition, detail)
    if condition then
        print("ok   " .. name)
    else
        failures = failures + 1
        print("FAIL " .. name .. (detail and (": " .. tostring(detail)) or ""))
    end
end

local function eq(name, got, want)
    check(name, got == want, ("got %s, want %s"):format(("%q"):format(tostring(got)), ("%q"):format(tostring(want))))
end

local function noErrors(step)
    local count = ns.ErrorCount()
    if count > lastErrors then
        failures = failures + 1
        print("FAIL errors after " .. step)
        print(ns.BuildReport())
        lastErrors = count
    else
        print("ok   no errors after " .. step)
    end
end

-- Load ------------------------------------------------------------------------
FireEvent("ADDON_LOADED", "MaldoesScribe")
noErrors("ADDON_LOADED")
check("db created", type(ns.db) == "table")
eq("language de", ns.uiLang, "de")
eq("L lookup de", ns.L.BTN_CLOSE, "Schließen")
eq("binding name", BINDING_NAME_MALDOESSCRIBE_CHAT, "Chat kopieren")
FireEvent("PLAYER_ENTERING_WORLD")
RunTimers()
noErrors("PLAYER_ENTERING_WORLD")

-- Text ------------------------------------------------------------------------
local T = ns.Text
eq("clean link", T.Clean("|cff1eff00|Hitem:123::::::::60:::::|h[Schwert]|h|r gefunden"), "[Schwert] gefunden")
eq("clean texture", T.Clean("|TInterface\\Icons\\X:16|t Hallo"), " Hallo")
eq("clean plural", T.Clean("3 |4day:days;, 1 |4hour:hours;"), "3 days, 1 hour")
eq("clean bnet", T.Clean("|K1234|k: hi"), "[Battle.net-Freund]: hi")
eq("clean pipe", T.Clean("a||b"), "a|b")
eq("clean named colour", T.Clean("|cnNORMAL_FONT_COLOR:x|r"), "x")
eq("clean atlas", T.Clean("|A:atlas:16:16|a X"), " X")
eq("clean newline", T.Clean("a|nb"), "a\nb")
eq("timestamp brackets", T.StripTimestamp("[12:34] Hallo"), "Hallo")
eq("timestamp seconds", T.StripTimestamp("12:34:56 Hallo"), "Hallo")
eq("timestamp pm", T.StripTimestamp("3:45 PM Hallo"), "Hallo")
eq("timestamp none", T.StripTimestamp("Hallo 12:34"), "Hallo 12:34")
eq("html", T.StripHtml("<HTML><BODY><P>Erste Zeile<BR/>Zweite</P><P>Absatz</P></BODY></HTML>"), "Erste Zeile\nZweite\n\nAbsatz")
eq("html plain", T.StripHtml("Nur Text"), "Nur Text")
local url, lead, trail = T.FindUrl("(https://example.com/x),")
eq("url scheme", url, "https://example.com/x")
eq("url lead", lead, "(")
eq("url trail", trail, "),")
eq("url www", (T.FindUrl("www.test.de")), "www.test.de")
eq("url bare", (T.FindUrl("youtube.com/watch?v=1")), "youtube.com/watch?v=1")
eq("url discord", (T.FindUrl("discord.gg/abc")), "discord.gg/abc")
eq("url port", (T.FindUrl("server.de:8080")), "server.de:8080")
eq("url not e.g", T.FindUrl("e.g"), nil)
eq("url not exe", T.FindUrl("foo.exe"), nil)
eq("url not link", T.FindUrl("|Hitem:1|h[x.com]|h"), nil)
eq("url not word", T.FindUrl("Hallo."), nil)
eq("url not dots", T.FindUrl("a..com"), nil)
local kind, id, name = T.ParseLink("|cffff8000|Hitem:19019::::::::60:::::|h[Thunderfury]|h|r")
eq("link kind", kind, "item")
eq("link id", id, 19019)
eq("link name", name, "Thunderfury")
kind, id, name = T.ParseLink("quest:123:60", "[Die Quest]")
eq("quest kind", kind, "quest")
eq("quest id", id, 123)
eq("quest name", name, "Die Quest")
kind, id, name = T.ParseLink("player:Name-Realm:12", "[Name]")
eq("player kind", kind, "player")
eq("player id", id, nil)
eq("player name", name, "Name")
eq("npc id", T.NpcID("Creature-0-4234-0-3-14645-00001E2F5A"), 14645)
eq("npc id player", T.NpcID("Player-1-000ABC"), nil)
eq("wowhead", T.Wowhead("item", 19019), "https://www.wowhead.com/classic/item=19019")
eq("wowhead unknown", T.Wowhead("player", 1), nil)
ns.db.wowhead = ""
eq("wowhead off", T.Wowhead("item", 1), nil)
ns.db.wowhead = "https://www.wowhead.com/classic"
eq("wowhead no slash", T.Wowhead("item", 1), "https://www.wowhead.com/classic/item=1")
ns.db.wowhead = "https://www.wowhead.com/classic/"

-- Chat ------------------------------------------------------------------------
local messages = {
    "|cffffffff[12:00] |r|Hplayer:Bob|h[Bob]|h: hallo |cff1eff00|Hitem:5:0|h[Dolch]|h|r",
    SECRET,
    "|TInterface\\x|t System: 3 |4day:days;",
}
rawset(ChatFrame1, "GetNumMessages", function() return #messages end)
rawset(ChatFrame1, "GetMessageInfo", function(_, index) return messages[index], 1, 1, 1, 1 end)
local source = ns.Sources.Chat()
local text = source.variants[1].build()
eq("chat text", text, "[12:00] [Bob]: hallo [Dolch]\nSystem: 3 days")
eq("chat note", source.note, "1 Zeilen sind vom Spiel geschützt und wurden ausgelassen.")
ns.db.chatStripTimestamps = true
eq("chat no timestamps", source.variants[1].build(), "[Bob]: hallo [Dolch]\nSystem: 3 days")
ns.db.chatStripTimestamps = false
ns.db.chatMaxLines = 1
eq("chat max lines", source.variants[1].build(), "System: 3 days")
ns.db.chatMaxLines = 500
ns.UI:Open(source)
noErrors("UI open chat")
eq("box text", ns.UI.box:GetText(), text)
check("window shown", ns.UI:IsShown())
eq("subtitle", ns.UI.subtitle:GetText(), "Chat: Allgemein")
eq("note shown", ns.UI.note:GetText(), "1 Zeilen sind vom Spiel geschützt und wurden ausgelassen.")
SlashCmdList.MALDOESSCRIBE("")
check("slash toggles off", not ns.UI:IsShown())
SlashCmdList.MALDOESSCRIBE("chat 1")
check("slash chat opens", ns.UI:IsShown())
noErrors("slash chat")

-- Quests ----------------------------------------------------------------------
QuestFrame:Show()
QuestFrameDetailPanel:Show()
source = ns.Sources.Quest()
check("quest source", source ~= nil)
text = source.variants[1].build()
eq("quest text", text, "Die große Quest\n\nText der Quest mit Farbe.\n\nZiele\nTöte 10 Eber.\n\nBelohnungen\nDu erhältst Gold.")
eq("quest variants", #source.variants, 4)
eq("quest id variant", source.variants[3].build(), "quest:123")
eq("quest wowhead", source.variants[4].build(), "https://www.wowhead.com/classic/quest=123")
QuestFrameDetailPanel:Hide()
QuestFrameGreetingPanel:Show()
source = ns.Sources.Quest()
eq("greeting text", source.variants[1].build(), "Questgeber\n\nWillkommen.\n\nVerfügbare Quests\n- Die große Quest")
eq("greeting npc name", source.variants[2].build(), "Questgeber")
eq("greeting wowhead", source.variants[3].build(), "https://www.wowhead.com/classic/npc=14645")
QuestFrameGreetingPanel:Hide()
QuestFrame:Hide()
SlashCmdList.MALDOESSCRIBE("quest")
eq("questlog title", ns.UI.subtitle:GetText(), "Quest: Logquest")
eq("questlog text", ns.UI.box:GetText(), "Logquest\n\nBeschreibung\n\nZiele\n[x] Eber getötet: 10/10")
noErrors("quest")

-- Gossip, book, guild ---------------------------------------------------------
GossipFrame:Show()
SlashCmdList.MALDOESSCRIBE("gossip")
eq("gossip text", ns.UI.box:GetText(), "Questgeber\n\nSeid gegrüßt, Reisender.\n\nOptionen\n- Ich möchte handeln.\n\nVerfügbare Quests\n- Die große Quest")
eq("gossip npc name", ns.UI.source.variants[2].build(), "Questgeber")
eq("gossip npc wowhead", ns.UI.source.variants[3].build(), "https://www.wowhead.com/classic/npc=14645")
GossipFrame:Hide()
SlashCmdList.MALDOESSCRIBE("gossip")
check("gossip closed keeps window", ns.UI:IsShown())
ItemTextFrame:Show()
SlashCmdList.MALDOESSCRIBE("book")
eq("book text", ns.UI.box:GetText(), "Altes Buch\n\nErste Zeile\nZweite\n\nAbsatz")
ItemTextFrame:Hide()
SlashCmdList.MALDOESSCRIBE("guild")
check("roster requested", ROSTER_REQUESTED == true)
eq("guild info", ns.UI.box:GetText(), "Testgilde\n\nNachricht des Tages\nRaid um 20 Uhr\n\nGildeninformation\nInfotext grün")
ns.UI.variantIndex = 2
ns.UI:Refresh()
eq("guild motd", ns.UI.box:GetText(), "Raid um 20 Uhr")
ns.UI.variantIndex = 3
ns.UI:Refresh()
eq("guild roster", ns.UI.box:GetText(), "Name\tRang\tStufe\tKlasse\tZone\tNotiz\tOffiziersnotiz\tStatus\nAlice\tOffizier\t60\tMagier\tOrgrimmar\tnotiz\t\tonline\nBob\tMitglied\t30\tKrieger\tDurotar\t\toffi\toffline")
eq("guild roster note", ns.UI.note:GetText(), "2 Mitglieder")
noErrors("gossip book guild")

-- Tooltips --------------------------------------------------------------------
GameTooltip:Show()
GameTooltip.__lines = { 1, 2 }
GameTooltipTextLeft1 = CreateFrame("FontString"); GameTooltipTextLeft1:SetText("|cffff8000Thunderfury|r")
GameTooltipTextLeft2 = CreateFrame("FontString"); GameTooltipTextLeft2:SetText("Legendär")
GameTooltipTextRight2 = CreateFrame("FontString"); GameTooltipTextRight2:SetText("Schwert")
MaldoesScribe_CopyTooltip()
eq("tooltip title", ns.UI.subtitle:GetText(), "Tooltip: Thunderfury")
eq("tooltip name", ns.UI.box:GetText(), "Thunderfury")
ns.UI.variantIndex = 2
ns.UI:Refresh()
eq("tooltip lines", ns.UI.box:GetText(), "Thunderfury\nLegendär    Schwert")
eq("tooltip id", ns.UI.source.variants[3].build(), "item:19019")
eq("tooltip wowhead", ns.UI.source.variants[4].build(), "https://www.wowhead.com/classic/item=19019")
MaldoesScribe_CopySmart()
eq("smart picks tooltip", ns.UI.subtitle:GetText(), "Tooltip: Thunderfury")
rawset(GameTooltip, "AddLine", function(self, line) self.__added = line end)
RunTooltipPostCalls(GameTooltip)
eq("tooltip hint without key", GameTooltip.__added, nil)
BINDINGS.MALDOESSCRIBE_TOOLTIP = "F9"
RunTooltipPostCalls(GameTooltip)
eq("tooltip hint", GameTooltip.__added, "F9: kopieren")
GameTooltip:Hide()
MaldoesScribe_CopyTooltip()
noErrors("tooltip")

-- Links in chat ---------------------------------------------------------------
local filter = FILTERS.CHAT_MSG_SAY[1]
local blocked, modified = filter(nil, "CHAT_MSG_SAY", "schau https://example.com/x und (www.test.de), ok", "Bob")
eq("filter not blocked", blocked, false)
eq("filter result", modified, "schau |cffffa463|Hmscurl:1|hhttps://example.com/x|h|r und (|cffffa463|Hmscurl:2|hwww.test.de|h|r), ok")
check("filter passthrough", filter(nil, "CHAT_MSG_SAY", "nichts hier", "Bob") == nil)
check("filter secret", filter(nil, "CHAT_MSG_SAY", SECRET, "Bob") == nil)
ns.db.chatUrls = false
check("filter off", filter(nil, "CHAT_MSG_SAY", "www.test.de", "Bob") == nil)
ns.db.chatUrls = true
SetItemRef("mscurl:2", "www.test.de", "LeftButton")
eq("url window", ns.UI.box:GetText(), "www.test.de")
eq("url hint", ns.UI.hint:GetText(), ns.L.LINK_COPY_HINT)
local itemLink = "|cffff8000|Hitem:19019::::::::60:::::|h[Thunderfury]|h|r"
ns.UI:Hide()
SetItemRef(itemLink, itemLink, "LeftButton")
check("plain click does nothing", not ns.UI:IsShown())
SetKey("ALT", true)
SetItemRef(itemLink, itemLink, "LeftButton")
eq("alt click link", ns.UI.box:GetText(), "Thunderfury")
eq("alt click variants", #ns.UI.source.variants, 3)
SetKey("ALT", false)
ItemRefTooltip:SetHyperlink("mscurl:1")
noErrors("links")

-- Buttons beside windows ------------------------------------------------------
check("pill on quest frame", ns.BuildReport():find("pill added: QuestFrameDetailPanel", 1, true) ~= nil)
check("pill on link tooltip", ns.BuildReport():find("pill added: ItemRefTooltip", 1, true) ~= nil)
CommunitiesFrame = CreateFrame("Frame", "CommunitiesFrame")
RunTimers()
check("pill added later", ns.BuildReport():find("pill added: CommunitiesFrame", 1, true) ~= nil)
local gossipPill = ns.Buttons.pills[GossipFrame]
check("gossip pill exists", gossipPill ~= nil)
check("gossip pill on UIParent", gossipPill:GetParent() == UIParent)
check("pill hidden while window hidden", not gossipPill:IsShown())
GossipFrame:Show()
GossipFrame:Fire("OnShow")
check("pill shown by OnShow", gossipPill:IsShown())
GossipFrame:Hide()
RunTimers()
check("pill hidden by ticker", not gossipPill:IsShown())
GossipFrame:Show()
RunTimers()
check("pill shown by ticker", gossipPill:IsShown())
gossipPill:Fire("OnClick")
eq("pill click opens", ns.UI.subtitle:GetText(), "Dialog: Questgeber")
GossipFrame:Hide()
GossipFrame:Fire("OnHide")
check("pill hidden by OnHide", not gossipPill:IsShown())
ns.db.contextButtons = false
ns.Buttons:ApplyPills()
ns.db.contextButtons = true
ns.Buttons:ApplyPills()
SlashCmdList.MALDOESSCRIBE("mouse")
RunTimers()
ChatFrame1:Fire("OnEnter")
ChatFrame1:Fire("OnLeave")
RunTimers()
ns.db.chatButtonHover = false
ns.Buttons:ApplyChatButtons()
noErrors("buttons")

-- Options ---------------------------------------------------------------------
local panel = ns.settingsCategory.panel
panel:Fire("OnShow")
noErrors("options build")
ns.db.language = "en"
ns.ApplyLanguage()
ns.UI:Relabel()
ns.Buttons:ApplyPills()
eq("english", ns.L.BTN_CLOSE, "Close")
eq("binding name en", BINDING_NAME_MALDOESSCRIBE_CHAT, "Copy the chat")
noErrors("language switch")

-- Names: right-click menus and chat links -----------------------------------
local root = { buttons = {} }
function root:CreateDivider() self.dividers = (self.dividers or 0) + 1 end
function root:CreateButton(label, callback) self.buttons[#self.buttons + 1] = { label = label, callback = callback } end
check("menus registered", MENUS.MENU_UNIT_FRIEND ~= nil and MENUS.MENU_UNIT_SELF ~= nil)
check("forever detected", ns.isForever == true)
-- A name from chat: the game's menu hands over name and server (the realm).
MENUS.MENU_UNIT_FRIEND(nil, root, { name = "Bob Baumeister", server = "Forever" })
eq("menu entry", root.buttons[1] and root.buttons[1].label, "Copy name")
root.buttons[1].callback()
eq("menu name", ns.UI.box:GetText(), "Bob Baumeister")
eq("menu title", ns.UI.subtitle:GetText(), "Player: Bob Baumeister")
eq("menu first name", ns.UI.source.variants[2].build(), "Bob")
eq("menu last name", ns.UI.source.variants[3].build(), "Baumeister")
eq("menu no realm variant on forever", #ns.UI.source.variants, 3)
-- The surname in the server field (Forever's menus may do that).
root.buttons = {}
MENUS.MENU_UNIT_FRIEND(nil, root, { name = "Bob", server = "Baumeister" })
root.buttons[1].callback()
eq("menu surname from server", ns.UI.box:GetText(), "Bob Baumeister")
-- An NPC target: the name and the Wowhead page, no name parts.
root.buttons = {}
MENUS.MENU_UNIT_TARGET(nil, root, { unit = "target" })
root.buttons[1].callback()
eq("menu npc name", ns.UI.box:GetText(), "Grubenlord")
eq("menu npc title", ns.UI.subtitle:GetText(), "NPC: Grubenlord")
eq("menu npc wowhead", ns.UI.source.variants[2].build(), "https://www.wowhead.com/classic/npc=14645")
eq("menu npc variants", #ns.UI.source.variants, 2)
-- The own portrait: UnitName gives first name and surname.
root.buttons = {}
MENUS.MENU_UNIT_SELF(nil, root, { unit = "player" })
root.buttons[1].callback()
eq("menu own name", ns.UI.box:GetText(), "Maldö Thousandkegs")
eq("menu own first", ns.UI.source.variants[2].build(), "Maldö")
eq("menu own last", ns.UI.source.variants[3].build(), "Thousandkegs")
-- A unit whose first value already carries the surname.
root.buttons = {}
MENUS.MENU_UNIT_PARTY(nil, root, { unit = "party1" })
root.buttons[1].callback()
eq("menu party name not doubled", ns.UI.box:GetText(), "Bob Baumeister")
eq("menu party first", ns.UI.source.variants[2].build(), "Bob")
-- Battle.net friends: character and BattleTag, never the protected name.
root.buttons = {}
MENUS.MENU_UNIT_BN_FRIEND(nil, root, { accountInfo = { accountName = "|Kq1|k", battleTag = "Bob#1234", gameAccountInfo = { characterName = "Bobchar Baumeister", realmName = "Forever" } } })
root.buttons[1].callback()
eq("menu bnet character", ns.UI.box:GetText(), "Bobchar Baumeister")
eq("menu bnet first", ns.UI.source.variants[2].build(), "Bobchar")
eq("menu bnet tag", ns.UI.source.variants[4].build(), "Bob#1234")
root.buttons = {}
MENUS.MENU_UNIT_BN_FRIEND(nil, root, { accountInfo = { accountName = "|Kq1|k" } })
eq("menu bnet nothing to copy", #root.buttons, 0)
ns.db.menuEntry = false
MENUS.MENU_UNIT_FRIEND(nil, root, { name = "Bob" })
eq("menu entry off", #root.buttons, 0)
ns.db.menuEntry = true
-- Names in chat: the shown text is the full name.
local playerSource = ns.Sources.Link("player:Alice-Forever:12:SAY", "[Alice Alder]")
eq("chat player name", playerSource.variants[1].build(), "Alice Alder")
eq("chat player first", playerSource.variants[2].build(), "Alice")
eq("chat player last", playerSource.variants[3].build(), "Alder")
local bnSource = ns.Sources.Link("BNplayer:|Kq1|k:58:837:BN_WHISPER:|Kq1|k", "[|Kq1|k]")
eq("chat bnet tag", bnSource and bnSource.variants[2].build(), "Bob#1234")
eq("chat bnet title", bnSource and bnSource.title, "Player: Bobchar")
-- NPC dialogue titles use the full display name too.
eq("npc display name", ns.UnitDisplayName("npc"), "Questgeber")
-- Other clients: no surnames, "Name-Realm" instead.
ns.isForever = false
local retail = ns.Sources.Player({ full = "Alice-Forever", isPlayer = true })
eq("retail name", retail.variants[1].build(), "Alice")
eq("retail name-realm", retail.variants[2].build(), "Alice-Forever")
retail = ns.Sources.Unit({ name = "Bob", server = "Forever" })
eq("retail menu name-realm", retail.variants[2].build(), "Bob-Forever")
ns.isForever = true
noErrors("names")

-- Mail, macro, group ------------------------------------------------------------
MailFrame:Show()
OpenMailFrame:Show()
SlashCmdList.MALDOESSCRIBE("mail")
eq("mail title", ns.UI.subtitle:GetText(), "Mail: Dein Erz")
eq("mail text", ns.UI.box:GetText(), "From: Bob Baumeister\nSubject: Dein Erz\n\nHier das Erz.\nGruß Bob\n\nCash on delivery: 5s 0c\nAttachments\n- Kupfererz x20")
ns.UI.variantIndex = 2
ns.UI:Refresh()
eq("mail body", ns.UI.box:GetText(), "Hier das Erz.\nGruß Bob")
ns.UI.variantIndex = 3
ns.UI:Refresh()
eq("mail inbox", ns.UI.box:GetText(), "Sender\tSubject\tMoney\tItems\tDays left\nAlice Alder\tHallo\t1g 23s 45c\t\t29.5\nBob Baumeister\tDein Erz\t\tx\t3.2")
eq("mail inbox note", ns.UI.note:GetText(), "2 mails")
OpenMailFrame:Hide()
SlashCmdList.MALDOESSCRIBE("mail")
eq("inbox title", ns.UI.subtitle:GetText(), "Inbox")
eq("inbox variants", #ns.UI.source.variants, 1)
SendMailFrame:Show()
SendMailSubjectEditBox = CreateFrame("EditBox"); SendMailSubjectEditBox:SetText("Betreff")
SendMailBodyEditBox = CreateFrame("EditBox"); SendMailBodyEditBox:SetText("Mein Entwurf")
SlashCmdList.MALDOESSCRIBE("mail")
eq("mail draft", ns.UI.source.variants[1].build(), "Subject: Betreff\n\nMein Entwurf")
SendMailFrame:Hide()
MailFrame:Hide()
check("mail pill above the mailbox", ns.Buttons.pills[MailFrame] ~= nil)
-- The mailbox open while another addon hides the mail window: the inbox is still there.
FireEvent("MAIL_SHOW")
SlashCmdList.MALDOESSCRIBE("mail")
eq("mail by event", ns.UI.subtitle:GetText(), "Inbox")
FireEvent("MAIL_CLOSED")
check("mailbox closed", ns.Sources.Mail() == nil)
MacroFrame:Show()
SlashCmdList.MALDOESSCRIBE("macro")
eq("macro title", ns.UI.subtitle:GetText(), "Macro: Trinken")
eq("macro text", ns.UI.box:GetText(), "/use Quellwasser\n/say Prost")
eq("macro name", ns.UI.source.variants[2].build(), "Trinken")
-- The modern macro window: a tab index that GetMacroDataIndex maps to the macro index.
MacroFrame.selectedMacro = nil
rawset(MacroFrame, "GetSelectedIndex", function() return 1 end)
rawset(MacroFrame, "GetMacroDataIndex", function(_, selected) return selected + 2 end)
SlashCmdList.MALDOESSCRIBE("macro")
eq("macro title by data index", ns.UI.subtitle:GetText(), "Macro: Trinken")
-- No index at all: the name from the window's label, the text from its edit box.
rawset(MacroFrame, "GetSelectedIndex", function() return nil end)
MacroFrameSelectedMacroName = CreateFrame("FontString"); MacroFrameSelectedMacroName:SetText("Prost")
MacroFrameText = CreateFrame("EditBox"); MacroFrameText:SetText("/say Prost")
SlashCmdList.MALDOESSCRIBE("macro")
eq("macro title from the label", ns.UI.subtitle:GetText(), "Macro: Prost")
eq("macro text from the box", ns.UI.box:GetText(), "/say Prost")
MacroFrame:Hide()
GROUPED = true
SlashCmdList.MALDOESSCRIBE("group")
eq("group names", ns.UI.box:GetText(), "Maldö Thousandkegs\nBob Baumeister")
eq("group note", ns.UI.note:GetText(), "2 members")
ns.UI.variantIndex = 2
ns.UI:Refresh()
eq("group table", ns.UI.box:GetText(), "Name\tLevel\tClass\nMaldö Thousandkegs\t37\tPriester\nBob Baumeister\t30\tKrieger")
GROUPED = false
noErrors("mail macro group")

-- Report, the rest of the commands -------------------------------------------
SlashCmdList.MALDOESSCRIBE("log")
check("report shown", ns.UI.box:GetText():find("### Maldö's Scribe report", 1, true) ~= nil)
eq("window title", ns.UI.title:GetText(), "Maldö's Scribe")
check("report lists neighbours", ns.UI.box:GetText():find("Other addons: EllesmereUIChat", 1, true) ~= nil)
SlashCmdList.MALDOESSCRIBE("reset")
SlashCmdList.MALDOESSCRIBE("help")
SlashCmdList.MALDOESSCRIBE("options")
eq("options opened", OPENED_CATEGORY, 7)
SlashCmdList.MALDOESSCRIBE("keys")
eq("keys opened", OPENED_CATEGORY, 99)
SlashCmdList.MALDOESSCRIBE("debug")
SlashCmdList.MALDOESSCRIBE("debug")
SlashCmdList.MALDOESSCRIBE("log clear")
eq("log cleared", ns.ErrorCount(), 0)
MaldoesScribe_OnAddonCompartmentClick(nil, "RightButton")
MaldoesScribe_OnAddonCompartmentClick(nil, "LeftButton")
MaldoesScribe_CopyChat()
noErrors("end")

TEST_FAILURES = failures
print(("\n%d failures"):format(failures))

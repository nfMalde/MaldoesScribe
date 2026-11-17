local _, ns = ...
local L = ns.L
local C = ns.colors

local Options = {}
ns.Options = Options

local LEFT = 16
local LABEL_WIDTH = 200
local CONTENT_WIDTH = 620
local TEXT_WIDTH = CONTENT_WIDTH - 2 * LEFT

-- Everything with a text, so a language change can relabel the page without a reload.
local texts = {}
local refreshers = {}

local function Text(parent, key, font, color)
    local fontString = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    fontString:SetJustifyH("LEFT")
    if color then fontString:SetTextColor(color[1], color[2], color[3]) end
    texts[#texts + 1] = { fontString = fontString, key = key }
    fontString:SetText(L[key])
    return fontString
end

local function Relabel()
    for _, entry in ipairs(texts) do
        if entry.fontString then
            entry.fontString:SetText(L[entry.key])
        else
            entry.button.label:SetText(L[entry.key])
        end
    end
    for _, refresh in ipairs(refreshers) do
        refresh()
    end
end

local function Button(parent, key, width)
    local button = ns.CreateFlatButton(parent, L[key], width, 22)
    button.solid = true
    button:Paint()
    texts[#texts + 1] = { button = button, key = key }
    return button
end

--- A row of buttons of which one is active (like the DE | EN switch in GT Toolz).
local function Segmented(parent, items, width, get, set)
    local group = ns.NewFrame("Frame", nil, parent)
    group:SetSize(#items * (width + 2), 22)
    local buttons = {}
    local function Refresh()
        local current = get()
        for _, button in ipairs(buttons) do
            button.selected = button.value == current
            button:Paint()
        end
    end
    for index, item in ipairs(items) do
        local button
        if item.key then
            button = Button(group, item.key, width)
        else
            button = ns.CreateFlatButton(group, item.text, width, 22)
            button.solid = true
        end
        button.value = item.value
        button:SetPoint("LEFT", (index - 1) * (width + 2), 0)
        button:SetScript("OnClick", function(self)
            set(self.value)
            Refresh()
        end)
        buttons[index] = button
    end
    refreshers[#refreshers + 1] = Refresh
    Refresh()
    return group
end

local function Checkbox(parent, key, get, set, width)
    local check = ns.NewFrame("Button", nil, parent)
    check:SetSize(width or 300, 20)

    local box = check:CreateTexture(nil, "BACKGROUND")
    box:SetSize(16, 16)
    box:SetPoint("LEFT")
    box:SetColorTexture(C.surface[1], C.surface[2], C.surface[3], 1)
    local mark = check:CreateTexture(nil, "ARTWORK")
    mark:SetSize(10, 10)
    mark:SetPoint("CENTER", box, "CENTER")
    mark:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)

    local label = Text(check, key, "GameFontHighlightSmall", C.text)
    label:SetPoint("LEFT", box, "RIGHT", 8, 0)
    label:SetPoint("RIGHT", check, "RIGHT", 0, 0)
    label:SetWordWrap(false)

    local function Refresh() mark:SetShown(get() and true or false) end
    check:SetScript("OnClick", function()
        set(not get())
        Refresh()
    end)
    refreshers[#refreshers + 1] = Refresh
    Refresh()
    return check
end

local function Slider(parent, minimum, maximum, step, get, set, format)
    local slider = ns.NewFrame("Slider", nil, parent)
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(200, 16)
    slider:EnableMouse(true)
    slider:SetMinMaxValues(minimum, maximum)
    slider:SetValueStep(step)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end

    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    track:SetHeight(4)
    track:SetColorTexture(C.surfaceHover[1], C.surfaceHover[2], C.surfaceHover[3], 1)

    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(10, 16)
    thumb:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
    slider:SetThumbTexture(thumb)

    local value = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    value:SetPoint("LEFT", slider, "RIGHT", 10, 0)
    value:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])

    slider:SetValue(get())
    value:SetText(format(get()))
    slider:SetScript("OnValueChanged", function(_, raw)
        local rounded = math.floor(raw / step + 0.5) * step
        set(rounded)
        value:SetText(format(rounded))
    end)
    return slider
end

local function Input(parent, width, maxLetters)
    local box = ns.NewFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetAutoFocus(false)
    box:SetSize(width, 20)
    box:SetMaxLetters(maxLetters)
    box:SetScript("OnEscapePressed", box.ClearFocus)
    box:SetScript("OnEnterPressed", box.ClearFocus)
    return box
end

local function Percent(value)
    return string.format("%d%%", math.floor(value * 100 + 0.5))
end

local function Whole(value)
    return tostring(math.floor(value + 0.5))
end

--- Builds the page the first time it is shown.
local function Build(panel)
    local db = ns.db
    local y = -16

    local icon = panel:CreateTexture(nil, "ARTWORK")
    icon:SetSize(36, 36)
    icon:SetPoint("TOPLEFT", LEFT, y)
    icon:SetTexture(ns.mediaPath .. "scribe-icon")

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -2)
    title:SetText("|cffffa463Maldö's|r Scribe")

    local subtitle = Text(panel, "OPT_SUBTITLE", "GameFontHighlightSmall", C.textDim)
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetWidth(TEXT_WIDTH - 46)
    subtitle:SetWordWrap(true)
    y = y - 64

    local function Section(key)
        local header = Text(panel, key, "GameFontNormal", C.accentText)
        header:SetPoint("TOPLEFT", LEFT, y)
        y = y - 20
    end

    local function Row(key, control, height)
        local label = Text(panel, key, "GameFontHighlightSmall", C.text)
        label:SetPoint("TOPLEFT", LEFT, y - 4)
        label:SetWidth(LABEL_WIDTH)
        control:SetPoint("TOPLEFT", LEFT + LABEL_WIDTH, y)
        y = y - (height or 26)
    end

    local function Check(key, get, set, width)
        local check = Checkbox(panel, key, get, set, width or TEXT_WIDTH)
        check:SetPoint("TOPLEFT", LEFT, y)
        y = y - 24
        return check
    end

    local function Hint(key)
        local hint = Text(panel, key, "GameFontHighlightSmall", C.textDim)
        hint:SetPoint("TOPLEFT", LEFT, y)
        hint:SetWidth(TEXT_WIDTH)
        hint:SetWordWrap(true)
        hint:SetText(L[key])
        y = y - math.max(14, hint:GetStringHeight() + 6)
        return hint
    end

    -- Language
    Section("OPT_LANGUAGE")
    Row("OPT_UI_LANGUAGE", Segmented(panel, {
        { key = "OPT_AUTO", value = "auto" },
        { text = "English", value = "en" },
        { text = "Deutsch", value = "de" },
    }, 110, function() return db.language end, function(value)
        db.language = value
        ns.ApplyLanguage()
        Relabel()
        ns.UI:Relabel()
        if ns.UI:IsShown() then ns.UI:Refresh() end
        ns.Buttons:ApplyPills()
    end))
    y = y - 8

    -- Copy window
    Section("OPT_WINDOW")
    Row("OPT_OPACITY", Slider(panel, 0.3, 1, 0.05, function() return db.opacity end, function(value)
        db.opacity = value
        ns.UI:ApplyStyle()
    end, Percent))
    Row("OPT_SCALE", Slider(panel, 0.7, 1.5, 0.05, function() return db.scale end, function(value)
        db.scale = value
        ns.UI:ApplyStyle()
    end, Percent))
    Row("OPT_FONT_SIZE", Slider(panel, 10, 20, 1, function() return db.fontSize end, function(value)
        db.fontSize = value
        ns.UI:ApplyStyle()
    end, Whole))
    local resetPosition = Button(panel, "OPT_RESET_POS", 200)
    resetPosition:SetPoint("TOPLEFT", LEFT, y)
    resetPosition:SetScript("OnClick", function()
        ns.UI:ResetPosition()
        ns.Print(L.POSITION_RESET)
    end)
    local openWindow = Button(panel, "OPT_OPEN_WINDOW", 160)
    openWindow:SetPoint("LEFT", resetPosition, "RIGHT", 8, 0)
    openWindow:SetScript("OnClick", function()
        ns.Copy(ns.Sources.Chat(), L.CHAT_EMPTY)
    end)
    y = y - 34

    -- Chat
    Section("OPT_CHAT")
    Check("OPT_CHAT_BUTTON", function() return db.chatButton end, function(value)
        db.chatButton = value
        ns.Buttons:ApplyChatButtons()
    end)
    Check("OPT_CHAT_BUTTON_HOVER", function() return db.chatButtonHover end, function(value)
        db.chatButtonHover = value
        ns.Buttons:ApplyChatButtons()
    end)
    Row("OPT_CHAT_CORNER", Segmented(panel, {
        { key = "OPT_CORNER_TOPRIGHT", value = "TOPRIGHT" },
        { key = "OPT_CORNER_BOTTOMRIGHT", value = "BOTTOMRIGHT" },
    }, 130, function() return db.chatButtonCorner end, function(value)
        db.chatButtonCorner = value
        ns.Buttons:ApplyChatButtons()
    end), 30)
    Check("OPT_CHAT_TIMESTAMPS", function() return db.chatStripTimestamps end, function(value)
        db.chatStripTimestamps = value
    end)
    Check("OPT_CHAT_URLS", function() return db.chatUrls end, function(value)
        db.chatUrls = value
    end)
    Hint("OPT_CHAT_URLS_HINT")
    Row("OPT_CHAT_MAX_LINES", Slider(panel, 50, 2000, 50, function() return db.chatMaxLines end, function(value)
        db.chatMaxLines = value
    end, Whole))
    y = y - 8

    -- Buttons beside windows
    Section("OPT_WINDOWS")
    Check("OPT_CONTEXT_BUTTONS", function() return db.contextButtons end, function(value)
        db.contextButtons = value
        ns.Buttons:ApplyPills()
    end)
    y = y - 8

    -- Tooltips and links
    Section("OPT_LINKS")
    Check("OPT_MENU_ENTRY", function() return db.menuEntry end, function(value)
        db.menuEntry = value
    end)
    Check("OPT_TOOLTIP_HINT", function() return db.tooltipHint end, function(value)
        db.tooltipHint = value
    end)
    Row("OPT_LINK_MODIFIER", Segmented(panel, {
        { key = "OPT_MOD_ALT", value = "ALT" },
        { key = "OPT_MOD_CTRL", value = "CTRL" },
        { key = "OPT_MOD_SHIFT", value = "SHIFT" },
        { key = "OPT_MOD_OFF", value = "NONE" },
    }, 96, function() return db.linkModifier end, function(value)
        db.linkModifier = value
    end), 30)
    Hint("OPT_LINK_MODIFIER_HINT")
    local keys = Button(panel, "OPT_KEYBINDINGS", 200)
    keys:SetPoint("TOPLEFT", LEFT, y)
    keys:SetScript("OnClick", function() ns.OpenKeyBindings() end)
    y = y - 28
    Hint("OPT_KEYBINDINGS_HINT")

    local wowhead = Input(panel, 380, 200)
    wowhead:SetText(db.wowhead or "")
    wowhead:SetScript("OnTextChanged", function(self, userInput)
        if userInput then db.wowhead = ns.Trim(self:GetText()) end
    end)
    Row("OPT_WOWHEAD", wowhead)
    wowhead:SetPoint("TOPLEFT", LEFT + LABEL_WIDTH + 6, y + 26)
    Hint("OPT_WOWHEAD_HINT")
    y = y - 8

    -- Troubleshooting
    Section("OPT_DIAGNOSE")
    local debug = Checkbox(panel, "OPT_DEBUG", function() return db.debug end, function(value) ns.SetDebug(value) end)
    debug:SetPoint("TOPLEFT", LEFT, y)
    local showLog = Button(panel, "OPT_SHOW_LOG", 150)
    showLog:SetPoint("TOPLEFT", LEFT + 330, y)
    showLog:SetScript("OnClick", function() ns.ShowReport() end)
    y = y - 34

    -- Support
    Section("OPT_SUPPORT")
    Hint("OPT_SUPPORT_HINT")
    local linkBar = ns.CreateLinkBar(panel, "medium")
    linkBar:SetPoint("TOPLEFT", LEFT, y)
    y = y - 24
    refreshers[#refreshers + 1] = function() linkBar:Relabel() end

    panel:SetHeight(-y + 24)
end

function Options:Register()
    local panel = ns.NewFrame("Frame")
    panel.name = "Maldö's Scribe"
    -- The settings window calls these on some client versions; everything here saves at once.
    panel.OnCommit = function() end
    panel.OnDefault = function() end
    panel.OnRefresh = function() end
    panel:Hide()

    local built = false
    panel:SetScript("OnShow", function(self)
        if built then return end
        built = true
        -- The page is taller than the settings window, so it scrolls.
        local scroll = ns.CreateScrollBox(self)
        scroll:SetPoint("TOPLEFT", 0, -4)
        scroll:SetPoint("BOTTOMRIGHT", -14, 4)
        local content = ns.NewFrame("Frame", nil, scroll)
        content:SetSize(CONTENT_WIDTH, 900)
        scroll:SetScrollChild(content)
        Build(content)
    end)

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        ns.settingsCategory = category
    end
end

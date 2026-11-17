local _, ns = ...
local L = ns.L
local C = ns.colors

local UI = {}
ns.UI = UI

local PAD = 10
local HEADER_HEIGHT = 30
local VARIANT_HEIGHT = 20
local BUTTON_HEIGHT = 22
local FOOTER_HEIGHT = 62 -- the button row and the link bar row
local SLIDER_WIDTH = 6
local MIN_WIDTH, MIN_HEIGHT = 340, 200

-- ---------------------------------------------------------------------------
-- Building blocks (also used by the options and the buttons beside windows)
-- ---------------------------------------------------------------------------

--- How opaque the buttons are: a little more than the window, so they stay readable.
local function FillAlpha()
    local opacity = ns.db and ns.db.opacity or 0.95
    return math.min(1, opacity + 0.3)
end

function ns.AddBorder(frame)
    local border = {}
    for index = 1, 4 do
        border[index] = frame:CreateTexture(nil, "BORDER")
    end
    border[1]:SetPoint("TOPLEFT")
    border[1]:SetPoint("TOPRIGHT")
    border[1]:SetHeight(1)
    border[2]:SetPoint("BOTTOMLEFT")
    border[2]:SetPoint("BOTTOMRIGHT")
    border[2]:SetHeight(1)
    border[3]:SetPoint("TOPLEFT")
    border[3]:SetPoint("BOTTOMLEFT")
    border[3]:SetWidth(1)
    border[4]:SetPoint("TOPRIGHT")
    border[4]:SetPoint("BOTTOMRIGHT")
    border[4]:SetWidth(1)

    function border:SetColor(r, g, b, a)
        for index = 1, 4 do
            self[index]:SetColorTexture(r, g, b, a or 1)
        end
    end
    border:SetColor(unpack(C.border))
    return border
end

local function PaintButton(self)
    local alpha = self.solid and 1 or FillAlpha()
    if self.selected then
        self.bg:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.95)
        self.label:SetTextColor(unpack(C.onAccent))
        if self.border then self.border:SetColor(C.accent[1], C.accent[2], C.accent[3], 1) end
    elseif self.hover then
        self.bg:SetColorTexture(C.surfaceHover[1], C.surfaceHover[2], C.surfaceHover[3], math.max(alpha, 0.9))
        self.label:SetTextColor(1, 1, 1)
        if self.border then self.border:SetColor(unpack(C.border)) end
    else
        local color = self.textColor or C.text
        self.bg:SetColorTexture(C.surface[1], C.surface[2], C.surface[3], self.ghost and 0 or alpha)
        self.label:SetTextColor(color[1], color[2], color[3])
        if self.border then self.border:SetColor(unpack(C.border)) end
    end
end

--[[
A flat button. Fields the caller may set before Paint():
  selected   amber fill
  textColor  colour of the label
  ghost      no fill and no border until hovered
  solid      ignore the window opacity (for the options)
  tooltip    text shown on hover
]]
function ns.CreateFlatButton(parent, text, width, height, ghost)
    local button = ns.NewFrame("Button", nil, parent)
    button:SetSize(width, height)
    button.ghost = ghost

    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetAllPoints()
    if not ghost then button.border = ns.AddBorder(button) end

    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.label:SetPoint("LEFT", 4, 0)
    button.label:SetPoint("RIGHT", -4, 0)
    button.label:SetJustifyH("CENTER")
    button.label:SetWordWrap(false)
    button.label:SetText(text or "")

    button.Paint = PaintButton
    button:SetScript("OnEnter", function(self)
        self.hover = true
        self:Paint()
        if self.tooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(self.tooltip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    button:SetScript("OnLeave", function(self)
        self.hover = false
        self:Paint()
        GameTooltip:Hide()
    end)
    button:Paint()
    return button
end

--[[
A scroll area with a thin amber scroll bar on its right. Anchor the returned frame and put the
content in scroll:SetScrollChild(child); the mouse wheel scrolls it. The bar is only shown when
the content is taller than the area.
]]
function ns.CreateScrollBox(parent)
    local scroll = ns.NewFrame("ScrollFrame", nil, parent)
    scroll:EnableMouseWheel(true)

    local slider = ns.NewFrame("Slider", nil, parent)
    slider:SetOrientation("VERTICAL")
    slider:SetWidth(SLIDER_WIDTH)
    slider:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 4, 0)
    slider:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 4, 0)
    slider:SetMinMaxValues(0, 0)
    slider:SetValueStep(1)
    slider:SetValue(0)
    slider:EnableMouse(true)
    slider:Hide()

    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(C.surface[1], C.surface[2], C.surface[3], 1)

    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(SLIDER_WIDTH, 36)
    thumb:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.9)
    slider:SetThumbTexture(thumb)

    slider:SetScript("OnValueChanged", function(_, value)
        scroll:SetVerticalScroll(value)
    end)
    scroll:SetScript("OnScrollRangeChanged", function(_, _, yRange)
        yRange = math.max(0, math.floor((yRange or 0) + 0.5))
        slider:SetMinMaxValues(0, yRange)
        slider:SetShown(yRange > 0)
        if slider:GetValue() > yRange then slider:SetValue(yRange) end
    end)
    scroll:SetScript("OnMouseWheel", function(_, delta)
        local _, maximum = slider:GetMinMaxValues()
        local value = slider:GetValue() - delta * 45
        slider:SetValue(math.max(0, math.min(maximum, value)))
    end)

    scroll.slider = slider

    --- Scrolls just enough to show the band from top to bottom (content coordinates, top is 0).
    function scroll:ShowBand(top, bottom)
        local current = self:GetVerticalScroll()
        local height = self:GetHeight()
        if top < current then
            slider:SetValue(top)
        elseif bottom > current + height then
            slider:SetValue(bottom - height)
        end
    end

    function scroll:ScrollToTop()
        slider:SetValue(0)
        self:SetVerticalScroll(0)
    end
    return scroll
end

-- ---------------------------------------------------------------------------
-- Links: the game cannot open a browser, so a click shows the link to copy
-- ---------------------------------------------------------------------------

--[[
The donation bar: "small" for the copy window (Donate and short channel names),
"medium" for the options (full names). Returns the bar; call bar:Relabel() after a language change.
]]
function ns.CreateLinkBar(parent, size)
    local medium = size == "medium"
    local height = medium and 24 or 16
    local bar = ns.NewFrame("Frame", nil, parent)
    bar:SetHeight(height)
    bar.buttons = {}

    -- Maldö's avatar in front of the links: this bar is about him, the rest of the addon shows the quill.
    bar.avatar = bar:CreateTexture(nil, "ARTWORK")
    bar.avatar:SetSize(height, height)
    bar.avatar:SetPoint("LEFT", 0, 0)
    bar.avatar:SetTexture(ns.mediaPath .. "maldoe")

    local x = height + 4
    for index, link in ipairs(ns.Links) do
        local button
        if link.donate then
            button = ns.CreateFlatButton(bar, "", medium and 118 or 58, height, not medium)
            button.textColor = C.accentText
        else
            button = ns.CreateFlatButton(bar, medium and link.name or link.short, medium and 74 or 26, height, not medium)
            button.textColor = medium and C.textDim or C.textFaint
            if not medium then
                -- Two letters on a small button: no room for the usual label insets.
                button.label:SetPoint("LEFT", 1, 0)
                button.label:SetPoint("RIGHT", -1, 0)
            end
        end
        button.solid = medium
        button.link = link
        button:SetPoint("LEFT", x, 0)
        button:SetScript("OnClick", function(self)
            UI:OpenText(self.link.name, self.link.url, L.LINK_COPY_HINT)
        end)
        x = x + button:GetWidth() + (medium and 4 or 1)

        if link.donate and ns.Links[index + 1] then
            -- A thin line between donating and the channels.
            local separator = bar:CreateTexture(nil, "ARTWORK")
            separator:SetColorTexture(C.border[1], C.border[2], C.border[3], 0.25)
            separator:SetSize(1, height - 6)
            separator:SetPoint("LEFT", x + 2, 0)
            x = x + 6
        end
        bar.buttons[#bar.buttons + 1] = button
    end
    bar:SetWidth(x)

    function bar:Relabel()
        for _, button in ipairs(self.buttons) do
            local link = button.link
            if link.donate then
                button.label:SetText(medium and (L.LINK_DONATE .. " (" .. link.name .. ")") or L.LINK_DONATE)
                button.tooltip = L.LINK_DONATE_TIP:format(link.name)
            else
                button.tooltip = L.LINK_FOLLOW_TIP:format(link.name)
            end
            button:Paint()
        end
    end
    bar:Relabel()
    return bar
end

-- ---------------------------------------------------------------------------
-- The copy window
-- ---------------------------------------------------------------------------

local function SavePosition(frame)
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    ns.db.position = { point, relativePoint, x, y }
end

local function SaveSize(frame)
    ns.db.windowWidth = math.floor(frame:GetWidth() + 0.5)
    ns.db.windowHeight = math.floor(frame:GetHeight() + 0.5)
end

local function RestorePosition(frame)
    frame:ClearAllPoints()
    local position = ns.db.position
    if type(position) == "table" and position[1] then
        frame:SetPoint(position[1], UIParent, position[2] or position[1], position[3] or 0, position[4] or 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    end
    frame:SetSize(ns.db.windowWidth or ns.defaults.windowWidth, ns.db.windowHeight or ns.defaults.windowHeight)
end

local function Tip(button, text)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(text, 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function UI:Create()
    if self.frame then return end
    local frame = ns.NewFrame("Frame", "MaldoesScribeFrame", UIParent)
    self.frame = frame
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT)
    elseif frame.SetMinResize then
        frame:SetMinResize(MIN_WIDTH, MIN_HEIGHT)
    end
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition(self)
    end)
    frame:Hide()
    -- Escape closes the window like the game's own.
    tinsert(UISpecialFrames, "MaldoesScribeFrame")

    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    ns.AddBorder(frame)

    -- A thin amber line at the top, the signature of the Maldö windows.
    local stripe = frame:CreateTexture(nil, "ARTWORK")
    stripe:SetPoint("TOPLEFT", 1, -1)
    stripe:SetPoint("TOPRIGHT", -1, -1)
    stripe:SetHeight(2)
    stripe:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.9)

    -- Header: quill, title, what is being copied, gear, close
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("TOPLEFT", PAD, -8)
    icon:SetTexture(ns.mediaPath .. "scribe")

    self.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.title:SetPoint("LEFT", icon, "RIGHT", 5, 0)
    self.title:SetTextColor(unpack(C.accentText))

    local close = ns.CreateFlatButton(frame, "x", 18, 16, true)
    close:SetPoint("TOPRIGHT", -5, -8)
    close.textColor = C.textDim
    close:SetScript("OnClick", function() UI:Hide() end)
    self.closeButton = close

    local options = ns.NewFrame("Button", nil, frame)
    options:SetSize(14, 14)
    options:SetPoint("RIGHT", close, "LEFT", -3, 0)
    options:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
    options:SetHighlightTexture("Interface\\Buttons\\UI-OptionsButton", "ADD")
    options:SetScript("OnClick", function() ns.OpenOptions() end)
    self.optionsButton = options

    self.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.subtitle:SetPoint("LEFT", self.title, "RIGHT", 8, 0)
    self.subtitle:SetPoint("RIGHT", options, "LEFT", -6, 0)
    self.subtitle:SetJustifyH("LEFT")
    self.subtitle:SetWordWrap(false)
    self.subtitle:SetTextColor(unpack(C.text))

    -- Variants (Text | Name | Wowhead) on the left, a note on the right
    self.variantRow = ns.NewFrame("Frame", nil, frame)
    self.variantRow:SetPoint("TOPLEFT", PAD, -(HEADER_HEIGHT + 2))
    self.variantRow:SetPoint("TOPRIGHT", -PAD, -(HEADER_HEIGHT + 2))
    self.variantRow:SetHeight(VARIANT_HEIGHT)
    self.variantButtons = {}

    self.note = self.variantRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.note:SetPoint("RIGHT", 0, 0)
    self.note:SetJustifyH("RIGHT")
    self.note:SetWordWrap(false)
    self.note:SetTextColor(unpack(C.textDim))

    -- The text
    local scroll = ns.CreateScrollBox(frame)
    scroll:SetPoint("TOPLEFT", self.variantRow, "BOTTOMLEFT", 0, -6)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(PAD + SLIDER_WIDTH + 4), FOOTER_HEIGHT)
    self.scroll = scroll

    local area = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    area:SetPoint("TOPLEFT", scroll, "TOPLEFT", -4, 4)
    area:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 4, -4)
    area:SetColorTexture(C.surface[1], C.surface[2], C.surface[3], 0.6)

    self.font = CreateFont("MaldoesScribeTextFont")

    local box = ns.NewFrame("EditBox", nil, scroll)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetMaxLetters(0)
    box:SetFontObject(self.font)
    box:SetTextInsets(2, 2, 2, 2)
    box:SetWidth(200)
    box:SetScript("OnEscapePressed", function(editBox)
        editBox:ClearFocus()
        UI:Hide()
    end)
    box:SetScript("OnKeyDown", function(editBox, key)
        if key == "A" and IsControlKeyDown() then editBox:HighlightText() end
    end)
    box:SetScript("OnTextChanged", function() scroll:UpdateScrollChildRect() end)
    box:SetScript("OnCursorChanged", function(_, _, y, _, height)
        -- Keep the cursor in view. The box resizes after this event, so apply it next frame.
        self.cursorTop, self.cursorBottom = -y, -y + height
        self.cursorPending = true
    end)
    scroll:SetScrollChild(box)
    scroll:EnableMouse(true)
    scroll:SetScript("OnMouseDown", function() box:SetFocus() end)
    scroll:SetScript("OnSizeChanged", function(_, width)
        if width and width > 8 then box:SetWidth(width - 4) end
    end)
    self.box = box

    frame:SetScript("OnUpdate", function()
        if self.cursorPending then
            self.cursorPending = false
            scroll:ShowBand(self.cursorTop or 0, self.cursorBottom or 0)
        end
    end)

    -- Footer: buttons
    self.selectAll = ns.CreateFlatButton(frame, "", 120, BUTTON_HEIGHT)
    self.selectAll.solid = true
    self.selectAll:SetPoint("BOTTOMLEFT", PAD, 32)
    self.selectAll:SetScript("OnClick", function() UI:SelectAll() end)

    self.refresh = ns.CreateFlatButton(frame, "", 120, BUTTON_HEIGHT)
    self.refresh.solid = true
    self.refresh:SetPoint("LEFT", self.selectAll, "RIGHT", 6, 0)
    self.refresh:SetScript("OnClick", function()
        UI:Refresh()
        UI:SelectAll()
    end)

    self.actionButtons = {}

    self.closeBottom = ns.CreateFlatButton(frame, "", 100, BUTTON_HEIGHT)
    self.closeBottom.solid = true
    self.closeBottom:SetPoint("BOTTOMRIGHT", -PAD, 32)
    self.closeBottom:SetScript("OnClick", function() UI:Hide() end)

    -- Footer: link bar and the Ctrl+C hint
    self.linkBar = ns.CreateLinkBar(frame, "small")
    self.linkBar:SetPoint("BOTTOMLEFT", PAD - 4, 8)

    self.hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.hint:SetPoint("BOTTOMLEFT", self.linkBar, "BOTTOMRIGHT", 10, 2)
    self.hint:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 10)
    self.hint:SetJustifyH("RIGHT")
    self.hint:SetWordWrap(false)
    self.hint:SetTextColor(unpack(C.textFaint))

    -- Resize handle in the corner
    local grip = ns.NewFrame("Button", nil, frame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -3, 3)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        SaveSize(frame)
        SavePosition(frame)
    end)
    self.grip = grip

    RestorePosition(frame)
    self:ApplyStyle()
    self:Relabel()
end

--- All texts that depend on the language.
function UI:Relabel()
    if not self.frame then return end
    self.title:SetText(L.TITLE)
    self.closeButton.tooltip = L.TIP_CLOSE
    Tip(self.optionsButton, L.TIP_OPTIONS)
    Tip(self.grip, L.TIP_RESIZE)
    self.selectAll.label:SetText(L.BTN_SELECT_ALL)
    self.refresh.label:SetText(L.BTN_REFRESH)
    self.closeBottom.label:SetText(L.BTN_CLOSE)
    self.selectAll:Paint()
    self.refresh:Paint()
    self.closeBottom:Paint()
    self.linkBar:Relabel()
    if self.source then self.hint:SetText(self.source.hint or L.HINT_COPY) end
end

local function AcquireVariantButton(self, index)
    local button = self.variantButtons[index]
    if button then return button end
    button = ns.CreateFlatButton(self.variantRow, "", 60, VARIANT_HEIGHT)
    button.solid = true
    button:SetScript("OnClick", function(clicked)
        UI.variantIndex = clicked.index
        UI:Refresh()
        UI:SelectAll()
    end)
    self.variantButtons[index] = button
    return button
end

local function AcquireActionButton(self, index)
    local button = self.actionButtons[index]
    if button then return button end
    button = ns.CreateFlatButton(self.frame, "", 120, BUTTON_HEIGHT)
    button.solid = true
    button:SetScript("OnClick", function(clicked)
        if clicked.action and clicked.action.click then clicked.action.click() end
        UI:Refresh()
        UI:SelectAll()
    end)
    self.actionButtons[index] = button
    return button
end

--- Builds the text of the chosen variant and lays out the variant and action buttons.
function UI:Refresh()
    local source = self.source
    if not (self.frame and source) then return end
    local variants = source.variants or {}
    if not self.variantIndex or self.variantIndex > #variants then self.variantIndex = 1 end

    -- The text first: a build may set source.note.
    local variant = variants[self.variantIndex]
    local text = ""
    if variant and type(variant.build) == "function" then
        local ok, result = pcall(variant.build)
        if ok then
            text = ns.Str(result) or ""
        else
            ns.ReportError(result)
            text = L.BUILD_FAILED
        end
    end

    -- Variant buttons
    local x = 0
    for index, item in ipairs(variants) do
        local button = AcquireVariantButton(self, index)
        button.index = index
        button.label:SetText(item.label or "?")
        button:SetWidth(math.max(56, button.label:GetStringWidth() + 18))
        button.selected = index == self.variantIndex
        button:ClearAllPoints()
        button:SetPoint("LEFT", x, 0)
        x = x + button:GetWidth() + 2
        button:SetShown(#variants > 1)
        button:Paint()
    end
    for index = #variants + 1, #self.variantButtons do
        self.variantButtons[index]:Hide()
    end

    local note = source.note or source.subtitle or ""
    self.note:SetText(note)
    -- The row takes its height only when it shows something.
    self.variantRow:SetHeight((#variants > 1 or note ~= "") and VARIANT_HEIGHT or 1)

    -- The box follows the width of the scroll area (also set here, in case the window has not
    -- been laid out yet).
    local width = self.scroll:GetWidth()
    if width and width > 8 then self.box:SetWidth(width - 4) end
    self.box:SetText(text)
    self.box:SetCursorPosition(0)
    self.scroll:ScrollToTop()

    self.subtitle:SetText(source.title or "")
    self.hint:SetText(source.hint or L.HINT_COPY)

    -- Extra actions after the Refresh button
    local actions = source.actions or {}
    local anchor = self.refresh
    for index, action in ipairs(actions) do
        local button = AcquireActionButton(self, index)
        button.action = action
        button.label:SetText(action.label or "?")
        button:SetWidth(math.max(90, button.label:GetStringWidth() + 20))
        button:ClearAllPoints()
        button:SetPoint("LEFT", anchor, "RIGHT", 6, 0)
        button:Show()
        button:Paint()
        anchor = button
    end
    for index = #actions + 1, #self.actionButtons do
        self.actionButtons[index]:Hide()
    end
end

--- Focuses the text and highlights all of it, so Ctrl+C copies everything.
function UI:SelectAll()
    if not self.frame then return end
    self.box:SetFocus()
    self.box:SetCursorPosition(0)
    self.box:HighlightText()
end

--- Shows a source in the window (see Sources.lua for what a source is).
function UI:Open(source)
    if type(source) ~= "table" then return end
    if not self.frame then self:Create() end
    self.source = source
    self.variantIndex = 1
    ns.lastSourceKind = source.kind
    ns.Debug("open:", source.kind, "| variants", #(source.variants or {}))
    self:Relabel()
    self:Refresh()
    self.frame:Show()
    self.frame:Raise()
    self:SelectAll()
end

--- A plain text with a title, for example a web address.
function UI:OpenText(title, text, hint)
    self:Open({
        kind = "text",
        title = title,
        hint = hint,
        variants = { { label = title, build = function() return text end } },
    })
end

--- Opacity, scale and text size from the options.
function UI:ApplyStyle()
    local frame = self.frame
    if not frame then return end
    local db = ns.db
    frame.bg:SetColorTexture(C.bg[1], C.bg[2], C.bg[3], db.opacity or 0.95)
    frame:SetScale(db.scale or 1)
    local path, _, flags = ChatFontNormal:GetFont()
    self.font:SetFont(path or STANDARD_TEXT_FONT, db.fontSize or 12, flags or "")
    self.font:SetTextColor(C.text[1], C.text[2], C.text[3])
    self.box:SetFontObject(self.font)
    for _, button in ipairs(self.variantButtons) do button:Paint() end
end

function UI:ResetPosition()
    ns.db.position = nil
    ns.db.windowWidth = ns.defaults.windowWidth
    ns.db.windowHeight = ns.defaults.windowHeight
    if self.frame then RestorePosition(self.frame) end
end

function UI:IsShown()
    return self.frame ~= nil and self.frame:IsShown()
end

function UI:Hide()
    if not self.frame then return end
    self.box:ClearFocus()
    self.frame:Hide()
end

function UI:Toggle()
    if self:IsShown() then
        self:Hide()
    elseif self.source then
        self:Open(self.source)
    end
end

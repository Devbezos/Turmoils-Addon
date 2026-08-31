-- TurmoilsAddon_Options.lua
-- A small hand-rolled options panel (no AceConfig dependency - this addon
-- has too few settings to justify the extra libraries) plus the /turmoil
-- slash command. Widgets are built directly with stable Blizzard templates
-- (UICheckButtonTemplate, UIPanelButtonTemplate, UIPanelCloseButton) so
-- there is nothing extra to ship or version.
local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

local PANEL_WIDTH, PANEL_HEIGHT = 260, 400

local panel

local function CreateCheckbox(parent, labelText, y, initial, onChange)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, y)
    if cb.Text then cb.Text:SetText(labelText) end
    cb:SetChecked(initial)
    cb:SetScript("OnClick", function(self_)
        onChange(self_:GetChecked() and true or false)
    end)
    return cb
end

-- Number of decimal places to display for a given step size (0.05 -> 2,
-- 1 -> 0), so the value label reads like "0.85" instead of a long raw float
-- (sliders don't report perfectly step-quantized values - see RoundToStep).
local function DecimalPlacesFor(step)
    if not step or step <= 0 or step >= 1 then return 0 end
    local text = tostring(step)
    local dot = text:find(".", 1, true)
    return dot and (#text - dot) or 0
end

-- A minimal hand-built slider (label above, live value to the right) rather
-- than a Blizzard slider template, so we're not depending on template
-- sub-region names that have shifted across client versions.
local function CreateSlider(parent, labelText, y, minValue, maxValue, step, initial, onChange)
    local track = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    track:SetSize(180, 14)
    track:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, y)
    track:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    track:SetBackdropColor(0.12, 0.12, 0.14, 0.9)
    track:SetBackdropBorderColor(0.3, 0.3, 0.32, 0.8)

    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("BOTTOMLEFT", track, "TOPLEFT", 0, 2)
    label:SetText(labelText)

    local decimals = DecimalPlacesFor(step)
    local function FormatValue(value)
        return string.format("%." .. decimals .. "f", value)
    end
    -- Sliders don't hand back perfectly step-quantized values (mouse
    -- position maps to a raw float), so snap to the nearest step multiple
    -- ourselves - both for the stored/applied value and the label text.
    local function RoundToStep(value)
        if not step or step <= 0 then return value end
        return math.floor(value / step + 0.5) * step
    end

    initial = RoundToStep(initial)

    local valueText = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    valueText:SetPoint("LEFT", track, "RIGHT", 8, 0)
    valueText:SetText(FormatValue(initial))

    local slider = CreateFrame("Slider", nil, track)
    slider:SetOrientation("HORIZONTAL")
    slider:SetAllPoints(track)
    slider:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    slider:SetValue(initial)
    slider:SetScript("OnValueChanged", function(_, value)
        value = RoundToStep(value)
        valueText:SetText(FormatValue(value))
        onChange(value)
    end)

    return slider
end

function Addon:EnsureOptionsPanel()
    if panel then return panel end

    panel = CreateFrame("Frame", "TurmoilsAddonOptionsPanel", UIParent, "BackdropTemplate")
    panel:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    panel:SetBackdropColor(0.05, 0.06, 0.07, 0.95)
    panel:SetBackdropBorderColor(0.20, 0.85, 0.55, 0.8)
    panel:Hide()

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", panel, "TOP", 0, -14)
    title:SetText("Turmoil's Addon")

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -2, -2)

    local y = -48
    CreateCheckbox(panel, "Lock frame position", y, self.db.global.locked, function(v)
        self:SetFrameLocked(v)
    end)

    y = y - 28
    CreateCheckbox(panel, "Hide when idle", y, self.db.global.autoHideWhenIdle, function(v)
        self.db.global.autoHideWhenIdle = v
        if not self.echoState.running then
            self:UpdateTimerDisplay(0, "fresh", false)
        end
    end)

    y = y - 28
    CreateCheckbox(panel, "Play sound on consume", y, self.db.global.soundOnConsume, function(v)
        self.db.global.soundOnConsume = v
    end)

    y = y - 36
    CreateSlider(panel, "Width", y, 80, 260, 2, self.db.global.frameWidth or 132, function(v)
        self:SetFrameSize(v, self.db.global.frameHeight or 54)
    end)

    y = y - 44
    CreateSlider(panel, "Height", y, 36, 100, 2, self.db.global.frameHeight or 54, function(v)
        self:SetFrameSize(self.db.global.frameWidth or 132, v)
    end)

    y = y - 44
    CreateSlider(panel, "Scale", y, 0.6, 2.0, 0.05, self.db.global.scale or 1, function(v)
        self:SetFrameScale(v)
    end)

    y = y - 44
    CreateSlider(panel, "Echo duration (seconds)", y, 12, 25, 1, self.db.global.echoDuration or 20, function(v)
        self.db.global.echoDuration = v
    end)

    y = y - 44
    local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetBtn:SetSize(110, 22)
    resetBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, y)
    resetBtn:SetText("Reset position")
    resetBtn:SetScript("OnClick", function() self:ResetFramePosition() end)

    local helloBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    helloBtn:SetSize(110, 22)
    helloBtn:SetPoint("LEFT", resetBtn, "RIGHT", 8, 0)
    helloBtn:SetText("Say hi again")
    helloBtn:SetScript("OnClick", function() self:Print(self.CONSTANTS.welcomeMessage) end)

    return panel
end

function Addon:ToggleOptions()
    self:EnsureOptionsPanel()
    if panel:IsShown() then panel:Hide() else panel:Show() end
end

-- /turmoil            toggle the options panel
-- /turmoil lock       lock the timer frame in place
-- /turmoil unlock     unlock it so it can be dragged
-- /turmoil reset      snap it back to the default position
function Addon:RegisterConsoleCommands()
    self:RegisterChatCommand("turmoil", function(msg)
        msg = tostring(msg or ""):lower():match("^%s*(.-)%s*$")
        if msg == "lock" then
            self:SetFrameLocked(true)
            self:Print("Locked.")
        elseif msg == "unlock" then
            self:SetFrameLocked(false)
            self:Print("Unlocked.")
        elseif msg == "reset" then
            self:ResetFramePosition()
            self:Print("Position reset.")
        else
            self:ToggleOptions()
        end
    end)
end

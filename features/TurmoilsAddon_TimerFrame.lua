-- TurmoilsAddon_TimerFrame.lua
-- The little on-screen timer: a movable, lockable, resizable, scalable
-- button that counts down from Addon.db.global.echoDuration and shows a
-- shrinking freshness bar, with a soft flash on apply and on consume.
-- Position/scale persist via LibWindow-1.1; lock state, size, scale, and
-- the visibility gates (manual hide, combat-only, raid-only) live in the
-- AceDB SavedVariables. Width/height and scale are independent
-- controls (see Options: "Width"/"Height" vs "Scale") - size changes the
-- frame's actual footprint (useful when slotting it next to other UI where
-- scaling everything, including the border/font, doesn't fit), while scale
-- just magnifies the whole thing uniformly.
local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

local DEFAULT_FRAME_WIDTH, DEFAULT_FRAME_HEIGHT = 132, 54
local FLASH_DURATION = 0.35

local COLORS = {
    fresh    = { r = 0.20, g = 0.85, b = 0.55 }, -- Preservation green
    aging    = { r = 0.95, g = 0.75, b = 0.20 }, -- amber warning
    stale    = { r = 0.90, g = 0.30, b = 0.30 }, -- red: probably about to fall off
    idle     = { r = 0.55, g = 0.55, b = 0.60 }, -- gray: nothing running
    consumed = { r = 0.40, g = 0.85, b = 1.00 }, -- cyan pop on a successful consume
}

local frame
local glow
local timeText
local barFill
local flashElapsed

local function OnFlashUpdate(f, elapsed)
    flashElapsed = flashElapsed + elapsed
    local pct = flashElapsed / FLASH_DURATION
    if pct >= 1 then
        glow:SetAlpha(0)
        f:SetScript("OnUpdate", nil)
        return
    end
    glow:SetAlpha(1 - pct)
end

function Addon:PlayEchoFlash(kind)
    if not (frame and glow) then return end
    local c = COLORS[kind] or COLORS.fresh
    glow:SetColorTexture(c.r, c.g, c.b, 1)
    flashElapsed = 0
    frame:SetScript("OnUpdate", OnFlashUpdate)
end

-- Shows/hides the frame based on the manual hide toggle plus the "Hide out
-- of combat" / "Hide outside raid" options - independent of the
-- running/idle countdown visuals in UpdateTimerDisplay below. Manual hide
-- wins outright; the combat/raid checks are each independent (either one
-- being unmet hides it). Also called directly from
-- TurmoilsAddon_EchoTracker.lua on PLAYER_REGEN_DISABLED/ENABLED/
-- GROUP_ROSTER_UPDATE, so combat/raid entry/exit updates visibility
-- immediately rather than waiting for the next cast.
function Addon:ApplyVisibilityGates()
    if not frame then return end

    if self.db.global.manuallyHidden then
        frame:Hide()
        return
    end
    if self.db.global.hideOutOfCombat and not InCombatLockdown() then
        frame:Hide()
        return
    end
    if self.db.global.hideOutsideRaid and not IsInRaid() then
        frame:Hide()
        return
    end
    frame:Show()
end

-- running == false means idle (remaining is always 0 in that case).
-- remaining counts DOWN from Addon.db.global.echoDuration to 0 and then
-- holds there (it does not auto-reset - only an actual consume does that,
-- see EchoLogic.HandleSpellCast).
function Addon:UpdateTimerDisplay(remaining, tier, running)
    if not frame then return end
    self:ApplyVisibilityGates()
    if not frame:IsShown() then return end

    if not running then
        frame:SetAlpha(0.55)
        timeText:SetText("--")
        timeText:SetTextColor(COLORS.idle.r, COLORS.idle.g, COLORS.idle.b)
        barFill:SetWidth(0.001)
        return
    end

    frame:SetAlpha(1)
    local c = COLORS[tier] or COLORS.fresh
    timeText:SetFormattedText("%.1fs", remaining)
    timeText:SetTextColor(c.r, c.g, c.b)

    local duration = self.db.global.echoDuration or 20
    local pct = math.max(0, math.min(1, remaining / duration))
    local maxWidth = (frame:GetWidth() or DEFAULT_FRAME_WIDTH) - 16
    barFill:SetWidth(math.max(0.001, pct * maxWidth))
    barFill:SetColorTexture(c.r, c.g, c.b, 0.9)
end

-- Called by TurmoilsAddon_EchoTracker.lua whenever a cast changes Echo state.
function Addon:OnEchoEvent(event)
    if event == "applied" then
        self:UpdateTimerDisplay(self.db.global.echoDuration or 20, "fresh", true)
        self:PlayEchoFlash("fresh")
    elseif event == "consumed" then
        self:UpdateTimerDisplay(0, "fresh", false)
        self:PlayEchoFlash("consumed")
        if self.db.global.soundOnConsume then
            PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856, "SFX")
        end
    end
    -- "consumed-idle": nothing was running, so nothing to show - a no-op
    -- press shouldn't flash like it accomplished something.
end

function Addon:EnsureTimerFrame()
    if frame then return frame end

    frame = CreateFrame("Button", "TurmoilsAddonTimerFrame", UIParent, "BackdropTemplate")
    frame:SetSize(
        self.db.global.frameWidth or DEFAULT_FRAME_WIDTH,
        self.db.global.frameHeight or DEFAULT_FRAME_HEIGHT
    )
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(0.04, 0.05, 0.06, 0.78)
    frame:SetBackdropBorderColor(0.20, 0.85, 0.55, 0.6)

    glow = frame:CreateTexture(nil, "OVERLAY")
    glow:SetAllPoints(frame)
    glow:SetColorTexture(1, 1, 1, 0)
    glow:SetBlendMode("ADD")

    local label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("TOP", frame, "TOP", 0, -6)
    label:SetText("ECHO")
    label:SetTextColor(0.65, 0.9, 0.8, 0.9)

    timeText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    timeText:SetPoint("CENTER", frame, "CENTER", 0, -2)

    local barBG = frame:CreateTexture(nil, "ARTWORK")
    barBG:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 6)
    barBG:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 6)
    barBG:SetHeight(3)
    barBG:SetColorTexture(1, 1, 1, 0.12)

    barFill = frame:CreateTexture(nil, "ARTWORK", nil, 1)
    barFill:SetPoint("BOTTOMLEFT", barBG, "BOTTOMLEFT", 0, 0)
    barFill:SetHeight(3)
    barFill:SetWidth(0.001)
    barFill:SetColorTexture(COLORS.fresh.r, COLORS.fresh.g, COLORS.fresh.b, 0.9)

    -- Movable + persisted position/scale.
    local LibWindow = LibStub("LibWindow-1.1")
    LibWindow:Embed(frame)
    frame:RegisterConfig(self.db.global)
    frame:RestorePosition()
    frame:SetScale(self.db.global.scale or 1)

    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(f)
        if Addon.db.global.locked then return end
        f:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        f:SavePosition()
    end)

    frame:RegisterForClicks("AnyUp")
    frame:SetScript("OnClick", function(_, button)
        if button == "RightButton" and Addon.ToggleOptions then
            Addon:ToggleOptions()
        end
    end)

    frame:SetScript("OnEnter", function(f)
        GameTooltip:SetOwner(f, "ANCHOR_TOP")
        GameTooltip:AddLine("Turmoil's Addon", 0.4, 0.9, 1)
        GameTooltip:AddLine("Echo timer - counts down from your first Echo/Temporal Anomaly, resets when consumed.", 1, 1, 1)
        GameTooltip:AddLine(Addon.CONSTANTS.tooltipFlavorText, 1, 1, 1)
        GameTooltip:AddLine(" ")
        local dragHint = Addon.db.global.locked and "Frame is locked (unlock in options)." or "Left-drag to move."
        GameTooltip:AddLine(dragHint .. " Right-click for options.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)

    return frame
end

function Addon:ShowTimerFrame()
    self:EnsureTimerFrame()
    self:UpdateTimerDisplay(0, "fresh", false)
end

function Addon:HideTimerFrame()
    if frame then frame:Hide() end
end

function Addon:SetFrameLocked(locked)
    self.db.global.locked = locked and true or false
end

function Addon:SetFrameScale(scale)
    scale = tonumber(scale) or 1
    self.db.global.scale = scale
    if frame then frame:SetScale(scale) end
end

-- Width/height in pixels, independent of scale. Clamped generously (well
-- past the options-panel slider's own range) as a defensive floor/ceiling
-- against a corrupted SavedVariables value.
function Addon:SetFrameSize(width, height)
    width = math.max(60, math.min(400, tonumber(width) or DEFAULT_FRAME_WIDTH))
    height = math.max(24, math.min(200, tonumber(height) or DEFAULT_FRAME_HEIGHT))
    self.db.global.frameWidth = width
    self.db.global.frameHeight = height
    if frame then frame:SetSize(width, height) end
end

function Addon:ResetFramePosition()
    if not frame then return end
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 160)
    frame:SavePosition()
end

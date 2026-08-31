-- TurmoilsAddon_EchoTracker.lua
-- WoW-facing glue: listens for the player's own successful spell casts,
-- feeds them through the pure EchoLogic state machine, and drives the
-- on-screen tick.
--
-- Deliberately cast-based, not aura-based: this watches *you pressing the
-- button*, not whether the Echo buff is actually still sitting on a target.
-- That matches what was asked for (a timer that starts on the first applying
-- cast and counts down until you consume it) and sidesteps combat-log/aura
-- latency and multi-target ambiguity. Two tradeoffs, both intentional - see
-- EchoLogic.HandleSpellCast: pressing a "consuming" spell resets the timer
-- even if nothing was actually echoed (no-op'd when idle), and pressing an
-- "applying" spell again while already running does NOT restart the
-- countdown.
--
-- One more wrinkle: Empower-type spells (Dream Breath) fire
-- UNIT_SPELLCAST_SUCCEEDED the instant you START the empower, not when you
-- release it - a WoW client quirk. Addon.CONSTANTS.empowerSpellIDs flags
-- those, so SUCCEEDED is ignored for them and UNIT_SPELLCAST_EMPOWER_STOP is
-- used instead, which fires on release/cast-completion.
local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

local Core = Addon.EchoLogic

local trackingFrame
local tickPending = false

local function GetSpellSets()
    local c = Addon.CONSTANTS
    return { apply = c.applySpellIDs, consume = c.consumeSpellIDs }
end

local function IsEmpowerSpell(spellID)
    local empower = Addon.CONSTANTS.empowerSpellIDs
    return empower ~= nil and empower[spellID] == true
end

-- Re-schedules itself on a short interval only while the timer is running,
-- so there is never more than one pending timer and nothing ticks while idle.
local function ScheduleTick()
    if tickPending then return end
    tickPending = true
    C_Timer.After(0.1, function()
        tickPending = false
        if not Addon.echoState.running then return end
        if Addon.UpdateTimerDisplay then
            local duration = (Addon.db and Addon.db.global.echoDuration) or 20
            local remaining = Core.GetRemaining(Addon.echoState, GetTime(), duration)
            Addon:UpdateTimerDisplay(remaining, Core.GetFreshnessTier(remaining, duration), true)
        end
        ScheduleTick()
    end)
end

local function ProcessSpellCast(spellID, now)
    local newState, event = Core.HandleSpellCast(Addon.echoState, spellID, now, GetSpellSets())
    Addon.echoState = newState
    if not event then return end

    if Addon.OnEchoEvent then
        Addon:OnEchoEvent(event)
    end

    if event == "applied" then
        ScheduleTick()
    end
end

local function OnTrackingEvent(_frame, eventName, unit, _castGUID, spellID, deployed)
    if unit ~= "player" or not spellID then return end

    if eventName == "UNIT_SPELLCAST_SUCCEEDED" then
        if IsEmpowerSpell(spellID) then return end -- handled via EMPOWER_STOP instead
        ProcessSpellCast(spellID, GetTime())
    elseif eventName == "UNIT_SPELLCAST_EMPOWER_STOP" then
        -- `deployed` is true when the empower was actually released and
        -- cast, false when canceled/interrupted before release. An
        -- unexpected/missing value is treated as a release - safer than
        -- silently never registering a real cast if this parameter turns
        -- out to differ from what's documented.
        if deployed == false then return end
        ProcessSpellCast(spellID, GetTime())
    end
end

function Addon:ActivateTracking()
    trackingFrame = trackingFrame or CreateFrame("Frame")
    trackingFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    trackingFrame:RegisterEvent("UNIT_SPELLCAST_EMPOWER_STOP")
    trackingFrame:SetScript("OnEvent", OnTrackingEvent)
end

function Addon:DeactivateTracking()
    if not trackingFrame then return end
    trackingFrame:UnregisterAllEvents()
    trackingFrame:SetScript("OnEvent", nil)
    self.echoState = { running = false, startedAt = nil }
end

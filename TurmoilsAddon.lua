-- TurmoilsAddon.lua
-- Main addon entry point.
--
-- Responsibilities:
-- - Bootstrap the Ace3 addon object + SavedVariables DB.
-- - Gate everything behind "is this character a Preservation Evoker right
--   now" so the timer never shows up on the wrong spec/class.
-- - Own the tiny bit of runtime (non-persisted) Echo state and the
--   first-run welcome message.
--
-- Everything else (spell-cast classification, the frame, the options panel)
-- lives in core/ and features/ and hangs off this Addon object.
local addonName = ...

local Addon = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceEvent-3.0", "AceConsole-3.0")
_G[addonName] = Addon

Addon.CONSTANTS = _G["TurmoilsAddon_CONSTANTS"]
if type(Addon.CONSTANTS) ~= "table" then
    -- Defensive fallback so a missing/failed constants load never hard-errors;
    -- the tracker simply never classifies any spell as apply/consume.
    Addon.CONSTANTS = { applySpellIDs = {}, consumeSpellIDs = {}, defaults = { global = {} } }
end

-- Runtime-only Echo state, intentionally not saved: a fresh timer on every
-- login/reload is the right behavior, there is nothing meaningful to persist.
Addon.echoState = { running = false, startedAt = nil }

function Addon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("TurmoilsAddonDB", self.CONSTANTS.defaults, true)
end

-- Returns true only while the player is actually a Preservation Evoker.
-- Everything (frame visibility, spellcast tracking) is gated on this so the
-- addon stays invisible on every other class/spec.
function Addon:IsPreservationEvoker()
    local _, classToken = UnitClass("player")
    local specIndex = GetSpecialization and GetSpecialization()
    local specID = specIndex and GetSpecializationInfo(specIndex)
    return self.EchoLogic.ShouldBeActive(classToken, specID, self.CONSTANTS.preservationSpecID)
end

-- Called on login and whenever the active spec changes. Activates/deactivates
-- the tracker + frame so nothing runs (and nothing shows) outside Preservation.
function Addon:RefreshSpecGate()
    local shouldBeActive = self:IsPreservationEvoker()
    if shouldBeActive == self._active then return end
    self._active = shouldBeActive

    if shouldBeActive then
        if self.ActivateTracking then self:ActivateTracking() end
        if self.ShowTimerFrame then self:ShowTimerFrame() end
        self:MaybeShowWelcomeMessage()
    else
        if self.DeactivateTracking then self:DeactivateTracking() end
        if self.HideTimerFrame then self:HideTimerFrame() end
    end
end

function Addon:MaybeShowWelcomeMessage()
    if self.db.global.firstRunSeen then return end
    self.db.global.firstRunSeen = true
    C_Timer.After(3, function()
        self:Print(self.CONSTANTS.welcomeMessage)
    end)
end

function Addon:OnEnable()
    if self.RegisterConsoleCommands then self:RegisterConsoleCommands() end
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "RefreshSpecGate")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "RefreshSpecGate")
    self:RefreshSpecGate()
end

-- Exercises TurmoilsAddon_EchoTracker.lua's WoW-facing glue: event
-- registration, filtering by unit, the Empower-spell routing quirk,
-- combat/raid state routing, and the polling tick it schedules while the
-- countdown is running. The state-machine decisions themselves are covered
-- exhaustively in echo_logic_test.lua - this file is about the wiring.
local Test = _G.TA_TEST
local Harness = _G.TA_HARNESS

local addonName = "TA_TRACKER_TEST_ADDON"
local Addon = {
    CONSTANTS = {
        applySpellIDs = { [364343] = true, [373861] = true }, -- Echo, Temporal Anomaly
        consumeSpellIDs = { [355936] = true, [360995] = true }, -- Dream Breath (empower), Verdant Embrace
        empowerSpellIDs = { [355936] = true }, -- Dream Breath
    },
    echoState = { running = false, startedAt = nil },
    db = { global = { echoDuration = 20 } },
}
_G[addonName] = Addon

local displayCalls = {}
local echoEvents = {}
local combatVisibilityCalls = 0
function Addon:UpdateTimerDisplay(remaining, tier, running)
    displayCalls[#displayCalls + 1] = { remaining = remaining, tier = tier, running = running }
end
function Addon:OnEchoEvent(event)
    echoEvents[#echoEvents + 1] = event
end
function Addon:ApplyVisibilityGates()
    combatVisibilityCalls = combatVisibilityCalls + 1
end

Harness.load(addonName, "core/TurmoilsAddon_EchoLogic.lua")
Harness.load(addonName, "features/TurmoilsAddon_EchoTracker.lua")

Addon:ActivateTracking()
local trackingFrame = Harness.findFrameWithEvent("UNIT_SPELLCAST_SUCCEEDED")

Test.case("ActivateTracking registers listeners for cast events, combat, and raid state", function()
    Test.truthy(trackingFrame, "expected a frame registered for UNIT_SPELLCAST_SUCCEEDED")
    Test.truthy(trackingFrame:IsEventRegistered("UNIT_SPELLCAST_EMPOWER_STOP"))
    Test.truthy(trackingFrame:IsEventRegistered("PLAYER_REGEN_DISABLED"))
    Test.truthy(trackingFrame:IsEventRegistered("PLAYER_REGEN_ENABLED"))
    Test.truthy(trackingFrame:IsEventRegistered("GROUP_ROSTER_UPDATE"))
end)

Test.case("combat/raid state changes call ApplyVisibilityGates without touching Echo state", function()
    local callsBefore = combatVisibilityCalls
    local runningBefore = Addon.echoState.running
    local eventCountBefore = #echoEvents
    trackingFrame:Fire("PLAYER_REGEN_DISABLED")
    trackingFrame:Fire("PLAYER_REGEN_ENABLED")
    trackingFrame:Fire("GROUP_ROSTER_UPDATE")
    Test.equal(combatVisibilityCalls, callsBefore + 3)
    Test.equal(Addon.echoState.running, runningBefore)
    Test.equal(#echoEvents, eventCountBefore)
end)

Test.case("casting Echo as the player starts the 20s countdown and fires 'applied'", function()
    Harness.now = 1000
    trackingFrame:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid-1", 364343)
    Test.truthy(Addon.echoState.running)
    Test.equal(Addon.echoState.startedAt, 1000)
    Test.equal(echoEvents[#echoEvents], "applied")
end)

Test.case("a spell cast by another unit is ignored", function()
    local before = Addon.echoState.running
    trackingFrame:Fire("UNIT_SPELLCAST_SUCCEEDED", "target", "guid-2", 364343)
    Test.equal(Addon.echoState.running, before)
end)

Test.case("casting Temporal Anomaly while already running does not restart the countdown", function()
    local eventCountBefore = #echoEvents
    trackingFrame:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid-3", 373861)
    Test.equal(Addon.echoState.startedAt, 1000, "startedAt must not move")
    Test.equal(#echoEvents, eventCountBefore, "a redundant apply cast should not fire an event")
end)

Test.case("the scheduled tick counts down and updates the display while running", function()
    Test.truthy(#Harness.timers > 0, "expected a pending tick after 'applied'")
    Harness.advanceTime(0.1)
    Harness.fireNextTimer()
    local last = displayCalls[#displayCalls]
    Test.truthy(last, "expected UpdateTimerDisplay to have been called")
    Test.truthy(last.running)
    Test.nearly(last.remaining, 19.9, 0.01)
end)

Test.case("an unrelated spell cast does not touch state or fire an event", function()
    local before = Addon.echoState.running
    local eventCountBefore = #echoEvents
    trackingFrame:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid-4", 99999)
    Test.equal(Addon.echoState.running, before)
    Test.equal(#echoEvents, eventCountBefore)
end)

Test.case("UNIT_SPELLCAST_SUCCEEDED for an empower spell (Dream Breath) is ignored entirely", function()
    -- This is the bug being fixed: WoW fires SUCCEEDED the instant the
    -- empower channel *starts*, not on release, so it must not consume.
    local before = Addon.echoState.running
    local eventCountBefore = #echoEvents
    trackingFrame:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid-5", 355936)
    Test.equal(Addon.echoState.running, before, "SUCCEEDED must not reset the timer for an empower spell")
    Test.equal(#echoEvents, eventCountBefore)
end)

Test.case("EMPOWER_STOP with deployed=false (canceled) does not consume", function()
    local before = Addon.echoState.running
    local eventCountBefore = #echoEvents
    trackingFrame:Fire("UNIT_SPELLCAST_EMPOWER_STOP", "player", "guid-5", 355936, false)
    Test.equal(Addon.echoState.running, before)
    Test.equal(#echoEvents, eventCountBefore)
end)

Test.case("EMPOWER_STOP with deployed=true (released) resets the timer and fires 'consumed'", function()
    trackingFrame:Fire("UNIT_SPELLCAST_EMPOWER_STOP", "player", "guid-6", 355936, true)
    Test.falsy(Addon.echoState.running)
    Test.equal(echoEvents[#echoEvents], "consumed")
end)

Test.case("the tick loop stops rescheduling once the timer is idle again", function()
    Harness.runTimers(50) -- drains any tick already in flight; must not requeue forever
    Test.equal(#Harness.timers, 0)
end)

Test.case("consuming again with nothing running fires 'consumed-idle', not 'consumed'", function()
    trackingFrame:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid-7", 360995)
    Test.equal(echoEvents[#echoEvents], "consumed-idle")
end)

Test.case("casting Echo again after a consume starts a brand new countdown", function()
    Harness.now = 2000
    trackingFrame:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid-8", 364343)
    Test.truthy(Addon.echoState.running)
    Test.equal(Addon.echoState.startedAt, 2000)
    Test.equal(echoEvents[#echoEvents], "applied")
end)

Test.case("a non-empower consume spell (Verdant Embrace) still works via plain SUCCEEDED", function()
    trackingFrame:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid-9", 360995)
    Test.falsy(Addon.echoState.running)
    Test.equal(echoEvents[#echoEvents], "consumed")
end)

Test.case("DeactivateTracking unregisters events and clears state", function()
    Addon:DeactivateTracking()
    Test.falsy(trackingFrame:IsEventRegistered("UNIT_SPELLCAST_SUCCEEDED"))
    Test.falsy(trackingFrame:IsEventRegistered("UNIT_SPELLCAST_EMPOWER_STOP"))
    Test.falsy(trackingFrame:IsEventRegistered("PLAYER_REGEN_DISABLED"))
    Test.falsy(trackingFrame:IsEventRegistered("PLAYER_REGEN_ENABLED"))
    Test.falsy(trackingFrame:IsEventRegistered("GROUP_ROSTER_UPDATE"))
    Test.falsy(Addon.echoState.running)
end)

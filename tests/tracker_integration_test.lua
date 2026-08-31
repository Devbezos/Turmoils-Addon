-- Exercises TurmoilsAddon_EchoTracker.lua's WoW-facing glue: event
-- registration, filtering by unit, and the polling tick it schedules while
-- Echo is running. The state-machine decisions themselves are covered
-- exhaustively in echo_logic_test.lua - this file is about the wiring.
local Test = _G.TA_TEST
local Harness = _G.TA_HARNESS

local addonName = "TA_TRACKER_TEST_ADDON"
local Addon = {
    CONSTANTS = {
        applySpellIDs = { [364343] = true },
        consumeSpellIDs = { [355936] = true },
    },
    echoState = { running = false, startedAt = nil },
    db = { global = { staleThreshold = 12 } },
}
_G[addonName] = Addon

local displayCalls = {}
local echoEvents = {}
function Addon:UpdateTimerDisplay(elapsed, tier, running)
    displayCalls[#displayCalls + 1] = { elapsed = elapsed, tier = tier, running = running }
end
function Addon:OnEchoEvent(event)
    echoEvents[#echoEvents + 1] = event
end

Harness.load(addonName, "core/TurmoilsAddon_EchoLogic.lua")
Harness.load(addonName, "features/TurmoilsAddon_EchoTracker.lua")

Addon:ActivateTracking()
local trackingFrame = Harness.findFrameWithEvent("UNIT_SPELLCAST_SUCCEEDED")

Test.case("ActivateTracking registers an OnEvent listener for spell casts", function()
    Test.truthy(trackingFrame, "expected a frame registered for UNIT_SPELLCAST_SUCCEEDED")
end)

Test.case("casting Echo as the player starts the timer and fires 'applied'", function()
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

Test.case("the scheduled tick updates the display while running", function()
    Test.truthy(#Harness.timers > 0, "expected a pending tick after 'applied'")
    Harness.advanceTime(0.1)
    Harness.fireNextTimer()
    local last = displayCalls[#displayCalls]
    Test.truthy(last, "expected UpdateTimerDisplay to have been called")
    Test.truthy(last.running)
    Test.nearly(last.elapsed, 0.1, 0.01)
end)

Test.case("an unrelated spell cast does not touch state or fire an event", function()
    local before = Addon.echoState.running
    local eventCountBefore = #echoEvents
    trackingFrame:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid-3", 99999)
    Test.equal(Addon.echoState.running, before)
    Test.equal(#echoEvents, eventCountBefore)
end)

Test.case("casting the consume spell resets the timer and fires 'consumed'", function()
    trackingFrame:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid-4", 355936)
    Test.falsy(Addon.echoState.running)
    Test.equal(echoEvents[#echoEvents], "consumed")
end)

Test.case("the tick loop stops rescheduling once the timer is idle again", function()
    Harness.runTimers(50) -- drains any tick already in flight; must not requeue forever
    Test.equal(#Harness.timers, 0)
end)

Test.case("consuming again with nothing running fires 'consumed-idle', not 'consumed'", function()
    trackingFrame:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid-5", 355936)
    Test.equal(echoEvents[#echoEvents], "consumed-idle")
end)

Test.case("DeactivateTracking unregisters events and clears state", function()
    Addon:DeactivateTracking()
    Test.falsy(trackingFrame:IsEventRegistered("UNIT_SPELLCAST_SUCCEEDED"))
    Test.falsy(Addon.echoState.running)
end)

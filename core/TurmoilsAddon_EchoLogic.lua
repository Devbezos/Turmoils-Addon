-- TurmoilsAddon_EchoLogic.lua
-- Pure Echo state-machine logic shared by the runtime tracker and the
-- standalone test suite. No WoW API calls live here on purpose - see
-- tests/echo_logic_test.lua, which loads this file with a plain Lua
-- interpreter and no game client at all.
local addonName = ...
local Addon = _G[addonName]
if not Addon then return end

local Core = {}
Addon.EchoLogic = Core

function Core.IsApplySpell(spellID, spellSets)
    return spellSets ~= nil and spellSets.apply ~= nil and spellSets.apply[spellID] == true
end

function Core.IsConsumeSpell(spellID, spellSets)
    return spellSets ~= nil and spellSets.consume ~= nil and spellSets.consume[spellID] == true
end

-- state shape: { running = boolean, startedAt = number|nil }
--
-- Casting an apply spell (Echo, Temporal Anomaly) starts the countdown only
-- if nothing was already running - a second apply-class cast while one is
-- already ticking is a deliberate no-op, not a restart. Restarting on every
-- apply cast would let you keep the timer looking "fresh" forever without
-- ever actually consuming it, which defeats the point.
--
-- Casting a consume spell resets the timer back to idle only if one was
-- actually running; consuming with nothing active is a no-op (nothing to
-- reset).
--
-- Returns: newState, event
--   event is one of "applied", "consumed", "consumed-idle", or nil (the
--   spell was unrelated to Echo, or a redundant apply while already running).
function Core.HandleSpellCast(state, spellID, now, spellSets)
    state = state or { running = false, startedAt = nil }

    if Core.IsApplySpell(spellID, spellSets) then
        if state.running then
            return state, nil
        end
        return { running = true, startedAt = now }, "applied"
    end

    if Core.IsConsumeSpell(spellID, spellSets) then
        if state.running then
            return { running = false, startedAt = nil }, "consumed"
        end
        return state, "consumed-idle"
    end

    return state, nil
end

-- Seconds left in the countdown; 0 while idle. Clamped to [0, duration] so a
-- clock rollback (or the countdown simply running out because it was never
-- consumed) can never display a negative or over-full time. Deliberately
-- does NOT auto-expire back to idle at 0 - see HandleSpellCast above, only
-- an actual consume clears it.
function Core.GetRemaining(state, now, duration)
    duration = duration or 20
    if not (state and state.running and state.startedAt) then return 0 end
    local remaining = duration - (now - state.startedAt)
    if remaining < 0 then return 0 end
    if remaining > duration then return duration end
    return remaining
end

-- Cosmetic freshness tier used to color the timer: "fresh" -> "aging" ->
-- "stale" as the countdown runs low. This is a nudge about how much time is
-- probably left, not a guaranteed buff countdown - the addon tracks casts,
-- not the actual aura/target.
function Core.GetFreshnessTier(remaining, duration)
    duration = duration or 20
    if remaining <= duration / 3 then return "stale" end
    if remaining <= duration * 2 / 3 then return "aging" end
    return "fresh"
end

-- Whether the tracker/frame should be active at all: only ever true for a
-- Preservation Evoker. Kept pure (fed already-resolved class/spec values)
-- so the class/spec gating decision is unit-testable without a real client;
-- TurmoilsAddon.lua:IsPreservationEvoker() is the thin WoW-API wrapper.
function Core.ShouldBeActive(classToken, specID, preservationSpecID)
    return classToken == "EVOKER" and specID == preservationSpecID
end

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
-- Casting an apply spell (Echo) always (re)starts the timer, even if it was
-- already running - re-applying Echo means the old one no longer matters.
-- Casting a consume spell resets the timer to 0 only if one was actually
-- running; consuming with no Echo active is a no-op (nothing to reset).
--
-- Returns: newState, event
--   event is one of "applied", "consumed", "consumed-idle", or nil (spell
--   was unrelated to Echo).
function Core.HandleSpellCast(state, spellID, now, spellSets)
    state = state or { running = false, startedAt = nil }

    if Core.IsApplySpell(spellID, spellSets) then
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

-- Seconds elapsed since the timer started; 0 while idle. Clamped at 0 so a
-- clock rollback (or a bad `now`) can never display a negative time.
function Core.GetElapsed(state, now)
    if not (state and state.running and state.startedAt) then return 0 end
    local elapsed = now - state.startedAt
    if elapsed < 0 then return 0 end
    return elapsed
end

-- Cosmetic freshness tier used to color the timer: "fresh" -> "aging" ->
-- "stale". This is a nudge about how long Echo has sat un-consumed, not a
-- real buff countdown - the addon tracks casts, not the actual aura/target,
-- so it can't know the true remaining duration. staleThreshold defaults to
-- Echo's baseline 12s duration.
function Core.GetFreshnessTier(elapsed, staleThreshold)
    staleThreshold = staleThreshold or 12
    if elapsed >= staleThreshold then return "stale" end
    if elapsed >= staleThreshold * 0.66 then return "aging" end
    return "fresh"
end

-- Whether the tracker/frame should be active at all: only ever true for a
-- Preservation Evoker. Kept pure (fed already-resolved class/spec values)
-- so the class/spec gating decision is unit-testable without a real client;
-- TurmoilsAddon.lua:IsPreservationEvoker() is the thin WoW-API wrapper.
function Core.ShouldBeActive(classToken, specID, preservationSpecID)
    return classToken == "EVOKER" and specID == preservationSpecID
end

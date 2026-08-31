local Test = _G.TA_TEST
local Core = _G.TA_TEST_ADDON.EchoLogic

local SPELL_SETS = {
    apply = { [364343] = true, [373861] = true }, -- Echo, Temporal Anomaly
    consume = { [355936] = true, [360995] = true }, -- Dream Breath, Verdant Embrace
}

Test.case("classifies apply and consume spells correctly", function()
    Test.truthy(Core.IsApplySpell(364343, SPELL_SETS))
    Test.truthy(Core.IsApplySpell(373861, SPELL_SETS))
    Test.falsy(Core.IsApplySpell(355936, SPELL_SETS))
    Test.truthy(Core.IsConsumeSpell(355936, SPELL_SETS))
    Test.falsy(Core.IsConsumeSpell(364343, SPELL_SETS))
    Test.falsy(Core.IsConsumeSpell(99999, SPELL_SETS))
end)

Test.case("casting Echo while idle starts the countdown", function()
    local state, event = Core.HandleSpellCast({ running = false }, 364343, 100, SPELL_SETS)
    Test.equal(event, "applied")
    Test.truthy(state.running)
    Test.equal(state.startedAt, 100)
end)

Test.case("casting Temporal Anomaly while idle also starts the countdown", function()
    local state, event = Core.HandleSpellCast({ running = false }, 373861, 100, SPELL_SETS)
    Test.equal(event, "applied")
    Test.truthy(state.running)
    Test.equal(state.startedAt, 100)
end)

Test.case("re-casting an apply spell while already running is a no-op, not a restart", function()
    local running = { running = true, startedAt = 100 }
    local state, event = Core.HandleSpellCast(running, 364343, 108, SPELL_SETS)
    Test.equal(event, nil)
    Test.equal(state, running)
    Test.equal(state.startedAt, 100, "startedAt must not move")
end)

Test.case("casting the other apply spell while already running is also a no-op", function()
    local running = { running = true, startedAt = 100 }
    local state, event = Core.HandleSpellCast(running, 373861, 108, SPELL_SETS)
    Test.equal(event, nil)
    Test.equal(state.startedAt, 100)
end)

Test.case("a consume spell resets a running timer to idle", function()
    local running = { running = true, startedAt = 100 }
    local state, event = Core.HandleSpellCast(running, 355936, 106, SPELL_SETS)
    Test.equal(event, "consumed")
    Test.falsy(state.running)
    Test.equal(state.startedAt, nil)
end)

Test.case("a consume spell with no Echo running is a no-op", function()
    local idle = { running = false, startedAt = nil }
    local state, event = Core.HandleSpellCast(idle, 360995, 106, SPELL_SETS)
    Test.equal(event, "consumed-idle")
    Test.falsy(state.running)
    Test.equal(state, idle, "idle state table should be returned unchanged")
end)

Test.case("an unrelated spell cast does not change state or fire an event", function()
    local running = { running = true, startedAt = 100 }
    local state, event = Core.HandleSpellCast(running, 12345, 106, SPELL_SETS)
    Test.equal(event, nil)
    Test.equal(state, running)
end)

Test.case("HandleSpellCast tolerates a nil starting state", function()
    local state, event = Core.HandleSpellCast(nil, 364343, 50, SPELL_SETS)
    Test.equal(event, "applied")
    Test.equal(state.startedAt, 50)
end)

Test.case("GetRemaining is 0 while idle", function()
    Test.equal(Core.GetRemaining({ running = false }, 500, 20), 0)
    Test.equal(Core.GetRemaining(nil, 500, 20), 0)
end)

Test.case("GetRemaining counts down from the full duration", function()
    Test.equal(Core.GetRemaining({ running = true, startedAt = 100 }, 100, 20), 20)
    Test.equal(Core.GetRemaining({ running = true, startedAt = 100 }, 105.5, 20), 14.5)
end)

Test.case("GetRemaining clamps to 0 once the duration has fully elapsed (no auto-reset)", function()
    Test.equal(Core.GetRemaining({ running = true, startedAt = 100 }, 130, 20), 0)
end)

Test.case("GetRemaining clamps to the duration if `now` is before startedAt", function()
    Test.equal(Core.GetRemaining({ running = true, startedAt = 100 }, 90, 20), 20)
end)

Test.case("GetFreshnessTier moves fresh -> aging -> stale as time runs out", function()
    Test.equal(Core.GetFreshnessTier(20, 20), "fresh")
    Test.equal(Core.GetFreshnessTier(14, 20), "fresh")
    Test.equal(Core.GetFreshnessTier(13, 20), "aging")
    Test.equal(Core.GetFreshnessTier(6.7, 20), "aging")
    Test.equal(Core.GetFreshnessTier(6.6, 20), "stale")
    Test.equal(Core.GetFreshnessTier(0, 20), "stale")
end)

Test.case("ShouldBeActive is only true for a Preservation Evoker", function()
    Test.truthy(Core.ShouldBeActive("EVOKER", 1468, 1468))
    Test.falsy(Core.ShouldBeActive("PRIEST", 1468, 1468))
    Test.falsy(Core.ShouldBeActive("EVOKER", 1467, 1468)) -- Devastation
    Test.falsy(Core.ShouldBeActive("EVOKER", nil, 1468))
end)

local Test = _G.TA_TEST
local Core = _G.TA_TEST_ADDON.EchoLogic

local SPELL_SETS = {
    apply = { [364343] = true },
    consume = { [355936] = true, [367226] = true, [360995] = true },
}

Test.case("classifies apply and consume spells correctly", function()
    Test.truthy(Core.IsApplySpell(364343, SPELL_SETS))
    Test.falsy(Core.IsApplySpell(355936, SPELL_SETS))
    Test.truthy(Core.IsConsumeSpell(355936, SPELL_SETS))
    Test.falsy(Core.IsConsumeSpell(364343, SPELL_SETS))
    Test.falsy(Core.IsConsumeSpell(99999, SPELL_SETS))
end)

Test.case("casting Echo starts the timer", function()
    local state, event = Core.HandleSpellCast({ running = false }, 364343, 100, SPELL_SETS)
    Test.equal(event, "applied")
    Test.truthy(state.running)
    Test.equal(state.startedAt, 100)
end)

Test.case("re-casting Echo while running restarts the timer at the new time", function()
    local running = { running = true, startedAt = 100 }
    local state, event = Core.HandleSpellCast(running, 364343, 108, SPELL_SETS)
    Test.equal(event, "applied")
    Test.truthy(state.running)
    Test.equal(state.startedAt, 108)
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
    local state, event = Core.HandleSpellCast(idle, 367226, 106, SPELL_SETS)
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

Test.case("GetElapsed is 0 while idle", function()
    Test.equal(Core.GetElapsed({ running = false }, 500), 0)
    Test.equal(Core.GetElapsed(nil, 500), 0)
end)

Test.case("GetElapsed reports seconds since start while running", function()
    Test.equal(Core.GetElapsed({ running = true, startedAt = 100 }, 104.5), 4.5)
end)

Test.case("GetElapsed clamps negative durations to 0", function()
    Test.equal(Core.GetElapsed({ running = true, startedAt = 100 }, 90), 0)
end)

Test.case("GetFreshnessTier moves fresh -> aging -> stale", function()
    Test.equal(Core.GetFreshnessTier(0, 12), "fresh")
    Test.equal(Core.GetFreshnessTier(7, 12), "fresh")
    Test.equal(Core.GetFreshnessTier(8, 12), "aging")
    Test.equal(Core.GetFreshnessTier(11.9, 12), "aging")
    Test.equal(Core.GetFreshnessTier(12, 12), "stale")
    Test.equal(Core.GetFreshnessTier(30, 12), "stale")
end)

Test.case("ShouldBeActive is only true for a Preservation Evoker", function()
    Test.truthy(Core.ShouldBeActive("EVOKER", 1468, 1468))
    Test.falsy(Core.ShouldBeActive("PRIEST", 1468, 1468))
    Test.falsy(Core.ShouldBeActive("EVOKER", 1467, 1468)) -- Devastation
    Test.falsy(Core.ShouldBeActive("EVOKER", nil, 1468))
end)

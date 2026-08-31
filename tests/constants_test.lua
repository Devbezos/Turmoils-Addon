-- Guards the real spell ID tables in TurmoilsAddon_Constants.lua against
-- typos - these are the actual game data the whole addon depends on.
local Test = _G.TA_TEST
local Core = _G.TA_TEST_ADDON.EchoLogic

Test.case("constants file loads and publishes a global table", function()
    local chunk, loadError = loadfile("constants/TurmoilsAddon_Constants.lua")
    Test.truthy(chunk, loadError)
    chunk()
    Test.truthy(type(_G.TurmoilsAddon_CONSTANTS) == "table")
end)

local function GetSpellSets()
    return {
        apply = _G.TurmoilsAddon_CONSTANTS.applySpellIDs,
        consume = _G.TurmoilsAddon_CONSTANTS.consumeSpellIDs,
    }
end

Test.case("Echo and Temporal Anomaly are both classified as apply spells", function()
    local sets = GetSpellSets()
    Test.truthy(Core.IsApplySpell(364343, sets), "Echo (364343) should apply")
    Test.truthy(Core.IsApplySpell(373861, sets), "Temporal Anomaly (373861) should apply")
    Test.falsy(Core.IsConsumeSpell(364343, sets), "Echo should not also be a consume spell")
    Test.falsy(Core.IsConsumeSpell(373861, sets), "Temporal Anomaly should not also be a consume spell")
end)

Test.case("known Echo-consuming heals are classified as consume spells", function()
    local sets = GetSpellSets()
    local expectedConsumers = {
        [355936] = "Dream Breath",
        [360995] = "Verdant Embrace",
        [361469] = "Living Flame",
        [366155] = "Reversion",
        [1256581] = "Merithra's Blessing",
    }
    for spellID, spellName in pairs(expectedConsumers) do
        Test.truthy(Core.IsConsumeSpell(spellID, sets), spellName .. " (" .. spellID .. ") should consume Echo")
        Test.falsy(Core.IsApplySpell(spellID, sets), spellName .. " should not also apply Echo")
    end
end)

Test.case("Spiritbloom is not classified as anything (removed from the game)", function()
    local sets = GetSpellSets()
    Test.falsy(Core.IsApplySpell(367226, sets))
    Test.falsy(Core.IsConsumeSpell(367226, sets))
end)

Test.case("Emerald Blossom no longer consumes Echo", function()
    local sets = GetSpellSets()
    Test.falsy(Core.IsConsumeSpell(355913, sets))
end)

Test.case("preservationSpecID matches the known Preservation spec ID", function()
    Test.equal(_G.TurmoilsAddon_CONSTANTS.preservationSpecID, 1468)
end)

Test.case("default echo duration is 20 seconds", function()
    Test.equal(_G.TurmoilsAddon_CONSTANTS.defaults.global.echoDuration, 20)
end)

Test.case("Dream Breath is flagged as an empower-type spell", function()
    Test.truthy(_G.TurmoilsAddon_CONSTANTS.empowerSpellIDs[355936])
end)

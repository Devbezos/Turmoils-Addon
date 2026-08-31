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

Test.case("Echo is classified as the apply spell", function()
    local sets = {
        apply = _G.TurmoilsAddon_CONSTANTS.applySpellIDs,
        consume = _G.TurmoilsAddon_CONSTANTS.consumeSpellIDs,
    }
    Test.truthy(Core.IsApplySpell(364343, sets), "Echo (364343) should apply")
    Test.falsy(Core.IsConsumeSpell(364343, sets), "Echo should not also be a consume spell")
end)

Test.case("all known Echo-consuming heals are classified as consume spells", function()
    local sets = {
        apply = _G.TurmoilsAddon_CONSTANTS.applySpellIDs,
        consume = _G.TurmoilsAddon_CONSTANTS.consumeSpellIDs,
    }
    local expectedConsumers = {
        [355936] = "Dream Breath",
        [367226] = "Spiritbloom",
        [360995] = "Verdant Embrace",
        [355913] = "Emerald Blossom",
        [373861] = "Temporal Anomaly",
        [361469] = "Living Flame",
    }
    for spellID, spellName in pairs(expectedConsumers) do
        Test.truthy(Core.IsConsumeSpell(spellID, sets), spellName .. " (" .. spellID .. ") should consume Echo")
        Test.falsy(Core.IsApplySpell(spellID, sets), spellName .. " should not also apply Echo")
    end
end)

Test.case("preservationSpecID matches the known Preservation spec ID", function()
    Test.equal(_G.TurmoilsAddon_CONSTANTS.preservationSpecID, 1468)
end)

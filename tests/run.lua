-- Test runner. Usage: lua tests/run.lua (run from the repo root).
local Test = dofile("tests/test_helper.lua")
_G.TA_TEST = Test
_G.TA_TEST_ADDON = {}

local Harness = dofile("tests/wow_mock.lua")
_G.TA_HARNESS = Harness
Harness.installGlobals()

local addonName = "TA_TEST_ADDON"
Harness.load(addonName, "core/TurmoilsAddon_EchoLogic.lua")

dofile("tests/echo_logic_test.lua")
dofile("tests/constants_test.lua")
dofile("tests/tracker_integration_test.lua")

print(string.format("1..%d", Test.total))
if Test.failed > 0 then
    error(string.format("%d of %d tests failed", Test.failed, Test.total), 0)
end
print(string.format("All %d tests passed.", Test.total))

-- Minimal TAP-style test harness. No external dependencies (no LuaRocks,
-- no busted) so `lua tests/run.lua` is all that's needed to run the suite.
local Test = { total = 0, failed = 0 }

function Test.case(name, callback)
    Test.total = Test.total + 1
    local ok, err = pcall(callback)
    if ok then
        print("ok " .. Test.total .. " - " .. name)
        return
    end
    Test.failed = Test.failed + 1
    print("not ok " .. Test.total .. " - " .. name)
    print("  " .. tostring(err))
end

function Test.equal(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected)
            .. ", got " .. tostring(actual), 2)
    end
end

function Test.truthy(value, message)
    if not value then error(message or "expected a truthy value", 2) end
end

function Test.falsy(value, message)
    if value then error(message or "expected a falsey value", 2) end
end

function Test.notEqual(actual, unexpected, message)
    if actual == unexpected then
        error((message or "values unexpectedly match") .. ": " .. tostring(actual), 2)
    end
end

function Test.nearly(actual, expected, tolerance, message)
    tolerance = tolerance or 0.001
    if math.abs((actual or 0) - expected) > tolerance then
        error((message or "values differ") .. ": expected ~" .. tostring(expected)
            .. ", got " .. tostring(actual), 2)
    end
end

return Test

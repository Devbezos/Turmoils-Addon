std = "lua51"
codes = true
max_line_length = false

-- WoW API names are runtime-provided globals. Keep undefined-global checks
-- out of the baseline while retaining Luacheck's local, control-flow, and
-- hygiene diagnostics across first-party code.
ignore = {
    "111", -- setting a non-standard global
    "112", -- mutating a non-standard global
    "113", -- accessing an undefined global
    "212", -- unused callback/method argument (WoW handler signatures and mock stubs)
}

exclude_files = {
    "lib/**",
}

-- core/ has no WoW-global dependency at all, so keep the full Luacheck
-- rule set (including 111/112/113) enabled there.
files["core/*.lua"] = { ignore = {} }

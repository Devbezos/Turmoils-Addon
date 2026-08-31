-- TurmoilsAddon_Constants.lua
-- Pure data only - no WoW API calls, no dependency on the Addon object. This
-- file loads first (see the .toc) and publishes a plain global table that
-- TurmoilsAddon.lua reads once the Ace3 addon object exists. Keeping it a
-- standalone global (instead of writing into _G[addonName]) means this file
-- never has to care what order it loads relative to the main file.
--
-- If Blizzard ever renumbers these spells, this is the one file to edit.

TurmoilsAddon_CONSTANTS = {
    -- Spells that start the countdown. Casting either of these while the
    -- timer is already running is a no-op - it does not restart it.
    applySpellIDs = {
        [364343] = true, -- Echo
        [373861] = true, -- Temporal Anomaly
    },

    -- Preservation Evoker heals that consume an active Echo and reset the
    -- countdown back to idle.
    consumeSpellIDs = {
        [355936] = true,  -- Dream Breath
        [360995] = true,  -- Verdant Embrace
        [361469] = true,  -- Living Flame
        [366155] = true,  -- Reversion
        [1256689] = true, -- Merithra's Blessing
    },

    -- Preservation is spec index/ID 1468 (Devastation 1467, Augmentation 1473).
    preservationSpecID = 1468,

    defaults = {
        global = {
            firstRunSeen = false,
            locked = false,
            scale = 1.0,
            autoHideWhenIdle = false,
            soundOnConsume = false,
            echoDuration = 20, -- seconds; the countdown starts here and only resets on an actual consume
        },
    },

    -- A little something extra. Shows once on first login, and any time from
    -- the options panel afterwards - never spammed, never shown to anyone
    -- but him.
    welcomeMessage = "|cff5cdff9Turmoil's Addon|r is live. A little gift, healer to healer" ..
        " - may your Echoes never go to waste. |cff2ecc71\226\153\165|r",
    tooltipFlavorText = "Made with a little extra care, just for you. |cff2ecc71\226\153\165|r",
}

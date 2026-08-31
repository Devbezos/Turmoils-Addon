# Turmoil's Addon

A tiny World of Warcraft addon for Preservation Evokers: it starts a timer
the moment you cast **Echo**, and resets it to `0` the moment you consume it
with **Dream Breath**, **Spiritbloom**, **Verdant Embrace**, **Emerald
Blossom**, **Temporal Anomaly**, or a healing **Living Flame**. A thin bar
underneath the number goes from green to amber to red as the timer runs, as
a nudge that an un-consumed Echo is going stale.

It only ever activates while you're actually playing Preservation - it stays
completely invisible on every other class and spec.

## Using it in-game

- The frame is draggable by default: left-click-drag to move it.
- Right-click it (or run `/turmoil`) to open the options panel: lock
  position, scale, hide-when-idle, a sound on consume, and how many seconds
  before the bar reads "stale".
- `/turmoil lock`, `/turmoil unlock`, `/turmoil reset` also work directly.

## How it works

The design is deliberately cast-based rather than aura-based: it watches
*you pressing the button* (`UNIT_SPELLCAST_SUCCEEDED` for the player), not
whether the Echo buff is still actually sitting on a target. That matches
the ask directly and sidesteps combat-log latency and multi-target
ambiguity. The one tradeoff: pressing a "consuming" spell resets the timer
even if nothing was actually echoed - harmless, since resetting an idle
timer is a no-op.

```
core/TurmoilsAddon_EchoLogic.lua      <- pure state machine, zero WoW API calls
features/TurmoilsAddon_EchoTracker.lua <- WoW glue: registers the cast event, drives EchoLogic
features/TurmoilsAddon_TimerFrame.lua  <- the on-screen frame (movable, lockable, LibWindow-backed)
features/TurmoilsAddon_Options.lua     <- options panel + /turmoil slash command
constants/TurmoilsAddon_Constants.lua  <- spell IDs, defaults, and text - the one edit spot for game data
```

This mirrors the structure of [Larias' Weekly
Checklist](../Larias-Weekly-Midnight-Checklist): pure decision logic kept
separate from anything that touches the WoW API, so the logic can be unit
tested with a plain Lua interpreter and no game client.

## Development

Requires [Lua 5.1](https://luabinaries.sourceforge.net/) and
[luacheck](https://github.com/mpeterv/luacheck) on `PATH` (or in their usual
Windows install locations).

```powershell
lua tests/run.lua                                   # run the test suite
luacheck TurmoilsAddon.lua constants core features tests
.\scripts\deploy_to_wow.ps1                          # validate, then copy into local WoW installs
.\scripts\deploy_to_wow.ps1 -ValidateOnly            # just validate, don't copy
```

`tests/` uses a small hand-rolled TAP-style runner (`tests/test_helper.lua`)
and a minimal WoW API mock (`tests/wow_mock.lua`) - same pattern as Larias'
`tests/`, scaled down to what this addon actually needs.

## Libraries

Ships with LibStub, CallbackHandler-1.0, AceAddon-3.0, AceEvent-3.0,
AceDB-3.0, AceConsole-3.0, and LibWindow-1.1 under `lib/`, committed
directly rather than fetched via a packager - this is a single-recipient
gift addon, not a CurseForge release, so "unzip and go" mattered more than
packager hygiene.

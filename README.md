# Turmoil's Addon

A tiny World of Warcraft addon for Preservation Evokers: the moment you cast
**Echo** or **Temporal Anomaly**, it starts a 20-second countdown (adjustable
in options). Casting either one again while it's already running does
*nothing* - it does not restart the clock. The countdown only clears back to
idle when you actually consume it with **Dream Breath**, **Verdant
Embrace**, **Reversion**, or **Merithra's Blessing**. If it's never
consumed, it holds at `0` - visibly red - rather than quietly resetting
itself, since the whole point is to notice a wasted Echo, not paper over
it. A thin bar underneath the number shrinks from green to amber to red as
time runs out.

(Living Flame deliberately doesn't count as a consume, even though it can
also consume Echo as a heal - it's the same spell ID whether cast
offensively or as a heal, and it's pressed offensively far more often, so
including it meant the timer kept getting reset by damage casts.)

It only ever activates while you're actually playing Preservation - it stays
completely invisible on every other class and spec.

## Using it in-game

- The frame is draggable by default: left-click-drag to move it.
- Right-click it (or run `/turmoil`) to open the options panel: lock
  position, width/height, scale, hide out of combat, a sound on consume,
  and the countdown duration. Width/height and scale are independent - resize
  it to fit a tight spot without the border/font scaling along with it, or
  use scale to just magnify the whole thing uniformly.
- `/turmoil lock`, `/turmoil unlock`, `/turmoil reset` also work directly.

## How it works

The design is deliberately cast-based rather than aura-based: it watches
*you pressing the button* (`UNIT_SPELLCAST_SUCCEEDED` for the player), not
whether the Echo buff is still actually sitting on a target. That matches
the ask directly and sidesteps combat-log latency and multi-target
ambiguity. Two tradeoffs, both intentional: pressing a "consuming" spell
resets the timer even if nothing was actually echoed (harmless - resetting
an idle timer is a no-op), and pressing an "applying" spell again while
already running does not restart the countdown.

Dream Breath needs one more wrinkle: it's an Empower spell (hold to charge,
release to cast), and WoW fires `UNIT_SPELLCAST_SUCCEEDED` for it the
instant the empower *starts*, not when you release it - a client quirk, not
a bug here. `constants.empowerSpellIDs` flags spells like this so the
tracker ignores `SUCCEEDED` for them and instead uses
`UNIT_SPELLCAST_EMPOWER_STOP`, which fires on release/completion.

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

# SD/HD Toggle (World of Warcraft: Forever)

A round button on the minimap, like most addons have, with yellow text inside that reads **HD**
or **SD**. Click it and the game switches to the other set of character models. That is the
whole addon.

Drag the button around the minimap ring to put it where you like. If you would rather have a
free-floating box anywhere on the screen, `/sdhd mode box` gives you that instead. The same
switch is also on a key binding and a slash command, and the button can be locked or hidden.

Targets the live Forever client (interface `16001`, build 1.60.1). The API calls were checked
against Blizzard's UI source for that build (the `forever` branch of `Gethe/wow-ui-source`,
commit for 1.60.1.70862, Nov 7 2026).

## Install

1. Copy the `SDHDToggle` folder into
   `World of Warcraft\_forever_\Interface\AddOns\SDHDToggle`
   (the folder must be named `SDHDToggle`, the same as the `.toc` file).
2. Restart the game or `/reload`.

The round button appears on the lower-left edge of the minimap. Drag it around the ring to
move it.

## Use

| Action | What it does |
|---|---|
| Left-click the button | switch between SD and HD models |
| Drag the button | slide it around the minimap ring (or anywhere, in box mode) |
| Right-click the button | lock it in place (right-click again to unlock) |
| `/sdhd` | switch |
| `/sdhd sd`, `/sdhd hd` | switch to a specific one |
| `/sdhd show`, `/sdhd hide`, `/sdhd button` | show, hide, or toggle the button |
| `/sdhd mode minimap`, `/sdhd mode box` | round minimap button (default) or a free-floating box |
| `/sdhd lock`, `/sdhd unlock`, `/sdhd reset` | lock, unlock, or put the button back at the default spot |
| `/sdhd scale <0.5 - 3>` | resize the box (box mode only) |
| `/sdhd sound on\|off`, `/sdhd announce on\|off` | the click sound and the chat line on each switch |
| `/sdhd key <KEY>` | bind a key to the switch, e.g. `/sdhd key F10` |
| `/sdhd status` | what is active now, and the bound key |

Key bindings also appear under Options > Keybindings > AddOns as
"SD/HD Toggle: switch models" and "SD/HD Toggle: show/hide the button".

## How it works

The Forever client exposes the switch to addons on the `C_GameRules` namespace:

| Call | Purpose |
|---|---|
| `C_GameRules.IsSDHDToggleEnabled()` | whether the choice is offered at all on this realm / account |
| `C_GameRules.AccountHasSDEnabled()` | `true` while SD models are active |
| `C_GameRules.SetSDHDToggleValue(setToSD, usageLocation)` | flip it; `usageLocation` is `Enum.SdToggleUsageLocationUI` (`BeforeLogin`, `CharacterCreation`, `BarberShop`, `OptionsMenu`) |

Blizzard's own Barbershop checkbox (`BarberShopSDToggleMixin` in `Blizzard_BarberShopUI.lua`)
calls exactly these three functions from a plain `OnClick`. None of them is flagged
`HasRestrictions` in the API documentation, so unlike buying on the auction house, no hardware
event is needed and no reload follows: the click handler calls the setter and the models change.
The addon reports itself as `OptionsMenu`, the closest match for an in-world button.

The value is account wide (the getter is literally "AccountHas..."), so one click changes it for
every character you log in with, the same as changing it in the Options menu.

No event fires when the value changes, so the addon re-reads the getter twice a second and fixes
the label if the Barbershop or the Options menu changed it behind its back.

The minimap button is the standard 31 px round button with Blizzard's `MiniMap-TrackingBorder`
ring, positioned on a circle of radius 80 around the minimap centre at a saved angle; dragging
sets the angle from the cursor's direction. It assumes a round minimap.

If the client has no `C_GameRules.SetSDHDToggleValue` (an older build) the label reads `?` and a
click prints a message instead of erroring. If `IsSDHDToggleEnabled()` is false, the button
hides itself and `/sdhd` explains why.

## Development

`tests/` holds a headless harness that stubs the client, including the three `C_GameRules`
calls, and drives the addon through minimap click and ring drag, box mode, key, slash commands,
polling, hide/lock/drag, the toggle-disabled case and the no-API case. Run it with Lua 5.1, the game's Lua version:

```bash
python3 tests/run.py
```

It needs `lua5.1` on PATH or `pip install lupa`.

## Things to verify in game

- Whether the model swap after a click is instant or shows a brief reload of nearby characters.
  Blizzard's Barbershop refreshes only its preview model after the call; the world refresh is
  the client's own business.
- Whether `AccountHasSDEnabled()` reflects the new value on the same frame as the setter. If it
  lags, the label catches up within half a second from the poll.
- Whether the realm has the toggle enabled at all. `/sdhd status` tells you.
- If you use a square-minimap addon, the button follows a circle anyway. Drag it to a corner
  that looks right, or use `/sdhd mode box`.

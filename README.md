# Quick Toggle (World of Warcraft: Forever)

Round buttons on the minimap ring, one per game setting, each flipped with a single click.
Pick which ones you want from a menu. Two toggles so far:

| Toggle | Button | What a click does |
|---|---|---|
| **SD / HD** | yellow **HD** or **SD** text | switches every character model between Standard and High Definition |
| **Music** | yellow musical note, red **X** over it while off | turns the game music on or off |

Every button can be dragged around the minimap ring, and the whole set can be locked or hidden.
Each toggle also has a key binding and a slash command.

Targets the live Forever client (interface `16001`, build 1.60.1). The API calls were checked
against Blizzard's UI source for that build (the `forever` branch of `Gethe/wow-ui-source`,
commit for 1.60.1.70862, Nov 7 2026).

## Install

1. Copy the `QuickToggle` folder into
   `World of Warcraft\_forever_\Interface\AddOns\QuickToggle`
   (the folder must be named `QuickToggle`, the same as the `.toc` file).
2. Restart the game or `/reload`.

Both buttons appear on the lower-left edge of the minimap. Drag them around the ring to move
them. If you had the earlier SD/HD Toggle addon installed, delete its `SDHDToggle` folder; this
replaces it.

## Use

| Action | What it does |
|---|---|
| Left-click a button | flip that setting |
| Drag a button | slide it around the minimap ring |
| Right-click a button, or `/qt` | open the menu: tick the toggles you want as buttons, lock them, reset positions |
| `/qt music`, `/qt sdhd` | flip a setting from chat |
| `/qt music on\|off`, `/qt sdhd sd\|hd` | set it to a specific value |
| `/qt enable <toggle>`, `/qt disable <toggle>` | show or hide one button (same as the menu ticks) |
| `/qt list` | every toggle, whether its button is on, and the current value |
| `/qt show`, `/qt hide` | all buttons at once |
| `/qt lock`, `/qt unlock`, `/qt reset` | lock, unlock, or put the buttons back at their default spots |
| `/qt sound on\|off`, `/qt announce on\|off` | the click sound and the chat line on each flip |
| `/qt key <toggle> <KEY>` | bind a key, e.g. `/qt key music F11` |

Key bindings also appear under Options > Keybindings > AddOns as "Quick Toggle: SD / HD
models", "Quick Toggle: music on / off" and "Quick Toggle: open the menu".

## How each toggle works

**SD / HD.** The Forever client exposes the switch on `C_GameRules`:
`IsSDHDToggleEnabled()` says whether the choice is offered on this realm or account,
`AccountHasSDEnabled()` is `true` while SD models are active, and
`SetSDHDToggleValue(setToSD, usageLocation)` flips it (`usageLocation` is
`Enum.SdToggleUsageLocationUI`; we report `OptionsMenu`). Blizzard's own Barbershop checkbox
(`BarberShopSDToggleMixin`) calls exactly these three from a plain `OnClick`, none is flagged
`HasRestrictions`, so no hardware event or reload is needed. The value is account wide. No event
fires when it changes, so the addon re-reads it twice a second and fixes the label if the
Barbershop or the Options menu changed it.

**Music.** The game keeps this in the `Sound_EnableMusic` console variable (`"1"` / `"0"`).
Blizzard's own music hotkey (`Sound_ToggleMusic` in `Blizzard_SharedXML/Sound.lua`) flips that
same variable, so the two stay in step, and `CVAR_UPDATE` fires with its name whenever it
changes, so the red X appears and disappears at once. If all sound is off in Options the
tooltip says so, since music will not play either way.

## Adding a toggle

Each toggle is one small file in `QuickToggle/Toggles/`, listed in the `.toc`, that calls
`QuickToggle:Register{...}` with: a `key` and `name`, `Get` and `Set` for the setting, `Create`
and `Update` to draw the inside of the button, and optionally `IsAvailable`, `Describe`, `Parse`
(for `/qt <key> <value>`), `Tooltip`, `events` to re-read on, and `defaultAngle`. Add a
`QUICKTOGGLE_<KEY>` line to `Bindings.xml` and a `BINDING_NAME_QUICKTOGGLE_<KEY>` string to get a
key binding. `Toggles/Music.lua` is the smallest example. The core handles the minimap button,
dragging, the menu entry, polling, the slash command and saved settings.

The minimap buttons are the standard 31 px round button with Blizzard's `MiniMap-TrackingBorder`
ring, placed on a circle of radius half the minimap's live width plus 5 px, so they land on the
outer ring whatever size the minimap is. The menu uses the client's `MenuUtil.CreateContextMenu`
when present and a plain frame otherwise. Square-minimap addons are not accounted for; drag the
buttons to a corner that looks right.

## Development

`tests/` holds a headless harness that stubs the client (the three `C_GameRules` calls, console
variables with `CVAR_UPDATE`, frames, tooltips, bindings) and drives the addon through both
toggles, external changes, dragging, the menu, slash commands, key bindings, the realm-disabled
case and the missing-API case. Run it with Lua 5.1, the game's Lua version:

```bash
python3 tests/run.py
```

It needs `lua5.1` on PATH or `pip install lupa`.

## Things to verify in game

- Whether the model swap after an SD/HD click is instant or shows a brief reload of nearby
  characters. The addon only calls the setter; the world refresh is the client's business.
- The musical note is drawn from three textures (round head, stem, angled flag). If the flag
  looks off on your display, say so and it can be tuned.
- Whether your realm has the SD/HD switch enabled. `/qt list` tells you.

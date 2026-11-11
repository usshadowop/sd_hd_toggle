# Quick Toggle (World of Warcraft: Forever)

Round buttons on the minimap ring, one per game setting, each flipped with a single click,
plus a small panel of quick-access sliders with an undo button each. Right-click any of them
for a menu where you tick which ones you want.

Minimap buttons:

| Toggle | Button | What a click does |
|---|---|---|
| **SD / HD** | yellow **HD** or **SD** text | switches every character model between Standard and High Definition |
| **Music** | yellow musical note, always shown, with a red **X** over it while off | turns the game music on or off |

Sliders, in one small panel that sits under the minimap by default:

| Slider | What it does |
|---|---|
| **Brightness** | the game's brightness, 0 to 100%, same as Options > Graphics |
| **Contrast** | the game's contrast, 0 to 100%, same as Options > Graphics |
| **Gamma** | the game's gamma, 0.3 to 2.8 in steps of 0.1 (default 1.0), same as Options > Graphics. Brightens shadows and midtones without washing out highlights as much as brightness does |

Each slider row has an **undo** button. It remembers where the setting was before you first
moved the slider and puts it back with one click. Several adjustments in a row still undo to
the original value, and the undo point survives a `/reload`.

Every button can be dragged around the minimap ring, the slider panel can be dragged anywhere,
and the whole set can be locked or hidden. Each toggle also has a key binding and a slash
command.

Targets the live Forever client (interface `16001`, build 1.60.1). The API calls were checked
against Blizzard's UI source for that build (the `forever` branch of `Gethe/wow-ui-source`,
commit for 1.60.1.70862, Nov 7 2026).

## Install

1. Copy the `QuickToggle` folder into
   `World of Warcraft\_forever_\Interface\AddOns\QuickToggle`
   (the folder must be named `QuickToggle`, the same as the `.toc` file).
2. Restart the game or `/reload`.

The buttons appear on the lower-left edge of the minimap and the slider panel just below the
minimap. Drag them to move them. If you had the earlier SD/HD Toggle addon installed, delete its `SDHDToggle` folder; this
replaces it.

## Use

| Action | What it does |
|---|---|
| Left-click a button | flip that setting |
| Drag a button | slide it around the minimap ring |
| Right-click a button, the slider panel, a slider or an undo button, or `/qt` | open the menu: tick the buttons and sliders you want, lock them, reset positions |
| Drag a slider, click along it, or roll the mouse wheel over it | change that setting |
| Click a slider's undo button | put the setting back where it was before you moved the slider |
| `/qt brightness 60`, `/qt contrast 45`, `/qt gamma 1.2` | set a slider value from chat (also undoable) |
| `/qt brightness undo`, `/qt contrast undo`, `/qt gamma undo` | undo from chat |
| `/qt music`, `/qt sdhd` | flip a setting from chat |
| `/qt music on\|off`, `/qt sdhd sd\|hd` | set it to a specific value |
| `/qt enable <name>`, `/qt disable <name>` | show or hide one button or slider, e.g. `/qt disable contrast` (same as the menu ticks) |
| `/qt list` | every button and slider, whether it is on, the current value and any undo point |
| `/qt show`, `/qt hide` | all buttons and the slider panel at once |
| `/qt lock`, `/qt unlock`, `/qt reset` | lock, unlock, or put the buttons and slider panel back at their default spots |
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

**Brightness, Contrast and Gamma.** All three are console variables (`Brightness`,
`Contrast`, `Gamma`) that Blizzard's Options > Graphics page drives with
`Settings.SetupCVarSlider` in `Blizzard_SettingsDefinitions_Shared/Graphics.lua`, which loads on
Forever. Brightness and contrast run 0 to 100 in steps of 1 with a default of 50%; gamma runs
0.3 to 2.8 in steps of 0.1 with a default of 1.0, and is shown to one decimal like Blizzard
shows it. The addon writes the same variables, then
reads them back; if the game refuses a change it says so once and the slider snaps back to the
real value. `CVAR_UPDATE` keeps the sliders in step when the value is changed in Options.

## Adding a toggle

Each toggle is one small file in `QuickToggle/Toggles/`, listed in the `.toc`, that calls
`QuickToggle:Register{...}` with: a `key` and `name`, `Get` and `Set` for the setting, `Create`
and `Update` to draw the inside of the button, and optionally `IsAvailable`, `Describe`, `Parse`
(for `/qt <key> <value>`), `Tooltip`, `events` to re-read on, and `defaultAngle`. Add a
`QUICKTOGGLE_<KEY>` line to `Bindings.xml` and a `BINDING_NAME_QUICKTOGGLE_<KEY>` string to get a
key binding. `Toggles/Music.lua` is the smallest example. The core handles the minimap button,
dragging, the menu entry, polling, the slash command and saved settings.

A slider is even shorter: one `QuickToggle:RegisterSlider{ key, name, cvar, min, max, step }`
call in a file under `QuickToggle/Sliders/`, listed in the `.toc`. `Sliders/Display.lua`
declares brightness, contrast and gamma; gamma shows how to give a slider a fractional step and
its own `Format`. The panel, undo button, menu entry, `/qt <key>` command
and syncing come from `Sliders.lua`.

The minimap buttons are the standard 31 px round button with Blizzard's `MiniMap-TrackingBorder`
ring, placed on a circle of radius half the minimap's live width plus 5 px, so they land on the
outer ring whatever size the minimap is. The menu uses the client's `MenuUtil.CreateContextMenu`
when present and a plain frame otherwise. Square-minimap addons are not accounted for; drag the
buttons to a corner that looks right.

## Development

`tests/` holds a headless harness that stubs the client (the three `C_GameRules` calls, console
variables with `CVAR_UPDATE`, frames, tooltips, bindings) and drives the addon through both
toggles, all three sliders with undo (including gamma's 0.1 steps), external changes, dragging, right-click from every element,
the menu, slash commands, key bindings, a refused setting, the realm-disabled case and the
missing-API case. Run it with Lua 5.1, the game's Lua version:

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
- Brightness, contrast and gamma are applied by the game the same way the Options sliders apply them.
  If the game ever refuses them from an addon, the panel prints "the game did not accept the
  change" once; tell me and I'll look at it.

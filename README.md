# Quick Toggle (World of Warcraft: Forever)

Turn any setting in the game's Options window into a one-click control on your screen.

Open Esc > Options. Every setting there now has two small tick boxes at the left of its
row. Tick one and that setting gets a quick control:

| Setting type | First box | Second box (blue) |
|---|---|---|
| On/off (checkbox) | a **floating button**: yellow name, green check when on, red X when off | a **minimap button**: round, initials in yellow, red X over it when off |
| Dropdown (Low / Medium / High...) | a **floating button** showing the setting and its current choice: click for the next, shift-click to go back | a **minimap button** showing the current choice, shortened: click for the next |
| Slider | a **floating slider**: its own small block you can put anywhere | a row in the **shared slider panel**, with your other sliders |

On a dropdown's minimap button the current choice is shortened to fit: short labels stay as
they are, several words become their initials ("High Definition" shows **HD**, "Standard
Definition" shows **SD**), and one long word shows its first letter. On/off minimap buttons
show the setting's initials with the red X while off.

**Character Models** (Options > Graphics) is the SD / HD switch: tick its blue box for a
minimap button that reads HD or SD and switches every character model on a click.

Rows that combine a checkbox with a slider or dropdown get a second pair of boxes at the
row's right edge for the slider or dropdown part. Hover any box to see what it does.

So it's clear these boxes come from an add-on, each section's boxes hang off a yellow bracket:
**Quick Toggle** in the game's small label font, underlined, with a bar running down from the
underline to the bottom of the section and a short branch out to each row's boxes. Rows
without boxes are passed by. There's no box around it: no top, right or bottom edge. The
bracket follows the list as you scroll, and the right-edge pairs on combined rows get a short
bar of their own. `docs/bracket-mockup.png` shows the look.

Every slider, floating or in the panel, has an **undo** button that puts the setting back
where it was before you first moved the slider. Every control follows the game: change the
setting in Options and the control updates.

The hand-made controls from earlier versions are still here and plug into the same boxes:

- **Music** minimap button: a yellow note with a red X over it while music is off. It is what
  the Music row's minimap box in Options > Audio controls.
- **Brightness, Contrast and Gamma** rows in the shared slider panel. They are what those rows'
  panel boxes in Options > Graphics control.

Targets the live Forever client (interface `16001`, build 1.60.1). Everything was checked
against Blizzard's UI source for that build (the `forever` branch of `Gethe/wow-ui-source`,
commit for 1.60.1.70862, Nov 7 2026).

## Install

1. Copy the `QuickToggle` folder into
   `World of Warcraft\_forever_\Interface\AddOns\QuickToggle`
   (the folder must be named `QuickToggle`, the same as the `.toc` file).
2. Restart the game or `/reload`.

Your earlier Quick Toggle settings carry over, undo points included. If you had the old SD/HD
minimap button, it becomes the Character Models minimap button at the same spot.

## Use

| Action | What it does |
|---|---|
| Esc > Options, tick a box beside any setting | add a floating button, minimap button, floating slider or slider-panel row for it |
| Untick it | remove that control |
| Left-click a button | flip the setting, or go to the next choice for a dropdown |
| Shift-click a dropdown's button | go to the previous choice |
| Drag a slider, click along it, or roll the mouse wheel over it | change that setting |
| Click a slider's undo button | put the setting back where it was before you moved the slider |
| Drag a button, block or the panel | move it (minimap buttons slide around the ring) |
| Right-click any control, or `/qt` | the menu: every control you've added, by kind, with a tick to show or hide each; lock; reset positions; allow settings that run Blizzard code; a button to open Options and add more |

Options > AddOns > Quick Toggle has the same main switches: show everything, lock, and allow
settings that run Blizzard code.

Chat commands:

| Command | What it does |
|---|---|
| `/qt` | open the menu |
| `/qt options` | open the Options window at Quick Toggle's page |
| `/qt music`, `/qt <key>` | flip a button's setting from chat; `/qt list` shows every key |
| `/qt music on\|off` | set it to a specific value |
| `/qt brightness 60`, `/qt gamma 1.2`, `/qt <slider key> <value>` | set a slider (undoable) |
| `/qt brightness undo`, `/qt <slider key> undo` | undo |
| `/qt enable <key>`, `/qt disable <key>` | show or hide one control |
| `/qt list` | every control, its kind, whether it is on, the current value and any undo point |
| `/qt show`, `/qt hide` | everything at once |
| `/qt lock`, `/qt unlock`, `/qt reset` | lock, unlock, or put everything back at its default spot |
| `/qt blizzard on\|off` | allow settings that run Blizzard code (see below) |
| `/qt sound on\|off`, `/qt announce on\|off` | the click sound and the chat line on each change |
| `/qt key <toggle> <KEY>` | bind a key, e.g. `/qt key music F11` |

Keys for controls added from Options are the setting's name in the game plus the kind, for
example `autoLootDefault@float` or `maxFPS@block`. Case doesn't matter.

## Which settings work, and why some are greyed out

About 300 settings in Forever's Options window are quick-toggle candidates:

- **About two thirds are console variables** (CVars). Quick Toggle changes them with `SetCVar`,
  the exact call Blizzard's own Options code makes for them (`CVarSettingMixin` in
  `Blizzard_Setting.lua`), so the result is identical. These work out of the box.
- **About a third are "proxy" settings** that apply by running Blizzard functions: graphics
  quality presets, action bars, nameplates, voice chat and others. When an addon runs that code,
  the game can later refuse protected actions with "Interface action blocked by an AddOn",
  usually in combat. So their boxes are greyed out until you tick **Allow settings that run
  Blizzard code** (right-click menu, Options > AddOns > Quick Toggle, or `/qt blizzard on`).
  Even then they are never changed in combat; the control says so and does nothing.
- **Character Models is the exception**: it is a proxy setting, but its Blizzard setter only
  calls `C_GameRules.SetSDHDToggleValue`, so Quick Toggle makes that call itself (the same one
  the Barbershop checkbox makes) and it works without the switch.
- **Settings that only apply after a restart** (display mode, resolution, anything Blizzard
  marks `ClientRestart`, `GxRestart`, `UIReload` or `UpdateWindow`) have greyed boxes. A quick
  toggle can't apply them.
- Key bindings, color pickers and plain buttons in Options aren't settings with a value, so
  they get no boxes.

If the game ever refuses a change, the control says "the game did not accept the change" once
and snaps back to the real value.

## How the Options window boxes stay safe

Blizzard's UI add-on policy allows addons that add their own frames to Blizzard's interface
through the normal Lua API, which is all this does. The technical risk with touching Blizzard's
Options window is "taint": if addon code writes to Blizzard's own tables, Blizzard code that
later reads them can be blocked. Quick Toggle avoids that:

- Every Options row runs `SettingsListElementMixin.Init`. Quick Toggle attaches with
  `hooksecurefunc`, Blizzard's approved way to run code after one of its functions without
  tainting it.
- The boxes are Quick Toggle's own child frames. Nothing is stored on Blizzard's row frames or
  setting objects; the row-to-boxes map lives in Quick Toggle's own weak table.
- Setting objects are only read (name, type, current value, slider range, dropdown choices).
  CVar settings are written with `SetCVar`, not through Blizzard's setting object.
- The boxes sit above the row's invisible hover area so a click on a box never also clicks
  Blizzard's checkbox.
- The section brackets live on Quick Toggle's own overlay frames on top of the list. They read
  the list's visible rows and the current page's layout to know where sections start and end,
  and change nothing of Blizzard's.

## Adding a hand-made toggle

For a control with custom art, write a small file in `QuickToggle/Toggles/` (minimap button,
`QuickToggle:Register{...}`) or `QuickToggle/Sliders/` (panel row, `QuickToggle:RegisterSlider{...}`),
and list it in the `.toc`. `Toggles/Music.lua` and `Sliders/Display.lua` are the smallest
examples. `QuickToggle:RegisterFloat{...}` and `QuickToggle:RegisterBlock{...}` make floating
ones. To make a hand-made control the one an Options row's box drives, add its setting to the
`FEATURED` table at the top of `Options.lua`.

Files:

| File | What it holds |
|---|---|
| `Core.lua` | element registry, saved settings, minimap buttons, the menu, slash commands, events and polling |
| `Floating.lua` | floating buttons |
| `Sliders.lua` | the shared slider panel, floating slider blocks, undo |
| `Options.lua` | reading the Options window's settings, the boxes in each row, the "Blizzard code" switch, the Options > AddOns page |
| `Toggles/Music.lua`, `Sliders/Display.lua` | the hand-made controls |

**Character Models** uses `C_GameRules.IsSDHDToggleEnabled()`, `AccountHasSDEnabled()` and
`SetSDHDToggleValue(setToSD, Enum.SdToggleUsageLocationUI.OptionsMenu)`, the same calls
Blizzard's Options and Barbershop make (the `DIRECT` table in `Options.lua`). **Music** is the
`Sound_EnableMusic` CVar.
**Brightness, Contrast, Gamma** are the `Brightness`, `Contrast` (0 to 100) and `Gamma`
(0.3 to 2.8 in 0.1 steps) CVars behind Options > Graphics.

## Development

`tests/` holds a headless harness that stubs the client, including Blizzard's settings system:
categories with subcategories, row initializers, CVar-backed and proxy setting objects, commit
flags, `hooksecurefunc` and `SETTINGS_LOADED`. It drives the addon through every control kind,
the boxes on every row shape (on/off, inverted on/off, dropdown, proxy, restart-only, combined
checkbox and slider, whole and fractional sliders, non-setting rows, add-on rows, reused rows),
the hand-made controls those rows map to, shared undo points, combat refusal, the menu, slash
commands, key bindings, the Options > AddOns page, and a `/reload` that restores everything you
ticked. Run it with Lua 5.1, the game's Lua version:

```bash
python3 tests/run.py
```

It needs `lua5.1` on PATH or `pip install lupa`.

## Things to verify in game

- **Box placement.** The boxes sit in the 37 px gutter Blizzard leaves left of each setting's
  label, and the second pair on combined rows at the row's right edge. The bracket sits just left
  of them, in the margin, with its label above the section's first row. If anything overlaps on your screen, send a screenshot.
- **Settings that apply differently from an addon.** A few CVar settings also have Blizzard
  code that runs only when changed from the Options window. Those change correctly from a quick
  toggle but may need a moment, or a zone change, to show. Tell me which ones and I'll look.
- **Character Models**: whether the model swap is instant. If the realm has the switch off, its
  boxes are greyed and the tooltip says so.

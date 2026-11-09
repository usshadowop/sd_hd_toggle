local here, addonDir = ...
here = here or "tests"
addonDir = addonDir or "SDHDToggle"

local Stub = dofile(here .. "/wow_stub.lua")

local failures, passes = 0, 0
local function check(cond, msg)
	if cond then passes = passes + 1 else failures = failures + 1; io.stderr:write("FAIL: " .. msg .. "\n") end
end
local function eq(a, b, msg)
	check(a == b, msg .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")")
end

Stub.LoadAddon(addonDir .. "/SDHDToggle.lua", "SDHDToggle")
local btn = SDHDToggleButton

-- Fresh install: HD active, button shown with yellow HD text.
eq(btn:IsShown(), true, "button shown on login when the toggle is available")
eq(btn.text:GetText(), "HD", "label reads HD while HD models are active")
check(btn.text.color and btn.text.color[1] == 1 and btn.text.color[3] == 0, "label is yellow")
eq(SDHDToggleDB.shown, true, "saved variables created with defaults")

-- Click flips to SD and tells the client who did it (OptionsMenu = 3).
btn.scripts.OnClick(btn, "LeftButton")
eq(Stub.game.sd, true, "click switches the game to SD")
eq(btn.text:GetText(), "SD", "label follows the switch to SD")
eq(#Stub.game.setCalls, 1, "exactly one SetSDHDToggleValue call per click")
eq(Stub.game.setCalls[1][2], 3, "reports usage location OptionsMenu")
check(Stub.LastPrint():find("SD") ~= nil, "announces the switch in chat")

-- Click again flips back.
btn.scripts.OnClick(btn, "LeftButton")
eq(Stub.game.sd, false, "second click switches back to HD")
eq(btn.text:GetText(), "HD", "label follows the switch back to HD")
eq(#Stub.sounds, 2, "a sound per switch")

-- Key binding entry point.
SDHDToggle_Switch()
eq(Stub.game.sd, true, "key binding switches too")
eq(btn.text:GetText(), "SD", "label updates from the key binding")

-- Slash commands: explicit targets are idempotent.
Stub.Slash("sd")
eq(#Stub.game.setCalls, 3, "/sdhd sd when already SD does not call the client again")
check(Stub.LastPrint():find("already") ~= nil, "says SD is already active")
Stub.Slash("hd")
eq(Stub.game.sd, false, "/sdhd hd switches to HD")
Stub.Slash("")
eq(Stub.game.sd, true, "bare /sdhd toggles")

-- The Barbershop (or Options) changes it behind our back: polling picks it up.
Stub.game.sd = false
Stub.Tick(0.3)
eq(btn.text:GetText(), "SD", "label unchanged before the poll interval")
Stub.Tick(0.3)
eq(btn.text:GetText(), "HD", "label corrected after the poll interval")

-- Show / hide, lock, position.
Stub.Slash("hide")
eq(btn:IsShown(), false, "/sdhd hide hides the box")
eq(SDHDToggleDB.shown, false, "hidden state is saved")
SDHDToggle_ShowHide()
eq(btn:IsShown(), true, "show/hide binding shows it again")

btn.scripts.OnClick(btn, "RightButton")
eq(SDHDToggleDB.locked, true, "right-click locks the box")
btn.scripts.OnDragStart(btn)
eq(btn.moving, nil, "locked box does not move on drag")
btn.scripts.OnClick(btn, "RightButton")
eq(SDHDToggleDB.locked, false, "right-click again unlocks")
btn.scripts.OnDragStart(btn)
eq(btn.moving, true, "unlocked box moves on drag")
btn:ClearAllPoints(); btn:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 120, -40)
btn.scripts.OnDragStop(btn)
check(SDHDToggleDB.pos and SDHDToggleDB.pos[3] == 120 and SDHDToggleDB.pos[4] == -40, "drag stop saves the position")
Stub.Slash("reset")
eq(SDHDToggleDB.pos, nil, "/sdhd reset clears the saved position")

Stub.Slash("scale 1.5")
eq(SDHDToggleDB.scale, 1.5, "/sdhd scale saves the scale")
Stub.Slash("scale 9")
eq(SDHDToggleDB.scale, 1.5, "out-of-range scale is rejected")

Stub.Slash("key F10")
eq(Stub.bindings["F10"], "SDHDTOGGLE_SWITCH", "/sdhd key binds the switch")
eq(Stub.savedBindings, true, "bindings are saved")
Stub.Slash("status")
check(Stub.LastPrint():find("F10") ~= nil, "status shows the bound key")

-- Toggle disabled on this realm/account: switch refuses, button hides on login.
Stub.game.toggleEnabled = false
local before = #Stub.game.setCalls
btn.scripts.OnClick(btn, "LeftButton")
eq(#Stub.game.setCalls, before, "no client call when the toggle is disabled")
check(Stub.LastPrint():find("turned off") ~= nil, "explains that the toggle is off")
Stub.Fire("PLAYER_LOGIN")
eq(btn:IsShown(), false, "box hidden when the toggle is disabled")
Stub.game.toggleEnabled = true

-- Client without the API at all (older build): nothing errors, label is "?".
local saved = C_GameRules
C_GameRules = nil
SDHDToggle.Refresh()
eq(btn.text:GetText(), "?", "label is ? without the API")
eq(SDHDToggle.Switch(), false, "switch returns false without the API")
check(Stub.LastPrint():find("missing") ~= nil, "explains the API is missing")
C_GameRules = saved

io.write(string.format("%d passed, %d failed\n", passes, failures))
return failures > 0

local here, addonDir = ...
here = here or "tests"
addonDir = addonDir or "QuickToggle"

local Stub = dofile(here .. "/wow_stub.lua")

local failures, passes = 0, 0
local function check(cond, msg)
	if cond then passes = passes + 1 else failures = failures + 1; io.stderr:write("FAIL: " .. msg .. "\n") end
end
local function eq(a, b, msg)
	check(a == b, msg .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")")
end
local function near(a, b, msg) check(math.abs(a - b) < 0.01, msg .. " (got " .. tostring(a) .. ", want " .. tostring(b) .. ")") end
local function onRing(btn, angleDeg, radius, msg)
	local p = { btn:GetPoint(1) }
	check(p[2] == Minimap and math.abs(p[4] - radius * math.cos(math.rad(angleDeg))) < 0.01
		and math.abs(p[5] - radius * math.sin(math.rad(angleDeg))) < 0.01, msg)
end

Stub.LoadAddon(addonDir, "QuickToggle")
local QT = QuickToggle
local sd = QuickToggle_sdhd_Button
local mu = QuickToggle_music_Button

-- Load: two toggles registered, both buttons on the minimap ring.
eq(#QT.toggles, 2, "two toggles registered")
eq(QT.toggles[1].key, "sdhd", "SD/HD registered first")
eq(QT.toggles[2].key, "music", "Music registered second")
eq(sd:IsShown(), true, "SD/HD button shown on login")
eq(mu:IsShown(), true, "Music button shown on login")
eq(sd.parent, Minimap, "buttons are children of the Minimap")
check(sd.ring.texture:find("TrackingBorder") ~= nil, "buttons have the standard minimap ring")
eq(QuickToggleDB.buttons.sdhd.enabled, true, "SD/HD saved as enabled by default")
eq(QuickToggleDB.buttons.music.enabled, true, "Music saved as enabled by default")
onRing(sd, 220, 75, "SD/HD sits at 220 degrees, half the minimap width + 5 out")
onRing(mu, 200, 75, "Music sits at 200 degrees, next to it")
Minimap:SetSize(250, 250)
onRing(sd, 220, 130, "a bigger minimap pushes SD/HD out to its edge")
onRing(mu, 200, 130, "a bigger minimap pushes Music out to its edge")

-- SD/HD: yellow text label, click flips through C_GameRules.
eq(sd.label:GetText(), "HD", "SD/HD label reads HD while HD models are active")
check(sd.label.color[1] == 1 and sd.label.color[3] == 0, "SD/HD label is yellow")
sd.scripts.OnClick(sd, "LeftButton")
eq(Stub.game.sd, true, "click switches the game to SD")
eq(sd.label:GetText(), "SD", "label follows the switch")
eq(Stub.game.setCalls[1][2], 3, "reports usage location OptionsMenu")
check(Stub.LastPrint():find("SD %(classic%)") ~= nil, "announces the switch")
sd.scripts.OnClick(sd, "LeftButton")
eq(Stub.game.sd, false, "second click switches back to HD")
eq(#Stub.sounds, 2, "a sound per flip")

-- Music: yellow note, red X overlaid while off, drives Sound_EnableMusic.
check(mu.noteHead and mu.noteStem and mu.noteFlag, "note drawn from head, stem and flag")
check(mu.noteHead.vcolor[1] == 1 and mu.noteHead.vcolor[3] == 0, "note is yellow")
check(mu.cross.texture:find("ReadyCheck%-NotReady") ~= nil, "red X uses the ready-check texture")
eq(mu.cross:IsShown(), false, "no red X while music is on")
mu.scripts.OnClick(mu, "LeftButton")
eq(Stub.cvars.Sound_EnableMusic, "0", "click turns music off via the cvar")
eq(mu.cross:IsShown(), true, "red X shown while music is off")
check(mu.noteHead:IsShown() and mu.noteStem:IsShown() and mu.noteFlag:IsShown() and mu.noteHead.alpha == nil, "note stays fully drawn while off, only the X is added")
check(Stub.LastPrint():find("music off") ~= nil, "announces music off")
mu.scripts.OnClick(mu, "LeftButton")
eq(Stub.cvars.Sound_EnableMusic, "1", "second click turns music on")
eq(mu.cross:IsShown(), false, "red X hidden again")

-- Music changed elsewhere (Blizzard's hotkey, Options): CVAR_UPDATE updates the button at once.
SetCVar("Sound_EnableMusic", "0")
eq(mu.cross:IsShown(), true, "external cvar change shows the red X without waiting for the poll")
SetCVar("Sound_EnableMusic", "1")
eq(mu.cross:IsShown(), false, "and hides it again")

-- SD/HD changed elsewhere: no event exists, the poll catches it.
Stub.game.sd = true
Stub.Tick(0.3)
eq(sd.label:GetText(), "HD", "label unchanged before the poll interval")
Stub.Tick(0.3)
eq(sd.label:GetText(), "SD", "label corrected after the poll interval")
Stub.game.sd = false
Stub.Tick(0.6)

-- Tooltips.
mu.scripts.OnEnter(mu)
check(GameTooltip.lines[1] == "Music" and GameTooltip.lines[2]:find("on") ~= nil, "music tooltip shows the state")
Stub.cvars.Sound_EnableAllSound = "0"
mu.scripts.OnEnter(mu)
check(GameTooltip.lines[#GameTooltip.lines - 1]:find("All sound is off") ~= nil, "music tooltip warns when all sound is off")
Stub.cvars.Sound_EnableAllSound = "1"
sd.scripts.OnEnter(sd)
check(GameTooltip.lines[1] == "SD / HD character models", "SD/HD tooltip titled")
mu.scripts.OnLeave(mu)

-- Slash commands.
Stub.Slash("music off")
eq(Stub.cvars.Sound_EnableMusic, "0", "/qt music off")
Stub.Slash("music off")
check(Stub.LastPrint():find("already") ~= nil, "/qt music off twice says already")
Stub.Slash("music")
eq(Stub.cvars.Sound_EnableMusic, "1", "bare /qt music flips")
Stub.Slash("sdhd sd")
eq(Stub.game.sd, true, "/qt sdhd sd")
Stub.Slash("sdhd hd")
eq(Stub.game.sd, false, "/qt sdhd hd")
Stub.Slash("sdhd purple")
check(Stub.LastPrint():find("don't know") ~= nil, "unknown value is reported")
Stub.Slash("bogus")
check(Stub.LastPrint():find("commands:") ~= nil, "unknown command prints help")

Stub.Slash("disable music")
eq(mu:IsShown(), false, "/qt disable music hides the button")
eq(QuickToggleDB.buttons.music.enabled, false, "and saves it")
eq(sd:IsShown(), true, "SD/HD unaffected")
Stub.Slash("enable music")
eq(mu:IsShown(), true, "/qt enable music shows it again")
Stub.Slash("disable nothing")
check(Stub.LastPrint():find("no toggle") ~= nil, "disable of unknown toggle is reported")

Stub.Slash("hide")
eq(sd:IsShown() or mu:IsShown(), false, "/qt hide hides every button")
Stub.Slash("show")
eq(sd:IsShown() and mu:IsShown(), true, "/qt show brings them back")

local n = #Stub.printed
Stub.Slash("list")
eq(#Stub.printed - n, 2, "/qt list prints one line per toggle")
check(Stub.printed[n + 2]:find("Music") ~= nil and Stub.printed[n + 2]:find("music on") ~= nil, "list shows the music state")

-- Key bindings.
QuickToggle_Press("music")
eq(Stub.cvars.Sound_EnableMusic, "0", "binding flips music")
QuickToggle_Press("sdhd")
eq(Stub.game.sd, true, "binding flips SD/HD")
Stub.Slash("key music F11")
eq(Stub.bindings["F11"], "QUICKTOGGLE_MUSIC", "/qt key binds the toggle's action")
eq(Stub.savedBindings, true, "bindings are saved")
Stub.Slash("key nothing F12")
check(Stub.LastPrint():find("usage") ~= nil, "bad key command prints usage")

-- Dragging slides each button independently around the ring.
Stub.cursor.x, Stub.cursor.y = 1000, 800
mu.scripts.OnDragStart(mu)
mu.scripts.OnUpdate(mu, 0.016)
mu.scripts.OnDragStop(mu)
near(QuickToggleDB.buttons.music.angle, 90, "music drag sets its angle from the cursor (90 = top)")
eq(QuickToggleDB.buttons.sdhd.angle, 220, "SD/HD angle untouched by the music drag")
onRing(mu, 90, 130, "music now sits at the top of the ring")
check(mu.scripts.OnUpdate == nil, "drag stop removes the OnUpdate")
Stub.Slash("lock")
sd.scripts.OnDragStart(sd)
check(sd.scripts.OnUpdate == nil, "locked buttons do not drag")
Stub.Slash("unlock")
Stub.Slash("reset")
eq(QuickToggleDB.buttons.music.angle, 200, "/qt reset puts music back at its default angle")

-- The menu (no MenuUtil in the stub, so the fallback frame is exercised).
eq(MenuUtil, nil, "stub has no MenuUtil, fallback menu in use")
sd.scripts.OnClick(sd, "RightButton")
local menu = QuickToggleMenu
check(menu and menu:IsShown(), "right-click opens the menu")
eq(#menu.rows, 2, "one menu row per toggle")
eq(menu.rows[1].label:GetText(), "SD / HD character models", "row 1 is SD/HD")
eq(menu.rows[2].label:GetText(), "Music", "row 2 is Music")
eq(menu.rows[2]:GetChecked(), true, "music row ticked while enabled")
menu.rows[2]:SetChecked(false)
menu.rows[2].scripts.OnClick(menu.rows[2])
eq(mu:IsShown(), false, "unticking Music in the menu hides its button")
eq(QuickToggleDB.buttons.music.enabled, false, "and saves it")
menu.rows[2]:SetChecked(true)
menu.rows[2].scripts.OnClick(menu.rows[2])
eq(mu:IsShown(), true, "ticking it again shows the button")
menu.lock:SetChecked(true)
menu.lock.scripts.OnClick(menu.lock)
eq(QuickToggleDB.locked, true, "menu lock row locks the buttons")
menu.lock:SetChecked(false)
menu.lock.scripts.OnClick(menu.lock)
QuickToggleDB.buttons.sdhd.angle = 10
menu.reset.scripts.OnClick(menu.reset)
eq(QuickToggleDB.buttons.sdhd.angle, 220, "menu reset button resets positions")
menu.close.scripts.OnClick(menu.close)
eq(menu:IsShown(), false, "close button hides the menu")
Stub.Slash("")
eq(menu:IsShown(), true, "bare /qt opens the menu")
menu:Hide()
QuickToggle_Press("menu")
eq(menu:IsShown(), true, "menu key binding opens the menu")
menu:Hide()

-- SD/HD switch turned off on this realm: its button hides, the music one stays, menu row says why.
Stub.game.toggleEnabled = false
local before = #Stub.game.setCalls
sd.scripts.OnClick(sd, "LeftButton")
eq(#Stub.game.setCalls, before, "no client call when the toggle is disabled")
check(Stub.LastPrint():find("turned off") ~= nil, "explains that the toggle is off")
Stub.Fire("PLAYER_LOGIN")
eq(sd:IsShown(), false, "SD/HD button hidden when the realm disables the switch")
eq(mu:IsShown(), true, "Music button unaffected")
QT:OpenMenu()
check(menu.rows[1].label:GetText():find("turned off") ~= nil, "menu row shows the reason")
menu:Hide()
Stub.game.toggleEnabled = true
QT:Refresh()
eq(sd:IsShown(), true, "SD/HD button back when the switch is enabled again")

-- Client without the API at all: nothing errors.
local saved = C_GameRules
C_GameRules = nil
QT:Refresh()
eq(sd:IsShown(), false, "SD/HD hidden without the API")
eq(QT:Press("sdhd"), false, "press returns false without the API")
check(Stub.LastPrint():find("no SD/HD") ~= nil, "explains the API is missing")
C_GameRules = saved
QT:Refresh()

-- Unknown toggle key.
eq(QT:Press("nope"), false, "unknown toggle returns false")
check(Stub.LastPrint():find("no toggle called") ~= nil, "and says so")

io.write(string.format("%d passed, %d failed\n", passes, failures))
return failures > 0

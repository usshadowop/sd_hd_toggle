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
eq(#Stub.printed - n, 5, "/qt list prints one line per button and slider")
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
eq(#menu.rows, 5, "one menu row per button and slider")
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

-------------------------------------------------------------------------------
-- Sliders: brightness and contrast
-------------------------------------------------------------------------------
local panel = QuickToggleSliderPanel
local bs = QuickToggle_brightness_Slider
local bu = QuickToggle_brightness_Undo
local cs = QuickToggle_contrast_Slider
local cu = QuickToggle_contrast_Undo
local brow = QT.panel.rows.brightness

eq(#QT.sliders, 3, "three sliders registered")
eq(panel:IsShown(), true, "slider panel shown on login")
eq(bs:IsShown() and cs:IsShown(), true, "both slider rows shown")
eq(bs.minV .. "-" .. bs.maxV .. "/" .. bs.step, "0-100/1", "brightness uses Blizzard's 0-100 range in steps of 1")
eq(bs.thumb, "Interface\\Buttons\\UI-SliderBar-Button-Horizontal", "classic slider thumb")
eq(bs:GetValue(), 50, "slider starts at the game's value")
eq(brow.value:GetText(), "50%", "value shown as a percentage")
eq(brow.label:GetText(), "Brightness", "row labelled")
eq(bu:IsEnabled(), false, "undo disabled before anything moved")
check(bu.icon.alpha < 1, "undo icon dimmed while there is nothing to undo")
eq(QuickToggleDB.sliders.brightness.enabled, true, "brightness saved as enabled by default")

-- Several moves in a row still undo to the original value.
bs:SetValue(70)
eq(Stub.cvars.Brightness, "70", "dragging the slider sets the Brightness cvar")
eq(QuickToggleDB.sliders.brightness.revert, 50, "undo point is the value before the first move")
eq(bu:IsEnabled(), true, "undo enabled after a move")
eq(bu.icon.alpha, 1, "undo icon lit")
eq(brow.value:GetText(), "70%", "value text follows")
bs:SetValue(80)
bs.scripts.OnMouseWheel(bs, 1)
eq(Stub.cvars.Brightness, "81", "mouse wheel steps by one")
eq(QuickToggleDB.sliders.brightness.revert, 50, "later moves keep the first undo point")
bu.scripts.OnClick(bu, "LeftButton")
eq(Stub.cvars.Brightness, "50", "undo puts brightness back where it was")
eq(bs:GetValue(), 50, "slider moves back too")
eq(QuickToggleDB.sliders.brightness.revert, nil, "undo point cleared")
eq(bu:IsEnabled(), false, "undo disabled again")
check(Stub.LastPrint():find("back to 50%%") ~= nil, "announces the undo")

-- Sliding back onto the undo point by hand clears it.
bs:SetValue(60)
bs:SetValue(50)
eq(QuickToggleDB.sliders.brightness.revert, nil, "sliding back to the start leaves nothing to undo")

-- Fractional input snaps to the step; values clamp to the range.
bs.scripts.OnValueChanged(bs, 42.6)
eq(Stub.cvars.Brightness, "43", "fractional value snaps to the step")
bs:SetValue(50)

-- Contrast is independent.
cs:SetValue(30)
eq(Stub.cvars.Contrast, "30", "contrast slider sets the Contrast cvar")
eq(QuickToggleDB.sliders.contrast.revert, 50, "contrast has its own undo point")
eq(QuickToggleDB.sliders.brightness.revert, nil, "brightness undo untouched")

-- Changed in Options: the slider follows at once (CVAR_UPDATE), the undo point stays.
SetCVar("Contrast", "65")
eq(cs:GetValue(), 65, "external change moves the slider")
eq(Stub.cvars.Contrast, "65", "and syncing the slider does not write the cvar back")
eq(QuickToggleDB.sliders.contrast.revert, 50, "external change keeps the undo point")
cu.scripts.OnClick(cu, "LeftButton")
eq(Stub.cvars.Contrast, "50", "contrast undo")

-- Undo point survives a reload (it lives in saved variables).
cs:SetValue(20)
eq(QuickToggleDB.sliders.contrast.revert, 50, "undo point saved")
SetCVar("Contrast", "50")
QuickToggleDB.sliders.contrast.revert = nil
QT:RefreshSliders()

-- Right-click anywhere on the slider panel opens the menu.
local menu = QuickToggleMenu
menu:Hide()
bs.scripts.OnMouseUp(bs, "RightButton")
eq(menu:IsShown(), true, "right-click on a slider opens the menu")
menu:Hide()
bu.scripts.OnClick(bu, "RightButton")
eq(menu:IsShown(), true, "right-click on an undo button opens the menu")
eq(Stub.cvars.Brightness, "50", "and does not undo anything")
menu:Hide()
eq(bu:IsEnabled(), false, "undo button disabled here")
bu.scripts.OnMouseUp(bu, "RightButton")
eq(menu:IsShown(), true, "right-click on a disabled undo button still opens the menu")
menu:Hide()
panel.scripts.OnMouseUp(panel, "RightButton")
eq(menu:IsShown(), true, "right-click on the panel background or a label opens the menu")
menu:Hide()
bs.scripts.OnMouseUp(bs, "LeftButton")
eq(menu:IsShown(), false, "left-click on a slider does not open the menu")

-- The menu lists sliders in their own section and can turn each off.
QT:OpenMenu(panel)
eq(#menu.rows >= 5, true, "menu has rows for 2 buttons and 3 sliders")
eq(menu.rows[3].label:GetText(), "Brightness", "row 3 is the brightness slider")
eq(menu.rows[4].label:GetText(), "Contrast", "row 4 is the contrast slider")
eq(menu.headers[1]:GetText(), "Minimap buttons", "buttons section header")
eq(menu.headers[2]:GetText(), "Sliders", "sliders section header")
check(menu.lock.label:GetText():find("sliders") ~= nil, "lock row covers sliders")
menu.rows[3]:SetChecked(false)
menu.rows[3].scripts.OnClick(menu.rows[3])
eq(bs:IsShown(), false, "unticking Brightness hides its row")
eq(cs:IsShown(), true, "contrast row stays")
eq(panel:IsShown(), true, "panel stays while one slider is left")
local oneRow = panel.h
menu.rows[4]:SetChecked(false)
menu.rows[4].scripts.OnClick(menu.rows[4])
eq(panel:IsShown(), true, "panel stays while gamma is left")
menu.rows[5]:SetChecked(false)
menu.rows[5].scripts.OnClick(menu.rows[5])
eq(panel:IsShown(), false, "panel hides when no slider is enabled")
menu.rows[3]:SetChecked(true)
menu.rows[3].scripts.OnClick(menu.rows[3])
menu.rows[4]:SetChecked(true)
menu.rows[4].scripts.OnClick(menu.rows[4])
menu.rows[5]:SetChecked(true)
menu.rows[5].scripts.OnClick(menu.rows[5])
eq(panel:IsShown(), true, "panel back with all sliders")
check(panel.h > oneRow, "panel grows with a second row")
local p1 = { cs:GetPoint(1) }
check(p1[5] < -10, "contrast row sits below brightness when both are on")
menu:Hide()

-- Panel drag, lock, reset.
panel.scripts.OnDragStart(panel)
eq(panel.moving, true, "panel drags when unlocked")
panel:ClearAllPoints(); panel:SetPoint("CENTER", UIParent, "CENTER", 100, 50)
panel.scripts.OnDragStop(panel)
check(QuickToggleDB.sliderPos and QuickToggleDB.sliderPos[3] == 100, "drag stop saves the panel position")
panel.moving = nil
Stub.Slash("lock")
panel.scripts.OnDragStart(panel)
eq(panel.moving, nil, "locked panel does not drag")
Stub.Slash("unlock")
Stub.Slash("reset")
eq(QuickToggleDB.sliderPos, false, "/qt reset forgets the panel position")
local pp = { panel:GetPoint(1) }
eq(pp[2], Minimap, "panel goes back under the minimap")

-- Show / hide covers the panel too.
Stub.Slash("hide")
eq(panel:IsShown(), false, "/qt hide hides the slider panel")
Stub.Slash("show")
eq(panel:IsShown(), true, "/qt show brings it back")

-- Slash commands.
Stub.Slash("brightness 65")
eq(Stub.cvars.Brightness, "65", "/qt brightness 65")
eq(QuickToggleDB.sliders.brightness.revert, 50, "chat changes also keep an undo point")
eq(bs:GetValue(), 65, "slider follows a chat change")
Stub.Slash("brightness")
check(Stub.LastPrint():find("65%%") and Stub.LastPrint():find("undo goes back to 50%%"), "bare /qt brightness reports value and undo point")
Stub.Slash("brightness undo")
eq(Stub.cvars.Brightness, "50", "/qt brightness undo")
Stub.Slash("brightness undo")
check(Stub.LastPrint():find("nothing to undo") ~= nil, "second undo says nothing to undo")
Stub.Slash("contrast 140")
check(Stub.LastPrint():find("usage") ~= nil, "out-of-range value prints usage")
eq(Stub.cvars.Contrast, "50", "and changes nothing")
Stub.Slash("disable contrast")
eq(cs:IsShown(), false, "/qt disable contrast hides its row")
check(Stub.LastPrint():find("Contrast slider off") ~= nil, "names it as a slider")
Stub.Slash("enable contrast")
eq(cs:IsShown(), true, "/qt enable contrast shows it")
local n0 = #Stub.printed
Stub.Slash("list")
eq(#Stub.printed - n0, 5, "/qt list covers 2 buttons and 3 sliders")
check(Stub.printed[n0 + 3]:find("Brightness") and Stub.printed[n0 + 3]:find("now: 50%%"), "list shows the brightness value")

-- Tooltips.
bu.scripts.OnEnter(bu)
check(GameTooltip.lines[2]:find("Nothing to undo") ~= nil, "undo tooltip says when there is nothing to undo")
bs:SetValue(55)
check(GameTooltip.lines[2]:find("Back to 50%%") ~= nil, "open undo tooltip updates to show the target")
bu.scripts.OnLeave(bu)
bu.scripts.OnClick(bu, "LeftButton")
bs.scripts.OnEnter(bs)
check(GameTooltip.lines[1]:find("Brightness") and GameTooltip.lines[1]:find("50%%"), "slider tooltip shows name and value")
bs.scripts.OnLeave(bs)

-- The game refuses the change: one warning, slider snaps back, no bogus undo point.
Stub.lockedCVars.Contrast = true
cs:SetValue(80)
eq(Stub.cvars.Contrast, "50", "refused write leaves the cvar alone")
eq(cs:GetValue(), 50, "slider snaps back to the real value")
eq(QuickToggleDB.sliders.contrast.revert, nil, "no undo point for a refused change")
check(Stub.LastPrint():find("did not accept") ~= nil, "warns once")
local n1 = #Stub.printed
cs:SetValue(81)
eq(#Stub.printed, n1, "no repeat warning")
Stub.lockedCVars.Contrast = nil

-- A client without the cvar: the row hides and the menu says why.
Stub.cvars.Brightness = nil
QT:RefreshSliders()
eq(bs:IsShown(), false, "brightness row hidden without the cvar")
eq(cs:IsShown(), true, "contrast row unaffected")
QT:OpenMenu(panel)
check(menu.rows[3].label:GetText():find("no Brightness setting") ~= nil, "menu row shows the reason")
menu:Hide()
Stub.cvars.Brightness = "50"
QT:RefreshSliders()
eq(bs:IsShown(), true, "row back when the cvar exists")

-- Gamma: a plain number in 0.1 steps from 0.3 to 2.8.
local gs = QuickToggle_gamma_Slider
local gu = QuickToggle_gamma_Undo
local grow = QT.panel.rows.gamma
eq(gs:IsShown(), true, "gamma row shown")
eq(grow.label:GetText(), "Gamma", "gamma row labelled")
eq(gs.minV .. "-" .. gs.maxV .. "/" .. gs.step, "0.3-2.8/0.1", "gamma uses Blizzard's 0.3-2.8 range in steps of 0.1")
eq(gs:GetValue(), 1, "gamma slider starts at the game's 1.0")
eq(grow.value:GetText(), "1.0", "gamma shown to one decimal, not as a percentage")
local gp = { gs:GetPoint(1) }
local cp = { cs:GetPoint(1) }
check(gp[5] < cp[5], "gamma row sits below contrast")
gs:SetValue(1.2)
eq(Stub.cvars.Gamma, "1.2", "gamma written without float noise")
eq(grow.value:GetText(), "1.2", "value text 1.2")
eq(QuickToggleDB.sliders.gamma.revert, 1, "gamma undo point is 1.0")
gs.scripts.OnMouseWheel(gs, 1)
eq(Stub.cvars.Gamma, "1.3", "mouse wheel steps gamma by 0.1")
gs.scripts.OnMouseWheel(gs, -1)
gs.scripts.OnMouseWheel(gs, -1)
eq(Stub.cvars.Gamma, "1.1", "wheel down twice")
gs.scripts.OnValueChanged(gs, 1.234)
eq(Stub.cvars.Gamma, "1.2", "fractional input snaps to 0.1")
gs:SetValue(5)
eq(Stub.cvars.Gamma, "2.8", "clamped to the 2.8 maximum")
gs:SetValue(0)
eq(Stub.cvars.Gamma, "0.3", "clamped to the 0.3 minimum")
gu.scripts.OnClick(gu, "LeftButton")
eq(tonumber(Stub.cvars.Gamma), 1, "gamma undo back to 1.0")
eq(QuickToggleDB.sliders.gamma.revert, nil, "gamma undo point cleared")
gs:SetValue(1.4)
gs:SetValue(1.0)
eq(QuickToggleDB.sliders.gamma.revert, nil, "sliding gamma back to 1.0 leaves nothing to undo")
SetCVar("Gamma", "0.8")
eq(gs:GetValue(), 0.8, "gamma follows a change made in Options")
eq(grow.value:GetText(), "0.8", "and shows it")
SetCVar("Gamma", "1.0")
Stub.Slash("gamma 1.5")
eq(Stub.cvars.Gamma, "1.5", "/qt gamma 1.5")
Stub.Slash("gamma undo")
eq(tonumber(Stub.cvars.Gamma), 1, "/qt gamma undo")
Stub.Slash("gamma 3")
check(Stub.LastPrint():find("<0.3%-2.8>") ~= nil, "gamma usage shows the real 0.3-2.8 range")
Stub.Slash("contrast 140")
check(Stub.LastPrint():find("<0%-100>") ~= nil, "contrast usage still shows 0-100")
n0 = #Stub.printed
Stub.Slash("list")
check(Stub.printed[n0 + 5]:find("Gamma") and Stub.printed[n0 + 5]:find("<0.3%-2.8>") and Stub.printed[n0 + 5]:find("now: 1.0"), "list shows gamma range and value")
QT:OpenMenu(panel)
eq(menu.rows[5].label:GetText(), "Gamma", "menu row 5 is gamma")
menu:Hide()
Stub.Slash("disable gamma")
eq(gs:IsShown(), false, "/qt disable gamma hides its row")
Stub.Slash("enable gamma")
eq(gs:IsShown(), true, "/qt enable gamma shows it")

-- Fresh saved variables from 1.0.x gain the slider tables.
check(type(QuickToggleDB.sliders) == "table" and QuickToggleDB.sliderPos ~= nil, "slider settings present in saved variables")

io.write(string.format("%d passed, %d failed\n", passes, failures))
return failures > 0

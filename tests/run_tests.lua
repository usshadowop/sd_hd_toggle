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
eq(QuickToggleDB.undo.Brightness, 50, "undo point is the value before the first move")
eq(bu:IsEnabled(), true, "undo enabled after a move")
eq(bu.icon.alpha, 1, "undo icon lit")
eq(brow.value:GetText(), "70%", "value text follows")
bs:SetValue(80)
bs.scripts.OnMouseWheel(bs, 1)
eq(Stub.cvars.Brightness, "81", "mouse wheel steps by one")
eq(QuickToggleDB.undo.Brightness, 50, "later moves keep the first undo point")
bu.scripts.OnClick(bu, "LeftButton")
eq(Stub.cvars.Brightness, "50", "undo puts brightness back where it was")
eq(bs:GetValue(), 50, "slider moves back too")
eq(QuickToggleDB.undo.Brightness, nil, "undo point cleared")
eq(bu:IsEnabled(), false, "undo disabled again")
check(Stub.LastPrint():find("back to 50%%") ~= nil, "announces the undo")

-- Sliding back onto the undo point by hand clears it.
bs:SetValue(60)
bs:SetValue(50)
eq(QuickToggleDB.undo.Brightness, nil, "sliding back to the start leaves nothing to undo")

-- Fractional input snaps to the step; values clamp to the range.
bs.scripts.OnValueChanged(bs, 42.6)
eq(Stub.cvars.Brightness, "43", "fractional value snaps to the step")
bs:SetValue(50)

-- Contrast is independent.
cs:SetValue(30)
eq(Stub.cvars.Contrast, "30", "contrast slider sets the Contrast cvar")
eq(QuickToggleDB.undo.Contrast, 50, "contrast has its own undo point")
eq(QuickToggleDB.undo.Brightness, nil, "brightness undo untouched")

-- Changed in Options: the slider follows at once (CVAR_UPDATE), the undo point stays.
SetCVar("Contrast", "65")
eq(cs:GetValue(), 65, "external change moves the slider")
eq(Stub.cvars.Contrast, "65", "and syncing the slider does not write the cvar back")
eq(QuickToggleDB.undo.Contrast, 50, "external change keeps the undo point")
cu.scripts.OnClick(cu, "LeftButton")
eq(Stub.cvars.Contrast, "50", "contrast undo")

-- Undo point survives a reload (it lives in saved variables).
cs:SetValue(20)
eq(QuickToggleDB.undo.Contrast, 50, "undo point saved")
SetCVar("Contrast", "50")
QuickToggleDB.undo.Contrast = nil
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
eq(menu.headers[2]:GetText(), "Slider panel", "slider panel section header")
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
local p1 = { QT.panel.rows.contrast.frame:GetPoint(1) }
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
eq(QuickToggleDB.undo.Brightness, 50, "chat changes also keep an undo point")
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
eq(QuickToggleDB.undo.Contrast, nil, "no undo point for a refused change")
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
local gp = { QT.panel.rows.gamma.frame:GetPoint(1) }
local cp = { QT.panel.rows.contrast.frame:GetPoint(1) }
check(gp[5] < cp[5], "gamma row sits below contrast")
gs:SetValue(1.2)
eq(Stub.cvars.Gamma, "1.2", "gamma written without float noise")
eq(grow.value:GetText(), "1.2", "value text 1.2")
eq(QuickToggleDB.undo.Gamma, 1, "gamma undo point is 1.0")
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
eq(QuickToggleDB.undo.Gamma, nil, "gamma undo point cleared")
gs:SetValue(1.4)
gs:SetValue(1.0)
eq(QuickToggleDB.undo.Gamma, nil, "sliding gamma back to 1.0 leaves nothing to undo")
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

-------------------------------------------------------------------------------
-- Options window integration
-------------------------------------------------------------------------------
Stub.cvars.autoLootDefault = "0"
Stub.cvars.hideTips = "0"
Stub.cvars.cameraSmoothStyle = "1"
Stub.cvars.gxMaximize = "1"
Stub.cvars.maxFPSToggle = "1"
Stub.cvars.maxFPS = "60"

local CF = Settings.CommitFlag
local sAutoLoot = Stub.CVarSetting("autoLootDefault", "boolean", "Auto Loot")
local sTips = Stub.CVarSetting("hideTips", "boolean", "Show Tips", { negate = true })
local sCamera = Stub.CVarSetting("cameraSmoothStyle", "number", "Camera Following Style")
local cameraChoices = function()
	return { { value = 0, label = "Never" }, { value = 1, label = "Smart" }, { value = 2, label = "Always" } }
end
local sSelfCast = Stub.ProxySetting("PROXY_SELF_CAST", "boolean", "Self Cast", false)
local sWindowed = Stub.CVarSetting("gxMaximize", "boolean", "Windowed Mode", { flags = CF.GxRestart })
local sFPSToggle = Stub.CVarSetting("maxFPSToggle", "boolean", "Max Foreground FPS")
local sFPS = Stub.CVarSetting("maxFPS", "number", "Max FPS")
local fpsOptions = { minValue = 8, maxValue = 200, steps = 192, formatters = { [2] = function(v) return string.format("%d fps", v) end } }
local sBright = Stub.CVarSetting("Brightness", "number", "Brightness")
local brightOptions = { minValue = 0, maxValue = 100, steps = 100, formatters = { [2] = function(v) return string.format("%d%%", v) end } }
local sGammaSet = Stub.CVarSetting("Gamma", "number", "Gamma")
local gammaOptions = { minValue = 0.3, maxValue = 2.8, steps = 25 }
local sMusic = Stub.CVarSetting("Sound_EnableMusic", "boolean", "Music")
local sTexture = Stub.ProxySetting("PROXY_TEXTURE", "number", "Texture Resolution", 1)
local textureChoices = function()
	return { { value = 0, label = "Low" }, { value = 1, label = "Medium" }, { value = 2, label = "High" } }
end

local iAutoLoot = Stub.Init({ setting = sAutoLoot, name = "Auto Loot" })
local iTips = Stub.Init({ setting = sTips, name = "Show Tips" })
local iCamera = Stub.Init({ setting = sCamera, name = "Camera Following Style", options = cameraChoices })
local iSelfCast = Stub.Init({ setting = sSelfCast, name = "Self Cast" })
local iWindowed = Stub.Init({ setting = sWindowed, name = "Windowed Mode" })
local iFPS = Stub.Init({ name = "Max Foreground FPS", cbSetting = sFPSToggle, cbLabel = "Max Foreground FPS",
	sliderSetting = sFPS, sliderOptions = fpsOptions, sliderLabel = "Max FPS" })
local iButtonRow = Stub.Init({ name = "Keybindings", buttonText = "Open" })
local iIndented = Stub.Init({ setting = sAutoLoot, name = "Auto Loot" }, 15)
local iBright = Stub.Init({ setting = sBright, name = "Brightness", options = brightOptions })
local iGamma = Stub.Init({ setting = sGammaSet, name = "Gamma", options = gammaOptions })
local iMusic = Stub.Init({ setting = sMusic, name = "Music" })
local iTexture = Stub.Init({ setting = sTexture, name = "Texture Resolution", options = textureChoices })

local advanced = Stub.Category("Advanced", { iTexture })
Stub.categories = {
	Stub.Category("Gameplay", { iAutoLoot, iTips, iCamera, iSelfCast, iWindowed, iFPS, iButtonRow }),
	Stub.Category("Graphics", { iBright, iGamma }, { advanced }),
	Stub.Category("Audio", { iMusic }),
}

-- The add-on page under Options > AddOns.
eq(#Stub.addonCategories, 1, "Quick Toggle page registered under Options > AddOns")
eq(Stub.addonCategories[1]:GetName(), "Quick Toggle", "page is named Quick Toggle")
check(Stub.addonSettings.QuickToggle_AllowProxy ~= nil, "page has the 'allow Blizzard code' switch")
check(Stub.addonSettings.QuickToggle_Locked and Stub.addonSettings.QuickToggle_Shown and Stub.addonSettings.QuickToggle_SDHD, "page has lock, show and SD/HD switches")

Stub.Fire("SETTINGS_LOADED")
local infos = QT.optionInfos
eq(infos.autoLootDefault and infos.autoLootDefault.kind, "toggle", "Auto Loot read as an on/off setting")
eq(infos.autoLootDefault.backing, "cvar", "Auto Loot is CVar-backed")
eq(infos.cameraSmoothStyle and infos.cameraSmoothStyle.kind, "cycle", "dropdown read as a cycle setting")
eq(infos.PROXY_SELF_CAST and infos.PROXY_SELF_CAST.backing, "proxy", "proxy setting recognised")
eq(infos.gxMaximize and infos.gxMaximize.restart, true, "restart-only setting recognised")
eq(infos.maxFPSToggle and infos.maxFPSToggle.kind, "toggle", "combined row: checkbox part")
eq(infos.maxFPS and infos.maxFPS.kind, "slider", "combined row: slider part")
eq(infos.maxFPS.step, 1, "slider step from Blizzard's steps count")
eq(infos.Gamma.step, 0.1, "gamma step 0.1 from 25 steps over 0.3-2.8")
eq(infos.PROXY_TEXTURE and infos.PROXY_TEXTURE.category, "Advanced", "subcategories are scanned")
eq(infos.Keybindings, nil, "button rows are not settings")

-- Finds the boxes Quick Toggle put on a Blizzard row (our CheckButtons parented to it).
local function Boxes(row)
	local out = {}
	for _, f in ipairs(Stub.frames) do
		if f.parent == row and f.objectType == "CheckButton" then out[#out + 1] = f end
	end
	return out
end

local function Keys(t)
	local k = {}
	for key in pairs(t) do k[key] = true end
	return k
end

-- A row Quick Toggle never touches, for comparison.
local plain = CreateFrame("Frame", nil, UIParent)
plain.data = iAutoLoot.data

-- Plain on/off row.
local r1 = Stub.ShowRow(iAutoLoot)
local b = Boxes(r1)
eq(#b, 4, "four boxes made for a row (two pairs)")
eq(b[1]:IsShown() and b[2]:IsShown(), true, "first pair shown")
eq(b[3]:IsShown() or b[4]:IsShown(), false, "second pair hidden on a single-setting row")
eq(b[1].kind .. "/" .. b[2].kind, "float/bubble", "on/off row: floating button, minimap button")
local bp1, bp2 = { b[1]:GetPoint(1) }, { b[2]:GetPoint(1) }
check(bp1[1] == "LEFT" and bp1[4] == 2 and bp2[4] == 19, "boxes sit in the left gutter before the label")
check(b[2].normal.vcolor and b[2].normal.vcolor[3] == 1 and b[2].normal.vcolor[1] < 1, "second box is tinted blue")
eq(b[1].normal.texture, "Interface\\Buttons\\UI-CheckBox-Up", "boxes use the standard check box art")
check(b[1]:GetFrameLevel() > r1:GetFrameLevel() + 5 and b[2]:GetFrameLevel() == b[1]:GetFrameLevel(), "boxes sit above the row's hover frame so they get the click")
local plainKeys, rowKeys = Keys(plain), Keys(r1)
local extra = {}
for key in pairs(rowKeys) do if not plainKeys[key] then extra[#extra + 1] = key end end
eq(#extra, 0, "the hook stores nothing on Blizzard's row frame (" .. table.concat(extra, ",") .. ")")
eq(b[1]:GetChecked(), false, "nothing ticked yet")

-- Indented rows shift the boxes with the label.
local rIndent = Stub.ShowRow(iIndented)
local ib = Boxes(rIndent)
check(({ ib[1]:GetPoint(1) })[4] == 17, "boxes follow the row's indent")

-- Tick the floating-button box.
b[1]:SetChecked(true)
b[1].scripts.OnClick(b[1])
local fl = _G["QuickToggle_autoLootDefault_float_Float"]
check(fl ~= nil and fl:IsShown(), "ticking the first box adds a floating button")
eq(QT.all["autoLootDefault@float"].kind, "float", "registered as a floating button")
eq(fl.text:GetText(), "Auto Loot", "floating button shows the setting's name")
check(fl.text.color[1] == 1 and fl.text.color[3] == 0, "in yellow")
eq(fl.icon.texture, "Interface\\RaidFrame\\ReadyCheck-NotReady", "red X while off")
check(Stub.LastPrint():find("added as a floating button") ~= nil, "says it was added")
fl.scripts.OnClick(fl, "LeftButton")
eq(Stub.cvars.autoLootDefault, "1", "clicking the floating button turns Auto Loot on")
eq(fl.icon.texture, "Interface\\RaidFrame\\ReadyCheck-Ready", "green check while on")
fl.scripts.OnClick(fl, "LeftButton")
eq(Stub.cvars.autoLootDefault, "0", "and off again")
fl.scripts.OnClick(fl, "RightButton")
eq(QuickToggleMenu:IsShown(), true, "right-click on a floating button opens the menu")
local found
for i, row in ipairs(QuickToggleMenu.rows) do
	if row:IsShown() and row.label:GetText() == "Auto Loot" then found = i end
end
check(found ~= nil, "menu lists the new floating button")
local hdr = {}
for _, fs in ipairs(QuickToggleMenu.headers) do if fs:IsShown() then hdr[#hdr + 1] = fs:GetText() end end
eq(table.concat(hdr, ","), "Minimap buttons,Floating buttons,Slider panel", "menu has a section per kind in use")
QuickToggleMenu:Hide()

-- Tick the minimap-button box.
b[2]:SetChecked(true)
b[2].scripts.OnClick(b[2])
local bub = _G["QuickToggle_autoLootDefault_bubble_Button"]
check(bub ~= nil and bub:IsShown(), "ticking the second box adds a minimap button")
eq(bub.parent, Minimap, "on the minimap")
eq(bub.label:GetText(), "AL", "bubble shows the initials in yellow")
eq(bub.cross:IsShown(), true, "red X over it while off")
bub.scripts.OnClick(bub, "LeftButton")
eq(Stub.cvars.autoLootDefault, "1", "bubble turns it on")
eq(bub.cross:IsShown(), false, "X gone while on")
eq(fl.icon.texture, "Interface\\RaidFrame\\ReadyCheck-Ready", "the floating button for the same setting follows")
local ap = { bub:GetPoint(1) }
check(math.abs(ap[4] - 130 * math.cos(math.rad(180))) < 0.01, "first generic bubble sits at 180 degrees")

-- Change in Options: both controls follow.
SetCVar("autoLootDefault", "0")
eq(bub.cross:IsShown(), true, "bubble follows a change made in Options")
eq(fl.icon.texture, "Interface\\RaidFrame\\ReadyCheck-NotReady", "floating button follows too")

-- Untick hides; re-showing the row reflects saved state.
b[1]:SetChecked(false)
b[1].scripts.OnClick(b[1])
eq(fl:IsShown(), false, "unticking removes the floating button")
eq(QuickToggleDB.floats["autoLootDefault@float"].enabled, false, "and saves that")
local r1b = Stub.ShowRow(iAutoLoot)
local b2 = Boxes(r1b)
eq(b2[1]:GetChecked(), false, "a fresh row shows the first box unticked")
eq(b2[2]:GetChecked(), true, "and the second ticked")
QT:SetEnabled("autoLootDefault@float", true)
eq(b[1]:GetChecked(), true, "ticking from the menu updates boxes already on screen")

-- Inverted setting (NegateBoolean): "Show Tips" is on while hideTips is 0.
local rt = Stub.ShowRow(iTips)
local tb = Boxes(rt)
tb[1]:SetChecked(true)
tb[1].scripts.OnClick(tb[1])
local tf = _G["QuickToggle_hideTips_float_Float"]
eq(tf.icon.texture, "Interface\\RaidFrame\\ReadyCheck-Ready", "inverted setting reads as on")
tf.scripts.OnClick(tf, "LeftButton")
eq(Stub.cvars.hideTips, "1", "turning 'Show Tips' off writes hideTips = 1")
eq(tf.icon.texture, "Interface\\RaidFrame\\ReadyCheck-NotReady", "and shows off")

-- Dropdown: cycle button.
local rc = Stub.ShowRow(iCamera)
local cb = Boxes(rc)
eq(cb[1].kind .. "/" .. cb[2].kind, "float/bubble", "dropdown rows get the same two boxes")
cb[1]:SetChecked(true)
cb[1].scripts.OnClick(cb[1])
local cf = _G["QuickToggle_cameraSmoothStyle_float_Float"]
eq(cf.text:GetText(), "Camera Following Style: Smart", "cycle button shows name and current choice")
eq(cf.icon:IsShown(), false, "no check/X icon on a cycle button")
cf.scripts.OnClick(cf, "LeftButton")
eq(Stub.cvars.cameraSmoothStyle, "2", "click moves to the next choice")
eq(cf.text:GetText(), "Camera Following Style: Always", "label follows")
cf.scripts.OnClick(cf, "LeftButton")
eq(Stub.cvars.cameraSmoothStyle, "0", "wraps around to the first choice")
Stub.shift = true
cf.scripts.OnClick(cf, "LeftButton")
Stub.shift = false
eq(Stub.cvars.cameraSmoothStyle, "2", "shift-click goes back")
check(Stub.LastPrint():find("Always") ~= nil, "announces the choice by name")
cf.scripts.OnEnter(cf)
local tipText = table.concat(GameTooltip.lines, " | ")
check(tipText:find("shift%-click") ~= nil, "cycle tooltip mentions shift-click")
cf.scripts.OnLeave(cf)
cb[2]:SetChecked(true)
cb[2].scripts.OnClick(cb[2])
eq(_G["QuickToggle_cameraSmoothStyle_bubble_Button"].label:GetText(), "CFS", "cycle bubble shows initials")

-- Proxy setting: greyed until allowed, never in combat.
local rs = Stub.ShowRow(iSelfCast)
local sb = Boxes(rs)
eq(sb[1]:IsEnabled(), false, "proxy setting boxes are disabled by default")
sb[1].scripts.OnEnter(sb[1])
check(table.concat(GameTooltip.lines, " "):find("runs Blizzard code") ~= nil, "tooltip explains why")
sb[1].scripts.OnLeave(sb[1])
Stub.addonSettings.QuickToggle_AllowProxy:SetValue(true)
eq(QuickToggleDB.allowProxy, true, "the Options > AddOns switch allows them")
eq(sb[1]:IsEnabled(), true, "boxes enable at once")
sb[1]:SetChecked(true)
sb[1].scripts.OnClick(sb[1])
local pf = _G["QuickToggle_PROXY_SELF_CAST_float_Float"]
pf.scripts.OnClick(pf, "LeftButton")
eq(sSelfCast.value, true, "proxy setting changed through Blizzard's setting object")
local last = Stub.proxyCalls[#Stub.proxyCalls]
eq(last[1] .. "/" .. tostring(last[3]), "PROXY_SELF_CAST/true", "with immediate = true, so it applies without the Apply button")
Stub.combat = true
local nCalls = #Stub.proxyCalls
pf.scripts.OnClick(pf, "LeftButton")
Stub.combat = false
eq(#Stub.proxyCalls, nCalls, "never called in combat")
eq(sSelfCast.value, true, "value unchanged in combat")
check(Stub.LastPrint():find("in combat") ~= nil, "says why")
Stub.Slash("blizzard off")
eq(QuickToggleDB.allowProxy, false, "/qt blizzard off")
eq(pf:IsShown(), false, "proxy controls hide when not allowed")
eq(sb[1]:IsEnabled(), false, "and their boxes grey out")
Stub.Slash("blizzard on")
eq(pf:IsShown(), true, "/qt blizzard on brings them back")
Stub.Slash("blizzard off")

-- Restart-only setting: no quick toggle.
local rw = Stub.ShowRow(iWindowed)
local wb = Boxes(rw)
eq(wb[1]:IsEnabled() or wb[2]:IsEnabled(), false, "restart-only setting boxes are disabled")
wb[1].scripts.OnEnter(wb[1])
check(table.concat(GameTooltip.lines, " "):find("restarting") ~= nil, "tooltip explains it needs a restart")
wb[1].scripts.OnLeave(wb[1])

-- Combined checkbox + slider row: second pair at the right edge for the slider.
local rf = Stub.ShowRow(iFPS)
local fb = Boxes(rf)
eq(fb[1].kind .. "/" .. fb[2].kind, "float/bubble", "combined row: checkbox part gets button boxes")
eq(fb[3]:IsShown() and fb[4]:IsShown(), true, "combined row: second pair shown")
eq(fb[3].kind .. "/" .. fb[4].kind, "block/slider", "combined row: slider part gets slider boxes")
check(({ fb[3]:GetPoint(1) })[1] == "RIGHT", "second pair sits at the row's right edge")
fb[3]:SetChecked(true)
fb[3].scripts.OnClick(fb[3])
local blk = _G["QuickToggle_maxFPS_block_Block"]
check(blk ~= nil and blk:IsShown(), "ticking the slider's first box adds a floating slider block")
local bsl = _G["QuickToggle_maxFPS_block_Slider"]
eq(bsl.minV .. "-" .. bsl.maxV .. "/" .. bsl.step, "8-200/1", "block uses Blizzard's range and step")
eq(bsl:GetValue(), 60, "block starts at the game's value")
eq(blk.row.value:GetText(), "60 fps", "uses Blizzard's own value format")
bsl:SetValue(144)
eq(Stub.cvars.maxFPS, "144", "moving the block's slider sets the setting")
eq(QuickToggleDB.undo.maxFPS, 60, "undo point recorded")
fb[4]:SetChecked(true)
fb[4].scripts.OnClick(fb[4])
local prow = QT.panel.rows["maxFPS@slider"]
check(prow and prow.frame:IsShown(), "ticking the second box adds it to the shared panel")
eq(prow.slider:GetValue(), 144, "panel row shows the same value")
eq(prow.undo:IsEnabled(), true, "and shares the block's undo point")
prow.undo.scripts.OnClick(prow.undo, "LeftButton")
eq(Stub.cvars.maxFPS, "60", "undo from the panel row")
eq(bsl:GetValue(), 60, "block moves back too")
eq(blk.row.undo:IsEnabled(), false, "block's undo button clears too")
bsl.scripts.OnMouseUp(bsl, "RightButton")
eq(QuickToggleMenu:IsShown(), true, "right-click on a floating slider opens the menu")
QuickToggleMenu:Hide()
blk.scripts.OnMouseUp(blk, "RightButton")
eq(QuickToggleMenu:IsShown(), true, "right-click on a block's background opens the menu")
QuickToggleMenu:Hide()
fb[1]:SetChecked(true)
fb[1].scripts.OnClick(fb[1])
check(_G["QuickToggle_maxFPSToggle_float_Float"]:IsShown(), "combined row's checkbox part works too")

-- Block drag, lock and reset.
blk.scripts.OnDragStart(blk)
eq(blk.moving, true, "block drags when unlocked")
blk:ClearAllPoints(); blk:SetPoint("CENTER", UIParent, "CENTER", 300, 10)
blk.scripts.OnDragStop(blk)
eq(QuickToggleDB.blocks["maxFPS@block"].pos[3], 300, "block position saved")
blk.moving = nil
Stub.Slash("lock")
blk.scripts.OnDragStart(blk)
eq(blk.moving, nil, "locked block does not drag")
fl.scripts.OnDragStart(fl)
eq(fl.moving, nil, "locked floating button does not drag")
Stub.Slash("unlock")
fl.scripts.OnDragStart(fl)
fl:ClearAllPoints(); fl:SetPoint("CENTER", UIParent, "CENTER", -50, 70)
fl.scripts.OnDragStop(fl)
eq(QuickToggleDB.floats["autoLootDefault@float"].pos[3], -50, "floating button position saved")
Stub.Slash("reset")
eq(QuickToggleDB.blocks["maxFPS@block"].pos, nil, "/qt reset clears block positions")
eq(QuickToggleDB.floats["autoLootDefault@float"].pos, nil, "and floating button positions")

-- Featured controls: Brightness and Music rows drive the existing ones.
local rb = Stub.ShowRow(iBright)
local bb = Boxes(rb)
eq(bb[1].kind .. "/" .. bb[2].kind, "block/slider", "slider rows: floating slider, shared panel")
eq(bb[2]:GetChecked(), true, "Brightness panel box ticked: the existing panel row")
bb[2]:SetChecked(false)
bb[2].scripts.OnClick(bb[2])
eq(QT.panel.rows.brightness.frame:IsShown(), false, "unticking hides the existing Brightness row")
eq(QT.all["Brightness@slider"], nil, "no duplicate panel row is made")
bb[2]:SetChecked(true)
bb[2].scripts.OnClick(bb[2])
eq(QT.panel.rows.brightness.frame:IsShown(), true, "re-ticking shows it again")
bb[1]:SetChecked(true)
bb[1].scripts.OnClick(bb[1])
local bblk = _G["QuickToggle_Brightness_block_Slider"]
bblk:SetValue(70)
eq(QuickToggleDB.undo.Brightness, 50, "a Brightness block shares the panel row's undo point")
eq(QT.panel.rows.brightness.undo:IsEnabled(), true, "panel row's undo lights up from the block")
Stub.Slash("brightness undo")
eq(bblk:GetValue(), 50, "undo from chat moves the block back")
local rm = Stub.ShowRow(iMusic)
local mb = Boxes(rm)
eq(mb[2]:GetChecked(), true, "Music minimap box ticked: it is the existing note button")
mb[2]:SetChecked(false)
mb[2].scripts.OnClick(mb[2])
eq(mu:IsShown(), false, "unticking it hides the note button")
eq(QT.all["Sound_EnableMusic@bubble"], nil, "no duplicate music bubble")
mb[2]:SetChecked(true)
mb[2].scripts.OnClick(mb[2])
eq(mu:IsShown(), true, "re-ticking shows it")
local rg = Stub.ShowRow(iGamma)
local gb = Boxes(rg)
gb[1]:SetChecked(true)
gb[1].scripts.OnClick(gb[1])
local gblk = _G["QuickToggle_Gamma_block_Slider"]
eq(gblk.step, 0.1, "gamma block steps 0.1")
gblk.scripts.OnMouseWheel(gblk, 1)
eq(Stub.cvars.Gamma, "1.1", "gamma block wheel")
Stub.Slash("gamma undo")

-- Rows reused for something else: boxes reassigned or hidden.
SettingsListElementMixin.Init(r1, iCamera)
local rb1 = Boxes(r1)
eq(#rb1, 4, "a reused row keeps its four boxes")
eq(rb1[1].info.var, "cameraSmoothStyle", "and points them at the new setting")
SettingsListElementMixin.Init(r1, iButtonRow)
eq(rb1[1]:IsShown() or rb1[2]:IsShown(), false, "boxes hide on a row that is not a setting")
local rbtn = Stub.ShowRow(iButtonRow)
eq(#Boxes(rbtn), 0, "no boxes are ever made for rows that are not settings")
local raddon = Stub.ShowRow(Stub.addonCategories[1].initializers[1])
eq(#Boxes(raddon), 0, "add-on settings (ours included) get no boxes")

-- Slash commands and the list cover the new kinds.
Stub.Slash("autolootdefault@float")
eq(Stub.cvars.autoLootDefault, "1", "/qt <key> works for generic toggles, any case")
Stub.Slash("maxfps@block 120")
eq(Stub.cvars.maxFPS, "120", "/qt <key> <value> works for floating sliders")
Stub.Slash("maxfps@block undo")
eq(Stub.cvars.maxFPS, "60", "and undo")
local n2 = #Stub.printed
Stub.Slash("list")
local listed = table.concat(Stub.printed, "\n", n2 + 1)
check(listed:find("floating button") and listed:find("floating slider"), "/qt list covers floating buttons and sliders")
Stub.Slash("disable autolootdefault@bubble")
eq(bub:IsShown(), false, "/qt disable works on generic keys")
Stub.Slash("enable autolootdefault@bubble")

-- Opening Options from the menu.
Stub.openedCategory = nil
Stub.Slash("options")
eq(Stub.openedCategory, Stub.addonCategories[1]:GetID(), "/qt options opens Options at the Quick Toggle page")
check(Stub.LastPrint():find("two Quick Toggle boxes") ~= nil, "and explains the boxes")
QT:OpenMenu(UIParent)
QuickToggleMenu.options.scripts.OnClick(QuickToggleMenu.options)
eq(QuickToggleMenu:IsShown(), false, "menu's 'Add more' button closes the menu")
QuickToggleMenu.proxy:SetChecked(true)
QuickToggleMenu.proxy.scripts.OnClick(QuickToggleMenu.proxy)
eq(QuickToggleDB.allowProxy, true, "menu has the 'allow Blizzard code' switch")
Stub.Slash("blizzard off")

-------------------------------------------------------------------------------
-- /reload: ticked controls come back
-------------------------------------------------------------------------------
local savedDB = QuickToggleDB
local keep = { UIParent, Minimap }
Stub.frames = keep
SettingsListElementMixin.Init = Stub.origRowInit
Stub.addonCategories = {}
QuickToggle = nil
Stub.LoadAddon(addonDir, "QuickToggle")
local QT2 = QuickToggle
check(QT2 ~= QT, "addon reloaded")
eq(QuickToggleDB, savedDB, "saved variables carried over")
check(QT2.all["autoLootDefault@float"] and _G["QuickToggle_autoLootDefault_float_Float"]:IsShown(), "floating button is back after a reload")
check(QT2.all["autoLootDefault@bubble"] and _G["QuickToggle_autoLootDefault_bubble_Button"]:IsShown(), "minimap button is back")
check(QT2.all["maxFPS@block"] and _G["QuickToggle_maxFPS_block_Block"]:IsShown(), "floating slider is back")
check(QT2.panel.rows["maxFPS@slider"] and QT2.panel.rows["maxFPS@slider"].frame:IsShown(), "shared panel row is back")
eq(QT2.all["Sound_EnableMusic@float"], nil, "nothing that was never ticked is created")
eq(QT2.all["PROXY_SELF_CAST@float"] ~= nil, true, "proxy control restored (it was ticked)")
eq(_G["QuickToggle_PROXY_SELF_CAST_float_Float"]:IsShown(), false, "but stays hidden while Blizzard code is not allowed")
local rr = Stub.ShowRow(iAutoLoot)
local rrb = Boxes(rr)
eq(rrb[1]:GetChecked() and rrb[2]:GetChecked(), true, "boxes in the Options window show the restored state")
eq(#QT2.floats, 5, "all five ticked floating buttons restored")
local nFloats, nBlocks, nBubbles = #QT2.floats, #QT2.blocks, #QT2.toggles
Stub.Fire("SETTINGS_LOADED")
eq(#QT2.floats .. "/" .. #QT2.blocks .. "/" .. #QT2.toggles, nFloats .. "/" .. nBlocks .. "/" .. nBubbles, "a second settings-loaded event creates no duplicates")

io.write(string.format("%d passed, %d failed\n", passes, failures))
return failures > 0

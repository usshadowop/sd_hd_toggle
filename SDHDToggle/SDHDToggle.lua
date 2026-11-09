--[[
	SD/HD Toggle  -  World of Warcraft: Forever (interface 16001)

	One small button on the screen. Click it and the game switches between Standard
	Definition (the original 2004 models) and High Definition character models. The
	same switch is on a key binding and a slash command.

	How it works (checked against Blizzard's UI source for build 1.60.1.70862):

	* The Forever client exposes the switch on the C_GameRules namespace:
	    C_GameRules.IsSDHDToggleEnabled()            -> is the choice offered at all
	    C_GameRules.AccountHasSDEnabled()            -> true when SD models are active
	    C_GameRules.SetSDHDToggleValue(setToSD, loc) -> flip it; loc says which UI did it
	  Blizzard's own Barbershop checkbox (BarberShopSDToggleMixin) calls exactly these
	  three from a plain OnClick, so no hardware event or reload is needed.
	* The setting is account wide (the getter is literally "AccountHas..."), so one
	  press changes it for every character you log in with.
	* There is no event for the value changing, so the button re-reads the getter a
	  couple of times a second and fixes its label if the Barbershop or the Options
	  menu changed it behind our back.
]]

local ADDON_NAME = ...

local SDHDToggle = {}
_G.SDHDToggle = SDHDToggle

-------------------------------------------------------------------------------
-- Settings
-------------------------------------------------------------------------------

local DEFAULTS = {
	pos = nil,        -- { point, relPoint, x, y } relative to UIParent
	shown = true,
	locked = false,   -- true = the button cannot be dragged
	scale = 1,
	sound = true,
	announce = true,  -- print a chat line on every switch
}

local db -- SDHDToggleDB after ADDON_LOADED

local POLL = 0.5 -- seconds between re-reads of the game's current value

-------------------------------------------------------------------------------
-- Game API
-------------------------------------------------------------------------------

-- Enum.SdToggleUsageLocationUI: BeforeLogin=0, CharacterCreation=1, BarberShop=2, OptionsMenu=3.
-- We report ourselves as the options menu, the closest match for an in-world button.
local function UsageLocation()
	local e = Enum and Enum.SdToggleUsageLocationUI
	return (e and e.OptionsMenu) or 3
end

local function HasAPI()
	local gr = C_GameRules
	return gr ~= nil
		and type(gr.IsSDHDToggleEnabled) == "function"
		and type(gr.AccountHasSDEnabled) == "function"
		and type(gr.SetSDHDToggleValue) == "function"
end

function SDHDToggle.IsAvailable()
	return HasAPI() and C_GameRules.IsSDHDToggleEnabled() == true
end

-- true = SD models are active, false = HD, nil = cannot tell
function SDHDToggle.IsSD()
	if not HasAPI() then return nil end
	return C_GameRules.AccountHasSDEnabled() == true
end

local function Print(msg)
	print("|cff33ff99SD/HD Toggle:|r " .. msg)
end

-------------------------------------------------------------------------------
-- The button
-------------------------------------------------------------------------------

-- A plain box: dark background, thin border, yellow text that reads HD or SD.
local button = CreateFrame("Button", "SDHDToggleButton", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
button:SetSize(56, 32)
button:SetFrameStrata("MEDIUM")
button:SetMovable(true)
button:SetClampedToScreen(true)
button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
button:RegisterForDrag("LeftButton")
if button.SetBackdrop then
	button:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		edgeSize = 1,
	})
	button:SetBackdropColor(0, 0, 0, 0.7)
	button:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.9)
end
button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
button.text:SetPoint("CENTER", 0, 0)
button.text:SetTextColor(1, 0.82, 0) -- WoW's yellow
button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
button.highlight:SetAllPoints()
button.highlight:SetColorTexture(1, 1, 1, 0.08)
button:Hide()

local function SavePosition()
	local point, _, relPoint, x, y = button:GetPoint(1)
	if point then
		db.pos = { point, relPoint, x, y }
	end
end

local function RestorePosition()
	button:ClearAllPoints()
	local p = db.pos
	if p then
		button:SetPoint(p[1], UIParent, p[2], p[3], p[4])
	else
		button:SetPoint("TOP", UIParent, "TOP", 0, -8)
	end
	button:SetScale(db.scale or 1)
end

-- The label shows the mode that is active right now; the tooltip says what a click does.
local lastSeen = nil
function SDHDToggle.Refresh()
	local isSD = SDHDToggle.IsSD()
	if isSD == nil then
		button.text:SetText("?")
	else
		button.text:SetText(isSD and "SD" or "HD")
	end
	lastSeen = isSD
	if GameTooltip and GameTooltip:IsOwned(button) then
		button:GetScript("OnEnter")(button)
	end
end

function SDHDToggle.Switch(toSD)
	if not HasAPI() then
		Print("this client has no SD/HD model switch (C_GameRules.SetSDHDToggleValue is missing).")
		return false
	end
	if not C_GameRules.IsSDHDToggleEnabled() then
		Print("the SD/HD switch is turned off on this realm or account.")
		return false
	end
	if toSD == nil then
		toSD = not SDHDToggle.IsSD()
	end
	if toSD == SDHDToggle.IsSD() then
		Print((toSD and "SD" or "HD") .. " models are already active.")
		SDHDToggle.Refresh()
		return false
	end
	C_GameRules.SetSDHDToggleValue(toSD, UsageLocation())
	if db.sound and PlaySound and SOUNDKIT then
		PlaySound(toSD and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	end
	if db.announce then
		Print("switched to " .. (toSD and "|cffffffffSD|r (classic)" or "|cffffd100HD|r") .. " character models.")
	end
	SDHDToggle.Refresh()
	return true
end

function SDHDToggle.SetShown(shown)
	db.shown = shown and true or false
	if db.shown and SDHDToggle.IsAvailable() then
		button:Show()
	else
		button:Hide()
	end
end

button:SetScript("OnClick", function(self, mouseButton)
	if mouseButton == "RightButton" then
		db.locked = not db.locked
		Print(db.locked and "button locked in place. Right-click it again to unlock." or "button unlocked, drag it to move.")
		return
	end
	SDHDToggle.Switch()
end)

button:SetScript("OnDragStart", function(self)
	if not db.locked then
		self:StartMoving()
	end
end)

button:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()
	SavePosition()
end)

button:SetScript("OnEnter", function(self)
	if not GameTooltip then return end
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
	GameTooltip:ClearLines()
	GameTooltip:AddLine("SD/HD Toggle")
	local isSD = SDHDToggle.IsSD()
	if isSD == nil then
		GameTooltip:AddLine("This client does not offer the switch.", 1, 0.3, 0.3)
	else
		GameTooltip:AddDoubleLine("Now showing", isSD and "SD (classic) models" or "HD models", 1, 1, 1, 1, 0.82, 0)
		GameTooltip:AddLine("Click to switch to " .. (isSD and "HD" or "SD") .. " models.", 0.6, 1, 0.6)
	end
	GameTooltip:AddLine(db.locked and "Right-click to unlock the button." or "Drag to move. Right-click to lock it.", 0.5, 0.5, 0.5)
	GameTooltip:AddLine("/sdhd for commands", 0.5, 0.5, 0.5)
	GameTooltip:Show()
end)

button:SetScript("OnLeave", function()
	if GameTooltip then GameTooltip:Hide() end
end)

-- No event fires when the value changes elsewhere (Barbershop, Options menu), so poll.
local elapsed = 0
button:SetScript("OnUpdate", function(self, dt)
	elapsed = elapsed + dt
	if elapsed < POLL then return end
	elapsed = 0
	if SDHDToggle.IsSD() ~= lastSeen then
		SDHDToggle.Refresh()
	end
end)

-------------------------------------------------------------------------------
-- Key bindings (Bindings.xml calls these)
-------------------------------------------------------------------------------

BINDING_NAME_SDHDTOGGLE_SWITCH = "SD/HD Toggle: switch models"
BINDING_NAME_SDHDTOGGLE_SHOWHIDE = "SD/HD Toggle: show/hide the button"

function SDHDToggle_Switch()
	if not db then return end
	SDHDToggle.Switch()
end

function SDHDToggle_ShowHide()
	if not db then return end
	SDHDToggle.SetShown(not db.shown)
end

local function BindKey(key)
	key = key and key:upper()
	if not key or key == "" then
		Print("usage: /sdhd key <KEY>   e.g. /sdhd key F10")
		return
	end
	local ok = SetBinding(key, "SDHDTOGGLE_SWITCH")
	if ok then
		SaveBindings(GetCurrentBindingSet())
		Print(key .. " now switches SD/HD.")
	else
		Print("could not bind " .. key .. ".")
	end
end

-------------------------------------------------------------------------------
-- Slash commands
-------------------------------------------------------------------------------

SLASH_SDHDTOGGLE1 = "/sdhd"
SLASH_SDHDTOGGLE2 = "/sdhdtoggle"

local function Status()
	local isSD = SDHDToggle.IsSD()
	if isSD == nil then
		Print("this client has no SD/HD model switch.")
	elseif not SDHDToggle.IsAvailable() then
		Print("the switch is turned off here. Models: " .. (isSD and "SD" or "HD") .. ".")
	else
		Print("models: " .. (isSD and "|cffffffffSD|r (classic)" or "|cffffd100HD|r")
			.. ". Button " .. (db.shown and "shown" or "hidden") .. (db.locked and ", locked" or "")
			.. ". Key: " .. (GetBindingKey and GetBindingKey("SDHDTOGGLE_SWITCH") or "none") .. ".")
	end
end

SlashCmdList["SDHDTOGGLE"] = function(msg)
	if not db then return end
	msg = (msg or ""):match("^%s*(.-)%s*$")
	local cmd, rest = msg:match("^(%S+)%s*(.-)$")
	cmd = (cmd or ""):lower()

	if cmd == "" or cmd == "toggle" or cmd == "switch" then
		SDHDToggle.Switch()
	elseif cmd == "sd" or cmd == "classic" then
		SDHDToggle.Switch(true)
	elseif cmd == "hd" then
		SDHDToggle.Switch(false)
	elseif cmd == "show" then
		SDHDToggle.SetShown(true)
	elseif cmd == "hide" then
		SDHDToggle.SetShown(false)
	elseif cmd == "button" then
		SDHDToggle.SetShown(not db.shown)
	elseif cmd == "lock" then
		db.locked = true
		Print("button locked.")
	elseif cmd == "unlock" then
		db.locked = false
		Print("button unlocked.")
	elseif cmd == "reset" then
		db.pos = nil
		db.scale = 1
		RestorePosition()
		SDHDToggle.SetShown(true)
		Print("button position reset.")
	elseif cmd == "scale" then
		local n = tonumber(rest)
		if n and n >= 0.5 and n <= 3 then
			db.scale = n
			button:SetScale(n)
		else
			Print("usage: /sdhd scale <0.5 - 3>")
		end
	elseif cmd == "sound" then
		db.sound = (rest:lower() ~= "off")
		Print("sound " .. (db.sound and "on" or "off") .. ".")
	elseif cmd == "announce" then
		db.announce = (rest:lower() ~= "off")
		Print("chat announcement " .. (db.announce and "on" or "off") .. ".")
	elseif cmd == "key" then
		BindKey(rest)
	elseif cmd == "status" then
		Status()
	else
		Print("commands: /sdhd (switch), sd, hd, show, hide, button, lock, unlock, reset, scale <n>, sound on|off, announce on|off, key <KEY>, status")
	end
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= ADDON_NAME then return end
		SDHDToggleDB = SDHDToggleDB or {}
		db = SDHDToggleDB
		for k, v in pairs(DEFAULTS) do
			if db[k] == nil then db[k] = v end
		end
		RestorePosition()
	elseif event == "PLAYER_LOGIN" then
		if not db then return end
		SDHDToggle.Refresh()
		if not HasAPI() then
			Print("this client has no SD/HD model switch; the button is hidden. Type /sdhd status to check again.")
		elseif not C_GameRules.IsSDHDToggleEnabled() then
			Print("the SD/HD switch is turned off on this realm or account; the button is hidden.")
		end
		SDHDToggle.SetShown(db.shown)
	elseif event == "PLAYER_ENTERING_WORLD" then
		if db then SDHDToggle.Refresh() end
	end
end)

--[[
	Quick Toggle  -  World of Warcraft: Forever (interface 16001)

	A set of round minimap buttons, one per game setting, each flipped with a single click.
	Which buttons you want is chosen from a menu (right-click any button, or /qt).

	Core.lua is the framework: saved settings, the minimap button factory, the menu, the
	slash command and key bindings, and a half-second poll that keeps every button's
	picture in step with the game if the setting is changed somewhere else.

	Each toggle lives in Toggles/<name>.lua and registers itself with QuickToggle:Register,
	giving: a key and name, how to read and write the setting, how to draw the inside of
	the button, and what the tooltip should say. See Toggles/Music.lua for the smallest
	example.
]]

local ADDON_NAME = ...

local QT = {
	toggles = {},  -- registration order
	byKey = {},
	buttons = {},  -- key -> minimap button
}
_G.QuickToggle = QT

-------------------------------------------------------------------------------
-- Settings
-------------------------------------------------------------------------------

local DEFAULTS = {
	shown = true,      -- master switch for all buttons
	locked = false,    -- true = buttons cannot be dragged
	sound = true,      -- click sound on every flip
	announce = true,   -- chat line on every flip
	buttons = {},      -- key -> { enabled = bool, angle = degrees around the minimap }
}

local db -- QuickToggleDB after ADDON_LOADED

local POLL = 0.5     -- seconds between re-reads of every setting
local RING_PAD = 5   -- px outside the minimap edge
local YELLOW = { 1, 0.82, 0 }
QT.YELLOW = YELLOW

local function Print(msg)
	print("|cff33ff99Quick Toggle:|r " .. msg)
end
QT.Print = Print

-------------------------------------------------------------------------------
-- Registry
-------------------------------------------------------------------------------

--[[
	def = {
		key = "music",               -- used in saved variables, slash commands and bindings
		name = "Music",              -- menu and tooltip title
		defaultAngle = 200,          -- where on the minimap ring it first appears (0 = right, 90 = top)
		defaultEnabled = true,       -- shown until the user unticks it in the menu (default true)
		IsAvailable = function() return ok, reasonIfNot end,   -- optional
		Get = function() return value end,                      -- current value (nil = unknown)
		Set = function(value) end,                              -- write it to the game
		Next = function(value) return other end,                -- optional, default `not value`
		Describe = function(value) return "music on" end,       -- for chat lines
		Parse = function(text) return value end,                -- optional, for "/qt music off"
		Create = function(button, disc) end,                    -- build textures once
		Update = function(button, value) end,                   -- draw the current value
		Tooltip = function(tooltip, value) end,                 -- optional extra lines
		events = { "CVAR_UPDATE" },                             -- optional, re-read on these
	}
]]
function QT:Register(def)
	assert(type(def) == "table" and def.key and def.name and def.Get and def.Set, "Quick Toggle: bad toggle definition")
	assert(not self.byKey[def.key], "Quick Toggle: duplicate toggle " .. tostring(def.key))
	if def.defaultEnabled == nil then def.defaultEnabled = true end
	def.Describe = def.Describe or function(v) return tostring(v) end
	def.Next = def.Next or function(v) return not v end
	self.toggles[#self.toggles + 1] = def
	self.byKey[def.key] = def
	if db then self:Setup(def) end -- registered after ADDON_LOADED
end

function QT:Available(def)
	if def.IsAvailable then
		local ok, reason = def.IsAvailable()
		return ok and true or false, reason
	end
	return true
end

function QT:Settings(key)
	local def = self.byKey[key]
	local s = db.buttons[key]
	if not s then
		s = { enabled = def and def.defaultEnabled or true, angle = def and def.defaultAngle or 220 }
		db.buttons[key] = s
	end
	if s.enabled == nil then s.enabled = def and def.defaultEnabled or true end
	if s.angle == nil then s.angle = def and def.defaultAngle or 220 end
	return s
end

function QT:IsEnabled(key)
	return self:Settings(key).enabled
end

-------------------------------------------------------------------------------
-- Minimap buttons
-------------------------------------------------------------------------------

-- Half the live minimap width plus a few px puts the button on the outer ring beside the
-- calendar and tracking buttons, whatever size the minimap is.
local function MinimapRadius()
	local w = Minimap and Minimap.GetWidth and Minimap:GetWidth()
	if not w or w < 50 then return 80 end
	return w / 2 + RING_PAD
end

function QT:Place(def)
	local b = self.buttons[def.key]
	if not b then return end
	local a = math.rad(self:Settings(def.key).angle)
	local r = MinimapRadius()
	b:ClearAllPoints()
	b:SetPoint("CENTER", Minimap or UIParent, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

function QT:PlaceAll()
	for _, def in ipairs(self.toggles) do self:Place(def) end
end

if Minimap and Minimap.HookScript then
	Minimap:HookScript("OnSizeChanged", function()
		if db then QT:PlaceAll() end
	end)
end

local function OnDrag(self)
	local parent = Minimap or UIParent
	local mx, my = parent:GetCenter()
	local cx, cy = GetCursorPosition()
	local scale = parent:GetEffectiveScale()
	if not (mx and cx and scale and scale > 0) then return end
	cx, cy = cx / scale, cy / scale
	QT:Settings(self.def.key).angle = math.deg(math.atan2(cy - my, cx - mx))
	QT:Place(self.def)
end

local function OnEnter(self)
	if not GameTooltip then return end
	local def = self.def
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:ClearLines()
	GameTooltip:AddLine(def.name)
	local ok, reason = QT:Available(def)
	if not ok then
		GameTooltip:AddLine(reason or "Not available.", 1, 0.3, 0.3)
	elseif def.Tooltip then
		def.Tooltip(GameTooltip, def.Get())
	else
		GameTooltip:AddLine("Now: " .. def.Describe(def.Get()), 1, 1, 1)
		GameTooltip:AddLine("Click to switch to " .. def.Describe(def.Next(def.Get())) .. ".", 0.6, 1, 0.6)
	end
	GameTooltip:AddLine(db.locked and "Right-click for the menu. Buttons are locked." or "Right-click for the menu. Drag to move.", 0.5, 0.5, 0.5)
	GameTooltip:Show()
end

local function OnLeave()
	if GameTooltip then GameTooltip:Hide() end
end

local function CreateButton(def)
	local b = CreateFrame("Button", "QuickToggle_" .. def.key .. "_Button", Minimap or UIParent)
	b.def = def
	b:SetSize(31, 31)
	b:SetFrameStrata("MEDIUM")
	b:SetFrameLevel(8)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:RegisterForDrag("LeftButton")
	b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	b.bg = b:CreateTexture(nil, "BACKGROUND")
	b.bg:SetSize(21, 21)
	b.bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	b.bg:SetPoint("TOPLEFT", 6, -5)
	b.disc = b:CreateTexture(nil, "BORDER")
	b.disc:SetSize(19, 19)
	b.disc:SetColorTexture(0.05, 0.05, 0.05, 0.9)
	b.disc:SetPoint("CENTER", b.bg, "CENTER")
	b.ring = b:CreateTexture(nil, "OVERLAY")
	b.ring:SetSize(53, 53)
	b.ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	b.ring:SetPoint("TOPLEFT")
	if def.Create then def.Create(b, b.disc) end

	b:SetScript("OnClick", function(self, mouseButton)
		if mouseButton == "RightButton" then
			QT:OpenMenu(self)
		else
			QT:Press(def.key)
		end
	end)
	b:SetScript("OnDragStart", function(self)
		if db.locked then return end
		self:SetScript("OnUpdate", OnDrag)
	end)
	b:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
	end)
	b:SetScript("OnEnter", OnEnter)
	b:SetScript("OnLeave", OnLeave)
	b:Hide()
	return b
end

-- Redraw one button from the game's current value.
function QT:Update(def)
	local b = self.buttons[def.key]
	if not b then return end
	local value = def.Get()
	b.last = value
	if def.Update then def.Update(b, value) end
	if GameTooltip and GameTooltip:IsOwned(b) then OnEnter(b) end
end

function QT:ApplyVisibility(def)
	local b = self.buttons[def.key]
	if not b then return end
	if db.shown and self:IsEnabled(def.key) and self:Available(def) then
		self:Update(def)
		b:Show()
	else
		b:Hide()
	end
end

function QT:Setup(def)
	if not self.buttons[def.key] then
		self.buttons[def.key] = CreateButton(def)
	end
	self:Settings(def.key)
	self:Place(def)
	self:ApplyVisibility(def)
end

function QT:Refresh()
	for _, def in ipairs(self.toggles) do self:ApplyVisibility(def) end
end

-------------------------------------------------------------------------------
-- Flipping a setting
-------------------------------------------------------------------------------

-- Flip toggle `key`, or set it to `value` when given. Returns true if the game was changed.
function QT:Press(key, value)
	local def = self.byKey[key]
	if not def then
		Print("no toggle called '" .. tostring(key) .. "'. /qt list shows them.")
		return false
	end
	local ok, reason = self:Available(def)
	if not ok then
		Print(def.name .. ": " .. (reason or "not available here."))
		return false
	end
	local cur = def.Get()
	if value == nil then value = def.Next(cur) end
	if value == cur then
		Print(def.name .. ": already " .. def.Describe(cur) .. ".")
		self:Update(def)
		return false
	end
	def.Set(value)
	if db.sound and PlaySound and SOUNDKIT then
		PlaySound(value and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
	end
	if db.announce then
		Print(def.name .. ": " .. def.Describe(value) .. ".")
	end
	self:Update(def)
	return true
end

function QT:SetEnabled(key, enabled)
	local def = self.byKey[key]
	if not def then return false end
	self:Settings(key).enabled = enabled and true or false
	self:ApplyVisibility(def)
	return true
end

function QT:SetShown(shown)
	db.shown = shown and true or false
	self:Refresh()
end

function QT:ResetPositions()
	for _, def in ipairs(self.toggles) do
		self:Settings(def.key).angle = def.defaultAngle or 220
	end
	self:PlaceAll()
end

-------------------------------------------------------------------------------
-- The menu: tick the toggles you want as buttons
-------------------------------------------------------------------------------

local fallbackMenu

-- Used when the client has no MenuUtil (and in the headless tests).
local function OpenFallbackMenu(owner)
	local m = fallbackMenu
	if not m then
		m = CreateFrame("Frame", "QuickToggleMenu", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
		fallbackMenu = m
		m:SetFrameStrata("DIALOG")
		m:SetSize(220, 100)
		m:EnableMouse(true)
		if m.SetBackdrop then
			m:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
			m:SetBackdropColor(0, 0, 0, 0.9)
			m:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
		end
		m.title = m:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		m.title:SetPoint("TOPLEFT", 12, -10)
		m.title:SetText("Quick Toggle")
		m.close = CreateFrame("Button", nil, m, "UIPanelCloseButton")
		m.close:SetPoint("TOPRIGHT", 2, 2)
		m.close:SetScript("OnClick", function() m:Hide() end)
		m.rows = {}
		m.lock = CreateFrame("CheckButton", nil, m, "UICheckButtonTemplate")
		m.lock:SetSize(24, 24)
		m.lock.label = m:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		m.lock.label:SetPoint("LEFT", m.lock, "RIGHT", 2, 0)
		m.lock.label:SetText("Lock buttons in place")
		m.lock:SetScript("OnClick", function(self) db.locked = self:GetChecked() and true or false end)
		m.reset = CreateFrame("Button", nil, m, "UIPanelButtonTemplate")
		m.reset:SetSize(120, 22)
		m.reset:SetText("Reset positions")
		m.reset:SetScript("OnClick", function() QT:ResetPositions() end)
		if UISpecialFrames then tinsert(UISpecialFrames, "QuickToggleMenu") end
	end

	local y = -30
	for i, def in ipairs(QT.toggles) do
		local row = m.rows[i]
		if not row then
			row = CreateFrame("CheckButton", nil, m, "UICheckButtonTemplate")
			row:SetSize(24, 24)
			row.label = m:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			row.label:SetPoint("LEFT", row, "RIGHT", 2, 0)
			row:SetScript("OnClick", function(self)
				QT:SetEnabled(self.def.key, self:GetChecked() and true or false)
			end)
			m.rows[i] = row
		end
		row.def = def
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", 10, y)
		row:SetChecked(QT:IsEnabled(def.key))
		local ok, reason = QT:Available(def)
		row.label:SetText(ok and def.name or (def.name .. " |cff888888(" .. (reason or "not available") .. ")|r"))
		row:Show()
		y = y - 24
	end
	for i = #QT.toggles + 1, #m.rows do m.rows[i]:Hide() end

	m.lock:ClearAllPoints()
	m.lock:SetPoint("TOPLEFT", 10, y - 6)
	m.lock:SetChecked(db.locked)
	m.reset:ClearAllPoints()
	m.reset:SetPoint("TOPLEFT", 14, y - 36)
	m:SetHeight(-y + 72)

	m:ClearAllPoints()
	if owner and owner ~= UIParent then
		m:SetPoint("TOPRIGHT", owner, "BOTTOMLEFT", 0, 0)
	else
		local x, cy = GetCursorPosition()
		local s = UIParent:GetEffectiveScale()
		m:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / s, cy / s)
	end
	m:Show()
end

function QT:OpenMenu(owner)
	if not db then return end
	if MenuUtil and MenuUtil.CreateContextMenu then
		MenuUtil.CreateContextMenu(owner or UIParent, function(_, root)
			root:CreateTitle("Quick Toggle")
			for _, def in ipairs(QT.toggles) do
				local ok, reason = QT:Available(def)
				local box = root:CreateCheckbox(def.name,
					function() return QT:IsEnabled(def.key) end,
					function() QT:SetEnabled(def.key, not QT:IsEnabled(def.key)) end)
				if not ok and box.SetEnabled then
					box:SetEnabled(false)
					if box.SetTooltip then
						box:SetTooltip(function(tooltip) tooltip:AddLine(reason or "Not available.", 1, 0.3, 0.3, true) end)
					end
				end
			end
			root:CreateDivider()
			root:CreateCheckbox("Lock buttons in place",
				function() return db.locked end,
				function() db.locked = not db.locked end)
			root:CreateButton("Reset positions", function() QT:ResetPositions() end)
		end)
	else
		OpenFallbackMenu(owner)
	end
end

-------------------------------------------------------------------------------
-- Key bindings (Bindings.xml calls this) and slash commands
-------------------------------------------------------------------------------

BINDING_NAME_QUICKTOGGLE_MENU = "Quick Toggle: open the menu"

function QuickToggle_Press(key)
	if not db then return end
	if key == "menu" then
		QT:OpenMenu(UIParent)
	else
		QT:Press(key)
	end
end

local function BindKey(toggleKey, key)
	local def = QT.byKey[toggleKey]
	key = key and key:upper()
	if not def or not key or key == "" then
		Print("usage: /qt key <toggle> <KEY>   e.g. /qt key music F11")
		return
	end
	local action = "QUICKTOGGLE_" .. toggleKey:upper()
	if not _G["BINDING_NAME_" .. action] then
		Print(def.name .. " has no key binding entry (needs a line in Bindings.xml).")
		return
	end
	if SetBinding(key, action) then
		SaveBindings(GetCurrentBindingSet())
		Print(key .. " now flips " .. def.name .. ".")
	else
		Print("could not bind " .. key .. ".")
	end
end

local function List()
	for _, def in ipairs(QT.toggles) do
		local ok, reason = QT:Available(def)
		local s = QT:Settings(def.key)
		Print(string.format("%s  (/qt %s)  button %s  now: %s%s",
			def.name, def.key,
			s.enabled and "on" or "off",
			ok and def.Describe(def.Get()) or "n/a",
			ok and "" or ("  - " .. (reason or "not available"))))
	end
end

SLASH_QUICKTOGGLE1 = "/qt"
SLASH_QUICKTOGGLE2 = "/quicktoggle"

SlashCmdList["QUICKTOGGLE"] = function(msg)
	if not db then return end
	msg = (msg or ""):match("^%s*(.-)%s*$")
	local cmd, rest = msg:match("^(%S+)%s*(.-)$")
	cmd = (cmd or ""):lower()
	rest = rest or ""

	if cmd == "" or cmd == "menu" then
		QT:OpenMenu(UIParent)
	elseif QT.byKey[cmd] then
		local def = QT.byKey[cmd]
		if rest == "" then
			QT:Press(cmd)
		elseif rest:lower() == "on" and not def.Parse then
			QT:Press(cmd, true)
		elseif rest:lower() == "off" and not def.Parse then
			QT:Press(cmd, false)
		elseif def.Parse then
			local v = def.Parse(rest)
			if v == nil then Print(def.name .. ": don't know '" .. rest .. "'.") else QT:Press(cmd, v) end
		else
			Print(def.name .. ": don't know '" .. rest .. "'.")
		end
	elseif cmd == "enable" or cmd == "disable" then
		local key = rest:lower()
		if QT:SetEnabled(key, cmd == "enable") then
			Print(QT.byKey[key].name .. " button " .. (cmd == "enable" and "on." or "off."))
		else
			Print("no toggle called '" .. key .. "'. /qt list shows them.")
		end
	elseif cmd == "list" or cmd == "status" then
		List()
	elseif cmd == "show" then
		QT:SetShown(true)
	elseif cmd == "hide" then
		QT:SetShown(false)
	elseif cmd == "lock" then
		db.locked = true
		Print("buttons locked.")
	elseif cmd == "unlock" then
		db.locked = false
		Print("buttons unlocked, drag them to move.")
	elseif cmd == "reset" then
		QT:ResetPositions()
		QT:SetShown(true)
		Print("button positions reset.")
	elseif cmd == "sound" then
		db.sound = (rest:lower() ~= "off")
		Print("sound " .. (db.sound and "on" or "off") .. ".")
	elseif cmd == "announce" then
		db.announce = (rest:lower() ~= "off")
		Print("chat announcement " .. (db.announce and "on" or "off") .. ".")
	elseif cmd == "key" then
		local t, k = rest:match("^(%S+)%s+(%S+)$")
		BindKey(t and t:lower(), k)
	else
		Print("commands: /qt (menu), /qt <toggle> [value], enable|disable <toggle>, list, show, hide, lock, unlock, reset, sound on|off, announce on|off, key <toggle> <KEY>")
	end
end

-------------------------------------------------------------------------------
-- Events and polling
-------------------------------------------------------------------------------

local ev = CreateFrame("Frame", "QuickToggleEvents", UIParent)
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")

local function RegisterToggleEvents()
	for _, def in ipairs(QT.toggles) do
		for _, e in ipairs(def.events or {}) do ev:RegisterEvent(e) end
	end
end

ev:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= ADDON_NAME then return end
		QuickToggleDB = QuickToggleDB or {}
		db = QuickToggleDB
		for k, v in pairs(DEFAULTS) do
			if db[k] == nil then db[k] = (type(v) == "table") and {} or v end
		end
		for _, def in ipairs(QT.toggles) do QT:Setup(def) end
		RegisterToggleEvents()
	elseif event == "PLAYER_LOGIN" then
		if not db then return end
		QT:Refresh()
		for _, def in ipairs(QT.toggles) do
			local ok, reason = QT:Available(def)
			if not ok and QT:IsEnabled(def.key) then
				Print(def.name .. " button hidden: " .. (reason or "not available here") .. ".")
			end
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		if not db then return end
		QT:PlaceAll()
		QT:Refresh()
	else
		if not db then return end
		for _, def in ipairs(QT.toggles) do
			for _, e in ipairs(def.events or {}) do
				if e == event then QT:Update(def) end
			end
		end
	end
end)

-- No event fires for some settings (the SD/HD switch has none), so poll all of them.
local elapsed = 0
ev:SetScript("OnUpdate", function(self, dt)
	elapsed = elapsed + dt
	if elapsed < POLL then return end
	elapsed = 0
	if not db then return end
	for _, def in ipairs(QT.toggles) do
		local b = QT.buttons[def.key]
		if b and b:IsShown() and def.Get() ~= b.last then
			QT:Update(def)
		end
	end
end)

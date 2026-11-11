--[[
	The slider panel: a small dark panel, draggable anywhere, with one row per enabled
	slider:

	    Brightness  [=====o=====]  50%  (undo)

	* Drag the slider, click along it, or roll the mouse wheel over it to change the value.
	  The game setting changes immediately.
	* The undo button remembers where the setting was before you first moved the slider and
	  puts it back. It stays lit until you press it (or slide back to that value yourself),
	  so several small adjustments in a row still undo to the original. The undo point is
	  saved, so it survives a /reload.
	* Right-click anywhere on the panel (a label, a slider, an undo button) to open the
	  Quick Toggle menu, the same one the minimap buttons open.
	* The panel follows the game: if the setting is changed in Options it moves to match.
	* Brightness and contrast are percentages in whole steps; gamma is a plain number in
	  0.1 steps. Clamp and Same keep fractional steps exact.

	Each slider is declared in Sliders/<name>.lua with QuickToggle:RegisterSlider.
]]

local QT = QuickToggle

local ROW_H = 24
local PAD = 6
local LABEL_W = 66
local SLIDER_W = 110
local VALUE_W = 38
local UNDO_W = 20
local PANEL_W = PAD + LABEL_W + 4 + SLIDER_W + 6 + VALUE_W + 2 + UNDO_W + PAD

-- Snaps to the step and range. The round-trip through %.4f strips float noise such as
-- 1.2000000000000002 from fractional steps (gamma moves in 0.1s).
local function Clamp(def, v)
	v = math.floor((v - def.min) / def.step + 0.5) * def.step + def.min
	if v < def.min then v = def.min end
	if v > def.max then v = def.max end
	return tonumber(string.format("%.4f", v))
end

local function Same(a, b)
	return a ~= nil and b ~= nil and math.abs(a - b) < 0.001
end

-- "0" for whole numbers, "0.3" otherwise: for ranges in usage lines and /qt list.
local function Num(v)
	if v == math.floor(v) then return string.format("%d", v) end
	return (string.format("%.2f", v):gsub("0+$", ""))
end

--[[
	def = {
		key = "brightness",          -- saved variables and /qt <key>
		name = "Brightness",         -- row label, menu entry
		cvar = "Brightness",         -- the console variable it drives
		min = 0, max = 100, step = 1,
		defaultEnabled = true,
		Format = function(v) return "50%" end,   -- optional, default "%d%%"; gamma uses "%.1f"
		IsAvailable = function() return ok, reason end, -- optional, default: the cvar exists
		events = { "CVAR_UPDATE" },  -- optional, default as shown
	}
]]
function QT:RegisterSlider(def)
	assert(type(def) == "table" and def.key and def.name and def.cvar and def.min and def.max, "Quick Toggle: bad slider definition")
	assert(not self.sliderByKey[def.key] and not self.byKey[def.key], "Quick Toggle: duplicate key " .. tostring(def.key))
	if def.defaultEnabled == nil then def.defaultEnabled = true end
	def.step = def.step or 1
	def.rangeText = Num(def.min) .. "-" .. Num(def.max)
	def.events = def.events or { "CVAR_UPDATE" }
	def.Format = def.Format or function(v)
		if v == nil then return "?" end
		return string.format("%d%%", math.floor(v + 0.5))
	end
	def.Get = def.Get or function()
		return tonumber(GetCVar(def.cvar))
	end
	def.IsAvailable = def.IsAvailable or function()
		if type(GetCVar) ~= "function" or GetCVar(def.cvar) == nil then
			return false, "this client has no " .. def.cvar .. " setting"
		end
		return true
	end
	self.sliders[#self.sliders + 1] = def
	self.sliderByKey[def.key] = def
	if self.panel then self:SetupSliders() end
end

-- Writes the cvar and checks the game took it. Returns true on success.
local warned = {}
local function Write(def, v)
	local ok = pcall(SetCVar, def.cvar, tostring(v))
	local now = def.Get()
	if ok and Same(now, v) then
		return true
	end
	if not warned[def.key] then
		warned[def.key] = true
		QT.Print(def.name .. ": the game did not accept the change. Try the same setting in Options > Graphics.")
	end
	return false
end

-------------------------------------------------------------------------------
-- Panel
-------------------------------------------------------------------------------

local panel

local function OpenMenuFrom(owner)
	QT:OpenMenu(owner or panel)
end

function QT:PlaceSliderPanel()
	if not panel then return end
	local db = self:DB()
	panel:ClearAllPoints()
	local p = db and db.sliderPos
	if p then
		panel:SetPoint(p[1], UIParent, p[2], p[3], p[4])
	elseif Minimap then
		panel:SetPoint("TOPRIGHT", Minimap, "BOTTOMRIGHT", 8, -28)
	else
		panel:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -16, -240)
	end
end

local function CreatePanel()
	local f = CreateFrame("Frame", "QuickToggleSliderPanel", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f:SetSize(PANEL_W, ROW_H + 2 * PAD)
	f:SetFrameStrata("MEDIUM")
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	if f.SetBackdrop then
		f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
		f:SetBackdropColor(0, 0, 0, 0.7)
		f:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.9)
	end
	f:SetScript("OnDragStart", function(self)
		if QT:DB().locked then return end
		self:StartMoving()
	end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, relPoint, x, y = self:GetPoint(1)
		if point then QT:DB().sliderPos = { point, relPoint, x, y } end
	end)
	f:SetScript("OnMouseUp", function(self, button)
		if button == "RightButton" then OpenMenuFrom(self) end
	end)
	f.rows = {}
	f:Hide()
	return f
end

local function UndoTooltip(btn)
	if not GameTooltip then return end
	local def = btn.def
	local s = QT:Settings(def.key)
	GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
	GameTooltip:ClearLines()
	GameTooltip:AddLine("Undo " .. def.name)
	if s.revert ~= nil then
		GameTooltip:AddLine("Back to " .. def.Format(s.revert) .. ", where it was before you moved the slider.", 1, 1, 1, true)
	else
		GameTooltip:AddLine("Nothing to undo yet. Move the slider first.", 0.6, 0.6, 0.6, true)
	end
	GameTooltip:AddLine("Right-click for the menu.", 0.5, 0.5, 0.5)
	GameTooltip:Show()
end

local function SliderTooltip(sl)
	if not GameTooltip then return end
	local def = sl.def
	GameTooltip:SetOwner(sl, "ANCHOR_RIGHT")
	GameTooltip:ClearLines()
	GameTooltip:AddDoubleLine(def.name, def.Format(def.Get()), 1, 0.82, 0, 1, 1, 1)
	GameTooltip:AddLine("Drag, click, or use the mouse wheel to adjust.", 0.6, 1, 0.6)
	GameTooltip:AddLine("Right-click for the menu.", 0.5, 0.5, 0.5)
	GameTooltip:Show()
end

local function HideTooltip()
	if GameTooltip then GameTooltip:Hide() end
end

local function UpdateRow(row)
	local def = row.def
	local v = def.Get()
	if v ~= nil then
		row.slider.syncing = true
		row.slider:SetValue(v)
		row.slider.syncing = false
	end
	row.last = v
	row.value:SetText(def.Format(v))
	local s = QT:Settings(def.key)
	if s.revert ~= nil then
		row.undo:Enable()
		row.undo.icon:SetAlpha(1)
	else
		row.undo:Disable()
		row.undo.icon:SetAlpha(0.3)
	end
	if GameTooltip then
		if GameTooltip:IsOwned(row.undo) then UndoTooltip(row.undo) end
		if GameTooltip:IsOwned(row.slider) then SliderTooltip(row.slider) end
	end
end

-- User moved the slider (drag, click or wheel).
local function OnSliderChanged(sl, value)
	if sl.syncing then return end
	local def = sl.def
	value = Clamp(def, value)
	local cur = def.Get()
	if cur == nil or Same(cur, value) then return end
	local s = QT:Settings(def.key)
	local revert = s.revert
	if revert == nil then revert = cur end
	if Write(def, value) then
		-- Sliding back onto the undo point means there is nothing left to undo.
		if Same(revert, value) then revert = nil end
		s.revert = revert
	end
	UpdateRow(sl.row)
end

function QT:UndoSlider(key)
	local def = self.sliderByKey[key]
	if not def then return false end
	local s = self:Settings(key)
	if s.revert == nil then
		self.Print(def.name .. ": nothing to undo.")
		return false
	end
	local target = s.revert
	if Write(def, target) then
		s.revert = nil
		if self:DB().announce then self.Print(def.name .. ": back to " .. def.Format(target) .. ".") end
	end
	if self.panel and self.panel.rows[key] then UpdateRow(self.panel.rows[key]) end
	return true
end

-- Same as moving the slider, from chat: keeps the undo point.
function QT:SetSlider(key, value)
	local def = self.sliderByKey[key]
	if not def then return false end
	local ok, reason = self:Available(def)
	if not ok then
		self.Print(def.name .. ": " .. (reason or "not available here."))
		return false
	end
	local row = self.panel and self.panel.rows[key]
	if row then
		OnSliderChanged(row.slider, value)
	else
		local cur = def.Get()
		value = Clamp(def, value)
		if not Same(cur, value) then
			local s = self:Settings(key)
			local revert = (s.revert == nil) and cur or s.revert
			if Write(def, value) then s.revert = (not Same(revert, value)) and revert or nil end
		end
	end
	return true
end

function QT:SliderCommand(key, rest)
	local def = self.sliderByKey[key]
	rest = (rest or ""):lower()
	if rest == "" then
		local s = self:Settings(key)
		self.Print(def.name .. ": " .. def.Format(def.Get())
			.. (s.revert and (", undo goes back to " .. def.Format(s.revert)) or "") .. ".")
	elseif rest == "undo" or rest == "revert" or rest == "back" then
		self:UndoSlider(key)
	else
		local n = tonumber((rest:gsub("%%", "")))
		if not n or n < def.min or n > def.max then
			self.Print(string.format("usage: /qt %s <%s> or /qt %s undo", key, def.rangeText, key))
			return
		end
		if self:SetSlider(key, n) and self:DB().announce then
			self.Print(def.name .. ": " .. def.Format(def.Get()) .. ".")
		end
	end
end

local function CreateRow(def)
	local row = { def = def }

	row.label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.label:SetWidth(LABEL_W)
	row.label:SetJustifyH("LEFT")
	row.label:SetTextColor(QT.YELLOW[1], QT.YELLOW[2], QT.YELLOW[3])
	row.label:SetText(def.name)

	-- The classic horizontal slider look (HorizontalSliderTemplate's backdrop and thumb).
	local sl = CreateFrame("Slider", "QuickToggle_" .. def.key .. "_Slider", panel, BackdropTemplateMixin and "BackdropTemplate" or nil)
	sl.def, sl.row = def, row
	sl:SetOrientation("HORIZONTAL")
	sl:SetSize(SLIDER_W, 17)
	if sl.SetBackdrop then
		sl:SetBackdrop({
			bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
			edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
			tile = true, tileSize = 8, edgeSize = 8,
			insets = { left = 3, right = 3, top = 6, bottom = 6 },
		})
	end
	sl:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
	sl:SetMinMaxValues(def.min, def.max)
	sl:SetValueStep(def.step)
	if sl.SetObeyStepOnDrag then sl:SetObeyStepOnDrag(true) end
	sl:EnableMouseWheel(true)
	sl:SetScript("OnValueChanged", OnSliderChanged)
	sl:SetScript("OnMouseWheel", function(self, delta)
		OnSliderChanged(self, (def.Get() or self:GetValue()) + delta * def.step)
	end)
	sl:SetScript("OnMouseUp", function(self, button)
		if button == "RightButton" then OpenMenuFrom(self) end
	end)
	sl:SetScript("OnEnter", SliderTooltip)
	sl:SetScript("OnLeave", HideTooltip)
	row.slider = sl

	row.value = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.value:SetWidth(VALUE_W)
	row.value:SetJustifyH("RIGHT")

	local undo = CreateFrame("Button", "QuickToggle_" .. def.key .. "_Undo", panel)
	undo.def, undo.row = def, row
	undo:SetSize(UNDO_W, UNDO_W)
	undo:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	undo.icon = undo:CreateTexture(nil, "ARTWORK")
	undo.icon:SetAllPoints()
	undo.icon:SetTexture("Interface\\Buttons\\UI-RefreshButton")
	undo:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
	undo:SetMotionScriptsWhileDisabled(true)
	undo:SetScript("OnClick", function(self, button)
		if button == "RightButton" then
			OpenMenuFrom(self)
		else
			QT:UndoSlider(def.key)
		end
	end)
	-- A disabled button swallows clicks without OnClick; still let right-click reach the menu.
	undo:SetScript("OnMouseUp", function(self, button)
		if button == "RightButton" and not self:IsEnabled() then OpenMenuFrom(self) end
	end)
	undo:SetScript("OnEnter", UndoTooltip)
	undo:SetScript("OnLeave", HideTooltip)
	row.undo = undo

	return row
end

local function SetRowShown(row, shown)
	for _, r in ipairs({ row.label, row.slider, row.value, row.undo }) do
		if shown then r:Show() else r:Hide() end
	end
end

-- Lays out the enabled, available rows; hides the panel when there are none.
function QT:RefreshSliders()
	if not panel then return end
	local db = self:DB()
	local n = 0
	for _, def in ipairs(self.sliders) do
		local row = panel.rows[def.key]
		local show = db.shown and self:IsEnabled(def.key) and self:Available(def)
		if show then
			local y = -PAD - n * ROW_H
			row.label:ClearAllPoints()
			row.label:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, y - 5)
			row.slider:ClearAllPoints()
			row.slider:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD + LABEL_W + 4, y - 3)
			row.value:ClearAllPoints()
			row.value:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD + LABEL_W + 4 + SLIDER_W + 6, y - 6)
			row.undo:ClearAllPoints()
			row.undo:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_W - PAD - UNDO_W, y - 2)
			UpdateRow(row)
			n = n + 1
		end
		SetRowShown(row, show)
	end
	panel:SetHeight(n * ROW_H + 2 * PAD - 4)
	if n > 0 then panel:Show() else panel:Hide() end
end

-- Moves each visible slider to the game's value if it changed elsewhere (Options menu).
function QT:SyncSliders()
	if not panel or not panel:IsShown() then return end
	for _, def in ipairs(self.sliders) do
		local row = panel.rows[def.key]
		if row and row.slider:IsShown() and not Same(def.Get(), row.last) then
			UpdateRow(row)
		end
	end
end

function QT:SetupSliders()
	panel = panel or CreatePanel()
	self.panel = panel
	for _, def in ipairs(self.sliders) do
		if not panel.rows[def.key] then panel.rows[def.key] = CreateRow(def) end
		self:Settings(def.key)
	end
	self:PlaceSliderPanel()
	self:RefreshSliders()
end

--[[
	Sliders, in two forms:

	  slider  a row in the shared slider panel: one dark panel, draggable anywhere, that
	          holds every slider you put in it
	  block   a free-floating block holding just one slider, draggable on its own

	Each row looks like this:

	    Brightness  [=====o=====]  50%  (undo)

	* Drag the slider, click along it, or roll the mouse wheel over it to change the value.
	  The game setting changes immediately.
	* The undo button remembers where the setting was before you first moved the slider and
	  puts it back. It stays lit until you press it (or slide back to that value yourself),
	  so several small adjustments in a row still undo to the original. The undo point is
	  saved per setting, so a panel row and a block for the same setting share it, and it
	  survives a /reload.
	* Right-click anywhere on a panel or block (a label, a slider, an undo button) to open
	  the Quick Toggle menu.
	* Controls follow the game: if the setting is changed in Options they move to match.
	* Clamp and Same keep fractional steps (gamma moves in 0.1s) exact.
]]

local QT = QuickToggle

local ROW_H = 24
local PAD = 6
local LABEL_W = 110
local SLIDER_W = 110
local VALUE_W = 40
local UNDO_W = 20
local ROW_W = LABEL_W + 4 + SLIDER_W + 6 + VALUE_W + 2 + UNDO_W
local PANEL_W = PAD + ROW_W + PAD

-- Snaps to the step and range. The round-trip through %.4f strips float noise such as
-- 1.2000000000000002 from fractional steps.
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
QT.FormatNumber = Num

local function SafeName(key)
	return (key:gsub("[^%w_]", "_"))
end

--[[
	def = {
		key = "brightness",          -- saved variables and /qt <key>
		name = "Brightness",         -- row label, menu entry
		cvar = "Brightness",         -- the console variable it drives (or give Get and Set)
		min = 0, max = 100, step = 1,
		defaultEnabled = true,
		Format = function(v) return "50%" end,   -- optional, default "%d%%"
		Get = function() return number end,      -- optional, default tonumber(GetCVar(cvar))
		Set = function(v) end,                   -- optional, default SetCVar(cvar, v); return false to refuse
		undoKey = "Brightness",      -- optional, default cvar or key; controls with the same undoKey share an undo point
		IsAvailable = function() return ok, reason end, -- optional, default: the cvar exists
		events = { "CVAR_UPDATE" },  -- optional, default as shown
	}
]]
local function SliderDefaults(def)
	assert(def.min and def.max and (def.cvar or (def.Get and def.Set)), "Quick Toggle: bad slider definition")
	def.step = def.step or 1
	def.rangeText = Num(def.min) .. "-" .. Num(def.max)
	def.events = def.events or { "CVAR_UPDATE" }
	def.undoKey = def.undoKey or def.cvar or def.key
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
end

-- A row in the shared slider panel.
function QT:RegisterSlider(def)
	SliderDefaults(def)
	return self:RegisterElement("slider", def)
end

-- A free-floating block holding one slider.
function QT:RegisterBlock(def)
	SliderDefaults(def)
	return self:RegisterElement("block", def)
end

-- Writes the value and checks the game took it. Returns true on success.
local warned = {}
local function Write(def, v)
	local ok, res
	if def.Set then
		ok, res = pcall(def.Set, v)
		if ok and res == false then return false end -- Set refused and said why
	else
		ok = pcall(SetCVar, def.cvar, tostring(v))
	end
	if ok and Same(def.Get(), v) then
		return true
	end
	if not warned[def.undoKey] then
		warned[def.undoKey] = true
		QT.Print(def.name .. ": the game did not accept the change. Try the same setting in the Options window.")
	end
	return false
end

-------------------------------------------------------------------------------
-- Rows (used by the shared panel and by blocks)
-------------------------------------------------------------------------------

local function UndoTooltip(btn)
	if not GameTooltip then return end
	local def = btn.def
	local undo = QT:GetUndo(def)
	GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
	GameTooltip:ClearLines()
	GameTooltip:AddLine("Undo " .. def.name)
	if undo ~= nil then
		GameTooltip:AddLine("Back to " .. def.Format(undo) .. ", where it was before you moved the slider.", 1, 1, 1, true)
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
	local ok, reason = QT:Available(def)
	if not ok then GameTooltip:AddLine(reason or "Not available.", 1, 0.3, 0.3, true) end
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
	row.undoOn = QT:GetUndo(def) ~= nil
	if row.undoOn then
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

-- User moved a slider (drag, click or wheel).
local function OnSliderChanged(sl, value)
	if sl.syncing then return end
	local def = sl.def
	value = Clamp(def, value)
	local cur = def.Get()
	if cur == nil or Same(cur, value) then return end
	local revert = QT:GetUndo(def)
	if revert == nil then revert = cur end
	if Write(def, value) then
		-- Sliding back onto the undo point means there is nothing left to undo.
		if Same(revert, value) then revert = nil end
		QT:SetUndo(def, revert)
	end
	UpdateRow(sl.row)
	QT:SyncAll() -- other controls for the same setting
end

local function OpenMenuFrom(owner)
	QT:OpenMenu(owner)
end

-- Builds one row inside `parent`; positions are relative to the row's own frame.
local function CreateRow(def, parent, globalBase)
	local row = { def = def }
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(ROW_W, ROW_H)
	f:EnableMouse(true)
	f:SetScript("OnMouseUp", function(self, button)
		if button == "RightButton" then OpenMenuFrom(parent) end
	end)
	row.frame = f

	row.label = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.label:SetWidth(LABEL_W)
	row.label:SetJustifyH("LEFT")
	if row.label.SetWordWrap then row.label:SetWordWrap(false) end
	row.label:SetTextColor(QT.YELLOW[1], QT.YELLOW[2], QT.YELLOW[3])
	row.label:SetText(def.name)
	row.label:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -5)

	-- The classic horizontal slider look (HorizontalSliderTemplate's backdrop and thumb).
	local sl = CreateFrame("Slider", globalBase .. "_Slider", f, BackdropTemplateMixin and "BackdropTemplate" or nil)
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
		if button == "RightButton" then OpenMenuFrom(parent) end
	end)
	sl:SetScript("OnEnter", SliderTooltip)
	sl:SetScript("OnLeave", HideTooltip)
	sl:SetPoint("TOPLEFT", f, "TOPLEFT", LABEL_W + 4, -3)
	row.slider = sl

	row.value = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.value:SetWidth(VALUE_W)
	row.value:SetJustifyH("RIGHT")
	row.value:SetPoint("TOPLEFT", f, "TOPLEFT", LABEL_W + 4 + SLIDER_W + 6, -6)

	local undo = CreateFrame("Button", globalBase .. "_Undo", f)
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
			OpenMenuFrom(parent)
		else
			QT:UndoSlider(def.key)
		end
	end)
	-- A disabled button swallows clicks without OnClick; still let right-click reach the menu.
	undo:SetScript("OnMouseUp", function(self, button)
		if button == "RightButton" and not self:IsEnabled() then OpenMenuFrom(parent) end
	end)
	undo:SetScript("OnEnter", UndoTooltip)
	undo:SetScript("OnLeave", HideTooltip)
	undo:SetPoint("TOPLEFT", f, "TOPLEFT", ROW_W - UNDO_W, -2)
	row.undo = undo

	return row
end

local function SetRowShown(row, shown)
	for _, r in ipairs({ row.frame, row.label, row.slider, row.value, row.undo }) do
		if shown then r:Show() else r:Hide() end
	end
end

-- Dark draggable frame used by the shared panel and by each block.
local function CreateHolder(name, onMoved)
	local f = CreateFrame("Frame", name, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f:SetSize(PANEL_W, ROW_H + 2 * PAD - 4)
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
		if point then onMoved({ point, relPoint, x, y }) end
	end)
	f:SetScript("OnMouseUp", function(self, button)
		if button == "RightButton" then OpenMenuFrom(self) end
	end)
	f:Hide()
	return f
end

-------------------------------------------------------------------------------
-- Undo and chat commands (rows and blocks alike)
-------------------------------------------------------------------------------

local function SliderDef(key)
	local def = QT.all[key]
	if def and (def.kind == "slider" or def.kind == "block") then return def end
end

function QT:UndoSlider(key)
	local def = SliderDef(key)
	if not def then return false end
	local target = self:GetUndo(def)
	if target == nil then
		self.Print(def.name .. ": nothing to undo.")
		return false
	end
	if Write(def, target) then
		self:SetUndo(def, nil)
		if self:DB().announce then self.Print(def.name .. ": back to " .. def.Format(target) .. ".") end
	end
	self:SyncAll()
	return true
end

-- Same as moving the slider, from chat: keeps the undo point.
function QT:SetSlider(key, value)
	local def = SliderDef(key)
	if not def then return false end
	local ok, reason = self:Available(def)
	if not ok then
		self.Print(def.name .. ": " .. (reason or "not available here."))
		return false
	end
	local cur = def.Get()
	value = Clamp(def, value)
	if not Same(cur, value) then
		local revert = self:GetUndo(def)
		if revert == nil then revert = cur end
		if Write(def, value) then self:SetUndo(def, (not Same(revert, value)) and revert or nil) end
	end
	self:SyncAll()
	return true
end

function QT:SliderCommand(key, rest)
	local def = SliderDef(key)
	rest = (rest or ""):lower()
	if rest == "" then
		local undo = self:GetUndo(def)
		self.Print(def.name .. ": " .. def.Format(def.Get())
			.. (undo and (", undo goes back to " .. def.Format(undo)) or "") .. ".")
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

-------------------------------------------------------------------------------
-- The shared panel
-------------------------------------------------------------------------------

local panel

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

local function EnsurePanel()
	if panel then return panel end
	panel = CreateHolder("QuickToggleSliderPanel", function(pos) QT:DB().sliderPos = pos end)
	panel.rows = {}
	QT.panel = panel
	QT:PlaceSliderPanel()
	return panel
end

-- Lays out the enabled, available rows; hides the panel when there are none.
function QT:RefreshSliders()
	if not panel then return end
	local db = self:DB()
	local n = 0
	for _, def in ipairs(self.sliders) do
		local row = panel.rows[def.key]
		if row then
			local show = db.shown and self:IsEnabled(def.key) and self:Available(def)
			if show then
				row.frame:ClearAllPoints()
				row.frame:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -PAD - n * ROW_H)
				UpdateRow(row)
				n = n + 1
			end
			SetRowShown(row, show)
		end
	end
	panel:SetHeight(n * ROW_H + 2 * PAD - 4)
	if n > 0 then panel:Show() else panel:Hide() end
end

-- Redraws a row if the value or its undo point changed since it was last drawn (the undo
-- point is shared, so a block can change a panel row's undo button and the other way round).
local function SyncRow(row)
	if row and row.frame:IsShown()
		and (not Same(row.def.Get(), row.last) or (QT:GetUndo(row.def) ~= nil) ~= row.undoOn) then
		UpdateRow(row)
	end
end

function QT:SyncSliders()
	if not panel or not panel:IsShown() then return end
	for _, def in ipairs(self.sliders) do SyncRow(panel.rows[def.key]) end
end

function QT:SetupSliders()
	EnsurePanel()
	for _, def in ipairs(self.sliders) do
		if not panel.rows[def.key] then
			panel.rows[def.key] = CreateRow(def, panel, "QuickToggle_" .. SafeName(def.key))
		end
		self:Settings(def.key)
	end
	self:RefreshSliders()
end

do
	local k = QT.kinds.slider
	k.Setup = function() QT:SetupSliders() end
	k.Refresh = function() QT:RefreshSliders() end
	k.RefreshAll = function() QT:RefreshSliders() end
	k.Sync = function() QT:SyncSliders() end
	k.Reset = function() QT:PlaceSliderPanel() end
end

-------------------------------------------------------------------------------
-- Floating blocks: one slider each
-------------------------------------------------------------------------------

QT.blockFrames = {}

local function PlaceBlock(def)
	local f = QT.blockFrames[def.key]
	if not f then return end
	f:ClearAllPoints()
	local p = QT:Settings(def.key).pos
	if p then
		f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
	else
		local i = 0
		for n, d in ipairs(QT.blocks) do if d == def then i = n end end
		f:SetPoint("CENTER", UIParent, "CENTER", 0, 160 - 34 * (i - 1))
	end
end

local function RefreshBlock(def)
	local f = QT.blockFrames[def.key]
	if not f then return end
	local show = QT:DB().shown and QT:IsEnabled(def.key) and QT:Available(def)
	if show then
		UpdateRow(f.row)
		f:Show()
	else
		f:Hide()
	end
	SetRowShown(f.row, show)
end

local function SetupBlock(def)
	if not QT.blockFrames[def.key] then
		local base = "QuickToggle_" .. SafeName(def.key)
		local f = CreateHolder(base .. "_Block", function(pos) QT:Settings(def.key).pos = pos end)
		f.row = CreateRow(def, f, base)
		f.row.frame:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -PAD)
		QT.blockFrames[def.key] = f
	end
	QT:Settings(def.key)
	PlaceBlock(def)
	RefreshBlock(def)
end

do
	local k = QT.kinds.block
	k.Setup = SetupBlock
	k.Refresh = RefreshBlock
	k.RefreshAll = function() for _, def in ipairs(QT.blocks) do RefreshBlock(def) end end
	k.Sync = function()
		for _, def in ipairs(QT.blocks) do
			local f = QT.blockFrames[def.key]
			if f and f:IsShown() then SyncRow(f.row) end
		end
	end
	k.Reset = function()
		for _, def in ipairs(QT.blocks) do
			QT:Settings(def.key).pos = nil
			PlaceBlock(def)
		end
	end
end

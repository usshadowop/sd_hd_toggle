--[[
	Floating buttons: one free-floating box per setting, draggable anywhere.

	    [x] Auto Loot           on/off setting: green check when on, red X when off
	    Texture Quality: High   cycle setting: click for the next choice, shift-click to go back

	The yellow text is the setting's name, as the Options window shows it. Left-click
	flips or cycles it, right-click opens the Quick Toggle menu, drag moves it (unless the
	menu's lock is on). Uses the same definition shape as minimap bubbles (Core.lua).
]]

local QT = QuickToggle

local H = 24
local ICON = 16

function QT:RegisterFloat(def)
	QT.ToggleDefaults(def)
	return self:RegisterElement("float", def)
end

QT.floatFrames = {}

local function Label(def, value)
	if def.Label then return def.Label(value) end
	if def.isToggle then return def.name end
	return def.name .. ": " .. def.Describe(value)
end

local function UpdateFloat(def)
	local f = QT.floatFrames[def.key]
	if not f then return end
	local value = def.Get()
	f.last = value
	f.text:SetText(Label(def, value))
	if def.isToggle then
		f.icon:SetTexture(value and "Interface\\RaidFrame\\ReadyCheck-Ready" or "Interface\\RaidFrame\\ReadyCheck-NotReady")
		f.icon:Show()
		f.text:SetPoint("LEFT", f, "LEFT", 8 + ICON + 4, 0)
	else
		f.icon:Hide()
		f.text:SetPoint("LEFT", f, "LEFT", 8, 0)
	end
	local w = (f.text.GetStringWidth and f.text:GetStringWidth()) or 0
	f:SetWidth(math.max(60, w + (def.isToggle and (ICON + 4) or 0) + 16))
	if GameTooltip and GameTooltip:IsOwned(f) then QT:ToggleTooltip(f, "ANCHOR_BOTTOM") end
end

local function PlaceFloat(def)
	local f = QT.floatFrames[def.key]
	if not f then return end
	f:ClearAllPoints()
	local p = QT:Settings(def.key).pos
	if p then
		f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
	else
		local i = 0
		for n, d in ipairs(QT.floats) do if d == def then i = n end end
		f:SetPoint("CENTER", UIParent, "CENTER", -240, 160 - 30 * (i - 1))
	end
end

local function RefreshFloat(def)
	local f = QT.floatFrames[def.key]
	if not f then return end
	if QT:DB().shown and QT:IsEnabled(def.key) and QT:Available(def) then
		UpdateFloat(def)
		f:Show()
	else
		f:Hide()
	end
end

local function CreateFloat(def)
	local f = CreateFrame("Button", "QuickToggle_" .. def.key:gsub("[^%w_]", "_") .. "_Float", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f.def = def
	f:SetSize(100, H)
	f:SetFrameStrata("MEDIUM")
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	f:RegisterForDrag("LeftButton")
	if f.SetBackdrop then
		f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
		f:SetBackdropColor(0, 0, 0, 0.7)
		f:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.9)
	end
	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetSize(ICON, ICON)
	f.icon:SetPoint("LEFT", f, "LEFT", 8, 0)
	f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	f.text:SetTextColor(QT.YELLOW[1], QT.YELLOW[2], QT.YELLOW[3])
	f.text:SetJustifyH("LEFT")
	f.highlight = f:CreateTexture(nil, "HIGHLIGHT")
	f.highlight:SetAllPoints()
	f.highlight:SetColorTexture(1, 1, 1, 0.08)

	f:SetScript("OnClick", function(self, button) QT:ToggleClick(self, button) end)
	f:SetScript("OnDragStart", function(self)
		if QT:DB().locked then return end
		self:StartMoving()
	end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, relPoint, x, y = self:GetPoint(1)
		if point then QT:Settings(def.key).pos = { point, relPoint, x, y } end
	end)
	f:SetScript("OnEnter", function(self) QT:ToggleTooltip(self, "ANCHOR_BOTTOM") end)
	f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	f:Hide()
	return f
end

do
	local k = QT.kinds.float
	k.Setup = function(def)
		if not QT.floatFrames[def.key] then QT.floatFrames[def.key] = CreateFloat(def) end
		QT:Settings(def.key)
		PlaceFloat(def)
		RefreshFloat(def)
	end
	k.Refresh = RefreshFloat
	k.RefreshAll = function() for _, def in ipairs(QT.floats) do RefreshFloat(def) end end
	k.Sync = function()
		for _, def in ipairs(QT.floats) do
			local f = QT.floatFrames[def.key]
			if f and f:IsShown() and def.Get() ~= f.last then UpdateFloat(def) end
		end
	end
	k.Reset = function()
		for _, def in ipairs(QT.floats) do
			QT:Settings(def.key).pos = nil
			PlaceFloat(def)
		end
	end
end

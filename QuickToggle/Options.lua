--[[
	Every setting in the game's Options window, as a quick toggle.

	Two small tick boxes are added at the left of each setting row in Blizzard's Options
	window (Esc > Options):

	  on/off and dropdown settings:  [floating button] [minimap button]
	  sliders:                       [floating slider] [row in the shared slider panel]

	The second box has a blue tint so the two are easy to tell apart. Rows that combine a
	checkbox with a slider or dropdown get a second pair at the row's right edge for the
	slider or dropdown part. Hover a box to see what it does.

	How it stays safe (checked against Blizzard's UI source for 1.60.1.70862):

	* The boxes are added with hooksecurefunc on SettingsListElementMixin.Init, the base
	  row setup every Options row runs, and are our own child frames. Nothing of
	  Blizzard's is written to, so Blizzard's Options code stays untainted.
	* Settings backed by a console variable (most of them) are changed with SetCVar, the
	  same call Blizzard's CVarSettingMixin makes, so the effect is identical.
	* "Proxy" settings run Blizzard functions to apply (graphics presets, action bars,
	  nameplates, voice chat...). Calling those from an addon can lead to "Interface action
	  blocked" errors, so they are off until the user ticks "Allow settings that run
	  Blizzard code" (menu, /qt blizzard on, or Options > AddOns > Quick Toggle), and are
	  never changed in combat.
	* Settings that only apply after a restart (ClientRestart, GxRestart, UIReload,
	  UpdateWindow commit flags) are shown with greyed boxes: a quick toggle can't apply them.
]]

local QT = QuickToggle

local infos = {}      -- variable -> info, every classified setting seen
local infoList = {}   -- in Options order
QT.optionInfos = infos

-- Hand-made controls that already cover a setting: tick boxes for these drive them.
local FEATURED = {
	bubble = { Sound_EnableMusic = "music" },
	slider = { Brightness = "brightness", Contrast = "contrast", Gamma = "gamma" },
}

local KIND_PAIRS = {
	toggle = { "float", "bubble" },
	cycle = { "float", "bubble" },
	slider = { "block", "slider" },
}

local RESTART_FLAGS = { "ClientRestart", "GxRestart", "UIReload", "UpdateWindow" }

local function Same(a, b)
	if type(a) == "number" and type(b) == "number" then return math.abs(a - b) < 0.001 end
	return a == b
end

-------------------------------------------------------------------------------
-- Reading Blizzard's setting objects (read-only)
-------------------------------------------------------------------------------

-- "cvar": CVarSettingMixin (has NegateBoolean); "proxy": ProxySettingMixin (getValue /
-- setValue closures). Anything else (add-on settings, modifier keys) is not offered.
local function Backing(setting)
	if type(setting) ~= "table" then return nil end
	if type(setting.NegateBoolean) == "function" then return "cvar" end
	if setting.getValue ~= nil and setting.setValue ~= nil then return "proxy" end
	return nil
end

local function NeedsRestart(setting)
	local flags = Settings and Settings.CommitFlag
	if not flags or type(setting.HasCommitFlag) ~= "function" then return false end
	for _, name in ipairs(RESTART_FLAGS) do
		if flags[name] then
			local ok, has = pcall(setting.HasCommitFlag, setting, flags[name])
			if ok and has then return true end
		end
	end
	return false
end

local function Text(v)
	if type(v) == "function" then
		local ok, s = pcall(v)
		v = ok and s or nil
	end
	if type(v) ~= "string" or v == "" then return nil end
	return v
end

-- The one or two settings a row controls.
local function Parts(data)
	if type(data) ~= "table" then return {} end
	if data.cbSetting then
		local parts = { { setting = data.cbSetting, name = Text(data.cbLabel) or Text(data.name) } }
		if data.sliderSetting then
			parts[2] = { setting = data.sliderSetting, options = data.sliderOptions, name = Text(data.sliderLabel) or Text(data.name) }
		elseif data.dropdownSetting then
			parts[2] = { setting = data.dropdownSetting, options = data.dropdownOptions, name = Text(data.dropDownLabel) or Text(data.name) }
		end
		return parts
	elseif data.setting then
		return { { setting = data.setting, options = data.options, name = Text(data.name) } }
	end
	return {}
end

local function Classify(part, category)
	local setting = part.setting
	local backing = Backing(setting)
	if not backing then return nil end
	local okV, var = pcall(setting.GetVariable, setting)
	local okT, vt = pcall(setting.GetVariableType, setting)
	if not okV or type(var) ~= "string" or not okT then return nil end
	if infos[var] then return infos[var] end

	local opts = part.options
	local kind
	if vt == "number" and type(opts) == "table" and opts.minValue and opts.maxValue then
		kind = "slider"
	elseif type(opts) == "function" then
		kind = "cycle"
	elseif vt == "boolean" then
		kind = "toggle"
	end
	if not kind then return nil end

	local name = part.name
	if not name then
		local ok, n = pcall(setting.GetName, setting)
		name = ok and Text(n) or var
	end

	local info = {
		var = var, name = name, kind = kind, setting = setting, backing = backing,
		restart = NeedsRestart(setting), options = opts, category = category,
	}
	if kind == "slider" then
		info.min, info.max = opts.minValue, opts.maxValue
		local steps = tonumber(opts.steps)
		info.step = (steps and steps > 0) and (info.max - info.min) / steps or 1
		info.step = tonumber(string.format("%.4f", info.step))
		local right = MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label
			and MinimalSliderWithSteppersMixin.Label.Right
		info.formatter = right and opts.formatters and opts.formatters[right]
	end
	infos[var] = info
	infoList[#infoList + 1] = info
	return info
end

local function CurrentValue(info)
	local ok, v = pcall(info.setting.GetValue, info.setting)
	if ok then return v end
end

-- Dropdown choices as { value, label } pairs.
local function Choices(info)
	local ok, list = pcall(info.options)
	local out = {}
	if ok and type(list) == "table" then
		for _, item in ipairs(list) do
			if type(item) == "table" and item.value ~= nil then
				out[#out + 1] = { value = item.value, label = Text(item.label) or tostring(item.value) }
			end
		end
	end
	return out
end

local function Step(info, value, dir)
	local list = Choices(info)
	local n = #list
	if n == 0 then return value end
	local idx
	for i, c in ipairs(list) do if Same(c.value, value) then idx = i end end
	if not idx then return list[1].value end
	return list[(idx - 1 + dir) % n + 1].value
end

local function Describe(info, value)
	if info.kind == "toggle" then return value and "on" or "off" end
	if info.kind == "cycle" then
		for _, c in ipairs(Choices(info)) do
			if Same(c.value, value) then return c.label end
		end
		return tostring(value)
	end
	if info.formatter then
		local ok, s = pcall(info.formatter, value)
		if ok and type(s) == "string" then return s end
	end
	if value == nil then return "?" end
	return QT.FormatNumber(tonumber(string.format("%.2f", value)))
end

-------------------------------------------------------------------------------
-- Changing a setting
-------------------------------------------------------------------------------

function QT:OptionAvailable(info)
	if info.restart then
		return false, "only takes effect after restarting the game, so it can't be a quick toggle"
	end
	if info.backing == "proxy" and not self:DB().allowProxy then
		return false, "runs Blizzard code to apply; tick 'Allow settings that run Blizzard code' in the Quick Toggle menu to use it"
	end
	return true
end

local warned = {}

-- Returns true if the game now has `value`, false (after saying why) if not.
local function Apply(info, value)
	local ok
	if info.backing == "cvar" then
		local cv = value
		if type(info.setting.TransformValue) == "function" then
			local okT, t = pcall(info.setting.TransformValue, info.setting, value) -- NegateBoolean settings
			if okT then cv = t end
		end
		local s
		if type(cv) == "boolean" then s = cv and "1" or "0" else s = tostring(cv) end
		ok = pcall(SetCVar, info.var, s)
	else
		if InCombatLockdown and InCombatLockdown() then
			QT.Print(info.name .. ": can't be changed in combat (it runs Blizzard code).")
			return false
		end
		ok = pcall(info.setting.SetValue, info.setting, value, true)
	end
	if ok and Same(CurrentValue(info), value) then return true end
	if not warned[info.var] then
		warned[info.var] = true
		QT.Print(info.name .. ": the game did not accept the change. Use the Options window for this one.")
	end
	return false
end

-------------------------------------------------------------------------------
-- Turning a setting into a control
-------------------------------------------------------------------------------

local function Abbrev(name)
	name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	local words = {}
	for w in name:gmatch("[%w]+") do words[#words + 1] = w end
	if #words >= 2 then
		local s = ""
		for i = 1, math.min(3, #words) do s = s .. words[i]:sub(1, 1):upper() end
		return s
	end
	local w = words[1] or "?"
	return w:sub(1, 1):upper() .. w:sub(2, 2):lower()
end

local nextBubbleAngle = 180

function QT:OptionKey(info, kind)
	local featured = FEATURED[kind] and FEATURED[kind][info.var]
	if featured and self.all[featured] then return featured end
	return info.var .. "@" .. kind
end

-- Registers the control for `info` of `kind` if it doesn't exist yet; returns its key.
function QT:EnsureOption(info, kind)
	local key = self:OptionKey(info, kind)
	if self.all[key] then return key end

	local common = {
		key = key, name = info.name, defaultEnabled = false, events = { "CVAR_UPDATE" },
		IsAvailable = function() return QT:OptionAvailable(info) end,
		Get = function() return CurrentValue(info) end,
	}

	if kind == "slider" or kind == "block" then
		common.min, common.max, common.step = info.min, info.max, info.step
		common.undoKey = info.var
		common.Format = function(v) return Describe(info, v) end
		common.Set = function(v) return Apply(info, v) end
		if kind == "slider" then self:RegisterSlider(common) else self:RegisterBlock(common) end
	else
		common.isToggle = (info.kind == "toggle")
		common.Set = function(v) return Apply(info, v) end
		common.Describe = function(v) return Describe(info, v) end
		if info.kind == "cycle" then
			common.Next = function(v) return Step(info, v, 1) end
			common.Prev = function(v) return Step(info, v, -1) end
			common.Tooltip = function(tooltip, v)
				tooltip:AddLine("Now: " .. Describe(info, v), 1, 1, 1)
				tooltip:AddLine("Click for " .. Describe(info, Step(info, v, 1)) .. ", shift-click to go back.", 0.6, 1, 0.6)
			end
		end
		if kind == "bubble" then
			common.defaultAngle = nextBubbleAngle
			nextBubbleAngle = (nextBubbleAngle - 24) % 360
			local abbrev = Abbrev(info.name)
			common.Create = function(b, disc)
				b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
				b.label:SetPoint("CENTER", disc, "CENTER", 0, 0)
				b.label:SetTextColor(QT.YELLOW[1], QT.YELLOW[2], QT.YELLOW[3])
				b.label:SetText(abbrev)
				b.cross = b:CreateTexture(nil, "OVERLAY")
				b.cross:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
				b.cross:SetSize(17, 17)
				b.cross:SetPoint("CENTER", disc, "CENTER", 0, 0)
				b.cross:Hide()
			end
			common.Update = function(b, v)
				if info.kind == "toggle" and v == false then b.cross:Show() else b.cross:Hide() end
			end
			self:Register(common)
		else
			self:RegisterFloat(common)
		end
	end
	return key
end

-------------------------------------------------------------------------------
-- Scanning the Options window's settings
-------------------------------------------------------------------------------

local scanned = false

function QT:ScanOptions()
	if not (SettingsPanel and SettingsPanel.GetAllCategories and SettingsPanel.GetLayout) then return false end
	local okC, cats = pcall(SettingsPanel.GetAllCategories, SettingsPanel)
	if not okC or type(cats) ~= "table" or #cats == 0 then return false end
	local seen = {}
	local function Visit(cat)
		if type(cat) ~= "table" or seen[cat] then return end
		seen[cat] = true
		local okN, catName = pcall(cat.GetName, cat)
		local okL, layout = pcall(SettingsPanel.GetLayout, SettingsPanel, cat)
		if okL and type(layout) == "table" and type(layout.GetInitializers) == "function" then
			local okI, inits = pcall(layout.GetInitializers, layout)
			if okI and type(inits) == "table" then
				for _, init in ipairs(inits) do
					local data = type(init) == "table" and init.data
					for _, part in ipairs(Parts(data)) do Classify(part, okN and catName or nil) end
				end
			end
		end
		if type(cat.GetSubcategories) == "function" then
			local okS, subs = pcall(cat.GetSubcategories, cat)
			if okS and type(subs) == "table" then
				for _, sub in ipairs(subs) do Visit(sub) end
			end
		end
	end
	for _, cat in ipairs(cats) do Visit(cat) end
	scanned = true
	return true
end

-- Re-creates the controls that were ticked last session.
function QT:RestoreOptions()
	local db = self:DB()
	for _, info in ipairs(infoList) do
		for _, kind in ipairs(KIND_PAIRS[info.kind]) do
			local key = self:OptionKey(info, kind)
			local store = db[self.kinds[kind].store]
			if not self.all[key] and store[key] and store[key].enabled then
				self:EnsureOption(info, kind)
			end
		end
	end
	self:Refresh()
end

local function ScanAndRestore()
	if QT:ScanOptions() then QT:RestoreOptions() end
end

-------------------------------------------------------------------------------
-- Tick boxes in Blizzard's Options rows
-------------------------------------------------------------------------------

local rowBoxes = setmetatable({}, { __mode = "k" }) -- Blizzard row frame -> our boxes

local BOX_TEXT = {
	float = "Floating button",
	bubble = "Minimap button",
	block = "Floating slider",
	slider = "Row in the shared slider panel",
}

local function BoxKey(box)
	return box.info and QT:OptionKey(box.info, box.kind)
end

local function RefreshBox(box)
	if not box.info then box:Hide(); return end
	local key = BoxKey(box)
	box:SetChecked(QT.all[key] ~= nil and QT:IsEnabled(key))
	if QT:OptionAvailable(box.info) then box:Enable() else box:Disable() end
	box:Show()
end

local function BoxTooltip(box)
	if not GameTooltip or not box.info then return end
	local info = box.info
	GameTooltip:SetOwner(box, "ANCHOR_RIGHT")
	GameTooltip:ClearLines()
	GameTooltip:AddLine("Quick Toggle: " .. BOX_TEXT[box.kind])
	GameTooltip:AddLine(info.name, 1, 1, 1)
	local ok, reason = QT:OptionAvailable(info)
	if not ok then
		GameTooltip:AddLine("Not available: " .. reason .. ".", 1, 0.3, 0.3, true)
	elseif box:GetChecked() then
		GameTooltip:AddLine("Ticked: shown. Untick to remove it.", 0.6, 1, 0.6, true)
	else
		GameTooltip:AddLine("Tick to add it.", 0.6, 1, 0.6, true)
	end
	GameTooltip:Show()
end

local function OnBoxClick(box)
	local on = box:GetChecked() and true or false
	local key = QT:EnsureOption(box.info, box.kind)
	QT:SetEnabled(key, on)
	if on and QT:DB().announce then
		QT.Print(box.info.name .. ": added as a " .. BOX_TEXT[box.kind]:lower() .. ". Right-click it for the menu.")
	end
end

local function CreateBox(row, tinted)
	local b = CreateFrame("CheckButton", nil, row)
	b:SetSize(16, 16)
	b:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
	b:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
	b:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
	b:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
	b:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
	if tinted and b:GetNormalTexture() then b:GetNormalTexture():SetVertexColor(0.55, 0.75, 1) end
	b:SetMotionScriptsWhileDisabled(true)
	b:SetScript("OnClick", OnBoxClick)
	b:SetScript("OnEnter", BoxTooltip)
	b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	b:SetScript("OnShow", RefreshBox)
	b:Hide()
	return b
end

local function Decorate(row, initializer)
	local data = type(initializer) == "table" and initializer.data
	local boxes = rowBoxes[row]
	local parts = Parts(data)
	local first = parts[1] and Classify(parts[1])
	local second = parts[2] and Classify(parts[2])
	if not first and not second and not boxes then return end -- leave rows we never touched alone
	if not boxes then
		boxes = { CreateBox(row), CreateBox(row, true), CreateBox(row), CreateBox(row, true) }
		rowBoxes[row] = boxes
	end
	local indent = 0
	if type(initializer) == "table" and type(initializer.GetIndent) == "function" then
		local ok, n = pcall(initializer.GetIndent, initializer)
		if ok and type(n) == "number" then indent = n end
	end
	-- Above the row's invisible hover frame (row.Tooltip), which covers the left gutter and,
	-- on checkbox rows, clicks Blizzard's checkbox: our boxes must get the click first.
	local level = (row.GetFrameLevel and row:GetFrameLevel() or 0) + 10
	local function Pair(i, info, x1, x2, point)
		for j, x in ipairs({ x1, x2 }) do
			local box = boxes[i + j - 1]
			box.info = info
			box.kind = info and KIND_PAIRS[info.kind][j]
			box:SetFrameLevel(level)
			box:ClearAllPoints()
			box:SetPoint(point, row, point, x, 0)
			RefreshBox(box)
		end
	end
	Pair(1, first, indent + 2, indent + 19, "LEFT")
	Pair(3, second, -38, -21, "RIGHT")
end

if SettingsListElementMixin and type(SettingsListElementMixin.Init) == "function" and hooksecurefunc then
	hooksecurefunc(SettingsListElementMixin, "Init", function(row, initializer)
		local ok, err = pcall(Decorate, row, initializer)
		if not ok and QT.debug then QT.Print("row hook: " .. tostring(err)) end
	end)
end

function QT:RefreshOptionBoxes()
	for _, boxes in pairs(rowBoxes) do
		for _, box in ipairs(boxes) do
			if box.info then RefreshBox(box) end
		end
	end
end

function QT:OnEnabledChanged() self:RefreshOptionBoxes() end

-------------------------------------------------------------------------------
-- The opt-in switch, our page under Options > AddOns, and opening Options
-------------------------------------------------------------------------------

function QT:SetAllowProxy(on, quiet)
	self:DB().allowProxy = on and true or false
	if not quiet then
		self.Print(on and "settings that run Blizzard code are now allowed. They can't be changed in combat."
			or "settings that run Blizzard code are off again.")
	end
	self:Refresh()
	self:RefreshOptionBoxes()
end

local function RegisterAddOnPage()
	if not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterAddOnSetting
		and Settings.CreateCheckbox and Settings.RegisterAddOnCategory) then
		return
	end
	local db = QT:DB()
	local category = Settings.RegisterVerticalLayoutCategory("Quick Toggle")
	local function Add(variable, key, tbl, name, default, tooltip, onChange)
		local setting = Settings.RegisterAddOnSetting(category, variable, key, tbl, "boolean", name, default)
		Settings.CreateCheckbox(category, setting, tooltip)
		if Settings.SetOnValueChangedCallback and onChange then
			Settings.SetOnValueChangedCallback(variable, function() onChange() end)
		end
	end
	Add("QuickToggle_Shown", "shown", db, "Show Quick Toggle controls",
		true, "Show every Quick Toggle button and slider. Same as /qt show and /qt hide.",
		function() QT:Refresh() end)
	Add("QuickToggle_Locked", "locked", db, "Lock buttons and sliders in place",
		false, "Stops them being dragged by accident.")
	Add("QuickToggle_AllowProxy", "allowProxy", db, "Allow settings that run Blizzard code",
		false, "About a third of the Options settings (graphics presets, action bars, nameplates, voice chat and others) apply by running Blizzard's own code. Changing those from an addon can cause 'Interface action blocked' errors, mostly after combat. Tick to allow them anyway; they are never changed in combat.",
		function() QT:SetAllowProxy(db.allowProxy, true) end)
	if QT.byKey.sdhd then
		Add("QuickToggle_SDHD", "enabled", QT:Settings("sdhd"), "SD / HD minimap button",
			true, "The round minimap button that switches character models between SD and HD.",
			function() QT:Refresh() end)
	end
	Settings.RegisterAddOnCategory(category)
	QT.optionsCategory = category
end

function QT:OpenOptions()
	if not scanned then ScanAndRestore() end
	self.Print("every setting in the Options window now has two Quick Toggle boxes at its left: the first makes a floating button or slider, the blue one a minimap button or a row in the slider panel.")
	if Settings and Settings.OpenToCategory and self.optionsCategory and self.optionsCategory.GetID then
		Settings.OpenToCategory(self.optionsCategory:GetID())
	end
end

function QT:OnLoaded()
	local ok, err = pcall(RegisterAddOnPage)
	if not ok and self.debug then self.Print("options page: " .. tostring(err)) end
end

QT:On("SETTINGS_LOADED", ScanAndRestore)
QT:On("PLAYER_ENTERING_WORLD", function()
	if not scanned then ScanAndRestore() end
end)

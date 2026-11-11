-- Minimal stand-in for the WoW Forever client, just enough to load Quick Toggle headless.
local Stub = {}

Stub.printed = {}
function print(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
	Stub.printed[#Stub.printed + 1] = table.concat(parts, " ")
end

Stub.sounds = {}
SOUNDKIT = { IG_MAINMENU_OPTION_CHECKBOX_ON = 856, IG_MAINMENU_OPTION_CHECKBOX_OFF = 857 }
function PlaySound(id) Stub.sounds[#Stub.sounds + 1] = id end

Enum = { SdToggleUsageLocationUI = { BeforeLogin = 0, CharacterCreation = 1, BarberShop = 2, OptionsMenu = 3 } }

-- The game rule the addon drives. `sd` is the account-wide value the real client keeps.
Stub.game = { toggleEnabled = true, sd = false, setCalls = {} }
C_GameRules = {
	IsSDHDToggleEnabled = function() return Stub.game.toggleEnabled end,
	AccountHasSDEnabled = function() return Stub.game.sd end,
	SetSDHDToggleValue = function(setToSD, loc)
		assert(type(setToSD) == "boolean", "setToSD must be a boolean")
		assert(type(loc) == "number" and loc >= 0 and loc <= 3, "bad usage location")
		Stub.game.sd = setToSD
		Stub.game.setCalls[#Stub.game.setCalls + 1] = { setToSD, loc }
	end,
}

-- Console variables: Sound_EnableMusic is what the music toggle drives.
Stub.cvars = { Sound_EnableMusic = "1", Sound_EnableAllSound = "1", Brightness = "50", Contrast = "50", Gamma = "1.000000" }
Stub.lockedCVars = {} -- names SetCVar should refuse, to test the "did not accept" path
function GetCVar(name) return Stub.cvars[name] end
function SetCVar(name, value)
	if Stub.lockedCVars[name] then error("cvar is secure") end
	Stub.cvars[name] = tostring(value)
	Stub.Fire("CVAR_UPDATE", name, tostring(value))
end

-- Frames -------------------------------------------------------------------
local function newRegion(kind)
	local r = { objectType = kind, points = {}, shown = true, scripts = {}, text = "" }
	function r:SetPoint(point, rel, relPoint, x, y)
		if type(rel) == "number" then x, y, relPoint, rel = rel, relPoint, point, nil end
		self.points[#self.points + 1] = { point, rel, relPoint or point, x or 0, y or 0 }
	end
	function r:GetPoint(i) local p = self.points[i or 1]; if p then return p[1], p[2], p[3], p[4], p[5] end end
	function r:ClearAllPoints() self.points = {} end
	function r:SetAllPoints() end
	function r:SetSize(w, h)
		self.w, self.h = w, h
		if self.hooks and self.hooks.OnSizeChanged then self.hooks.OnSizeChanged(self, w, h) end
	end
	function r:GetSize() return self.w, self.h end
	function r:GetWidth() return self.w or 0 end
	function r:HookScript(name, fn) self.hooks = self.hooks or {}; self.hooks[name] = fn end
	function r:Show() self.shown = true end
	function r:Hide() self.shown = false end
	function r:IsShown() return self.shown end
	function r:SetText(t) self.text = t end
	function r:GetStringWidth() return #(self.text or "") * 6 end
	function r:SetWordWrap() end
	function r:SetNormalTexture(t) self.normal = newRegion("Texture"); self.normal.texture = t end
	function r:GetNormalTexture() return self.normal end
	function r:SetPushedTexture(t) self.pushed = t end
	function r:SetCheckedTexture(t) self.checkedTex = t end
	function r:SetDisabledCheckedTexture(t) self.disabledChecked = t end
	function r:GetText() return self.text end
	function r:SetTextColor(...) self.color = { ... } end
	function r:SetVertexColor(...) self.vcolor = { ... } end
	function r:SetAlpha(a) self.alpha = a end
	function r:SetRotation(a) self.rotation = a end
	function r:SetChecked(b) self.checked = b and true or false end
	function r:GetChecked() return self.checked end
	function r:EnableMouse() end
	function r:SetHeight(h) self.h = h end
	function r:SetWidth(w) self.w = w end
	function r:GetHeight() return self.h end
	function r:SetJustifyH(j) self.justify = j end
	function r:Enable() self.enabled = true end
	function r:Disable() self.enabled = false end
	function r:IsEnabled() return self.enabled ~= false end
	function r:SetMotionScriptsWhileDisabled() end
	function r:EnableMouseWheel(b) self.wheel = b end
	-- Slider
	function r:SetOrientation(o) self.orientation = o end
	function r:SetThumbTexture(t) self.thumb = t end
	function r:SetMinMaxValues(a, b) self.minV, self.maxV = a, b end
	function r:GetMinMaxValues() return self.minV, self.maxV end
	function r:SetValueStep(st) self.step = st end
	function r:SetObeyStepOnDrag(b) self.obey = b end
	function r:GetValue() return self.value or 0 end
	function r:SetValue(v)
		if self.minV then v = math.max(self.minV, math.min(self.maxV, v)) end
		local changed = v ~= self.value
		self.value = v
		if changed and self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, v, false) end
	end
	function r:SetColorTexture(...) self.color = { ... } end
	function r:SetScale(s) self.scale = s end
	function r:SetFrameStrata(s) self.strata = s end
	function r:SetMovable(b) self.movable = b end
	function r:SetClampedToScreen() end
	function r:RegisterForClicks() end
	function r:RegisterForDrag() end
	function r:StartMoving() self.moving = true end
	function r:StopMovingOrSizing() self.moving = false end
	function r:SetBackdrop(b) self.backdrop = b end
	function r:SetTexture(t) self.texture = t end
	function r:SetHighlightTexture(t) self.highlightTexture = t end
	function r:SetFrameLevel(l) self.level = l end
	function r:GetFrameLevel() return self.level or 1 end
	function r:GetCenter() return self.cx or 0, self.cy or 0 end
	function r:GetTop() return self.topY end
	function r:GetBottom() return self.bottomY end
	function r:SetClipsChildren(b) self.clips = b end
	function r:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
	function r:SetFont(path, size, flags) self.fontSize = size end
	function r:GetEffectiveScale() return self.effScale or 1 end
	function r:SetBackdropColor() end
	function r:SetBackdropBorderColor() end
	function r:CreateFontString() return newRegion("FontString") end
	function r:CreateTexture() return newRegion("Texture") end
	function r:SetScript(name, fn) self.scripts[name] = fn end
	function r:GetScript(name) return self.scripts[name] end
	function r:RegisterEvent(e) self.events = self.events or {}; self.events[e] = true end
	function r:UnregisterEvent(e) if self.events then self.events[e] = nil end end
	return r
end

Stub.frames = {}
function CreateFrame(kind, name, parent, template)
	local f = newRegion(kind)
	f.name, f.parent, f.template = name, parent, template
	Stub.frames[#Stub.frames + 1] = f
	if name then _G[name] = f end
	return f
end
BackdropTemplateMixin = {}
UIParent = CreateFrame("Frame", "UIParent")
Minimap = CreateFrame("Frame", "Minimap", UIParent)
Minimap.cx, Minimap.cy = 1000, 600
Minimap:SetSize(140, 140) -- the classic size; Forever's is larger, see the tests

Stub.cursor = { x = 0, y = 0 }
function GetCursorPosition() return Stub.cursor.x, Stub.cursor.y end

-- Delivers an event to every frame registered for it.
function Stub.Fire(event, ...)
	for _, f in ipairs(Stub.frames) do
		if f.events and f.events[event] and f.scripts.OnEvent then
			f.scripts.OnEvent(f, event, ...)
		end
	end
end

-- Advances time for OnUpdate handlers.
function Stub.Tick(dt)
	for _, f in ipairs(Stub.frames) do
		if f.scripts.OnUpdate then f.scripts.OnUpdate(f, dt) end
	end
end

GameTooltip = newRegion("GameTooltip")
function GameTooltip:SetOwner(o) self.owner = o end
function GameTooltip:IsOwned(o) return self.owner == o and self.shown end
function GameTooltip:ClearLines() self.lines = {} end
function GameTooltip:AddLine(t) self.lines[#self.lines + 1] = t end
function GameTooltip:AddDoubleLine(a, b) self.lines[#self.lines + 1] = a .. " " .. b end
GameTooltip.shown = false

Stub.bindings = {}
function SetBinding(key, action) Stub.bindings[key] = action; return true end
function SaveBindings() Stub.savedBindings = true end
function GetCurrentBindingSet() return 1 end
function GetBindingKey(action)
	for k, a in pairs(Stub.bindings) do if a == action then return k end end
end

SlashCmdList = {}
UISpecialFrames = {}

Stub.combat = false
function InCombatLockdown() return Stub.combat end
Stub.shift = false
function IsShiftKeyDown() return Stub.shift end
Stub.alt = false
function IsAltKeyDown() return Stub.alt end

-- hooksecurefunc(table, "method", hook): original runs first, then the hook.
function hooksecurefunc(tbl, name, hook)
	local orig = tbl[name]
	tbl[name] = function(...)
		local a, b, c, d = orig(...)
		hook(...)
		return a, b, c, d
	end
end

-------------------------------------------------------------------------------
-- Blizzard's settings system (Blizzard_Settings_Shared), just the parts read
-------------------------------------------------------------------------------

MinimalSliderWithSteppersMixin = { Label = { Left = 1, Right = 2 } }

-- Every Options row runs this base setup (SettingsControlMixin.Init calls it by name).
SettingsListElementMixin = {}
function SettingsListElementMixin.Init(row, initializer)
	row.data = initializer.data
end
Stub.origRowInit = SettingsListElementMixin.Init

Settings = {
	CommitFlag = { None = 0, ClientRestart = 1, GxRestart = 2, UpdateWindow = 4, SaveBindings = 8,
		Revertable = 16, Apply = 32, IgnoreApply = 64, KioskProtected = 128, UIReload = 256 },
}
Stub.addonSettings = {}   -- variable -> setting registered by an addon
Stub.valueCallbacks = {}  -- variable -> callback
Stub.addonCategories = {}
function Settings.RegisterVerticalLayoutCategory(name)
	local cat = { name = name, id = 9000 + #Stub.addonCategories, initializers = {} }
	function cat:GetID() return self.id end
	function cat:GetName() return self.name end
	return cat, {}
end
function Settings.RegisterAddOnSetting(cat, variable, key, tbl, vtype, name, default)
	if tbl[key] == nil then tbl[key] = default end
	local setting = { variable = variable, key = key, tbl = tbl, name = name }
	function setting:GetValue() return self.tbl[self.key] end
	function setting:SetValue(v)
		self.tbl[self.key] = v
		if Stub.valueCallbacks[variable] then Stub.valueCallbacks[variable](nil, self, v) end
	end
	Stub.addonSettings[variable] = setting
	return setting
end
function Settings.CreateCheckbox(cat, setting, tooltip)
	cat.initializers[#cat.initializers + 1] = { data = { setting = setting, name = setting.name, tooltip = tooltip } }
end
function Settings.RegisterAddOnCategory(cat) Stub.addonCategories[#Stub.addonCategories + 1] = cat end
function Settings.SetOnValueChangedCallback(variable, fn) Stub.valueCallbacks[variable] = fn end
function Settings.OpenToCategory(id) Stub.openedCategory = id end

-- A CVar-backed setting (CVarSettingMixin): reads and writes Stub.cvars.
function Stub.CVarSetting(var, vtype, name, opts)
	opts = opts or {}
	local s = { variable = var, variableType = vtype, name = name, flags = opts.flags or 0, negate = opts.negate }
	function s:NegateBoolean() self.negate = true end
	function s:TransformValue(v) if self.negate then return not v end return v end
	function s:GetVariable() return self.variable end
	function s:GetVariableType() return self.variableType end
	function s:GetName() return self.name end
	function s:HasCommitFlag(f) return (math.floor(self.flags / f) % 2) == 1 end
	function s:GetValue()
		local raw = Stub.cvars[self.variable]
		if self.variableType == "boolean" then return self:TransformValue(raw ~= nil and raw ~= "0") end
		if self.variableType == "number" then return tonumber(raw) end
		return raw
	end
	return s
end

-- A proxy setting (ProxySettingMixin): applies through a Blizzard function.
Stub.proxyCalls = {}
function Stub.ProxySetting(var, vtype, name, initial)
	local s = { variable = var, variableType = vtype, name = name, value = initial, flags = 0 }
	s.getValue = function() return s.value end
	s.setValue = function(v) s.value = v end
	function s:GetVariable() return self.variable end
	function s:GetVariableType() return self.variableType end
	function s:GetName() return self.name end
	function s:HasCommitFlag(f) return false end
	function s:GetValue() return self.value end
	function s:SetValue(v, immediate)
		Stub.proxyCalls[#Stub.proxyCalls + 1] = { self.variable, v, immediate }
		self.setValue(v)
	end
	return s
end

-- Initializers as Blizzard builds them: .data plus GetIndent.
function Stub.Init(data, indent, template)
	local init = { data = data, template = template or "SettingsCheckboxControlTemplate" }
	function init:GetIndent() return indent or 0 end
	function init:GetTemplate() return self.template end
	function init:ShouldShow() return not self.hidden end
	return init
end
function Stub.Header(name)
	return Stub.Init({ name = name }, 0, "SettingsListSectionHeaderTemplate")
end

Stub.categories = {}
function Stub.Category(name, initializers, subs)
	local cat = { name = name, layout = { inits = initializers }, subs = subs or {} }
	function cat:GetName() return self.name end
	function cat:GetSubcategories() return self.subs end
	function cat.layout:GetInitializers() return self.inits end
	return cat
end
SettingsPanel = CreateFrame("Frame", "SettingsPanel", UIParent)
function SettingsPanel:GetAllCategories() return Stub.categories end
function SettingsPanel:GetLayout(cat) return cat.layout end
-- The settings list: a scroll box whose visible row frames are Stub.visibleFrames.
Stub.scrollBox = CreateFrame("Frame", nil, SettingsPanel)
Stub.scrollBox.topY, Stub.scrollBox.bottomY = 410, 100
Stub.visibleFrames = {}
function Stub.scrollBox:EnumerateFrames() return ipairs(Stub.visibleFrames) end
SettingsPanel.settingsList = { ScrollBox = Stub.scrollBox }
function SettingsPanel:GetSettingsList() return self.settingsList end
function SettingsPanel:GetCurrentLayout() return Stub.currentLayout end
-- Puts `init` on screen as a list row between top and bottom (y grows upward).
function Stub.ListRow(init, top, bottom, frame)
	frame = frame or CreateFrame("Frame", nil, UIParent)
	if init.data and (init.data.setting or init.data.cbSetting) then SettingsListElementMixin.Init(frame, init) end
	frame.GetElementData = function() return init end
	frame.topY, frame.bottomY = top, bottom
	return frame
end

-- Builds the row frame Blizzard would show for `init` and runs its setup.
function Stub.ShowRow(init)
	local row = CreateFrame("Frame", nil, UIParent)
	SettingsListElementMixin.Init(row, init)
	return row
end

tinsert = table.insert

-- Loads the addon the way the client would: every file listed in the .toc, in order, each
-- run with the addon name as `...`, then the login events.
function Stub.LoadAddon(dir, name)
	local toc = assert(io.open(dir .. "/" .. name .. ".toc"))
	for line in toc:lines() do
		line = line:gsub("\r", "")
		if line ~= "" and not line:match("^##") then
			local path = dir .. "/" .. line:gsub("\\", "/")
			local chunk, err = loadfile(path)
			if not chunk then error(err) end
			chunk(name)
		end
	end
	toc:close()
	Stub.Fire("ADDON_LOADED", name)
	Stub.Fire("PLAYER_LOGIN")
	Stub.Fire("PLAYER_ENTERING_WORLD")
end

function Stub.Slash(msg)
	SlashCmdList["QUICKTOGGLE"](msg)
end

function Stub.LastPrint() return Stub.printed[#Stub.printed] or "" end

return Stub

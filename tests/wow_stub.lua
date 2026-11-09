-- Minimal stand-in for the WoW Forever client, just enough to load SDHDToggle.lua headless.
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

-- Frames -------------------------------------------------------------------
local function newRegion(kind)
	local r = { kind = kind, points = {}, shown = true, scripts = {}, text = "" }
	function r:SetPoint(point, rel, relPoint, x, y)
		if type(rel) == "number" then x, y, relPoint, rel = rel, relPoint, point, nil end
		self.points[#self.points + 1] = { point, rel, relPoint or point, x or 0, y or 0 }
	end
	function r:GetPoint(i) local p = self.points[i or 1]; if p then return p[1], p[2], p[3], p[4], p[5] end end
	function r:ClearAllPoints() self.points = {} end
	function r:SetAllPoints() end
	function r:SetSize(w, h) self.w, self.h = w, h end
	function r:GetSize() return self.w, self.h end
	function r:Show() self.shown = true end
	function r:Hide() self.shown = false end
	function r:IsShown() return self.shown end
	function r:SetText(t) self.text = t end
	function r:GetText() return self.text end
	function r:SetTextColor(...) self.color = { ... } end
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

-- Loads the addon the way the client would: the file is run with the addon name as `...`.
function Stub.LoadAddon(path, name)
	local chunk, err = loadfile(path)
	if not chunk then error(err) end
	chunk(name)
	Stub.Fire("ADDON_LOADED", name)
	Stub.Fire("PLAYER_LOGIN")
	Stub.Fire("PLAYER_ENTERING_WORLD")
end

function Stub.Slash(msg)
	SlashCmdList["SDHDTOGGLE"](msg)
end

function Stub.LastPrint() return Stub.printed[#Stub.printed] or "" end

return Stub

--[[
	SD / HD character models.

	The Forever client exposes the switch on C_GameRules (checked against Blizzard's UI
	source for 1.60.1.70862; the Barbershop checkbox calls the same three functions from a
	plain OnClick, so no hardware event or reload is needed):
	    C_GameRules.IsSDHDToggleEnabled()            -> is the choice offered at all
	    C_GameRules.AccountHasSDEnabled()            -> true when SD models are active
	    C_GameRules.SetSDHDToggleValue(setToSD, loc) -> flip it; loc = Enum.SdToggleUsageLocationUI
	The setting is account wide. There is no event for it changing, so the core's poll
	keeps the label right if the Barbershop or Options menu changes it.
]]

local QT = QuickToggle

BINDING_NAME_QUICKTOGGLE_SDHD = "Quick Toggle: SD / HD models"

local function HasAPI()
	local gr = C_GameRules
	return gr ~= nil
		and type(gr.IsSDHDToggleEnabled) == "function"
		and type(gr.AccountHasSDEnabled) == "function"
		and type(gr.SetSDHDToggleValue) == "function"
end

-- BeforeLogin=0, CharacterCreation=1, BarberShop=2, OptionsMenu=3. We are closest to the options menu.
local function UsageLocation()
	local e = Enum and Enum.SdToggleUsageLocationUI
	return (e and e.OptionsMenu) or 3
end

QT:Register({
	key = "sdhd",
	name = "SD / HD character models",
	defaultAngle = 220,

	IsAvailable = function()
		if not HasAPI() then
			return false, "this client has no SD/HD model switch"
		elseif not C_GameRules.IsSDHDToggleEnabled() then
			return false, "the SD/HD switch is turned off on this realm or account"
		end
		return true
	end,

	-- value: true = SD (classic) models, false = HD
	Get = function()
		if not HasAPI() then return nil end
		return C_GameRules.AccountHasSDEnabled() == true
	end,
	Set = function(sd)
		C_GameRules.SetSDHDToggleValue(sd and true or false, UsageLocation())
	end,
	Describe = function(sd)
		if sd == nil then return "unknown" end
		return sd and "SD (classic) models" or "HD models"
	end,
	Parse = function(text)
		text = text:lower()
		if text == "sd" or text == "classic" or text == "old" then return true end
		if text == "hd" or text == "new" then return false end
		return nil
	end,

	Create = function(button, disc)
		button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		button.label:SetPoint("CENTER", disc, "CENTER", 0, 0)
		button.label:SetTextColor(QT.YELLOW[1], QT.YELLOW[2], QT.YELLOW[3])
	end,
	Update = function(button, sd)
		button.label:SetText(sd == nil and "?" or (sd and "SD" or "HD"))
	end,
	Tooltip = function(tooltip, sd)
		tooltip:AddDoubleLine("Now showing", sd and "SD (classic) models" or "HD models", 1, 1, 1, 1, 0.82, 0)
		tooltip:AddLine("Click to switch to " .. (sd and "HD" or "SD") .. " models.", 0.6, 1, 0.6)
		tooltip:AddLine("Account wide, like the Options menu setting.", 0.5, 0.5, 0.5)
	end,
})

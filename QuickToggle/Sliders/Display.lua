--[[
	Brightness, contrast and gamma.

	All three are console variables that Blizzard's Options > Graphics page drives with
	Settings.SetupCVarSlider in Blizzard_SettingsDefinitions_Shared/Graphics.lua, which
	loads on Forever:
	    "Brightness"  0 - 100 in steps of 1, shown as a percentage, default 50
	    "Contrast"    0 - 100 in steps of 1, shown as a percentage, default 50
	    "Gamma"       0.3 - 2.8 in steps of 0.1, shown to one decimal (RoundToOneTenth), default 1.0
]]

local QT = QuickToggle

QT:RegisterSlider({
	key = "brightness",
	name = "Brightness",
	cvar = "Brightness",
	min = 0, max = 100, step = 1,
})

QT:RegisterSlider({
	key = "contrast",
	name = "Contrast",
	cvar = "Contrast",
	min = 0, max = 100, step = 1,
})

QT:RegisterSlider({
	key = "gamma",
	name = "Gamma",
	cvar = "Gamma",
	min = 0.3, max = 2.8, step = 0.1,
	Format = function(v)
		if v == nil then return "?" end
		return string.format("%.1f", v)
	end,
})

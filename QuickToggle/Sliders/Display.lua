--[[
	Brightness and contrast.

	Both are console variables that Blizzard's Options > Graphics page drives with a
	0-100 slider in steps of 1 (Settings.SetupCVarSlider(category, "Brightness", ...) and
	"Contrast" in Blizzard_SettingsDefinitions_Shared/Graphics.lua, which loads on Forever).
	The game default for both is 50.
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

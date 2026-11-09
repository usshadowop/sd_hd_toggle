--[[
	Music on / off.

	The game keeps this in the Sound_EnableMusic console variable ("1" / "0"). Blizzard's
	own music hotkey (Sound_ToggleMusic in Blizzard_SharedXML/Sound.lua) flips exactly that
	variable, and CVAR_UPDATE fires with its name when it changes anywhere.

	The button always shows a yellow musical note; a red X is laid over it while music is off.
]]

local QT = QuickToggle

BINDING_NAME_QUICKTOGGLE_MUSIC = "Quick Toggle: music on / off"

local CVAR = "Sound_EnableMusic"

QT:Register({
	key = "music",
	name = "Music",
	defaultAngle = 200,
	events = { "CVAR_UPDATE" },

	IsAvailable = function()
		if type(GetCVar) ~= "function" or GetCVar(CVAR) == nil then
			return false, "this client has no " .. CVAR .. " setting"
		end
		return true
	end,

	-- value: true = music on
	Get = function()
		return GetCVar(CVAR) == "1"
	end,
	Set = function(on)
		SetCVar(CVAR, on and "1" or "0")
	end,
	Describe = function(on)
		return on and "music on" or "music off"
	end,

	Create = function(button, disc)
		local y = QT.YELLOW
		-- A quaver drawn from three pieces: round head, stem up its right side, flag off the top.
		button.noteHead = button:CreateTexture(nil, "ARTWORK")
		button.noteHead:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask") -- a filled white disc
		button.noteHead:SetVertexColor(y[1], y[2], y[3])
		button.noteHead:SetSize(7, 6)
		button.noteHead:SetPoint("CENTER", disc, "CENTER", -2.5, -4)

		button.noteStem = button:CreateTexture(nil, "ARTWORK")
		button.noteStem:SetColorTexture(y[1], y[2], y[3])
		button.noteStem:SetSize(1.5, 12)
		button.noteStem:SetPoint("BOTTOMRIGHT", button.noteHead, "RIGHT", 0, -1)

		button.noteFlag = button:CreateTexture(nil, "ARTWORK")
		button.noteFlag:SetColorTexture(y[1], y[2], y[3])
		button.noteFlag:SetSize(5, 2)
		button.noteFlag:SetPoint("TOPLEFT", button.noteStem, "TOPRIGHT", -0.5, -1)
		if button.noteFlag.SetRotation then button.noteFlag:SetRotation(math.rad(-40)) end

		-- The red X that means "off".
		button.cross = button:CreateTexture(nil, "OVERLAY")
		button.cross:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
		button.cross:SetSize(17, 17)
		button.cross:SetPoint("CENTER", disc, "CENTER", 0, 0)
		button.cross:Hide()
	end,
	-- The note is always drawn; only the red X comes and goes.
	Update = function(button, on)
		if on then button.cross:Hide() else button.cross:Show() end
	end,
	Tooltip = function(tooltip, on)
		tooltip:AddDoubleLine("Music", on and "on" or "off", 1, 1, 1, 1, 0.82, 0)
		tooltip:AddLine("Click to turn it " .. (on and "off" or "on") .. ".", 0.6, 1, 0.6)
		if GetCVar("Sound_EnableAllSound") == "0" then
			tooltip:AddLine("All sound is off in Options, so music will not play either way.", 1, 0.3, 0.3, true)
		end
	end,
})

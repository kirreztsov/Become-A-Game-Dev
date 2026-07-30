local SoundService = game:GetService("SoundService")
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)

local Sound = {}

-- Every game sound in ONE place. Fill ids from Studio -> Toolbox -> Audio.
-- Paste the full "rbxassetid://XXXX" or just the number; an id of 0 (or blank)
-- is "unset" and plays nothing (no errors), so the game runs while slots fill.
local CUES = {
	Music       = { id = "rbxassetid://0", volume = 0.30, looped = true },
	Ambient     = { id = "rbxassetid://0", volume = 0.15, looped = true },
	Click       = { id = "rbxassetid://0", volume = 0.50 },
	PanelOpen   = { id = "rbxassetid://0", volume = 0.45 },
	Error       = { id = "rbxassetid://0", volume = 0.45 },
	Teleport    = { id = "rbxassetid://0", volume = 0.50 },
	Cash        = { id = "rbxassetid://0", volume = 0.50 },
	Purchase    = { id = "rbxassetid://0", volume = 0.60 },
	Hire        = { id = "rbxassetid://0", volume = 0.55 },
	DailyReward = { id = "rbxassetid://0", volume = 0.60 },
	RoundStart  = { id = "rbxassetid://0", volume = 0.40 },
	MinigameTap = { id = "rbxassetid://0", volume = 0.40 },
	Correct     = { id = "rbxassetid://0", volume = 0.50 },
	Wrong       = { id = "rbxassetid://0", volume = 0.40 },
	Shipped     = { id = "rbxassetid://0", volume = 0.60 },
	TrendHit    = { id = "rbxassetid://0", volume = 0.70 },
	Milestone   = { id = "rbxassetid://0", volume = 0.70 },
	CaseSpin    = { id = "rbxassetid://0", volume = 0.45 },
	CaseReveal  = { id = "rbxassetid://0", volume = 0.65 },
	Rebirth     = { id = "rbxassetid://0", volume = 0.70 },
}

local function normalizeId(id)
	if id == nil or id == "" then
		return ""
	end
	if string.match(id, "^%d+$") then
		return "rbxassetid://" .. id
	end
	return id
end

local function isUnset(id)
	local n = normalizeId(id)
	return n == "" or n == "rbxassetid://0"
end

local folder
local templates = {}
local muted = false
local playerState

function Sound.isMuted()
	return muted
end

function Sound.play(cueName)
	if muted then
		return
	end
	local spec = CUES[cueName]
	local t = templates[cueName]
	if not spec or not t or spec.looped or isUnset(spec.id) then
		return
	end
	-- clone so rapid repeats overlap instead of cutting each other off
	local s = t:Clone()
	s.Parent = folder
	s:Play()
	s.Ended:Connect(function()
		s:Destroy()
	end)
	task.delay(20, function()
		if s and s.Parent and not s.IsPlaying then
			s:Destroy()
		end
	end)
end

local function startBeds()
	for name, spec in pairs(CUES) do
		if spec.looped and not isUnset(spec.id) then
			local t = templates[name]
			if t and not t.IsPlaying then
				t:Play()
			end
		end
	end
end

local function stopBeds()
	for name, spec in pairs(CUES) do
		if spec.looped then
			local t = templates[name]
			if t and t.IsPlaying then
				t:Stop()
			end
		end
	end
end

function Sound.setMuted(on, persist)
	muted = on and true or false
	if muted then
		stopBeds()
	else
		startBeds()
	end
	if persist then
		if playerState then
			playerState.soundMuted = muted
		end
		Remotes.SetSoundMuted:FireServer(muted)
	end
end

function Sound.init(player, state)
	playerState = state
	folder = Instance.new("Folder")
	folder.Name = "GameAudio"
	folder.Parent = SoundService
	for name, spec in pairs(CUES) do
		local s = Instance.new("Sound")
		s.Name = name
		s.SoundId = isUnset(spec.id) and "" or normalizeId(spec.id)
		s.Volume = spec.volume
		s.Looped = spec.looped == true
		s.Parent = folder
		templates[name] = s
	end

	-- 🔊 / 🔇 toggle button, just below the DarkMode toggle (top-left).
	local pg = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "SoundGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 30
	gui.Parent = pg
	local btn = Instance.new("TextButton")
	btn.Name = "SoundToggle"
	btn.Size = UDim2.fromOffset(46, 46)
	btn.Position = UDim2.fromOffset(16, 70)
	btn.BackgroundColor3 = Color3.fromRGB(120, 90, 235)
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Font = Enum.Font.FredokaOne
	btn.TextSize = 22
	btn.Text = "\240\159\148\138" -- 🔊
	btn.Parent = gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = btn

	local function refreshIcon()
		btn.Text = muted and "\240\159\148\135" or "\240\159\148\138" -- 🔇 / 🔊
	end
	btn.MouseButton1Click:Connect(function()
		Sound.setMuted(not muted, true)
		refreshIcon()
	end)

	-- Load the saved preference (mirror DarkMode): first state we receive.
	local loaded = false
	Remotes.PlayerStateUpdated.OnClientEvent:Connect(function(data)
		if not loaded then
			loaded = true
			if data.soundMuted then
				Sound.setMuted(true, false)
				refreshIcon()
			else
				startBeds()
			end
		end
	end)
	task.delay(4, function()
		if not loaded then
			startBeds()
		end
	end)
	Remotes.RequestInitialState:FireServer()
end

return Sound

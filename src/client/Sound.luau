local SoundService = game:GetService("SoundService")
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)

local Sound = {}

-- Every game sound in ONE place. Fill ids from Studio -> Toolbox -> Audio.
-- Paste the full "rbxassetid://XXXX" or just the number; an id of 0 (or blank)
-- is "unset" and plays nothing (no errors), so the game runs while slots fill.
local CUES = {
	Music       = { id = "rbxassetid://1848354536", volume = 0.30, looped = true },   -- "Relaxed Scene" (APM)
	Ambient     = { id = "rbxassetid://9112831284", volume = 0.12, looped = true },   -- Morning Birds loop (Pro Sound Effects)
	Click       = { id = "rbxassetid://88442833509532", volume = 0.50 },              -- ui-simple-button-click
	PanelOpen   = { id = "rbxassetid://130029763520057", volume = 0.45 },             -- Open SFX
	Error       = { id = "rbxassetid://16903690359", volume = 0.45 },                 -- warning beep
	Teleport    = { id = "rbxassetid://129081570292387", volume = 0.50 },             -- Teleport Warp
	Cash        = { id = "rbxassetid://93529351909119", volume = 0.50 },              -- coin pickup
	Purchase    = { id = "rbxassetid://4612374036", volume = 0.55 },                  -- bling pickup
	Hire        = { id = "rbxassetid://3416831713", volume = 0.55 },                  -- Token_Get
	DailyReward = { id = "rbxassetid://1848281810", volume = 0.55 },                  -- "Everything Works Out" sting (APM)
	RoundStart  = { id = "rbxassetid://117166473587029", volume = 0.40 },             -- spin/start beep
	MinigameTap = { id = "rbxassetid://9113873775", volume = 0.35 },                  -- keyboard key (Pro Sound Effects)
	Correct     = { id = "rbxassetid://3416831713", volume = 0.50 },                  -- Token_Get (positive ding)
	Wrong       = { id = "rbxassetid://16903690359", volume = 0.40 },                 -- warning beep
	Shipped     = { id = "rbxassetid://9045295141", volume = 0.55 },                  -- "Roll The Dice" sting (APM)
	TrendHit    = { id = "rbxassetid://1839881844", volume = 0.70 },                  -- "Spinning Around" sting (APM)
	Milestone   = { id = "rbxassetid://9045298695", volume = 0.70 },                  -- "Crack The Safe" sting (APM)
	CaseSpin    = { id = "rbxassetid://95442501996101", volume = 0.45 },              -- wheel spin
	CaseReveal  = { id = "rbxassetid://1840076509", volume = 0.60 },                  -- "Through the Roof" sting (APM)
	Rebirth     = { id = "rbxassetid://126805498637586", volume = 0.65 },             -- magical
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

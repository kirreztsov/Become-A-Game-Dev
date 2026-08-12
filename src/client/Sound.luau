local SoundService = game:GetService("SoundService")
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)

local Sound = {}

-- Every game sound in ONE place. Fill ids from Studio -> Toolbox -> Audio.
-- Paste the full "rbxassetid://XXXX" or just the number; an id of 0 (or blank)
-- is "unset" and plays nothing (no errors), so the game runs while slots fill.
local CUES = {
	-- Volumes kept low + gentle on purpose (cozy game); tune freely.
	Music       = { id = "rbxassetid://1848354536", volume = 0.20, looped = true },   -- "Relaxed Scene" (APM)
	Ambient     = { id = "rbxassetid://9112831284", volume = 0.07, looped = true },   -- Morning Birds loop (Pro Sound Effects)
	Click       = { id = "rbxassetid://88442833509532", volume = 0.30 },              -- soft UI click
	PanelOpen   = { id = "rbxassetid://130029763520057", volume = 0.28 },             -- open pop
	Error       = { id = "rbxassetid://16903690359", volume = 0.22 },                 -- soft warning beep
	Teleport    = { id = "rbxassetid://129081570292387", volume = 0.30 },             -- warp
	Cash        = { id = "rbxassetid://9114350155", volume = 0.45 },                 -- ATM bill-counter "brrrt" (Epson feed, Pro Sound Effects) -- big gains
	CashTick    = { id = "rbxassetid://93529351909119", volume = 0.14 },             -- soft coin blip for small/passive ticks
	Purchase    = { id = "rbxassetid://4612374036", volume = 0.32 },                  -- bling
	Hire        = { id = "rbxassetid://3416831713", volume = 0.32 },                  -- token get
	DailyReward = { id = "rbxassetid://114558778620362", volume = 0.30 },             -- gentle twinkle
	RoundStart  = { id = "rbxassetid://117166473587029", volume = 0.26 },             -- start beep
	MinigameTap = { id = "rbxassetid://9113873775", volume = 0.20 },                  -- keyboard key (Pro Sound Effects)
	Correct     = { id = "rbxassetid://3416831713", volume = 0.32 },                  -- positive ding
	Wrong       = { id = "rbxassetid://16903690359", volume = 0.22 },                 -- soft warning beep
	Shipped     = { id = "rbxassetid://107123499340448", volume = 0.33 },             -- pleasant bell chime
	TrendHit    = { id = "rbxassetid://73370234810660", volume = 0.38 },              -- sparkle pickup
	Milestone   = { id = "rbxassetid://79130903404606", volume = 0.38 },              -- crystal chime
	CaseSpin    = { id = "rbxassetid://95442501996101", volume = 0.28 },              -- wheel spin
	CaseReveal  = { id = "rbxassetid://4612374495", volume = 0.36 },                  -- bling reveal
	Rebirth     = { id = "rbxassetid://118372621575284", volume = 0.36 },             -- calm bell (suzu)
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
	-- Top RIGHT, under the dark-mode toggle (see DarkMode.luau) -- keeps the
	-- left column free for the main button stack.
	btn.AnchorPoint = Vector2.new(1, 0)
	btn.Position = UDim2.new(1, -16, 0, 70)
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

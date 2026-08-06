-- Dynamic onboarding tutorial (M2). A friendly, NON-BLOCKING guide that walks a
-- brand-new player through their first full loop and then congratulates them.
-- Input is never locked. All motion uses manual loops (TweenService is
-- unreliable in this project). Step completion is detected from deltas captured
-- when each step starts, so Replay works for veteran players too.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local TutorialGuide = {}

local STEP_TEXT = {
	"Step 1 of 6 — Head to the Studio Kiosk and press E! 🏠",
	"Step 2 of 6 — Sit at the New Project computer! 💻",
	"Step 3 of 6 — Pick a Genre + Topic that matches a Trend, then hit Start! 🎯",
	"Step 4 of 6 — Play the mini-games to build your game! 🎮",
	"Step 5 of 6 — Earn $200, then buy a PC upgrade here! 💻",
	"Step 6 of 6 — Hire your first worker! 👷",
}
local FINALE_TEXT = "🎉 You're all set! Keep releasing hit games and grow your studio!"

function TutorialGuide.init(player, theme, playerState, hooks)
	hooks = hooks or {}
	local currentStep = 0 -- 0 = idle; 1..6 = active; back to 0 after finale
	local baseline = { games = 0, houseTier = 0, pcTier = 0, workersHired = 0 }
	local beacon = nil
	local beaconGen = 0

	local gui = Instance.new("ScreenGui")
	gui.Name = "TutorialGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 15
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Bottom-center step banner.
	local banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.Size = UDim2.fromOffset(580, 66)
	banner.AnchorPoint = Vector2.new(0.5, 1)
	banner.Position = UDim2.new(0.5, 0, 1, -28)
	banner.BackgroundColor3 = theme.Panel
	banner.Visible = false
	banner.Parent = gui
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 14)
	bc.Parent = banner
	local bs = Instance.new("UIStroke")
	bs.Color = theme.Accent
	bs.Thickness = 2
	bs.Transparency = 0.25
	bs.Parent = banner

	local bannerText = Instance.new("TextLabel")
	bannerText.Name = "Text"
	bannerText.Size = UDim2.new(1, -110, 1, -12)
	bannerText.Position = UDim2.fromOffset(20, 6)
	bannerText.BackgroundTransparency = 1
	bannerText.TextXAlignment = Enum.TextXAlignment.Left
	bannerText.TextWrapped = true
	bannerText.TextColor3 = theme.Text
	bannerText.Font = Enum.Font.FredokaOne
	bannerText.TextSize = 19
	bannerText.Parent = banner

	local skip = Instance.new("TextButton")
	skip.Name = "Skip"
	skip.Size = UDim2.fromOffset(78, 30)
	skip.AnchorPoint = Vector2.new(1, 0.5)
	skip.Position = UDim2.new(1, -14, 0.5, 0)
	skip.BackgroundTransparency = 1
	skip.Text = "Skip ×"
	skip.TextColor3 = theme.TextMuted
	skip.Font = Enum.Font.GothamMedium
	skip.TextSize = 15
	skip.Parent = banner

	-- "?" replay button, just below the middle-left Rebirth button.
	local replay = Instance.new("TextButton")
	replay.Name = "ReplayTutorial"
	replay.Size = UDim2.fromOffset(40, 40)
	replay.AnchorPoint = Vector2.new(0, 0.5)
	replay.Position = UDim2.new(0, 24, 0.5, 74)
	replay.BackgroundColor3 = theme.Accent
	replay.Text = "?"
	replay.TextColor3 = Color3.fromRGB(255, 255, 255)
	replay.Font = Enum.Font.FredokaOne
	replay.TextSize = 22
	replay.Parent = gui
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(1, 0)
	rc.Parent = replay

	-- ---- pointing helper (beacon) -----------------------------------------

	local function hideBeacon()
		beaconGen += 1
		if beacon then
			beacon:Destroy()
			beacon = nil
		end
	end

	-- Show a big glowing arrow + label over a target part (a seat, the PC, etc).
	local function showBeacon(targetPart, labelText)
		hideBeacon()
		if not targetPart then
			return
		end
		beaconGen += 1
		local myGen = beaconGen

		local model = Instance.new("Model")
		model.Name = "TutorialBeacon"

		local pillar = Instance.new("Part")
		pillar.Name = "Pillar"
		pillar.Size = Vector3.new(0.6, 10, 0.6)
		pillar.Anchored = true
		pillar.CanCollide = false
		pillar.CanQuery = false
		pillar.Material = Enum.Material.Neon
		pillar.Color = theme.Accent
		pillar.Transparency = 0.35
		pillar.CFrame = targetPart.CFrame * CFrame.new(0, 6, 0)
		pillar.Parent = model

		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(150, 120)
		bb.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
		bb.AlwaysOnTop = true
		bb.Adornee = targetPart
		bb.Parent = model
		local arrow = Instance.new("TextLabel")
		arrow.Size = UDim2.fromScale(1, 0.6)
		arrow.BackgroundTransparency = 1
		arrow.Text = "⬇"
		arrow.TextColor3 = theme.Accent
		arrow.Font = Enum.Font.FredokaOne
		arrow.TextScaled = true
		arrow.Parent = bb
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.fromScale(1, 0.4)
		lbl.Position = UDim2.fromScale(0, 0.6)
		lbl.BackgroundTransparency = 1
		lbl.Text = labelText or ""
		lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
		lbl.TextStrokeTransparency = 0.3
		lbl.Font = Enum.Font.FredokaOne
		lbl.TextScaled = true
		lbl.Parent = bb

		model.Parent = workspace
		beacon = model

		task.spawn(function()
			local t = 0
			while myGen == beaconGen and model.Parent do
				t += 0.1
				bb.StudsOffsetWorldSpace = Vector3.new(0, 7 + math.sin(t * 3) * 0.6, 0)
				task.wait(0.05)
			end
		end)
	end

	-- Resolve a target part in the player's plot by seat name / prompt name.
	local function plotPart(childName)
		local plot = hooks.getPlotFolder and hooks.getPlotFolder()
		if not plot then
			return nil
		end
		local found = plot:FindFirstChild(childName, true)
		-- A ProximityPrompt isn't a part; point at the part it's attached to.
		if found and found:IsA("ProximityPrompt") then
			return found.Parent
		end
		return found
	end

	-- ---- step machine -----------------------------------------------------
	local function captureBaseline()
		local hired = 0
		if playerState.workers then
			for _, w in pairs(playerState.workers) do
				if w.hired then
					hired += 1
				end
			end
		end
		baseline = {
			games = playerState.gamesReleased or 0,
			houseTier = playerState.houseTier or 0,
			pcTier = playerState.pcTier or 0,
			workersHired = hired,
		}
	end

	local function finish(showFinale)
		currentStep = 0
		hideBeacon()
		if showFinale then
			bannerText.Text = FINALE_TEXT
			skip.Visible = false
			banner.Visible = true
			task.delay(5, function()
				if currentStep == 0 then
					banner.Visible = false
				end
			end)
		else
			banner.Visible = false
		end
		if not playerState.tutorialDone then
			playerState.tutorialDone = true
			Remotes.SetTutorialDone:FireServer()
		end
	end

	local function setStep(n)
		currentStep = n
		hideBeacon()
		captureBaseline()
		bannerText.Text = STEP_TEXT[n]
		skip.Visible = true
		banner.Visible = true
		if n == 1 then
			local prompt = hooks.getStudioKioskPrompt and hooks.getStudioKioskPrompt()
			if prompt and prompt.Parent then
				showBeacon(prompt.Parent, "Press E!")
			end
		elseif n == 2 then
			showBeacon(plotPart("NewProjectSeat"), "Sit here!")
		elseif n == 5 then
			showBeacon(plotPart("PCUpgradePrompt"), "Upgrade here!")
		end
	end

	local function advance()
		if currentStep < 1 then
			return
		end
		if currentStep >= #STEP_TEXT then
			finish(true)
		else
			setStep(currentStep + 1)
		end
	end

	local function startTutorial()
		setStep(1)
	end

	-- ---- wiring -----------------------------------------------------------
	skip.MouseButton1Click:Connect(function()
		finish(false)
	end)
	replay.MouseButton1Click:Connect(function()
		startTutorial()
	end)

	-- Advance step 1 when the player triggers the lobby Studio Kiosk. The prompt
	-- replicates with the lobby, so wait for it (via the getter) then connect.
	if hooks.getStudioKioskPrompt then
		task.spawn(function()
			local prompt
			for _ = 1, 100 do
				prompt = hooks.getStudioKioskPrompt()
				if prompt then
					break
				end
				task.wait(0.2)
			end
			if prompt then
				prompt.Triggered:Connect(function()
					if currentStep == 1 then
						advance()
					end
				end)
				-- If step 1 started before the prompt replicated, its beacon was
				-- skipped -- show it now that we have the kiosk.
				if currentStep == 1 and prompt.Parent then
					showBeacon(prompt.Parent, "Press E!")
				end
			end
		end)
	end

	if hooks.onSeatedStationChanged then
		hooks.onSeatedStationChanged(function(station)
			if currentStep == 2 and station == "NewProject" then
				advance()
			end
		end)
	end

	Remotes.PhaseStarted.OnClientEvent:Connect(function()
		if currentStep == 3 then
			advance()
		end
	end)

	Remotes.DevelopmentComplete.OnClientEvent:Connect(function()
		if currentStep == 4 then
			advance()
		end
	end)

	local autoStartChecked = false
	Remotes.PlayerStateUpdated.OnClientEvent:Connect(function(data)
		playerState.tutorialDone = data.tutorialDone
		if not autoStartChecked then
			autoStartChecked = true
			if not data.tutorialDone then
				startTutorial()
			end
			return
		end
		if currentStep == 5 then
			if (data.houseTier or 0) > baseline.houseTier or (data.pcTier or 0) > baseline.pcTier then
				advance()
			end
		elseif currentStep == 6 then
			local hired = 0
			if data.workers then
				for _, w in pairs(data.workers) do
					if w.hired then
						hired += 1
					end
				end
			end
			if hired > baseline.workersHired then
				advance()
			end
		end
	end)

	-- Listeners are connected now; pull our current state so the auto-start
	-- check runs even if the server's initial push arrived before we loaded.
	Remotes.RequestInitialState:FireServer()
end

return TutorialGuide

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local GameData = require(game.ReplicatedStorage.Shared.GameData)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)

local UI = {}

local selectedGenre = nil
local selectedTopic = nil
local playerState = {
	cash = 0,
	gamesReleased = 0,
	houseTier = 0,
	workers = {
		Coding = { hired = false, level = 0 },
		MapBuilding = { hired = false, level = 0 },
		Testing = { hired = false, level = 0 },
	},
}

local Theme = {
	Panel = Color3.fromRGB(36, 27, 54),
	PanelLight = Color3.fromRGB(46, 35, 68),
	Neutral = Color3.fromRGB(46, 36, 66),
	NeutralHover = Color3.fromRGB(58, 46, 82),
	Accent = Color3.fromRGB(140, 92, 255),
	AccentDeep = Color3.fromRGB(108, 66, 214),
	Gold = Color3.fromRGB(255, 209, 102),
	Success = Color3.fromRGB(92, 255, 176),
	Danger = Color3.fromRGB(255, 92, 122),
	Text = Color3.fromRGB(240, 238, 250),
	TextMuted = Color3.fromRGB(178, 168, 205),
}

UI.Theme = Theme

local function addCorner(instance, radius)
	instance.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
	return corner
end

local function addStroke(instance, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency or 0
	stroke.Parent = instance
	return stroke
end

local function addGradient(instance, colorA, colorB, rotation)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(colorA, colorB)
	gradient.Rotation = rotation or 90
	gradient.Parent = instance
	return gradient
end

local function addHoverFeedback(button, baseColor, hoverColor)
	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = hoverColor }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = baseColor }):Play()
	end)
end

local function makeButton(parent, layoutOrder, text, size, textSize)
	local button = Instance.new("TextButton")
	button.Name = text
	button.Text = text
	button.Size = size
	button.LayoutOrder = layoutOrder
	button.BackgroundColor3 = Theme.Neutral
	button.TextColor3 = Theme.Text
	button.Font = Enum.Font.FredokaOne
	button.TextSize = textSize or 18
	button.TextWrapped = true
	button.AutoButtonColor = false
	button.Parent = parent
	addCorner(button, 10)
	addStroke(button, Color3.fromRGB(255, 255, 255), 1, 0.85)
	return button
end

UI.addCorner = addCorner
UI.addStroke = addStroke
UI.addGradient = addGradient
UI.addHoverFeedback = addHoverFeedback
UI.makeButton = makeButton

local function makeStationPanel(screenGui, name)
	local panel = Instance.new("Frame")
	panel.Name = name .. "Panel"
	panel.Size = UDim2.fromOffset(380, 190)
	panel.Position = UDim2.fromScale(0.5, 0.82)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.BackgroundColor3 = Theme.Panel
	panel.Visible = false
	panel.Parent = screenGui
	addCorner(panel, 16)
	addStroke(panel, Theme.Accent, 2, 0.4)
	addGradient(panel, Theme.PanelLight, Theme.Panel, 90)
	return panel
end

function UI.init()
	local player = Players.LocalPlayer
	local CodingGame = require(script.Parent.CodingGame)
	local MapBuildingGame = require(script.Parent.MapBuildingGame)
	local TestingGame = require(script.Parent.TestingGame)
	local WorkersPanel = require(script.Parent.WorkersPanel)
	local HousePanel = require(script.Parent.HousePanel)

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "GameDevTycoonUI"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = player:WaitForChild("PlayerGui")

	-- Floating Cash HUD pill
	local cashPill = Instance.new("Frame")
	cashPill.Name = "CashPill"
	cashPill.Size = UDim2.fromOffset(170, 44)
	cashPill.Position = UDim2.fromOffset(20, 20)
	cashPill.BackgroundColor3 = Theme.Gold
	cashPill.Parent = screenGui
	addCorner(cashPill, 22)
	addStroke(cashPill, Color3.fromRGB(255, 255, 255), 1, 0.7)
	addGradient(cashPill, Color3.fromRGB(255, 224, 148), Color3.fromRGB(255, 191, 71), 90)

	local cashLabel = Instance.new("TextLabel")
	cashLabel.Name = "CashLabel"
	cashLabel.Text = "\240\159\146\176 $0"
	cashLabel.Size = UDim2.fromScale(1, 1)
	cashLabel.BackgroundTransparency = 1
	cashLabel.TextColor3 = Color3.fromRGB(60, 40, 10)
	cashLabel.Font = Enum.Font.FredokaOne
	cashLabel.TextSize = 22
	cashLabel.Parent = cashPill

	-- Small transient status toast (feedback wherever you are, not gated by seating)
	local statusToast = Instance.new("TextLabel")
	statusToast.Name = "StatusToast"
	statusToast.Size = UDim2.fromOffset(360, 30)
	statusToast.Position = UDim2.fromOffset(20, 72)
	statusToast.BackgroundTransparency = 1
	statusToast.TextColor3 = Theme.TextMuted
	statusToast.Font = Enum.Font.GothamMedium
	statusToast.TextSize = 15
	statusToast.TextXAlignment = Enum.TextXAlignment.Left
	statusToast.TextWrapped = true
	statusToast.Text = ""
	statusToast.Parent = screenGui

	-- New Project panel (seat-gated: only visible while sitting at NewProjectSeat)
	local newProjectPanel = makeStationPanel(screenGui, "NewProject")

	local newProjectPadding = Instance.new("UIPadding")
	newProjectPadding.PaddingTop = UDim.new(0, 12)
	newProjectPadding.PaddingBottom = UDim.new(0, 12)
	newProjectPadding.PaddingLeft = UDim.new(0, 12)
	newProjectPadding.PaddingRight = UDim.new(0, 12)
	newProjectPadding.Parent = newProjectPanel

	local newProjectLayout = Instance.new("UIListLayout")
	newProjectLayout.Padding = UDim.new(0, 8)
	newProjectLayout.SortOrder = Enum.SortOrder.LayoutOrder
	newProjectLayout.Parent = newProjectPanel

	local genreLabel = Instance.new("TextLabel")
	genreLabel.Text = "GENRE"
	genreLabel.Size = UDim2.new(1, 0, 0, 16)
	genreLabel.LayoutOrder = 1
	genreLabel.BackgroundTransparency = 1
	genreLabel.TextColor3 = Theme.TextMuted
	genreLabel.Font = Enum.Font.GothamBold
	genreLabel.TextSize = 12
	genreLabel.TextXAlignment = Enum.TextXAlignment.Left
	genreLabel.Parent = newProjectPanel

	local genreRow = Instance.new("Frame")
	genreRow.Size = UDim2.new(1, 0, 0, 34)
	genreRow.LayoutOrder = 2
	genreRow.BackgroundTransparency = 1
	genreRow.Parent = newProjectPanel

	local genreRowLayout = Instance.new("UIListLayout")
	genreRowLayout.FillDirection = Enum.FillDirection.Horizontal
	genreRowLayout.Padding = UDim.new(0, 6)
	genreRowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	genreRowLayout.Parent = genreRow

	local genreButtons = {}
	for i, genre in ipairs(GameData.Genres) do
		local button = makeButton(genreRow, i, genre, UDim2.new(0.25, -5, 1, 0), 14)
		genreButtons[genre] = button
		button.MouseButton1Click:Connect(function()
			selectedGenre = genre
			for name, btn in pairs(genreButtons) do
				btn.BackgroundColor3 = (name == genre) and Theme.Accent or Theme.Neutral
			end
		end)
	end

	local topicLabel = Instance.new("TextLabel")
	topicLabel.Text = "TOPIC"
	topicLabel.Size = UDim2.new(1, 0, 0, 16)
	topicLabel.LayoutOrder = 3
	topicLabel.BackgroundTransparency = 1
	topicLabel.TextColor3 = Theme.TextMuted
	topicLabel.Font = Enum.Font.GothamBold
	topicLabel.TextSize = 12
	topicLabel.TextXAlignment = Enum.TextXAlignment.Left
	topicLabel.Parent = newProjectPanel

	local topicRow = Instance.new("Frame")
	topicRow.Size = UDim2.new(1, 0, 0, 34)
	topicRow.LayoutOrder = 4
	topicRow.BackgroundTransparency = 1
	topicRow.Parent = newProjectPanel

	local topicRowLayout = Instance.new("UIListLayout")
	topicRowLayout.FillDirection = Enum.FillDirection.Horizontal
	topicRowLayout.Padding = UDim.new(0, 6)
	topicRowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	topicRowLayout.Parent = topicRow

	local topicButtons = {}
	for i, topic in ipairs(GameData.Topics) do
		local button = makeButton(topicRow, i, topic, UDim2.new(0.25, -5, 1, 0), 14)
		topicButtons[topic] = button
		button.MouseButton1Click:Connect(function()
			selectedTopic = topic
			for name, btn in pairs(topicButtons) do
				btn.BackgroundColor3 = (name == topic) and Theme.Accent or Theme.Neutral
			end
		end)
	end

	local startButton = makeButton(newProjectPanel, 5, "\240\159\154\128 Start Developing", UDim2.new(1, 0, 0, 40), 18)
	startButton.BackgroundColor3 = Theme.Accent
	addGradient(startButton, Color3.fromRGB(163, 110, 255), Color3.fromRGB(120, 74, 220), 90)
	addHoverFeedback(startButton, Theme.Accent, Theme.AccentDeep)

	-- Mini-game panels (each seat-gated to its matching computer)
	local codingPanel = makeStationPanel(screenGui, "Coding")
	local mapBuildingPanel = makeStationPanel(screenGui, "MapBuilding")
	local testingPanel = makeStationPanel(screenGui, "Testing")

	CodingGame.init(codingPanel, Theme)
	MapBuildingGame.init(mapBuildingPanel, Theme)
	TestingGame.init(testingPanel, Theme)

	local function hideAllMiniGames()
		CodingGame.hide()
		MapBuildingGame.hide()
		TestingGame.hide()
	end

	hideAllMiniGames()

	-- Seat tracking: show the matching panel only while physically seated at that computer
	local STATION_NAMES = { "NewProject", "Coding", "MapBuilding", "Testing" }
	local STATION_PANELS = {
		NewProject = newProjectPanel,
		Coding = codingPanel,
		MapBuilding = mapBuildingPanel,
		Testing = testingPanel,
	}

	local seats = {}
	local seatedStation = nil

	local function refreshStationVisibility()
		for _, name in ipairs(STATION_NAMES) do
			STATION_PANELS[name].Visible = (seatedStation == name)
		end
	end

	local function isPlayerInSeat(seat)
		local character = player.Character
		return character ~= nil and seat.Occupant ~= nil and seat.Occupant.Parent == character
	end

	local function updateSeatedStation()
		local newStation = nil
		for _, name in ipairs(STATION_NAMES) do
			local seat = seats[name]
			if seat and isPlayerInSeat(seat) then
				newStation = name
				break
			end
		end
		seatedStation = newStation
		refreshStationVisibility()
	end

	-- Find this player's own plot (assigned server-side on join) rather than
	-- a single shared lobby -- everything below is relative to that plot.
	local plotIndex = player:GetAttribute("PlotIndex")
	if not plotIndex then
		local gotAttribute = false
		local connection
		connection = player:GetAttributeChangedSignal("PlotIndex"):Connect(function()
			gotAttribute = true
		end)

		local waited = 0
		while not gotAttribute and waited < 10 do
			task.wait(0.2)
			waited += 0.2
		end

		connection:Disconnect()
		plotIndex = player:GetAttribute("PlotIndex")
	end

	if not plotIndex then
		warn("No plot was assigned -- the server may be full (max 4 players).")
		return
	end

	local plotFolder = workspace:WaitForChild("Plots"):WaitForChild("Plot" .. plotIndex)

	for _, name in ipairs(STATION_NAMES) do
		local seat = plotFolder:WaitForChild(name .. "Seat")
		seats[name] = seat
		seat:GetPropertyChangedSignal("Occupant"):Connect(updateSeatedStation)
	end

	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		updateSeatedStation()
	end)

	updateSeatedStation()

	-- Physical wall sign showing the Trends Board
	local trendsText = plotFolder:WaitForChild("TrendsSignBacking"):WaitForChild("TrendsDisplay"):WaitForChild("TrendsText")

	local PHASE_DISPLAY_NAMES = {
		Coding = "Coding",
		MapBuilding = "Map Building",
		Testing = "Testing",
	}

	-- Watchdog resets on every sign of progress (phase/round events) instead of
	-- using one fixed deadline for the whole cycle -- a player can now spend up
	-- to ~30s walking to a station between phases, so a single fixed timeout
	-- sized for the old always-on-screen UI would misfire on ordinary play.
	local WATCHDOG_SECONDS = 60
	local developing = false
	local developSequence = 0

	local function armWatchdog()
		developSequence += 1
		local mySequence = developSequence
		task.delay(WATCHDOG_SECONDS, function()
			if developing and mySequence == developSequence then
				developing = false
				hideAllMiniGames()
				statusToast.Text = "Something went wrong -- try again."
				statusToast.TextColor3 = Theme.Danger
			end
		end)
	end

	Remotes.PhaseStarted.OnClientEvent:Connect(function(phase, isAutomated)
		hideAllMiniGames()
		armWatchdog()
		if isAutomated then
			statusToast.Text = ("\240\159\164\150 Your %s worker is working..."):format(PHASE_DISPLAY_NAMES[phase])
			statusToast.TextColor3 = Theme.TextMuted
		else
			statusToast.Text = ("Go sit at the %s computer!"):format(PHASE_DISPLAY_NAMES[phase])
			statusToast.TextColor3 = Theme.Gold
		end
	end)

	Remotes.RoundStarted.OnClientEvent:Connect(function(phase, roundIndex, roundData)
		armWatchdog()
		statusToast.Text = ("%s \226\128\148 round %d/%d"):format(PHASE_DISPLAY_NAMES[phase], roundIndex, GameData.RoundsPerPhase)
		statusToast.TextColor3 = Theme.TextMuted
		if phase == "Coding" then
			CodingGame.startRound()
		elseif phase == "MapBuilding" then
			MapBuildingGame.startRound(roundData.startTime, roundData.periodSeconds)
		elseif phase == "Testing" then
			TestingGame.startRound(roundData.prompt, roundData.options)
		end
	end)

	Remotes.RoundComplete.OnClientEvent:Connect(function(phase, roundIndex, score)
		armWatchdog()
		statusToast.Text = ("Round %d: %d%%"):format(roundIndex, math.floor(score * 100 + 0.5))
		statusToast.TextColor3 = Theme.TextMuted
	end)

	Remotes.PhaseComplete.OnClientEvent:Connect(function(phase, score)
		hideAllMiniGames()
		armWatchdog()
		statusToast.Text = ("%s complete: %d%%"):format(PHASE_DISPLAY_NAMES[phase], math.floor(score * 100 + 0.5))
	end)

	startButton.MouseButton1Click:Connect(function()
		if developing then
			return
		end

		if not selectedGenre or not selectedTopic then
			statusToast.Text = "Pick a Genre and a Topic first!"
			statusToast.TextColor3 = Theme.Danger
			return
		end

		developing = true
		statusToast.Text = "Starting..."
		statusToast.TextColor3 = Theme.TextMuted
		Remotes.RequestStartDevelopment:FireServer(selectedGenre, selectedTopic)
		armWatchdog()
	end)

	Remotes.DevelopmentComplete.OnClientEvent:Connect(function(cash, wasCopy, hitBonus)
		developing = false
		hideAllMiniGames()

		if wasCopy then
			statusToast.Text = "That was a copy! Earned $0."
			statusToast.TextColor3 = Theme.Danger
		elseif hitBonus then
			statusToast.Text = ("\240\159\148\165 TRENDY HIT! Earned $%d!"):format(cash)
			statusToast.TextColor3 = Theme.Success
		else
			statusToast.Text = ("Released! Earned $%d."):format(cash)
			statusToast.TextColor3 = Theme.Gold
		end
	end)

	Remotes.PlayerStateUpdated.OnClientEvent:Connect(function(data)
		playerState.cash = data.cash
		playerState.gamesReleased = data.gamesReleased
		playerState.houseTier = data.houseTier
		playerState.workers = data.workers
		cashLabel.Text = ("\240\159\146\176 $%d"):format(playerState.cash)
	end)

	Remotes.TrendsUpdated.OnClientEvent:Connect(function(trend1, trend2)
		trendsText.Text = ("%s + %s\n%s + %s"):format(
			trend1.genre, trend1.topic, trend2.genre, trend2.topic
		)
	end)

	WorkersPanel.init(player, Theme, playerState)
	HousePanel.init(player, Theme, playerState)
end

return UI

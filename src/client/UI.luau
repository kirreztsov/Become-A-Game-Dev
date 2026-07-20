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

function UI.init()
	local player = Players.LocalPlayer
	local CodingGame = require(script.Parent.CodingGame)
	local MapBuildingGame = require(script.Parent.MapBuildingGame)
	local TestingGame = require(script.Parent.TestingGame)
	local WorkersPanel = require(script.Parent.WorkersPanel)

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "GameDevTycoonUI"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = player:WaitForChild("PlayerGui")

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

	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.fromOffset(460, 560)
	mainFrame.Position = UDim2.fromOffset(20, 80)
	mainFrame.BackgroundColor3 = Theme.Panel
	mainFrame.Parent = screenGui
	addCorner(mainFrame, 18)
	addStroke(mainFrame, Theme.Accent, 2, 0.4)
	addGradient(mainFrame, Theme.PanelLight, Theme.Panel, 90)

	local mainPadding = Instance.new("UIPadding")
	mainPadding.PaddingTop = UDim.new(0, 16)
	mainPadding.PaddingBottom = UDim.new(0, 16)
	mainPadding.PaddingLeft = UDim.new(0, 16)
	mainPadding.PaddingRight = UDim.new(0, 16)
	mainPadding.Parent = mainFrame

	local mainLayout = Instance.new("UIListLayout")
	mainLayout.FillDirection = Enum.FillDirection.Vertical
	mainLayout.Padding = UDim.new(0, 10)
	mainLayout.SortOrder = Enum.SortOrder.LayoutOrder
	mainLayout.Parent = mainFrame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Text = "\240\159\142\174 Game Studio"
	titleLabel.Size = UDim2.new(1, 0, 0, 32)
	titleLabel.LayoutOrder = 1
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Theme.Text
	titleLabel.Font = Enum.Font.FredokaOne
	titleLabel.TextSize = 26
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = mainFrame

	local trendsCard = Instance.new("Frame")
	trendsCard.Size = UDim2.new(1, 0, 0, 56)
	trendsCard.LayoutOrder = 2
	trendsCard.BackgroundColor3 = Color3.fromRGB(58, 32, 20)
	trendsCard.Parent = mainFrame
	addCorner(trendsCard, 12)
	addStroke(trendsCard, Color3.fromRGB(255, 158, 66), 2, 0.2)
	addGradient(trendsCard, Color3.fromRGB(72, 40, 24), Color3.fromRGB(48, 26, 16), 90)

	local trendsEyebrow = Instance.new("TextLabel")
	trendsEyebrow.Text = "\240\159\148\165 TRENDING NOW"
	trendsEyebrow.Size = UDim2.new(1, -16, 0, 16)
	trendsEyebrow.Position = UDim2.fromOffset(8, 4)
	trendsEyebrow.BackgroundTransparency = 1
	trendsEyebrow.TextColor3 = Color3.fromRGB(255, 158, 66)
	trendsEyebrow.Font = Enum.Font.GothamBold
	trendsEyebrow.TextSize = 12
	trendsEyebrow.TextXAlignment = Enum.TextXAlignment.Left
	trendsEyebrow.Parent = trendsCard

	local trendsLabel = Instance.new("TextLabel")
	trendsLabel.Name = "TrendsLabel"
	trendsLabel.Text = "Loading..."
	trendsLabel.Size = UDim2.new(1, -16, 0, 28)
	trendsLabel.Position = UDim2.fromOffset(8, 22)
	trendsLabel.BackgroundTransparency = 1
	trendsLabel.TextColor3 = Theme.Text
	trendsLabel.Font = Enum.Font.GothamMedium
	trendsLabel.TextSize = 15
	trendsLabel.TextXAlignment = Enum.TextXAlignment.Left
	trendsLabel.TextWrapped = true
	trendsLabel.Parent = trendsCard

	local genreLabel = Instance.new("TextLabel")
	genreLabel.Text = "GENRE"
	genreLabel.Size = UDim2.new(1, 0, 0, 18)
	genreLabel.LayoutOrder = 3
	genreLabel.BackgroundTransparency = 1
	genreLabel.TextColor3 = Theme.TextMuted
	genreLabel.Font = Enum.Font.GothamBold
	genreLabel.TextSize = 12
	genreLabel.TextXAlignment = Enum.TextXAlignment.Left
	genreLabel.Parent = mainFrame

	local genreRow = Instance.new("Frame")
	genreRow.Size = UDim2.new(1, 0, 0, 36)
	genreRow.LayoutOrder = 4
	genreRow.BackgroundTransparency = 1
	genreRow.Parent = mainFrame

	local genreRowLayout = Instance.new("UIListLayout")
	genreRowLayout.FillDirection = Enum.FillDirection.Horizontal
	genreRowLayout.Padding = UDim.new(0, 8)
	genreRowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	genreRowLayout.Parent = genreRow

	local genreButtons = {}
	for i, genre in ipairs(GameData.Genres) do
		local button = makeButton(genreRow, i, genre, UDim2.new(0.25, -6, 1, 0), 15)
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
	topicLabel.Size = UDim2.new(1, 0, 0, 18)
	topicLabel.LayoutOrder = 5
	topicLabel.BackgroundTransparency = 1
	topicLabel.TextColor3 = Theme.TextMuted
	topicLabel.Font = Enum.Font.GothamBold
	topicLabel.TextSize = 12
	topicLabel.TextXAlignment = Enum.TextXAlignment.Left
	topicLabel.Parent = mainFrame

	local topicRow = Instance.new("Frame")
	topicRow.Size = UDim2.new(1, 0, 0, 36)
	topicRow.LayoutOrder = 6
	topicRow.BackgroundTransparency = 1
	topicRow.Parent = mainFrame

	local topicRowLayout = Instance.new("UIListLayout")
	topicRowLayout.FillDirection = Enum.FillDirection.Horizontal
	topicRowLayout.Padding = UDim.new(0, 8)
	topicRowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	topicRowLayout.Parent = topicRow

	local topicButtons = {}
	for i, topic in ipairs(GameData.Topics) do
		local button = makeButton(topicRow, i, topic, UDim2.new(0.25, -6, 1, 0), 15)
		topicButtons[topic] = button
		button.MouseButton1Click:Connect(function()
			selectedTopic = topic
			for name, btn in pairs(topicButtons) do
				btn.BackgroundColor3 = (name == topic) and Theme.Accent or Theme.Neutral
			end
		end)
	end

	local startButton = makeButton(mainFrame, 7, "\240\159\154\128 Start Developing", UDim2.new(1, 0, 0, 48), 20)
	startButton.BackgroundColor3 = Theme.Accent
	addGradient(startButton, Color3.fromRGB(163, 110, 255), Color3.fromRGB(120, 74, 220), 90)
	addHoverFeedback(startButton, Theme.Accent, Theme.AccentDeep)

	local phaseLabel = Instance.new("TextLabel")
	phaseLabel.Text = ""
	phaseLabel.Size = UDim2.new(1, 0, 0, 20)
	phaseLabel.LayoutOrder = 8
	phaseLabel.BackgroundTransparency = 1
	phaseLabel.TextColor3 = Theme.TextMuted
	phaseLabel.Font = Enum.Font.GothamBold
	phaseLabel.TextSize = 13
	phaseLabel.TextXAlignment = Enum.TextXAlignment.Left
	phaseLabel.Parent = mainFrame

	local phaseArea = Instance.new("Frame")
	phaseArea.Name = "PhaseArea"
	phaseArea.Size = UDim2.new(1, 0, 0, 160)
	phaseArea.LayoutOrder = 9
	phaseArea.BackgroundColor3 = Theme.Neutral
	phaseArea.Parent = mainFrame
	addCorner(phaseArea, 12)

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Text = ""
	statusLabel.Size = UDim2.new(1, 0, 0, 24)
	statusLabel.LayoutOrder = 10
	statusLabel.BackgroundTransparency = 1
	statusLabel.TextColor3 = Theme.TextMuted
	statusLabel.Font = Enum.Font.GothamMedium
	statusLabel.TextSize = 15
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.Parent = mainFrame

	local workerMessageLabel = Instance.new("TextLabel")
	workerMessageLabel.Name = "WorkerMessage"
	workerMessageLabel.Text = ""
	workerMessageLabel.Size = UDim2.fromScale(1, 1)
	workerMessageLabel.BackgroundTransparency = 1
	workerMessageLabel.TextColor3 = Theme.Text
	workerMessageLabel.Font = Enum.Font.GothamMedium
	workerMessageLabel.TextSize = 16
	workerMessageLabel.TextWrapped = true
	workerMessageLabel.Visible = false
	workerMessageLabel.Parent = phaseArea

	CodingGame.init(phaseArea, Theme)
	MapBuildingGame.init(phaseArea, Theme)
	TestingGame.init(phaseArea, Theme)

	local function hideAllPhaseUI()
		workerMessageLabel.Visible = false
		CodingGame.hide()
		MapBuildingGame.hide()
		TestingGame.hide()
	end

	hideAllPhaseUI()

	local PHASE_DISPLAY_NAMES = {
		Coding = "Coding",
		MapBuilding = "Map Building",
		Testing = "Testing",
	}

	Remotes.PhaseStarted.OnClientEvent:Connect(function(phase, isAutomated)
		hideAllPhaseUI()
		if isAutomated then
			phaseLabel.Text = ("%s \226\128\148 your worker is on it"):format(PHASE_DISPLAY_NAMES[phase])
			workerMessageLabel.Text = ("\240\159\164\150 Your %s worker is working..."):format(PHASE_DISPLAY_NAMES[phase])
			workerMessageLabel.Visible = true
		else
			phaseLabel.Text = PHASE_DISPLAY_NAMES[phase]
		end
	end)

	Remotes.RoundStarted.OnClientEvent:Connect(function(phase, roundIndex, roundData)
		phaseLabel.Text = ("%s \226\128\148 round %d/%d"):format(PHASE_DISPLAY_NAMES[phase], roundIndex, GameData.RoundsPerPhase)
		if phase == "Coding" then
			CodingGame.startRound()
		elseif phase == "MapBuilding" then
			MapBuildingGame.startRound(roundData.startTime, roundData.periodSeconds)
		elseif phase == "Testing" then
			TestingGame.startRound(roundData.prompt, roundData.options)
		end
	end)

	Remotes.RoundComplete.OnClientEvent:Connect(function(phase, roundIndex, score)
		statusLabel.Text = ("Round %d: %d%%"):format(roundIndex, math.floor(score * 100 + 0.5))
		statusLabel.TextColor3 = Theme.TextMuted
	end)

	Remotes.PhaseComplete.OnClientEvent:Connect(function(phase, score)
		hideAllPhaseUI()
		phaseLabel.Text = ("%s complete: %d%%"):format(PHASE_DISPLAY_NAMES[phase], math.floor(score * 100 + 0.5))
	end)

	local developing = false
	local developSequence = 0

	startButton.MouseButton1Click:Connect(function()
		if developing then
			return
		end

		if not selectedGenre or not selectedTopic then
			statusLabel.Text = "Pick a Genre and a Topic first!"
			statusLabel.TextColor3 = Theme.Danger
			return
		end

		developing = true
		developSequence += 1
		local mySequence = developSequence
		statusLabel.Text = ""
		phaseLabel.Text = "Starting..."
		Remotes.RequestStartDevelopment:FireServer(selectedGenre, selectedTopic)

		task.delay(90, function()
			if developing and mySequence == developSequence then
				developing = false
				hideAllPhaseUI()
				phaseLabel.Text = ""
				statusLabel.Text = "Something went wrong -- try again."
				statusLabel.TextColor3 = Theme.Danger
			end
		end)
	end)

	Remotes.DevelopmentComplete.OnClientEvent:Connect(function(cash, wasCopy, hitBonus)
		developing = false
		hideAllPhaseUI()
		phaseLabel.Text = ""

		if wasCopy then
			statusLabel.Text = "That was a copy! Earned $0."
			statusLabel.TextColor3 = Theme.Danger
		elseif hitBonus then
			statusLabel.Text = ("\240\159\148\165 TRENDY HIT! Earned $%d!"):format(cash)
			statusLabel.TextColor3 = Theme.Success
		else
			statusLabel.Text = ("Released! Earned $%d."):format(cash)
			statusLabel.TextColor3 = Theme.Gold
		end
	end)

	Remotes.PlayerStateUpdated.OnClientEvent:Connect(function(data)
		playerState.cash = data.cash
		playerState.gamesReleased = data.gamesReleased
		playerState.workers = data.workers
		cashLabel.Text = ("\240\159\146\176 $%d"):format(playerState.cash)
	end)

	Remotes.TrendsUpdated.OnClientEvent:Connect(function(trend1, trend2)
		trendsLabel.Text = ("%s + %s    %s + %s"):format(
			trend1.genre, trend1.topic, trend2.genre, trend2.topic
		)
	end)

	WorkersPanel.init(player, Theme, playerState)
end

return UI

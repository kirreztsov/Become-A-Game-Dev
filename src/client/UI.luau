local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local GameData = require(game.ReplicatedStorage.Shared.GameData)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)

local UI = {}

local selectedGenre = nil
local selectedTopic = nil
local playerState = {
	cash = 0,
	devSpeedLevel = 0,
	qualityBoostLevel = 0,
	gamesReleased = 0,
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

function UI.init()
	local player = Players.LocalPlayer
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

	-- Main panel
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.fromOffset(460, 500)
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

	-- Trends card (the signature element -- the whole game revolves around this)
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

	-- Genre picker
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

	-- Topic picker
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

	-- Start Developing button
	local startButton = makeButton(mainFrame, 7, "\240\159\154\128 Start Developing", UDim2.new(1, 0, 0, 48), 20)
	startButton.BackgroundColor3 = Theme.Accent
	addGradient(startButton, Color3.fromRGB(163, 110, 255), Color3.fromRGB(120, 74, 220), 90)
	addHoverFeedback(startButton, Theme.Accent, Theme.AccentDeep)

	-- Progress bar
	local progressBackground = Instance.new("Frame")
	progressBackground.Size = UDim2.new(1, 0, 0, 20)
	progressBackground.LayoutOrder = 8
	progressBackground.BackgroundColor3 = Theme.Neutral
	progressBackground.Parent = mainFrame
	addCorner(progressBackground, 10)

	local progressBar = Instance.new("Frame")
	progressBar.Size = UDim2.fromScale(0, 1)
	progressBar.BackgroundColor3 = Theme.Success
	progressBar.Parent = progressBackground
	addCorner(progressBar, 10)
	addGradient(progressBar, Color3.fromRGB(120, 255, 200), Theme.Success, 0)

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Text = ""
	statusLabel.Size = UDim2.new(1, 0, 0, 24)
	statusLabel.LayoutOrder = 9
	statusLabel.BackgroundTransparency = 1
	statusLabel.TextColor3 = Theme.TextMuted
	statusLabel.Font = Enum.Font.GothamMedium
	statusLabel.TextSize = 15
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.Parent = mainFrame

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
		statusLabel.Text = "Developing..."
		statusLabel.TextColor3 = Theme.TextMuted
		Remotes.RequestStartDevelopment:FireServer(selectedGenre, selectedTopic)

		local devTime = GameData.getDevTime(playerState.devSpeedLevel)
		local startClock = os.clock()

		task.delay(devTime + 5, function()
			if developing and mySequence == developSequence then
				developing = false
				progressBar.Size = UDim2.fromScale(0, 1)
				statusLabel.Text = "Something went wrong -- try again."
				statusLabel.TextColor3 = Theme.Danger
			end
		end)

		local connection
		connection = game:GetService("RunService").RenderStepped:Connect(function()
			if not developing then
				connection:Disconnect()
				return
			end

			local elapsed = os.clock() - startClock
			local fraction = math.clamp(elapsed / devTime, 0, 1)
			progressBar.Size = UDim2.fromScale(fraction, 1)
		end)
	end)

	Remotes.DevelopmentComplete.OnClientEvent:Connect(function(cash, wasCopy, hitBonus)
		developing = false
		progressBar.Size = UDim2.fromScale(0, 1)

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

	-- Upgrades
	local upgradesRow = Instance.new("Frame")
	upgradesRow.Size = UDim2.new(1, 0, 0, 64)
	upgradesRow.LayoutOrder = 10
	upgradesRow.BackgroundTransparency = 1
	upgradesRow.Parent = mainFrame

	local upgradesRowLayout = Instance.new("UIListLayout")
	upgradesRowLayout.FillDirection = Enum.FillDirection.Horizontal
	upgradesRowLayout.Padding = UDim.new(0, 12)
	upgradesRowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	upgradesRowLayout.Parent = upgradesRow

	local devSpeedButton = makeButton(upgradesRow, 1, "\226\154\161 Dev Speed", UDim2.new(0.5, -6, 1, 0), 16)
	addHoverFeedback(devSpeedButton, Theme.Neutral, Theme.NeutralHover)

	local qualityBoostButton = makeButton(upgradesRow, 2, "\226\156\168 Quality", UDim2.new(0.5, -6, 1, 0), 16)
	addHoverFeedback(qualityBoostButton, Theme.Neutral, Theme.NeutralHover)

	local function refreshUpgradeButtons()
		devSpeedButton.Text = ("\226\154\161 Dev Speed\nLv%d \194\183 $%d"):format(
			playerState.devSpeedLevel,
			GameData.getDevSpeedCost(playerState.devSpeedLevel)
		)
		qualityBoostButton.Text = ("\226\156\168 Quality\nLv%d \194\183 $%d"):format(
			playerState.qualityBoostLevel,
			GameData.getQualityBoostCost(playerState.qualityBoostLevel)
		)
	end

	refreshUpgradeButtons()

	devSpeedButton.MouseButton1Click:Connect(function()
		Remotes.RequestBuyUpgrade:FireServer("DevSpeed")
	end)

	qualityBoostButton.MouseButton1Click:Connect(function()
		Remotes.RequestBuyUpgrade:FireServer("QualityBoost")
	end)

	Remotes.UpgradeResult.OnClientEvent:Connect(function(upgradeType, success)
		if not success then
			statusLabel.Text = ("Not enough cash to upgrade %s!"):format(upgradeType)
			statusLabel.TextColor3 = Theme.Danger
		end
	end)

	Remotes.PlayerStateUpdated.OnClientEvent:Connect(function(data)
		playerState.cash = data.cash
		playerState.devSpeedLevel = data.devSpeedLevel
		playerState.qualityBoostLevel = data.qualityBoostLevel
		playerState.gamesReleased = data.gamesReleased
		cashLabel.Text = ("\240\159\146\176 $%d"):format(playerState.cash)
		refreshUpgradeButtons()
	end)

	Remotes.TrendsUpdated.OnClientEvent:Connect(function(trend1, trend2)
		trendsLabel.Text = ("%s + %s    %s + %s"):format(
			trend1.genre, trend1.topic, trend2.genre, trend2.topic
		)
	end)
end

return UI

local Players = game:GetService("Players")
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

local function makeButton(parent, layoutOrder, text, position, size)
	local button = Instance.new("TextButton")
	button.Name = text
	button.Text = text
	button.Position = position
	button.Size = size
	button.LayoutOrder = layoutOrder
	button.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Parent = parent
	return button
end

function UI.init()
	local player = Players.LocalPlayer
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "GameDevTycoonUI"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.fromOffset(420, 400)
	mainFrame.Position = UDim2.fromScale(0.02, 0.1)
	mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	mainFrame.Parent = screenGui

	local cashLabel = Instance.new("TextLabel")
	cashLabel.Name = "CashLabel"
	cashLabel.Text = "Cash: $0"
	cashLabel.Size = UDim2.fromOffset(200, 24)
	cashLabel.Position = UDim2.fromOffset(210, 10)
	cashLabel.BackgroundTransparency = 1
	cashLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
	cashLabel.Parent = screenGui

	local trendsLabel = Instance.new("TextLabel")
	trendsLabel.Name = "TrendsLabel"
	trendsLabel.Text = "Trends: loading..."
	trendsLabel.Size = UDim2.fromOffset(400, 40)
	trendsLabel.Position = UDim2.fromOffset(10, 320)
	trendsLabel.BackgroundTransparency = 1
	trendsLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
	trendsLabel.Parent = mainFrame

	local genreLabel = Instance.new("TextLabel")
	genreLabel.Text = "Genre:"
	genreLabel.Size = UDim2.fromOffset(400, 24)
	genreLabel.Position = UDim2.fromOffset(10, 10)
	genreLabel.BackgroundTransparency = 1
	genreLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	genreLabel.Parent = mainFrame

	local genreButtons = {}
	for i, genre in ipairs(GameData.Genres) do
		local button = makeButton(mainFrame, i, genre, UDim2.fromOffset(10 + (i - 1) * 100, 36), UDim2.fromOffset(95, 30))
		genreButtons[genre] = button
		button.MouseButton1Click:Connect(function()
			selectedGenre = genre
			for name, btn in pairs(genreButtons) do
				btn.BackgroundColor3 = (name == genre) and Color3.fromRGB(90, 140, 90) or Color3.fromRGB(60, 60, 70)
			end
		end)
	end

	local topicLabel = Instance.new("TextLabel")
	topicLabel.Text = "Topic:"
	topicLabel.Size = UDim2.fromOffset(400, 24)
	topicLabel.Position = UDim2.fromOffset(10, 76)
	topicLabel.BackgroundTransparency = 1
	topicLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	topicLabel.Parent = mainFrame

	local topicButtons = {}
	for i, topic in ipairs(GameData.Topics) do
		local button = makeButton(mainFrame, i, topic, UDim2.fromOffset(10 + (i - 1) * 100, 102), UDim2.fromOffset(95, 30))
		topicButtons[topic] = button
		button.MouseButton1Click:Connect(function()
			selectedTopic = topic
			for name, btn in pairs(topicButtons) do
				btn.BackgroundColor3 = (name == topic) and Color3.fromRGB(90, 140, 90) or Color3.fromRGB(60, 60, 70)
			end
		end)
	end

	local startButton = makeButton(mainFrame, 100, "Start Developing", UDim2.fromOffset(10, 150), UDim2.fromOffset(190, 36))

	local progressBackground = Instance.new("Frame")
	progressBackground.Size = UDim2.fromOffset(390, 20)
	progressBackground.Position = UDim2.fromOffset(10, 196)
	progressBackground.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	progressBackground.Parent = mainFrame

	local progressBar = Instance.new("Frame")
	progressBar.Size = UDim2.fromScale(0, 1)
	progressBar.BackgroundColor3 = Color3.fromRGB(90, 140, 90)
	progressBar.Parent = progressBackground

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Text = ""
	statusLabel.Size = UDim2.fromOffset(400, 24)
	statusLabel.Position = UDim2.fromOffset(10, 222)
	statusLabel.BackgroundTransparency = 1
	statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	statusLabel.Parent = mainFrame

	local developing = false

	startButton.MouseButton1Click:Connect(function()
		if developing then
			return
		end

		if not selectedGenre or not selectedTopic then
			statusLabel.Text = "Pick a Genre and a Topic first!"
			return
		end

		developing = true
		statusLabel.Text = "Developing..."
		Remotes.RequestStartDevelopment:FireServer(selectedGenre, selectedTopic)

		local devTime = GameData.getDevTime(playerState.devSpeedLevel)
		local startClock = os.clock()

		task.delay(devTime + 5, function()
			if developing then
				developing = false
				progressBar.Size = UDim2.fromScale(0, 1)
				statusLabel.Text = "Something went wrong -- try again."
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
		elseif hitBonus then
			statusLabel.Text = ("TRENDY HIT! Earned $%d!"):format(cash)
		else
			statusLabel.Text = ("Released! Earned $%d."):format(cash)
		end
	end)

	local devSpeedButton = makeButton(mainFrame, 200, "Upgrade Dev Speed", UDim2.fromOffset(210, 150), UDim2.fromOffset(190, 36))
	local qualityBoostButton = makeButton(mainFrame, 201, "Upgrade Quality", UDim2.fromOffset(210, 252), UDim2.fromOffset(190, 36))

	local function refreshUpgradeButtons()
		devSpeedButton.Text = ("Upgrade Dev Speed ($%d)"):format(GameData.getDevSpeedCost(playerState.devSpeedLevel))
		qualityBoostButton.Text = ("Upgrade Quality ($%d)"):format(GameData.getQualityBoostCost(playerState.qualityBoostLevel))
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
		end
	end)

	Remotes.PlayerStateUpdated.OnClientEvent:Connect(function(data)
		playerState.cash = data.cash
		playerState.devSpeedLevel = data.devSpeedLevel
		playerState.qualityBoostLevel = data.qualityBoostLevel
		playerState.gamesReleased = data.gamesReleased
		cashLabel.Text = ("Cash: $%d"):format(playerState.cash)
		refreshUpgradeButtons()
	end)

	Remotes.TrendsUpdated.OnClientEvent:Connect(function(trend1, trend2)
		trendsLabel.Text = ("Trends: %s+%s and %s+%s"):format(
			trend1.genre, trend1.topic, trend2.genre, trend2.topic
		)
	end)
end

return UI

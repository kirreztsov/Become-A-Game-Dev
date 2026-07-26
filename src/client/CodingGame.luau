local Remotes = require(game.ReplicatedStorage.Shared.Remotes)

local CodingGame = {}

local container
local counterLabel
local tapCount = 0
local roundActive = false

function CodingGame.init(parent, theme)
	container = Instance.new("Frame")
	container.Name = "CodingGame"
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundTransparency = 1
	container.Visible = false
	container.Parent = parent

	counterLabel = Instance.new("TextLabel")
	counterLabel.Size = UDim2.new(1, 0, 0, 28)
	counterLabel.Position = UDim2.fromOffset(0, 8)
	counterLabel.BackgroundTransparency = 1
	counterLabel.Text = "Taps: 0"
	counterLabel.Font = Enum.Font.FredokaOne
	counterLabel.TextSize = 20
	counterLabel.TextColor3 = theme.Text
	counterLabel.Parent = container

	local tapButton = Instance.new("TextButton")
	tapButton.Size = UDim2.fromOffset(140, 90)
	tapButton.Position = UDim2.new(0.5, -70, 0, 48)
	tapButton.BackgroundColor3 = theme.Accent
	tapButton.Text = "\240\159\146\187 TAP!"
	tapButton.Font = Enum.Font.FredokaOne
	tapButton.TextSize = 22
	tapButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	tapButton.AutoButtonColor = false
	tapButton.BorderSizePixel = 0
	tapButton.Parent = container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = tapButton

	tapButton.MouseButton1Click:Connect(function()
		if not roundActive then
			return
		end
		tapCount += 1
		counterLabel.Text = ("Taps: %d"):format(tapCount)
		Remotes.ReportTap:FireServer()
	end)
end

function CodingGame.startRound()
	tapCount = 0
	roundActive = true
	counterLabel.Text = "Taps: 0"
	container.Visible = true
end

function CodingGame.hide()
	roundActive = false
	if container then
		container.Visible = false
	end
end

return CodingGame

local Remotes = require(game.ReplicatedStorage.Shared.Remotes)

local TestingGame = {}

local container
local promptLabel
local optionButtons = {}
local answered = false

function TestingGame.init(parent, theme)
	container = Instance.new("Frame")
	container.Name = "TestingGame"
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundTransparency = 1
	container.Visible = false
	container.Parent = parent

	promptLabel = Instance.new("TextLabel")
	promptLabel.Size = UDim2.new(1, -24, 0, 60)
	promptLabel.Position = UDim2.fromOffset(12, 8)
	promptLabel.BackgroundTransparency = 1
	promptLabel.Text = ""
	promptLabel.Font = Enum.Font.GothamMedium
	promptLabel.TextSize = 15
	promptLabel.TextWrapped = true
	promptLabel.TextColor3 = theme.Text
	promptLabel.Parent = container

	for i = 1, 2 do
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(1, -24, 0, 36)
		button.Position = UDim2.fromOffset(12, 70 + (i - 1) * 44)
		button.BackgroundColor3 = theme.Neutral
		button.Text = ""
		button.Font = Enum.Font.GothamMedium
		button.TextSize = 14
		button.TextWrapped = true
		button.TextColor3 = theme.Text
		button.AutoButtonColor = false
		button.BorderSizePixel = 0
		button.Parent = container

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = button

		button.MouseButton1Click:Connect(function()
			if answered then
				return
			end
			answered = true
			Remotes.ReportChoice:FireServer(i)
		end)

		optionButtons[i] = button
	end
end

function TestingGame.startRound(prompt, options)
	answered = false
	promptLabel.Text = prompt
	for i, button in ipairs(optionButtons) do
		button.Text = options[i] or ""
	end
	container.Visible = true
end

function TestingGame.hide()
	if container then
		container.Visible = false
	end
end

return TestingGame

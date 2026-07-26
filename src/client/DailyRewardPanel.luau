local Remotes = require(game.ReplicatedStorage.Shared.Remotes)

local DailyRewardPanel = {}

local function corner(inst, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
	return c
end

function DailyRewardPanel.init(player, theme)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DailyRewardGui"
	screenGui.ResetOnSpawn = false
	screenGui.Enabled = false
	screenGui.DisplayOrder = 20
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	backdrop.BackgroundTransparency = 0.5
	backdrop.BorderSizePixel = 0
	backdrop.Parent = screenGui

	local card = Instance.new("Frame")
	card.Size = UDim2.fromOffset(360, 280)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.BackgroundColor3 = theme.Panel
	card.Parent = screenGui
	corner(card, 20)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = theme.Gold
	stroke.Transparency = 0.2
	stroke.Parent = card
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(theme.PanelLight, theme.Panel)
	grad.Rotation = 90
	grad.Parent = card

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 40)
	title.Position = UDim2.fromOffset(0, 16)
	title.BackgroundTransparency = 1
	title.Text = "\240\159\142\129 Daily Reward"
	title.TextColor3 = theme.Gold
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 30
	title.Parent = card

	local streakLabel = Instance.new("TextLabel")
	streakLabel.Size = UDim2.new(1, 0, 0, 22)
	streakLabel.Position = UDim2.fromOffset(0, 56)
	streakLabel.BackgroundTransparency = 1
	streakLabel.Text = "Day 1 streak"
	streakLabel.TextColor3 = theme.TextMuted
	streakLabel.Font = Enum.Font.GothamMedium
	streakLabel.TextSize = 15
	streakLabel.Parent = card

	-- 7 day-pips showing where in the weekly cycle we are.
	local pipRow = Instance.new("Frame")
	pipRow.Size = UDim2.fromOffset(7 * 34, 30)
	pipRow.Position = UDim2.new(0.5, 0, 0, 90)
	pipRow.AnchorPoint = Vector2.new(0.5, 0)
	pipRow.BackgroundTransparency = 1
	pipRow.Parent = card
	local pips = {}
	for i = 1, 7 do
		local pip = Instance.new("TextLabel")
		pip.Size = UDim2.fromOffset(28, 28)
		pip.Position = UDim2.fromOffset((i - 1) * 34, 0)
		pip.BackgroundColor3 = theme.Neutral
		pip.Text = tostring(i)
		pip.TextColor3 = theme.TextMuted
		pip.Font = Enum.Font.FredokaOne
		pip.TextSize = 14
		pip.Parent = pipRow
		corner(pip, 8)
		pips[i] = pip
	end

	local rewardLabel = Instance.new("TextLabel")
	rewardLabel.Size = UDim2.new(1, -40, 0, 44)
	rewardLabel.Position = UDim2.fromOffset(20, 132)
	rewardLabel.BackgroundTransparency = 1
	rewardLabel.Text = "$500"
	rewardLabel.TextColor3 = theme.Success
	rewardLabel.Font = Enum.Font.FredokaOne
	rewardLabel.TextSize = 34
	rewardLabel.Parent = card

	local claim = Instance.new("TextButton")
	claim.Size = UDim2.fromOffset(240, 54)
	claim.Position = UDim2.new(0.5, 0, 1, -22)
	claim.AnchorPoint = Vector2.new(0.5, 1)
	claim.BackgroundColor3 = theme.Accent
	claim.TextColor3 = Color3.fromRGB(255, 255, 255)
	claim.Font = Enum.Font.FredokaOne
	claim.TextSize = 22
	claim.Text = "Claim!"
	claim.AutoButtonColor = true
	claim.Parent = card
	corner(claim, 12)

	local function showFor(streakDay, rewardDesc)
		streakLabel.Text = ("Day %d streak"):format(streakDay)
		rewardLabel.Text = rewardDesc
		local cycleIndex = ((streakDay - 1) % 7) + 1
		for i, pip in ipairs(pips) do
			if i <= cycleIndex then
				pip.BackgroundColor3 = theme.Gold
				pip.TextColor3 = Color3.fromRGB(60, 40, 10)
			else
				pip.BackgroundColor3 = theme.Neutral
				pip.TextColor3 = theme.TextMuted
			end
		end
		claim.Text = "Claim!"
		claim.Active = true
		screenGui.Enabled = true
	end

	claim.MouseButton1Click:Connect(function()
		if not claim.Active then
			return
		end
		claim.Active = false
		claim.Text = "Claiming..."
		Remotes.RequestClaimDaily:FireServer()
	end)

	Remotes.DailyRewardAvailable.OnClientEvent:Connect(function(streakDay, rewardDesc)
		showFor(streakDay, rewardDesc)
	end)

	Remotes.DailyRewardClaimed.OnClientEvent:Connect(function()
		screenGui.Enabled = false
	end)
end

return DailyRewardPanel

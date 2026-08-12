local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local Sound = require(script.Parent.Sound)
local MarketplaceService = game:GetService("MarketplaceService")
local GameData = require(game.ReplicatedStorage.Shared.GameData)

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
	card.Size = UDim2.fromOffset(470, 600) -- taller: it now holds a 30-cell grid
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

	-- A 30-cell calendar: 6 columns x 5 rows. Each cell shows its day number,
	-- with milestones (7/14/30) drawn larger and gold-ringed.
	local GRID_COLS, CELL, GAP = 6, 62, 6
	local gridRows = math.ceil(GameData.DailyCalendarDays / GRID_COLS)
	local gridHeight = gridRows * CELL + (gridRows - 1) * GAP
	local grid = Instance.new("Frame")
	grid.Name = "Calendar"
	grid.Size = UDim2.fromOffset(GRID_COLS * CELL + (GRID_COLS - 1) * GAP, gridHeight)
	grid.Position = UDim2.new(0.5, 0, 0, 88)
	grid.AnchorPoint = Vector2.new(0.5, 0)
	grid.BackgroundTransparency = 1
	grid.Parent = card

	local cells = {}
	for day = 1, GameData.DailyCalendarDays do
		local reward = GameData.getDailyReward(day)
		local col = (day - 1) % GRID_COLS
		local row = math.floor((day - 1) / GRID_COLS)

		local cell = Instance.new("TextLabel")
		cell.Name = "Day" .. day
		cell.Size = UDim2.fromOffset(CELL, CELL)
		cell.Position = UDim2.fromOffset(col * (CELL + GAP), row * (CELL + GAP))
		cell.BackgroundColor3 = theme.Neutral
		cell.Text = tostring(day)
		cell.TextColor3 = theme.TextMuted
		cell.Font = Enum.Font.FredokaOne
		cell.TextSize = reward.milestone and 20 or 15
		cell.TextYAlignment = Enum.TextYAlignment.Top
		cell.Parent = grid
		corner(cell, 10)

		-- Milestone days get a gold ring so the chase is visible at a glance.
		if reward.milestone then
			local ring = Instance.new("UIStroke")
			ring.Color = theme.Gold
			ring.Thickness = 2
			ring.Transparency = 0.15
			ring.Parent = cell
		end

		-- Small reward hint under the day number.
		local hint = Instance.new("TextLabel")
		hint.Name = "Hint"
		hint.Size = UDim2.new(1, -6, 0, 26)
		hint.Position = UDim2.fromOffset(3, CELL - 28)
		hint.BackgroundTransparency = 1
		hint.Text = GameData.describeDailyReward(reward)
		hint.TextColor3 = theme.TextMuted
		hint.Font = Enum.Font.GothamMedium
		hint.TextSize = 9
		hint.TextWrapped = true
		hint.Parent = cell

		cells[day] = { cell = cell, hint = hint }
	end

	local rewardLabel = Instance.new("TextLabel")
	rewardLabel.Size = UDim2.new(1, -40, 0, 44)
	rewardLabel.Position = UDim2.fromOffset(20, 88 + gridHeight + 10)
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

	-- Shown only when a broken streak can be bought back.
	local repairBtn = Instance.new("TextButton")
	repairBtn.Name = "Repair"
	repairBtn.Size = UDim2.fromOffset(240, 36)
	repairBtn.Position = UDim2.new(0.5, 0, 1, -80)
	repairBtn.AnchorPoint = Vector2.new(0.5, 1)
	repairBtn.BackgroundColor3 = theme.Gold
	repairBtn.TextColor3 = Color3.fromRGB(60, 40, 10)
	repairBtn.Font = Enum.Font.FredokaOne
	repairBtn.TextSize = 16
	repairBtn.Text = "\240\159\148\167 Repair streak"
	repairBtn.Visible = false
	repairBtn.Parent = card
	corner(repairBtn, 10)

	repairBtn.MouseButton1Click:Connect(function()
		local product = GameData.Products.StreakRepair
		if not product or product.id == 0 then
			repairBtn.Text = "Coming soon!"
			return
		end
		MarketplaceService:PromptProductPurchase(player, product.id)
	end)

	local function showFor(streakDay, rewardDesc, repairOffered, brokenStreak)
		if repairOffered and (brokenStreak or 0) > 0 then
			streakLabel.Text = ("Streak broken at day %d!"):format(brokenStreak)
			repairBtn.Visible = true
			repairBtn.Text = "\240\159\148\167 Repair streak"
		else
			streakLabel.Text = ("Day %d of %d"):format(streakDay, GameData.DailyCalendarDays)
			repairBtn.Visible = false
		end
		rewardLabel.Text = rewardDesc

		-- Past days are ticked off, today is highlighted, the rest stay dim.
		for day, entry in pairs(cells) do
			if day < streakDay then
				entry.cell.BackgroundColor3 = theme.Success
				entry.cell.TextColor3 = Color3.fromRGB(255, 255, 255)
				entry.hint.Text = "\226\156\133"
			elseif day == streakDay then
				entry.cell.BackgroundColor3 = theme.Gold
				entry.cell.TextColor3 = Color3.fromRGB(60, 40, 10)
			else
				entry.cell.BackgroundColor3 = theme.Neutral
				entry.cell.TextColor3 = theme.TextMuted
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

	Remotes.DailyRewardAvailable.OnClientEvent:Connect(function(streakDay, rewardDesc, repairOffered, brokenStreak)
		showFor(streakDay, rewardDesc, repairOffered, brokenStreak)
	end)

	Remotes.DailyRewardClaimed.OnClientEvent:Connect(function()
		screenGui.Enabled = false
		Sound.play("DailyReward")
	end)
end

return DailyRewardPanel

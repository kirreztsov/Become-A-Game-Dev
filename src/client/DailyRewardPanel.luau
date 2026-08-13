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

	-- Latest player state, so calendar cells can show the SAME progression-scaled
	-- values the server will actually grant (see GameData.getScaledDailyReward).
	local latestState = nil

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

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Size = UDim2.fromOffset(34, 34)
	close.Position = UDim2.new(1, -12, 0, 12)
	close.AnchorPoint = Vector2.new(1, 0)
	close.BackgroundTransparency = 1
	close.Text = "\195\151"
	close.TextColor3 = theme.TextMuted
	close.Font = Enum.Font.GothamBold
	close.TextSize = 26
	close.Parent = card
	close.MouseButton1Click:Connect(function()
		screenGui.Enabled = false
	end)

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
	-- Compact label for a calendar cell. The full description ("$1500 + 3x - 15m")
	-- is far too long for a 62px cell and wrapped onto two cramped lines, so each
	-- reward gets a short form that always fits on one.
	local function shortReward(reward)
		if reward.kind == "champion" then
			return "PART"
		end
		if reward.kind == "case" then
			return "SPIN"
		end
		if reward.amount then
			local a = reward.amount
			local cash = a >= 1000
				and ("$%s"):format((("%.1f"):format(a / 1000):gsub("%.0$", "")) .. "K")
				or ("$%d"):format(a)
			-- Day 7 pays cash AND a boost; show the cash and mark the extra.
			return reward.mult and (cash .. "+") or cash
		end
		if reward.mult then
			return ("%gx %dm"):format(reward.mult, math.floor((reward.dur or 0) / 60))
		end
		return ""
	end

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

		-- Each cell reads as a prize rather than a spreadsheet row: a big icon for
		-- what you get, the day number tucked into the corner, and a short label
		-- that never wraps. Milestones (7/14/30) are filled gold so the chase is
		-- obvious at a glance.
		local isBoost = reward.kind == "boost" or (reward.mult ~= nil and reward.amount == nil)
		local faceIcon, tint
		if reward.kind == "champion" then
			faceIcon, tint = "\240\159\143\134", theme.Gold                      -- trophy
		elseif reward.kind == "case" then
			faceIcon, tint = "\240\159\142\129", Color3.fromRGB(120, 90, 235)    -- gift
		elseif isBoost then
			faceIcon, tint = "\226\154\161", Color3.fromRGB(150, 92, 255)        -- bolt
		else
			faceIcon, tint = "\240\159\146\176", Color3.fromRGB(56, 150, 90)     -- money bag
		end

		local cell = Instance.new("Frame")
		cell.Name = "Day" .. day
		cell.Size = UDim2.fromOffset(CELL, CELL)
		cell.Position = UDim2.fromOffset(col * (CELL + GAP), row * (CELL + GAP))
		cell.BackgroundColor3 = theme.Neutral
		cell.BorderSizePixel = 0
		cell.Parent = grid
		corner(cell, 12)

		-- Day number, small and out of the way in the top-left.
		local dayLabel = Instance.new("TextLabel")
		dayLabel.Name = "DayNum"
		dayLabel.Size = UDim2.fromOffset(CELL - 10, 14)
		dayLabel.Position = UDim2.fromOffset(6, 4)
		dayLabel.BackgroundTransparency = 1
		dayLabel.Text = tostring(day)
		dayLabel.TextColor3 = theme.TextMuted
		dayLabel.Font = Enum.Font.GothamBold
		dayLabel.TextSize = 11
		dayLabel.TextXAlignment = Enum.TextXAlignment.Left
		dayLabel.Parent = cell

		-- The prize itself, front and centre.
		local face = Instance.new("TextLabel")
		face.Name = "Face"
		face.Size = UDim2.new(1, 0, 0, 24)
		face.Position = UDim2.fromOffset(0, 16)
		face.BackgroundTransparency = 1
		face.Text = faceIcon
		face.TextSize = reward.milestone and 24 or 19
		face.Font = Enum.Font.FredokaOne
		face.Parent = cell

		-- Short label ("$1.5K", "3x 15m", "SPIN", "PART") -- sized never to wrap.
		local hint = Instance.new("TextLabel")
		hint.Name = "Hint"
		hint.Size = UDim2.new(1, -4, 0, 14)
		hint.Position = UDim2.fromOffset(2, CELL - 17)
		hint.BackgroundTransparency = 1
		hint.Text = shortReward(reward)
		hint.TextColor3 = tint
		hint.Font = Enum.Font.FredokaOne
		hint.TextSize = 11
		hint.TextWrapped = false
		hint.Parent = cell

		-- Milestones: filled gold with a ring, so they read as real prizes.
		if reward.milestone then
			cell.BackgroundColor3 = Color3.fromRGB(255, 238, 200)
			dayLabel.TextColor3 = Color3.fromRGB(150, 105, 20)
			hint.TextColor3 = Color3.fromRGB(150, 105, 20)
			local ring = Instance.new("UIStroke")
			ring.Color = theme.Gold
			ring.Thickness = 2.5
			ring.Transparency = 0.1
			ring.Parent = cell
		end

		-- `faceIcon` is kept so a collected day (which shows a tick) can be put
		-- back to its prize icon when the calendar restarts.
		cells[day] = { cell = cell, hint = hint, face = face, dayLabel = dayLabel, tint = tint, faceIcon = faceIcon, milestone = reward.milestone }
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
		local showRepair = repairOffered and (brokenStreak or 0) > 0
		if showRepair then
			streakLabel.Text = ("Streak broken at day %d!"):format(brokenStreak)
			repairBtn.Visible = true
			repairBtn.Text = "\240\159\148\167 Repair streak"
		else
			streakLabel.Text = ("Day %d of %d"):format(streakDay, GameData.DailyCalendarDays)
			repairBtn.Visible = false
		end
		rewardLabel.Text = rewardDesc

		-- The repair button is usually hidden, and both buttons are anchored to
		-- the card's bottom edge -- so a fixed height left its slot as a band of
		-- dead space under the reward. Size the card to what is actually shown.
		card.Size = UDim2.fromOffset(470, showRepair and 604 or 564)

		-- Repaint every cell for its state. The cell is a Frame holding a day
		-- number, a big icon and a short label, so colours go on those children
		-- rather than the frame itself.
		local MILESTONE_FILL = Color3.fromRGB(255, 238, 200)
		local MILESTONE_INK = Color3.fromRGB(150, 105, 20)
		for day, entry in pairs(cells) do
			-- Label reflects the player's own progression, so a cell never
			-- disagrees with the headline figure.
			local scaled = latestState and GameData.getScaledDailyReward(latestState, day)
				or GameData.getDailyReward(day)

			if day < streakDay then
				-- Already collected: a clean green tick, nothing else competing.
				entry.cell.BackgroundColor3 = theme.Success
				entry.face.Text = "\226\156\133"
				entry.hint.Text = ""
				entry.dayLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			elseif day == streakDay then
				-- Today: gold, and the prize spelled out.
				entry.cell.BackgroundColor3 = theme.Gold
				entry.face.Text = entry.faceIcon -- back from a tick if the calendar restarted
				entry.hint.Text = shortReward(scaled)
				entry.dayLabel.TextColor3 = Color3.fromRGB(90, 60, 10)
				entry.hint.TextColor3 = Color3.fromRGB(90, 60, 10)
			else
				-- Still to come. Milestones keep their gold so the chase stays visible.
				entry.cell.BackgroundColor3 = entry.milestone and MILESTONE_FILL or theme.Neutral
				entry.face.Text = entry.faceIcon -- back from a tick if the calendar restarted
				entry.hint.Text = shortReward(scaled)
				entry.dayLabel.TextColor3 = entry.milestone and MILESTONE_INK or theme.TextMuted
				entry.hint.TextColor3 = entry.milestone and MILESTONE_INK or entry.tint
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

	Remotes.PlayerStateUpdated.OnClientEvent:Connect(function(data)
		latestState = data
	end)
end

return DailyRewardPanel

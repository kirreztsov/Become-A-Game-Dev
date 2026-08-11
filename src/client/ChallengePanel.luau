-- Daily challenges UI. A 🗓️ HUD button (with a claimable badge) opens a panel
-- showing today's 3 challenges with progress bars, a Claim button, and a "resets
-- in Xh" countdown. Progress is computed client-side from the player's own data
-- via the shared ChallengeData; claiming is server-authoritative.
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local ChallengeData = require(game.ReplicatedStorage.Shared.ChallengeData)

local ChallengePanel = {}

local function corner(inst, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
end

local function short(n)
	if n >= 1e6 then
		return (string.format("%.1f", n / 1e6):gsub("%.0$", "")) .. "M"
	elseif n >= 1e3 then
		return (string.format("%.1f", n / 1e3):gsub("%.0$", "")) .. "K"
	end
	return tostring(math.floor(n))
end

local function rewardText(reward)
	local parts = {}
	if reward.cash then
		table.insert(parts, "+$" .. short(reward.cash))
	end
	if reward.luckySpins then
		table.insert(parts, "+" .. reward.luckySpins .. " \240\159\142\129")
	end
	return table.concat(parts, "  ")
end

local function fmtCountdown(secs)
	local h = math.floor(secs / 3600)
	local m = math.floor((secs % 3600) / 60)
	return string.format("Resets in %dh %dm", h, m)
end

function ChallengePanel.init(player, theme, playerState)
	local ACCENT = Color3.fromRGB(90, 175, 230) -- cool blue, distinct from Quests' amber

	local state = {}
	if playerState then
		for k, v in pairs(playerState) do
			state[k] = v
		end
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "ChallengeGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 21
	gui.Parent = player:WaitForChild("PlayerGui")

	-- 🗓️ Daily HUD button (left stack, above the Quests button).
	local openBtn = Instance.new("TextButton")
	openBtn.Name = "ChallengeButton"
	openBtn.Size = UDim2.fromOffset(178, 48)
	openBtn.AnchorPoint = Vector2.new(0, 0.5)
	openBtn.Position = UDim2.new(0, 16, 0.5, -174)
	openBtn.BackgroundColor3 = Color3.fromRGB(70, 155, 220)
	openBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	openBtn.Font = Enum.Font.FredokaOne
	openBtn.TextSize = 18
	openBtn.Text = "\240\159\151\147\239\184\143 Daily"
	openBtn.AutoButtonColor = true
	openBtn.Parent = gui
	corner(openBtn, 12)
	local obStroke = Instance.new("UIStroke")
	obStroke.Color = Color3.fromRGB(255, 255, 255)
	obStroke.Thickness = 1
	obStroke.Transparency = 0.6
	obStroke.Parent = openBtn

	local badge = Instance.new("TextLabel")
	badge.Name = "Badge"
	badge.Size = UDim2.fromOffset(24, 24)
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Position = UDim2.new(1, 4, 0, -6)
	badge.BackgroundColor3 = Color3.fromRGB(230, 70, 70)
	badge.TextColor3 = Color3.fromRGB(255, 255, 255)
	badge.Font = Enum.Font.FredokaOne
	badge.TextSize = 14
	badge.Text = "0"
	badge.Visible = false
	badge.Parent = openBtn
	corner(badge, 12)

	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	backdrop.BackgroundTransparency = 0.5
	backdrop.BorderSizePixel = 0
	backdrop.Visible = false
	backdrop.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromOffset(560, 400)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.BackgroundColor3 = theme.Panel
	panel.Parent = backdrop
	corner(panel, 18)
	local pStroke = Instance.new("UIStroke")
	pStroke.Color = ACCENT
	pStroke.Thickness = 2.5
	pStroke.Transparency = 0.2
	pStroke.Parent = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 46)
	title.Position = UDim2.fromOffset(0, 14)
	title.BackgroundTransparency = 1
	title.Text = "\240\159\151\147\239\184\143 Daily Challenges"
	title.TextColor3 = theme.Gold
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 26
	title.Parent = panel

	local countdown = Instance.new("TextLabel")
	countdown.Size = UDim2.new(1, -40, 0, 20)
	countdown.Position = UDim2.fromOffset(20, 54)
	countdown.BackgroundTransparency = 1
	countdown.Text = ""
	countdown.TextColor3 = theme.TextMuted
	countdown.Font = Enum.Font.GothamMedium
	countdown.TextSize = 13
	countdown.Parent = panel

	local close = Instance.new("TextButton")
	close.Size = UDim2.fromOffset(34, 34)
	close.Position = UDim2.new(1, -12, 0, 12)
	close.AnchorPoint = Vector2.new(1, 0)
	close.BackgroundTransparency = 1
	close.Text = "\195\151"
	close.TextColor3 = theme.TextMuted
	close.Font = Enum.Font.GothamBold
	close.TextSize = 26
	close.Parent = panel

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -32, 1, -96)
	list.Position = UDim2.fromOffset(16, 84)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	-- Today's set changes daily, so rebuild the cards each refresh.
	local function buildCard(entry, order)
		local card = Instance.new("Frame")
		card.Name = entry.id
		card.Size = UDim2.new(1, -6, 0, 86)
		card.LayoutOrder = order
		card.BackgroundColor3 = theme.PanelLight or theme.Panel
		card.Parent = list
		corner(card, 12)

		local icon = Instance.new("TextLabel")
		icon.Size = UDim2.fromOffset(48, 48)
		icon.Position = UDim2.fromOffset(14, 12)
		icon.BackgroundTransparency = 1
		icon.Text = entry.icon
		icon.TextSize = 34
		icon.Font = Enum.Font.FredokaOne
		icon.Parent = card

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(1, -240, 0, 22)
		name.Position = UDim2.fromOffset(72, 12)
		name.BackgroundTransparency = 1
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Text = entry.title
		name.TextColor3 = theme.Text
		name.Font = Enum.Font.FredokaOne
		name.TextSize = 18
		name.Parent = card

		local desc = Instance.new("TextLabel")
		desc.Size = UDim2.new(1, -240, 0, 18)
		desc.Position = UDim2.fromOffset(72, 34)
		desc.BackgroundTransparency = 1
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.Text = entry.desc
		desc.TextColor3 = theme.TextMuted
		desc.Font = Enum.Font.GothamMedium
		desc.TextSize = 12
		desc.Parent = card

		local track = Instance.new("Frame")
		track.Size = UDim2.new(1, -252, 0, 14)
		track.Position = UDim2.fromOffset(72, 58)
		track.BackgroundColor3 = theme.Neutral or Color3.fromRGB(210, 214, 222)
		track.BorderSizePixel = 0
		track.Parent = card
		corner(track, 7)
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(math.clamp(entry.target > 0 and entry.progress / entry.target or 0, 0, 1), 1)
		fill.BackgroundColor3 = ACCENT
		fill.BorderSizePixel = 0
		fill.Parent = track
		corner(fill, 7)
		local barLabel = Instance.new("TextLabel")
		barLabel.Size = UDim2.fromScale(1, 1)
		barLabel.BackgroundTransparency = 1
		barLabel.Text = short(entry.progress) .. " / " .. short(entry.target)
		barLabel.TextColor3 = Color3.fromRGB(60, 62, 72)
		barLabel.Font = Enum.Font.GothamBold
		barLabel.TextSize = 11
		barLabel.Parent = track

		local reward = Instance.new("TextLabel")
		reward.Size = UDim2.fromOffset(150, 18)
		reward.Position = UDim2.new(1, -16, 0, 12)
		reward.AnchorPoint = Vector2.new(1, 0)
		reward.BackgroundTransparency = 1
		reward.TextXAlignment = Enum.TextXAlignment.Right
		reward.Text = rewardText(entry.reward)
		reward.TextColor3 = theme.Gold
		reward.Font = Enum.Font.FredokaOne
		reward.TextSize = 15
		reward.Parent = card

		local action = Instance.new("TextButton")
		action.Size = UDim2.fromOffset(130, 40)
		action.Position = UDim2.new(1, -16, 1, -12)
		action.AnchorPoint = Vector2.new(1, 1)
		action.Font = Enum.Font.FredokaOne
		action.TextSize = 16
		action.TextColor3 = Color3.fromRGB(255, 255, 255)
		action.Parent = card
		corner(action, 10)

		if entry.claimed then
			action.Text = "Claimed \226\156\133"
			action.BackgroundColor3 = theme.Neutral or Color3.fromRGB(180, 184, 192)
			action.AutoButtonColor = false
			action.Active = false
		elseif entry.done then
			action.Text = "CLAIM"
			action.BackgroundColor3 = theme.Success or Color3.fromRGB(90, 190, 120)
			action.AutoButtonColor = true
			action.Active = true
			action.MouseButton1Click:Connect(function()
				Remotes.RequestClaimChallenge:FireServer(entry.id)
			end)
		else
			action.Text = "In progress"
			action.BackgroundColor3 = theme.Neutral or Color3.fromRGB(180, 184, 192)
			action.AutoButtonColor = false
			action.Active = false
		end
	end

	local function rebuild()
		for _, ch in ipairs(list:GetChildren()) do
			if ch:IsA("Frame") then
				ch:Destroy()
			end
		end
		local day = ChallengeData.dayIndex(os.time())
		local entries = ChallengeData.list(state, day)
		for i, entry in ipairs(entries) do
			buildCard(entry, i)
		end
		local claimable = ChallengeData.claimableCount(state, day)
		badge.Text = tostring(claimable)
		badge.Visible = claimable > 0
	end
	rebuild()

	openBtn.MouseButton1Click:Connect(function()
		rebuild()
		countdown.Text = fmtCountdown(ChallengeData.secondsUntilReset(os.time()))
		backdrop.Visible = true
	end)
	close.MouseButton1Click:Connect(function()
		backdrop.Visible = false
	end)

	Remotes.PlayerStateUpdated.OnClientEvent:Connect(function(data)
		for k, v in pairs(data) do
			state[k] = v
		end
		rebuild()
	end)

	-- Keep the badge + open countdown fresh (and catch a day rollover).
	task.spawn(function()
		while true do
			task.wait(20)
			rebuild()
			if backdrop.Visible then
				countdown.Text = fmtCountdown(ChallengeData.secondsUntilReset(os.time()))
			end
		end
	end)
end

return ChallengePanel

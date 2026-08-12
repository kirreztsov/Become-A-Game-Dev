-- Quest / achievement ladder UI. A 📜 HUD button (with a badge showing how many
-- rewards are ready) opens a panel listing every quest with a progress bar and a
-- Claim button. Progress is computed client-side from the player's own data via
-- the shared QuestData; claiming is server-authoritative (RequestClaimQuest).
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local QuestData = require(game.ReplicatedStorage.Shared.QuestData)

local QuestPanel = {}

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

function QuestPanel.init(player, theme, playerState)
	local ACCENT = Color3.fromRGB(245, 170, 60) -- warm gold/amber, distinct from Store's purple

	-- Local snapshot of the player's stats, kept in sync from PlayerStateUpdated.
	local state = {}
	if playerState then
		for k, v in pairs(playerState) do
			state[k] = v
		end
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "QuestGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 21
	gui.Parent = player:WaitForChild("PlayerGui")

	-- 📜 Quests HUD button (left stack, above the Store button).
	local openBtn = Instance.new("TextButton")
	openBtn.Name = "QuestButton"
	openBtn.Size = UDim2.fromOffset(178, 48)
	openBtn.AnchorPoint = Vector2.new(0, 0.5)
	openBtn.Position = UDim2.new(0, 16, 0.5, -122)
	openBtn.BackgroundColor3 = Color3.fromRGB(235, 150, 45)
	openBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	openBtn.Font = Enum.Font.FredokaOne
	openBtn.TextSize = 18
	openBtn.Text = "\240\159\147\156 Quests"
	openBtn.AutoButtonColor = true
	openBtn.Parent = gui
	corner(openBtn, 12)
	local obStroke = Instance.new("UIStroke")
	obStroke.Color = Color3.fromRGB(255, 255, 255)
	obStroke.Thickness = 1
	obStroke.Transparency = 0.6
	obStroke.Parent = openBtn

	-- Badge: number of claimable rewards, top-right of the button.
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

	-- Modal backdrop + panel.
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
	panel.Size = UDim2.fromOffset(560, 490)
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
	title.Text = "\240\159\147\156 Quests"
	title.TextColor3 = theme.Gold
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 28
	title.Parent = panel

	local subtitle = Instance.new("TextLabel")
	subtitle.Size = UDim2.new(1, -40, 0, 20)
	subtitle.Position = UDim2.fromOffset(20, 54)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "Complete goals to earn cash and rewards!"
	subtitle.TextColor3 = theme.TextMuted
	subtitle.Font = Enum.Font.GothamMedium
	subtitle.TextSize = 13
	subtitle.Parent = panel

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

	-- Build one card per quest; keep a per-quest refresh fn.
	local refreshers = {}
	for i, q in ipairs(QuestData.QUESTS) do
		local card = Instance.new("Frame")
		card.Name = q.id
		card.Size = UDim2.new(1, -6, 0, 86)
		card.LayoutOrder = i
		card.BackgroundColor3 = theme.PanelLight or theme.Panel
		card.Parent = list
		corner(card, 12)

		local icon = Instance.new("TextLabel")
		icon.Size = UDim2.fromOffset(48, 48)
		icon.Position = UDim2.fromOffset(14, 12)
		icon.BackgroundTransparency = 1
		icon.Text = q.icon
		icon.TextSize = 34
		icon.Font = Enum.Font.FredokaOne
		icon.Parent = card

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(1, -240, 0, 22)
		name.Position = UDim2.fromOffset(72, 12)
		name.BackgroundTransparency = 1
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Text = q.title
		name.TextColor3 = theme.Text
		name.Font = Enum.Font.FredokaOne
		name.TextSize = 18
		name.Parent = card

		local desc = Instance.new("TextLabel")
		desc.Size = UDim2.new(1, -240, 0, 18)
		desc.Position = UDim2.fromOffset(72, 34)
		desc.BackgroundTransparency = 1
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.Text = q.desc
		desc.TextColor3 = theme.TextMuted
		desc.Font = Enum.Font.GothamMedium
		desc.TextSize = 12
		desc.Parent = card

		-- progress bar track + fill + label
		local track = Instance.new("Frame")
		track.Size = UDim2.new(1, -252, 0, 14)
		track.Position = UDim2.fromOffset(72, 58)
		track.BackgroundColor3 = theme.Neutral or Color3.fromRGB(210, 214, 222)
		track.BorderSizePixel = 0
		track.Parent = card
		corner(track, 7)
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(0, 1)
		fill.BackgroundColor3 = ACCENT
		fill.BorderSizePixel = 0
		fill.Parent = track
		corner(fill, 7)
		local barLabel = Instance.new("TextLabel")
		barLabel.Size = UDim2.fromScale(1, 1)
		barLabel.BackgroundTransparency = 1
		barLabel.Text = ""
		-- White + a dark stroke stays legible on the track in both light and dark mode.
		barLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		barLabel.TextStrokeColor3 = Color3.fromRGB(25, 27, 38)
		barLabel.TextStrokeTransparency = 0.35
		barLabel.Font = Enum.Font.GothamBold
		barLabel.TextSize = 11
		barLabel.Parent = track

		local reward = Instance.new("TextLabel")
		reward.Size = UDim2.fromOffset(150, 18)
		reward.Position = UDim2.new(1, -16, 0, 12)
		reward.AnchorPoint = Vector2.new(1, 0)
		reward.BackgroundTransparency = 1
		reward.TextXAlignment = Enum.TextXAlignment.Right
		reward.Text = rewardText(q.reward)
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

		action.MouseButton1Click:Connect(function()
			if QuestData.canClaim(state, q.id) then
				Remotes.RequestClaimQuest:FireServer(q.id)
			end
		end)

		refreshers[q.id] = function()
			local prog = QuestData.progress(state, q)
			local pct = q.target > 0 and (prog / q.target) or 0
			fill.Size = UDim2.fromScale(math.clamp(pct, 0, 1), 1)
			barLabel.Text = short(prog) .. " / " .. short(q.target)
			local claimed = QuestData.isClaimed(state, q.id)
			local done = QuestData.isComplete(state, q)
			if claimed then
				action.Text = "Claimed \226\156\133"
				action.BackgroundColor3 = theme.Neutral or Color3.fromRGB(180, 184, 192)
				action.AutoButtonColor = false
				action.Active = false
			elseif done then
				action.Text = "CLAIM"
				action.BackgroundColor3 = theme.Success or Color3.fromRGB(90, 190, 120)
				action.AutoButtonColor = true
				action.Active = true
			else
				action.Text = "In progress"
				action.BackgroundColor3 = theme.Neutral or Color3.fromRGB(180, 184, 192)
				action.AutoButtonColor = false
				action.Active = false
			end
		end
		refreshers[q.id]()
	end

	local function refreshAll()
		for _, fn in pairs(refreshers) do
			fn()
		end
		local claimable = QuestData.claimableCount(state)
		badge.Text = tostring(claimable)
		badge.Visible = claimable > 0
	end
	refreshAll()

	openBtn.MouseButton1Click:Connect(function()
		refreshAll()
		backdrop.Visible = true
	end)
	close.MouseButton1Click:Connect(function()
		backdrop.Visible = false
	end)

	-- Keep the local snapshot fresh: PlayerStateUpdated carries the full data table.
	Remotes.PlayerStateUpdated.OnClientEvent:Connect(function(data)
		for k, v in pairs(data) do
			state[k] = v
		end
		refreshAll()
	end)
end

return QuestPanel

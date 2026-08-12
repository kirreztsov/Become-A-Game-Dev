-- Sunday Showdown event UI. A 🏆 HUD button (shown only on Sundays, with a
-- claimable badge) opens a panel with the 6 sequential quest bars, an "event
-- ends in" countdown, and the 7-slot Champion-parts collection. Progress is
-- computed client-side from the player's own data via the shared EventData;
-- claiming is server-authoritative and Sunday-gated.
-- Clock note: the Sunday check uses Workspace:GetServerTimeNow() (the synced
-- server clock), NOT os.time(), so a player with a skewed device clock can't
-- lose the event button or see one the server would reject.
local Workspace = game:GetService("Workspace")

local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local EventData = require(game.ReplicatedStorage.Shared.EventData)

-- Server-synced clock, so a skewed device clock can't hide the event. Falls
-- back to os.time() if the first time-sync hasn't landed yet (GetServerTimeNow
-- throws before then, and this runs during client init).
local function now()
	local ok, t = pcall(function()
		return Workspace:GetServerTimeNow()
	end)
	return ok and t or os.time()
end

local EventPanel = {}

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

local function fmtCountdown(secs)
	local h = math.floor(secs / 3600)
	local m = math.floor((secs % 3600) / 60)
	-- %% is a literal percent sign for string.format. The +50% matches the
	-- eventBoost DevelopmentService applies to both cash and subs on release.
	return string.format("Event ends in %dh %dm  •  +50%% cash & subs", h, m)
end

function EventPanel.init(player, theme, playerState)
	local ACCENT = Color3.fromRGB(240, 180, 70) -- gold, distinct from the other panels

	local state = {}
	if playerState then
		for k, v in pairs(playerState) do
			state[k] = v
		end
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "EventGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 22
	gui.Parent = player:WaitForChild("PlayerGui")

	-- 🏆 HUD button (left stack, below Perks). Visible only while the event runs.
	local openBtn = Instance.new("TextButton")
	openBtn.Name = "EventButton"
	openBtn.Size = UDim2.fromOffset(178, 48)
	openBtn.AnchorPoint = Vector2.new(0, 0.5)
	openBtn.Position = UDim2.new(0, 16, 0.5, -278)
	openBtn.BackgroundColor3 = Color3.fromRGB(232, 168, 56)
	openBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	openBtn.Font = Enum.Font.FredokaOne
	openBtn.TextSize = 18
	openBtn.Text = "🏆 Showdown"
	openBtn.AutoButtonColor = true
	openBtn.Visible = false
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
	panel.Size = UDim2.fromOffset(560, 470)
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
	title.Text = "🏆 Sunday Showdown"
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
	close.Text = "×"
	close.TextColor3 = theme.TextMuted
	close.Font = Enum.Font.GothamBold
	close.TextSize = 26
	close.Parent = panel

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -32, 1, -166)
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

	-- Champion collection strip along the bottom (7 slots).
	local collectionTitle = Instance.new("TextLabel")
	collectionTitle.Size = UDim2.new(1, -32, 0, 18)
	collectionTitle.Position = UDim2.new(0, 16, 1, -74)
	collectionTitle.AnchorPoint = Vector2.new(0, 0)
	collectionTitle.BackgroundTransparency = 1
	collectionTitle.TextXAlignment = Enum.TextXAlignment.Left
	collectionTitle.Text = "Champion Parts"
	collectionTitle.TextColor3 = theme.Text
	collectionTitle.Font = Enum.Font.FredokaOne
	collectionTitle.TextSize = 15
	collectionTitle.Parent = panel

	local strip = Instance.new("Frame")
	strip.Size = UDim2.new(1, -32, 0, 44)
	strip.Position = UDim2.new(0, 16, 1, -52)
	strip.BackgroundTransparency = 1
	strip.Parent = panel
	local stripLayout = Instance.new("UIListLayout")
	stripLayout.FillDirection = Enum.FillDirection.Horizontal
	stripLayout.Padding = UDim.new(0, 8)
	stripLayout.SortOrder = Enum.SortOrder.LayoutOrder
	stripLayout.Parent = strip

	local function buildQuestCard(entry)
		local card = Instance.new("Frame")
		card.Name = "Q" .. entry.index
		card.Size = UDim2.new(1, -6, 0, 86)
		card.LayoutOrder = entry.index
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
		name.Text = entry.index .. ". " .. entry.title
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
		fill.Size = UDim2.fromScale(entry.target > 0 and math.clamp(entry.progress / entry.target, 0, 1) or 0, 1)
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
		-- The final quest's headline reward is the Champion part, so say so --
		-- otherwise it lands with no feedback at all.
		reward.Text = "+$" .. short(entry.rewardCash)
		if entry.index == #EventData.QUESTS then
			reward.Text ..= "  + 🏆 Part"
		end
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
			action.Text = "Claimed ✅"
			action.BackgroundColor3 = theme.Neutral or Color3.fromRGB(180, 184, 192)
			action.AutoButtonColor = false
			action.Active = false
		elseif entry.claimable then
			action.Text = "CLAIM"
			action.BackgroundColor3 = theme.Success or Color3.fromRGB(90, 190, 120)
			action.AutoButtonColor = true
			action.Active = true
			action.MouseButton1Click:Connect(function()
				Remotes.RequestClaimEventQuest:FireServer(entry.index)
			end)
		elseif entry.locked then
			action.Text = "Locked 🔒"
			action.BackgroundColor3 = theme.Neutral or Color3.fromRGB(180, 184, 192)
			action.AutoButtonColor = false
			action.Active = false
		else
			action.Text = "In progress"
			action.BackgroundColor3 = theme.Neutral or Color3.fromRGB(180, 184, 192)
			action.AutoButtonColor = false
			action.Active = false
		end
	end

	local function buildChampionSlot(entry, order)
		local slot = Instance.new("TextLabel")
		slot.Name = entry.id
		slot.Size = UDim2.fromOffset(44, 44)
		slot.LayoutOrder = order
		slot.BackgroundColor3 = entry.owned and ACCENT or (theme.Neutral or Color3.fromRGB(210, 214, 222))
		slot.Text = entry.owned and entry.icon or "❔"
		slot.TextSize = 24
		slot.Font = Enum.Font.FredokaOne
		slot.TextColor3 = Color3.fromRGB(255, 255, 255)
		slot.Parent = strip
		corner(slot, 10)
	end

	local function rebuild()
		local active = EventData.isEventActive(now())
		openBtn.Visible = active
		if not active then
			backdrop.Visible = false
			badge.Visible = false
			return
		end

		for _, ch in ipairs(list:GetChildren()) do
			if ch:IsA("Frame") then
				ch:Destroy()
			end
		end
		for _, entry in ipairs(EventData.list(state)) do
			buildQuestCard(entry)
		end

		for _, ch in ipairs(strip:GetChildren()) do
			if ch:IsA("TextLabel") then
				ch:Destroy()
			end
		end
		for i, entry in ipairs(EventData.championList(state)) do
			buildChampionSlot(entry, i)
		end
		collectionTitle.Text = "Champion Parts  (" .. EventData.championCount(state) .. "/7)"

		local claimable = EventData.claimableCount(state)
		badge.Text = tostring(claimable)
		badge.Visible = claimable > 0
	end
	rebuild()

	openBtn.MouseButton1Click:Connect(function()
		rebuild()
		countdown.Text = fmtCountdown(EventData.secondsUntilEnd(now()))
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

	-- Keep the badge + countdown fresh and catch the Sunday start/end boundary.
	task.spawn(function()
		while true do
			task.wait(20)
			rebuild()
			if backdrop.Visible then
				countdown.Text = fmtCountdown(EventData.secondsUntilEnd(now()))
			end
		end
	end)
end

return EventPanel

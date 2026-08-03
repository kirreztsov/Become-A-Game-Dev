-- Scrollable global-leaderboard panel: pick a stat + period, see the top 100
-- and your own standing. Data comes from the server cache via RequestLeaderboardData.
local Players = game:GetService("Players")
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local GameData = require(game.ReplicatedStorage.Shared.GameData)

local LeaderboardPanel = {}

local PANEL_BG = Color3.fromRGB(255, 255, 255)
local TEXT_DARK = Color3.fromRGB(30, 33, 48)
local MUTED = Color3.fromRGB(120, 126, 142)
local ACCENT = Color3.fromRGB(140, 92, 255)
local ROW_ALT = Color3.fromRGB(244, 244, 250)
local MINE = Color3.fromRGB(255, 244, 205)

local gui, listFrame, youLabel
local currentStat = GameData.LeaderboardStats[1].key
local currentPeriod = "week"
local myUserId

local function statByKey(key)
	for _, s in ipairs(GameData.LeaderboardStats) do
		if s.key == key then return s end
	end
	return GameData.LeaderboardStats[1]
end

local function request()
	Remotes.RequestLeaderboardData:FireServer(currentStat, currentPeriod)
end

-- Rebuild the scrolling list from a server response.
local function render(stat, period, rows, standing)
	if stat ~= currentStat or period ~= currentPeriod then return end -- stale reply
	for _, c in ipairs(listFrame:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
	local statDef = statByKey(stat)
	if not rows then
		youLabel.Text = "\240\159\140\141 Global rankings appear in the live game"
		return
	end
	if standing and standing.rank then
		youLabel.Text = ("You: #%d  \226\128\148  %s"):format(standing.rank, statDef.format(standing.value))
	elseif standing then
		youLabel.Text = ("You: %s  \226\128\148  climb into the top 100!"):format(statDef.format(standing.value))
	end
	for i, r in ipairs(rows) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 30)
		row.BackgroundColor3 = (r.userId == myUserId) and MINE or (i % 2 == 0 and ROW_ALT or PANEL_BG)
		row.BorderSizePixel = 0
		row.LayoutOrder = i
		row.Parent = listFrame

		local rank = Instance.new("TextLabel")
		rank.Size = UDim2.new(0, 52, 1, 0)
		rank.BackgroundTransparency = 1
		rank.Text = "#" .. i
		rank.TextColor3 = (i <= 3) and ACCENT or MUTED
		rank.Font = Enum.Font.FredokaOne
		rank.TextSize = 18
		rank.TextXAlignment = Enum.TextXAlignment.Left
		rank.Parent = row

		local name = Instance.new("TextLabel")
		name.Position = UDim2.fromOffset(56, 0)
		name.Size = UDim2.new(1, -170, 1, 0)
		name.BackgroundTransparency = 1
		name.Text = r.name
		name.TextColor3 = TEXT_DARK
		name.Font = Enum.Font.GothamMedium
		name.TextSize = 16
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.Parent = row

		local val = Instance.new("TextLabel")
		val.AnchorPoint = Vector2.new(1, 0)
		val.Position = UDim2.new(1, -8, 0, 0)
		val.Size = UDim2.new(0, 110, 1, 0)
		val.BackgroundTransparency = 1
		val.Text = statDef.format(r.value)
		val.TextColor3 = TEXT_DARK
		val.Font = Enum.Font.FredokaOne
		val.TextSize = 16
		val.TextXAlignment = Enum.TextXAlignment.Right
		val.Parent = row
	end
	if #rows == 0 then
		youLabel.Text = "Be the first on this board!"
	end
end

local function makeTabButton(parent, text, order, onClick)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 0, 1, 0)
	b.AutomaticSize = Enum.AutomaticSize.X
	b.BackgroundColor3 = Color3.fromRGB(238, 238, 246)
	b.TextColor3 = TEXT_DARK
	b.Font = Enum.Font.FredokaOne
	b.TextSize = 15
	b.Text = "  " .. text .. "  "
	b.AutoButtonColor = true
	b.LayoutOrder = order
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = b
	b.MouseButton1Click:Connect(onClick)
	b.Parent = parent
	return b
end

function LeaderboardPanel.toggle()
	if gui then
		gui.Enabled = not gui.Enabled
		if gui.Enabled then request() end
	end
end

function LeaderboardPanel.init(player)
	myUserId = player.UserId
	local pg = player:WaitForChild("PlayerGui")

	gui = Instance.new("ScreenGui")
	gui.Name = "LeaderboardPanelGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 40
	gui.Enabled = false
	gui.Parent = pg

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(520, 560)
	panel.BackgroundColor3 = PANEL_BG
	panel.Parent = gui
	local pc = Instance.new("UICorner"); pc.CornerRadius = UDim.new(0, 16); pc.Parent = panel

	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, -80, 0, 44)
	header.Position = UDim2.fromOffset(20, 12)
	header.BackgroundTransparency = 1
	header.Text = "\240\159\143\134 Global Leaderboards"
	header.TextColor3 = TEXT_DARK
	header.Font = Enum.Font.FredokaOne
	header.TextSize = 26
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Parent = panel

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -14, 0, 14)
	close.Size = UDim2.fromOffset(40, 40)
	close.BackgroundColor3 = Color3.fromRGB(238, 238, 246)
	close.Text = "\195\151"
	close.TextColor3 = TEXT_DARK
	close.Font = Enum.Font.FredokaOne
	close.TextSize = 22
	close.Parent = panel
	local cc = Instance.new("UICorner"); cc.CornerRadius = UDim.new(1, 0); cc.Parent = close
	close.MouseButton1Click:Connect(function() gui.Enabled = false end)

	-- Stat tabs
	local statTabs = Instance.new("Frame")
	statTabs.Position = UDim2.fromOffset(20, 64)
	statTabs.Size = UDim2.new(1, -40, 0, 34)
	statTabs.BackgroundTransparency = 1
	statTabs.Parent = panel
	local statLayout = Instance.new("UIListLayout")
	statLayout.FillDirection = Enum.FillDirection.Horizontal
	statLayout.Padding = UDim.new(0, 6)
	statLayout.Parent = statTabs
	for i, s in ipairs(GameData.LeaderboardStats) do
		makeTabButton(statTabs, s.title, i, function()
			currentStat = s.key
			request()
		end)
	end

	-- Period tabs
	local periodTabs = Instance.new("Frame")
	periodTabs.Position = UDim2.fromOffset(20, 104)
	periodTabs.Size = UDim2.new(1, -40, 0, 32)
	periodTabs.BackgroundTransparency = 1
	periodTabs.Parent = panel
	local periodLayout = Instance.new("UIListLayout")
	periodLayout.FillDirection = Enum.FillDirection.Horizontal
	periodLayout.Padding = UDim.new(0, 6)
	periodLayout.Parent = periodTabs
	makeTabButton(periodTabs, "\240\159\151\147\239\184\143 This Week", 1, function()
		currentPeriod = "week"; request()
	end)
	makeTabButton(periodTabs, "\240\159\143\134 All-Time", 2, function()
		currentPeriod = "all"; request()
	end)

	youLabel = Instance.new("TextLabel")
	youLabel.Position = UDim2.fromOffset(20, 142)
	youLabel.Size = UDim2.new(1, -40, 0, 30)
	youLabel.BackgroundColor3 = MINE
	youLabel.Text = "You: —"
	youLabel.TextColor3 = TEXT_DARK
	youLabel.Font = Enum.Font.FredokaOne
	youLabel.TextSize = 16
	youLabel.Parent = panel
	local yc = Instance.new("UICorner"); yc.CornerRadius = UDim.new(0, 8); yc.Parent = youLabel

	listFrame = Instance.new("ScrollingFrame")
	listFrame.Position = UDim2.fromOffset(20, 180)
	listFrame.Size = UDim2.new(1, -40, 1, -196)
	listFrame.BackgroundColor3 = PANEL_BG
	listFrame.BorderSizePixel = 0
	listFrame.ScrollBarThickness = 6
	listFrame.CanvasSize = UDim2.new()
	listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listFrame.Parent = panel
	local ll = Instance.new("UIListLayout")
	ll.SortOrder = Enum.SortOrder.LayoutOrder
	ll.Parent = listFrame

	Remotes.LeaderboardData.OnClientEvent:Connect(render)
end

return LeaderboardPanel

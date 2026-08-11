-- Rebirth perk tree UI. A ⭐ HUD button (badge = spendable Prestige Points) opens
-- a panel listing perks with their level, effect, cost, and a Buy button.
-- Progress/affordability is computed client-side from the player's own data via
-- the shared PerkData; buying is server-authoritative (RequestBuyPerk).
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local PerkData = require(game.ReplicatedStorage.Shared.PerkData)

local PerkPanel = {}

local function corner(inst, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
end

function PerkPanel.init(player, theme, playerState)
	local ACCENT = Color3.fromRGB(160, 110, 245) -- purple, matches the prestige/rebirth theme

	local state = {}
	if playerState then
		for k, v in pairs(playerState) do
			state[k] = v
		end
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "PerkGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 21
	gui.Parent = player:WaitForChild("PlayerGui")

	-- ⭐ Perks HUD button (left stack, above the Daily button).
	local openBtn = Instance.new("TextButton")
	openBtn.Name = "PerkButton"
	openBtn.Size = UDim2.fromOffset(178, 48)
	openBtn.AnchorPoint = Vector2.new(0, 0.5)
	openBtn.Position = UDim2.new(0, 16, 0.5, -226)
	openBtn.BackgroundColor3 = Color3.fromRGB(150, 100, 240)
	openBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	openBtn.Font = Enum.Font.FredokaOne
	openBtn.TextSize = 18
	openBtn.Text = "\226\173\144 Perks"
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
	panel.Size = UDim2.fromOffset(560, 440)
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
	title.Text = "\226\173\144 Rebirth Perks"
	title.TextColor3 = theme.Gold
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 26
	title.Parent = panel

	local points = Instance.new("TextLabel")
	points.Size = UDim2.new(1, -40, 0, 20)
	points.Position = UDim2.fromOffset(20, 54)
	points.BackgroundTransparency = 1
	points.Text = ""
	points.TextColor3 = ACCENT
	points.Font = Enum.Font.FredokaOne
	points.TextSize = 15
	points.Parent = panel

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

	local refreshers = {}
	for i, p in ipairs(PerkData.PERKS) do
		local card = Instance.new("Frame")
		card.Name = p.id
		card.Size = UDim2.new(1, -6, 0, 82)
		card.LayoutOrder = i
		card.BackgroundColor3 = theme.PanelLight or theme.Panel
		card.Parent = list
		corner(card, 12)

		local icon = Instance.new("TextLabel")
		icon.Size = UDim2.fromOffset(48, 48)
		icon.Position = UDim2.fromOffset(14, 16)
		icon.BackgroundTransparency = 1
		icon.Text = p.icon
		icon.TextSize = 34
		icon.Font = Enum.Font.FredokaOne
		icon.Parent = card

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(1, -260, 0, 22)
		name.Position = UDim2.fromOffset(72, 14)
		name.BackgroundTransparency = 1
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Text = p.name
		name.TextColor3 = theme.Text
		name.Font = Enum.Font.FredokaOne
		name.TextSize = 18
		name.Parent = card

		local desc = Instance.new("TextLabel")
		desc.Size = UDim2.new(1, -260, 0, 34)
		desc.Position = UDim2.fromOffset(72, 38)
		desc.BackgroundTransparency = 1
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.TextYAlignment = Enum.TextYAlignment.Top
		desc.TextWrapped = true
		desc.Text = p.desc
		desc.TextColor3 = theme.TextMuted
		desc.Font = Enum.Font.GothamMedium
		desc.TextSize = 12
		desc.Parent = card

		local lvl = Instance.new("TextLabel")
		lvl.Size = UDim2.fromOffset(150, 18)
		lvl.Position = UDim2.new(1, -16, 0, 14)
		lvl.AnchorPoint = Vector2.new(1, 0)
		lvl.BackgroundTransparency = 1
		lvl.TextXAlignment = Enum.TextXAlignment.Right
		lvl.Text = ""
		lvl.TextColor3 = theme.Text
		lvl.Font = Enum.Font.FredokaOne
		lvl.TextSize = 15
		lvl.Parent = card

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
			if PerkData.canBuy(state, p.id) then
				Remotes.RequestBuyPerk:FireServer(p.id)
			end
		end)

		refreshers[p.id] = function()
			local level = PerkData.level(state, p.id)
			lvl.Text = "Lvl " .. level .. " / " .. p.maxLevel
			if level >= p.maxLevel then
				action.Text = "MAXED"
				action.BackgroundColor3 = theme.Neutral or Color3.fromRGB(180, 184, 192)
				action.AutoButtonColor = false
				action.Active = false
			elseif PerkData.canBuy(state, p.id) then
				action.Text = "Buy (" .. p.cost .. " \226\173\144)"
				action.BackgroundColor3 = theme.Success or Color3.fromRGB(90, 190, 120)
				action.AutoButtonColor = true
				action.Active = true
			else
				action.Text = "Need " .. p.cost .. " \226\173\144"
				action.BackgroundColor3 = theme.Neutral or Color3.fromRGB(180, 184, 192)
				action.AutoButtonColor = false
				action.Active = false
			end
		end
		refreshers[p.id]()
	end

	local function refreshAll()
		for _, fn in pairs(refreshers) do
			fn()
		end
		local pts = state.perkPoints or 0
		points.Text = "Prestige Points: " .. pts .. "  \226\173\144  (earn 1 per rebirth)"
		badge.Text = tostring(pts)
		badge.Visible = pts > 0
	end
	refreshAll()

	openBtn.MouseButton1Click:Connect(function()
		refreshAll()
		backdrop.Visible = true
	end)
	close.MouseButton1Click:Connect(function()
		backdrop.Visible = false
	end)

	Remotes.PlayerStateUpdated.OnClientEvent:Connect(function(data)
		for k, v in pairs(data) do
			state[k] = v
		end
		refreshAll()
	end)
end

return PerkPanel

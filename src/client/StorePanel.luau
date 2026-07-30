-- The Robux Store: a 💎 HUD button that opens a panel of game passes + dev
-- products (M3). Buying uses Roblox's own purchase prompts; ownership + the
-- one-time Starter Pack state come from playerState (server-authoritative).
-- Items whose id is still 0 (not yet created on the Roblox site) show as
-- "Coming soon" so the whole Store works before the real IDs exist.
local MarketplaceService = game:GetService("MarketplaceService")
local GameData = require(game.ReplicatedStorage.Shared.GameData)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)

local StorePanel = {}

local function corner(inst, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
end

function StorePanel.init(player, theme, playerState)
	-- Build the flat list of store entries: passes first, then products.
	local entries = {}
	for key, info in pairs(GameData.GamePasses) do
		table.insert(entries, { kind = "pass", key = key, info = info })
	end
	for key, info in pairs(GameData.Products) do
		table.insert(entries, { kind = "product", key = key, info = info })
	end
	table.sort(entries, function(a, b)
		if a.kind ~= b.kind then
			return a.kind == "pass" -- passes before products
		end
		return (a.info.order or 99) < (b.info.order or 99)
	end)

	local gui = Instance.new("ScreenGui")
	gui.Name = "StoreGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.Parent = player:WaitForChild("PlayerGui")

	-- 💎 Store HUD button (top-left, where the old Goals checklist sat).
	local openBtn = Instance.new("TextButton")
	openBtn.Name = "StoreButton"
	openBtn.Size = UDim2.fromOffset(178, 48)
	openBtn.AnchorPoint = Vector2.new(0, 0.5)
	openBtn.Position = UDim2.new(0, 16, 0.5, -70) -- left stack, above the Rebirth button
	openBtn.BackgroundColor3 = Color3.fromRGB(120, 90, 235)
	openBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	openBtn.Font = Enum.Font.FredokaOne
	openBtn.TextSize = 18
	openBtn.Text = "\240\159\146\142 Store"
	openBtn.AutoButtonColor = true
	openBtn.Parent = gui
	corner(openBtn, 12)
	local obStroke = Instance.new("UIStroke")
	obStroke.Color = Color3.fromRGB(255, 255, 255)
	obStroke.Thickness = 1
	obStroke.Transparency = 0.6
	obStroke.Parent = openBtn

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
	panel.Size = UDim2.fromOffset(560, 470)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.BackgroundColor3 = theme.Panel
	panel.Parent = backdrop
	corner(panel, 18)
	local pStroke = Instance.new("UIStroke")
	pStroke.Color = Color3.fromRGB(120, 90, 235)
	pStroke.Thickness = 2.5
	pStroke.Transparency = 0.2
	pStroke.Parent = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 46)
	title.Position = UDim2.fromOffset(0, 14)
	title.BackgroundTransparency = 1
	title.Text = "\240\159\146\142 Store"
	title.TextColor3 = theme.Gold
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 28
	title.Parent = panel

	local subtitle = Instance.new("TextLabel")
	subtitle.Size = UDim2.new(1, -40, 0, 20)
	subtitle.Position = UDim2.fromOffset(20, 54)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "Free players can earn everything \226\128\148 these just make it faster!"
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

	-- Build one card per entry; keep a refresh fn so we can update owned states.
	local refreshers = {}
	for i, entry in ipairs(entries) do
		local info = entry.info
		local card = Instance.new("Frame")
		card.Name = entry.key
		card.Size = UDim2.new(1, -6, 0, 92)
		card.LayoutOrder = i
		card.BackgroundColor3 = theme.PanelLight or theme.Panel
		card.Parent = list
		corner(card, 12)

		local icon = Instance.new("TextLabel")
		icon.Size = UDim2.fromOffset(56, 56)
		icon.Position = UDim2.fromOffset(14, 18)
		icon.BackgroundTransparency = 1
		icon.Text = info.icon or "\240\159\155\146"
		icon.TextSize = 40
		icon.Font = Enum.Font.FredokaOne
		icon.Parent = card

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(1, -240, 0, 26)
		name.Position = UDim2.fromOffset(78, 14)
		name.BackgroundTransparency = 1
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Text = info.name
		name.TextColor3 = theme.Text
		name.Font = Enum.Font.FredokaOne
		name.TextSize = 19
		name.Parent = card

		local desc = Instance.new("TextLabel")
		desc.Size = UDim2.new(1, -240, 0, 44)
		desc.Position = UDim2.fromOffset(78, 40)
		desc.BackgroundTransparency = 1
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.TextYAlignment = Enum.TextYAlignment.Top
		desc.TextWrapped = true
		desc.Text = info.desc or ""
		desc.TextColor3 = theme.TextMuted
		desc.Font = Enum.Font.GothamMedium
		desc.TextSize = 13
		desc.Parent = card

		local action = Instance.new("TextButton")
		action.Size = UDim2.fromOffset(140, 44)
		action.Position = UDim2.new(1, -16, 0.5, 0)
		action.AnchorPoint = Vector2.new(1, 0.5)
		action.Font = Enum.Font.FredokaOne
		action.TextSize = 17
		action.TextColor3 = Color3.fromRGB(255, 255, 255)
		action.Parent = card
		corner(action, 10)

		action.MouseButton1Click:Connect(function()
			-- Owned skins: clicking the action button wears the skin instead
			-- of prompting a purchase (there's nothing left to buy).
			if info.skin and playerState.passes and playerState.passes[entry.key] then
				if playerState.activeSkin ~= info.skin then
					Remotes.RequestSetSkin:FireServer(info.skin)
				end
				return
			end
			if not (info.id and info.id > 0) then
				return -- not created yet
			end
			if entry.kind == "pass" then
				MarketplaceService:PromptGamePassPurchase(player, info.id)
			else
				MarketplaceService:PromptProductPurchase(player, info.id)
			end
		end)

		refreshers[entry.key] = function()
			local created = info.id and info.id > 0
			local owned = false
			if entry.kind == "pass" then
				owned = playerState.passes and playerState.passes[entry.key]
			elseif entry.key == "StarterPack" then
				owned = playerState.starterPackBought
			end

			if info.skin and owned then
				-- Owned skin pass: "Wear" it (or show it's already worn).
				local wearing = playerState.activeSkin == info.skin
				action.Text = wearing and "Wearing \226\156\133" or "Wear"
				action.BackgroundColor3 = wearing and (theme.Success or Color3.fromRGB(90, 190, 120))
					or (theme.Accent or Color3.fromRGB(120, 90, 235))
				action.AutoButtonColor = not wearing
				action.Active = not wearing
				card.Visible = true
			elseif not created then
				action.Text = "Coming soon"
				action.BackgroundColor3 = theme.Neutral
				action.AutoButtonColor = false
				action.Active = false
				card.Visible = true
			elseif owned then
				action.Text = "Owned \226\156\133"
				action.BackgroundColor3 = theme.Success or Color3.fromRGB(90, 190, 120)
				action.AutoButtonColor = false
				action.Active = false
				-- One-time Starter Pack disappears once bought.
				card.Visible = (entry.key ~= "StarterPack")
			else
				action.Text = (entry.kind == "pass") and "Get" or "Buy"
				action.BackgroundColor3 = theme.Accent or Color3.fromRGB(120, 90, 235)
				action.AutoButtonColor = true
				action.Active = true
				card.Visible = true
			end
		end
		refreshers[entry.key]()
	end

	-- Always-available "Plain look" card to revert to the Default skin, even
	-- once every skin pass is owned. Sits above all the passes (LayoutOrder 0).
	do
		local card = Instance.new("Frame")
		card.Name = "DefaultLook"
		card.Size = UDim2.new(1, -6, 0, 92)
		card.LayoutOrder = 0
		card.BackgroundColor3 = theme.PanelLight or theme.Panel
		card.Parent = list
		corner(card, 12)

		local icon = Instance.new("TextLabel")
		icon.Size = UDim2.fromOffset(56, 56)
		icon.Position = UDim2.fromOffset(14, 18)
		icon.BackgroundTransparency = 1
		icon.Text = "\240\159\143\160"
		icon.TextSize = 40
		icon.Font = Enum.Font.FredokaOne
		icon.Parent = card

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(1, -240, 0, 26)
		name.Position = UDim2.fromOffset(78, 14)
		name.BackgroundTransparency = 1
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Text = "Plain Look"
		name.TextColor3 = theme.Text
		name.Font = Enum.Font.FredokaOne
		name.TextSize = 19
		name.Parent = card

		local desc = Instance.new("TextLabel")
		desc.Size = UDim2.new(1, -240, 0, 44)
		desc.Position = UDim2.fromOffset(78, 40)
		desc.BackgroundTransparency = 1
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.TextYAlignment = Enum.TextYAlignment.Top
		desc.TextWrapped = true
		desc.Text = "Revert your studio to its plain, default look."
		desc.TextColor3 = theme.TextMuted
		desc.Font = Enum.Font.GothamMedium
		desc.TextSize = 13
		desc.Parent = card

		local action = Instance.new("TextButton")
		action.Size = UDim2.fromOffset(140, 44)
		action.Position = UDim2.new(1, -16, 0.5, 0)
		action.AnchorPoint = Vector2.new(1, 0.5)
		action.Font = Enum.Font.FredokaOne
		action.TextSize = 17
		action.TextColor3 = Color3.fromRGB(255, 255, 255)
		action.Parent = card
		corner(action, 10)

		action.MouseButton1Click:Connect(function()
			if playerState.activeSkin ~= "Default" then
				Remotes.RequestSetSkin:FireServer("Default")
			end
		end)

		refreshers.DefaultLook = function()
			local active = playerState.activeSkin == "Default" or playerState.activeSkin == nil
			action.Text = active and "Wearing \226\156\133" or "Wear"
			action.BackgroundColor3 = active and (theme.Success or Color3.fromRGB(90, 190, 120))
				or (theme.Accent or Color3.fromRGB(120, 90, 235))
			action.AutoButtonColor = not active
			action.Active = not active
		end
		refreshers.DefaultLook()
	end

	local function refreshAll()
		for _, fn in pairs(refreshers) do
			fn()
		end
	end

	openBtn.MouseButton1Click:Connect(function()
		refreshAll()
		backdrop.Visible = true
	end)
	close.MouseButton1Click:Connect(function()
		backdrop.Visible = false
	end)

	Remotes.PlayerStateUpdated.OnClientEvent:Connect(function(data)
		if data.passes then
			playerState.passes = data.passes
		end
		if data.starterPackBought ~= nil then
			playerState.starterPackBought = data.starterPackBought
		end
		if data.activeSkin ~= nil then
			playerState.activeSkin = data.activeSkin
		end
		refreshAll()
	end)
end

return StorePanel

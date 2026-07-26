local ProximityPromptService = game:GetService("ProximityPromptService")
local Workspace = game:GetService("Workspace")
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local GameData = require(game.ReplicatedStorage.Shared.GameData)

local ShopPanel = {}

function ShopPanel.init(player, theme, playerState)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ShopPanelGui"
	screenGui.ResetOnSpawn = false
	screenGui.Enabled = false
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(380, 380)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = theme.Panel
	frame.BorderSizePixel = 0
	frame.Parent = screenGui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Transparency = 0.35
	stroke.Color = theme.Accent
	stroke.Parent = frame
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(theme.PanelLight, theme.Panel)
	gradient.Rotation = 90
	gradient.Parent = frame

	-- A header bar whose colour is themed per shop.
	local headerBar = Instance.new("Frame")
	headerBar.Name = "HeaderBar"
	headerBar.Size = UDim2.new(1, 0, 0, 8)
	headerBar.BackgroundColor3 = theme.Accent
	headerBar.BorderSizePixel = 0
	headerBar.Parent = frame
	local hc = Instance.new("UICorner")
	hc.CornerRadius = UDim.new(0, 8)
	hc.Parent = headerBar

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 20)
	padding.PaddingBottom = UDim.new(0, 14)
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0, 30)
	titleLabel.LayoutOrder = 1
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = theme.Text
	titleLabel.Font = Enum.Font.FredokaOne
	titleLabel.TextSize = 24
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Text = "Shop"
	titleLabel.Parent = frame

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Status"
	statusLabel.Size = UDim2.new(1, 0, 0, 20)
	statusLabel.LayoutOrder = 2
	statusLabel.BackgroundTransparency = 1
	statusLabel.TextColor3 = theme.Success
	statusLabel.Font = Enum.Font.GothamMedium
	statusLabel.TextSize = 13
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.Text = ""
	statusLabel.Parent = frame

	-- Scrollable list of item cards (rebuilt per shop).
	local list = Instance.new("ScrollingFrame")
	list.Name = "Items"
	list.Size = UDim2.new(1, 0, 1, -96)
	list.LayoutOrder = 3
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = frame
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 8)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = list

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "Close"
	closeButton.Text = "Close"
	closeButton.Size = UDim2.new(1, 0, 0, 30)
	closeButton.LayoutOrder = 4
	closeButton.BackgroundColor3 = theme.Neutral
	closeButton.TextColor3 = theme.Text
	closeButton.Font = Enum.Font.FredokaOne
	closeButton.TextSize = 15
	closeButton.AutoButtonColor = false
	closeButton.BorderSizePixel = 0
	closeButton.Parent = frame
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, 10)
	cc.Parent = closeButton
	closeButton.MouseButton1Click:Connect(function()
		screenGui.Enabled = false
	end)

	local currentShopKey = nil

	local function makeCard(shopKey, item, accent)
		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, -4, 0, 64)
		card.BackgroundColor3 = theme.Neutral
		card.BorderSizePixel = 0
		card.Parent = list
		local ccorner = Instance.new("UICorner")
		ccorner.CornerRadius = UDim.new(0, 10)
		ccorner.Parent = card

		-- A round icon chip on the left showing the item's emoji graphic.
		local iconHolder = Instance.new("Frame")
		iconHolder.Size = UDim2.fromOffset(46, 46)
		iconHolder.Position = UDim2.fromOffset(9, 9)
		iconHolder.BackgroundColor3 = accent
		iconHolder.BorderSizePixel = 0
		iconHolder.Parent = card
		local ic = Instance.new("UICorner")
		ic.CornerRadius = UDim.new(1, 0)
		ic.Parent = iconHolder
		local icon = Instance.new("TextLabel")
		icon.Size = UDim2.fromScale(0.8, 0.8)
		icon.Position = UDim2.fromScale(0.1, 0.1)
		icon.BackgroundTransparency = 1
		icon.Text = item.icon or "\240\159\155\146"
		icon.TextScaled = true
		icon.Font = Enum.Font.FredokaOne
		icon.Parent = iconHolder

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(0, 130, 0, 24)
		name.Position = UDim2.fromOffset(64, 9)
		name.BackgroundTransparency = 1
		name.TextColor3 = theme.Text
		name.Font = Enum.Font.FredokaOne
		name.TextSize = 16
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Text = item.name
		name.Parent = card

		local desc = Instance.new("TextLabel")
		desc.Size = UDim2.new(0, 130, 0, 20)
		desc.Position = UDim2.fromOffset(64, 33)
		desc.BackgroundTransparency = 1
		desc.TextColor3 = theme.TextMuted
		desc.Font = Enum.Font.GothamMedium
		desc.TextSize = 12
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.Text = item.desc
		desc.Parent = card

		local buy = Instance.new("TextButton")
		buy.Size = UDim2.new(0, 100, 0, 42)
		buy.Position = UDim2.new(1, -110, 0.5, -21)
		buy.BackgroundColor3 = accent
		buy.TextColor3 = Color3.fromRGB(30, 25, 20)
		buy.Font = Enum.Font.FredokaOne
		buy.TextSize = 15
		buy.AutoButtonColor = true
		buy.BorderSizePixel = 0
		buy.Text = ("$%d"):format(item.cost)
		buy.Parent = card
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0, 8)
		bc.Parent = buy
		buy.MouseButton1Click:Connect(function()
			Remotes.RequestBuyShopItem:FireServer(shopKey, item.id)
		end)
	end

	local function openShop(shopKey)
		local shop = GameData.ShopCatalog[shopKey]
		if not shop then
			return
		end
		currentShopKey = shopKey
		titleLabel.Text = shop.title
		headerBar.BackgroundColor3 = shop.accent
		stroke.Color = shop.accent
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for _, item in ipairs(shop.items) do
			makeCard(shopKey, item, shop.accent)
		end
		screenGui.Enabled = true
	end

	local function refreshStatus()
		local now = Workspace:GetServerTimeNow()
		if GameData.isBoostActive(playerState, now) then
			local remaining = math.max(0, math.floor(playerState.boostUntil - now))
			statusLabel.TextColor3 = theme.Success
			statusLabel.Text = ("\226\154\161 %gx cash boost active \194\183 %ds left"):format(playerState.boostMult or 2, remaining)
		elseif playerState.outfitLabel then
			statusLabel.TextColor3 = theme.Success
			statusLabel.Text = ("\240\159\145\149 Wearing the %s outfit"):format(playerState.outfitLabel)
		else
			statusLabel.Text = ""
		end
	end

	Remotes.PlayerStateUpdated.OnClientEvent:Connect(refreshStatus)

	ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeringPlayer)
		if triggeringPlayer == player and prompt.Name == "ShopPrompt" then
			openShop(prompt:GetAttribute("ShopKey"))
			refreshStatus()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			if screenGui.Enabled then
				refreshStatus()
			end
		end
	end)
end

return ShopPanel

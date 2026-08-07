-- PC Parts Shop: upgrade your computer's 7 parts. Money parts (CPU/RAM/Storage/
-- Cooling) scale cash per game; follower parts (GPU/Monitor/RGB) scale
-- subscribers per release. Opens from the New Project computer's prompt.
local ProximityPromptService = game:GetService("ProximityPromptService")
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local GameData = require(game.ReplicatedStorage.Shared.GameData)
local Sound = require(script.Parent.Sound)
local Fx = require(script.Parent.Fx)

local PCPanel = {}

local function withCommas(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

function PCPanel.init(player, theme, playerState)
	-- Local snapshot kept fresh from PlayerStateUpdated (don't rely on the
	-- shared playerState carrying pcParts).
	local myParts = (playerState and playerState.pcParts) or {}
	local myCash = (playerState and playerState.cash) or 0
	-- The shopkeeper's current per-visit deal (set by the PCStoreOpen remote).
	local dealPartId, dealDiscount = nil, nil

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "PCPanelGui"
	screenGui.ResetOnSpawn = false
	screenGui.Enabled = false
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(400, 452)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = theme.Panel
	frame.BorderSizePixel = 0
	frame.Parent = screenGui
	local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 18); corner.Parent = frame
	local stroke = Instance.new("UIStroke"); stroke.Color = theme.Accent; stroke.Thickness = 2; stroke.Transparency = 0.4; stroke.Parent = frame
	local gradient = Instance.new("UIGradient"); gradient.Color = ColorSequence.new(theme.PanelLight, theme.Panel); gradient.Rotation = 90; gradient.Parent = frame
	local headerBar = Instance.new("Frame"); headerBar.Size = UDim2.new(1, 0, 0, 6); headerBar.BackgroundColor3 = theme.Accent; headerBar.BorderSizePixel = 0; headerBar.Parent = frame
	local hbc = Instance.new("UICorner"); hbc.CornerRadius = UDim.new(0, 6); hbc.Parent = headerBar

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 16); padding.PaddingBottom = UDim.new(0, 14)
	padding.PaddingLeft = UDim.new(0, 16); padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = frame

	local title = Instance.new("TextLabel")
	title.Text = "\240\159\155\146 PC Parts Shop"
	title.Size = UDim2.new(1, 0, 0, 30); title.Position = UDim2.fromOffset(0, 0)
	title.BackgroundTransparency = 1; title.TextColor3 = theme.Text; title.Font = Enum.Font.FredokaOne
	title.TextSize = 24; title.TextXAlignment = Enum.TextXAlignment.Left; title.Parent = frame

	local subtitle = Instance.new("TextLabel")
	subtitle.Size = UDim2.new(1, 0, 0, 40); subtitle.Position = UDim2.fromOffset(0, 32)
	subtitle.TextYAlignment = Enum.TextYAlignment.Top
	subtitle.BackgroundTransparency = 1; subtitle.TextColor3 = theme.TextMuted; subtitle.Font = Enum.Font.GothamMedium
	subtitle.TextSize = 14; subtitle.TextXAlignment = Enum.TextXAlignment.Left; subtitle.RichText = true; subtitle.Parent = frame

	-- Scrolling list of part rows.
	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, 0, 1, -122); list.Position = UDim2.fromOffset(0, 76)
	list.BackgroundTransparency = 1; list.BorderSizePixel = 0
	list.ScrollBarThickness = 5; list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y; list.Parent = frame
	local listLayout = Instance.new("UIListLayout"); listLayout.Padding = UDim.new(0, 8); listLayout.SortOrder = Enum.SortOrder.LayoutOrder; listLayout.Parent = list

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Text = ""; statusLabel.Size = UDim2.new(1, 0, 0, 18); statusLabel.Position = UDim2.new(0, 0, 1, -40)
	statusLabel.BackgroundTransparency = 1; statusLabel.TextColor3 = theme.Danger; statusLabel.Font = Enum.Font.GothamMedium
	statusLabel.TextSize = 13; statusLabel.TextXAlignment = Enum.TextXAlignment.Left; statusLabel.Parent = frame

	local closeButton = Instance.new("TextButton")
	closeButton.Text = "Close"; closeButton.Size = UDim2.new(1, 0, 0, 30); closeButton.Position = UDim2.new(0, 0, 1, -30)
	closeButton.BackgroundColor3 = theme.Neutral; closeButton.TextColor3 = theme.Text; closeButton.Font = Enum.Font.FredokaOne
	closeButton.TextSize = 16; closeButton.AutoButtonColor = true; closeButton.BorderSizePixel = 0; closeButton.Parent = frame
	local cbc = Instance.new("UICorner"); cbc.CornerRadius = UDim.new(0, 10); cbc.Parent = closeButton
	closeButton.MouseButton1Click:Connect(function() screenGui.Enabled = false end)

	-- Build one row per part; keep handles for refresh().
	local rows = {}
	for i, part in ipairs(GameData.PCParts) do
		local kindColor = (part.kind == "money") and theme.Success or theme.Gold
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -6, 0, 56); row.BackgroundColor3 = theme.PanelLight
		row.BorderSizePixel = 0; row.LayoutOrder = i; row.Parent = list
		local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 12); rc.Parent = row

		local info = Instance.new("TextLabel")
		info.Size = UDim2.new(1, -108, 1, 0); info.Position = UDim2.fromOffset(12, 0)
		info.BackgroundTransparency = 1; info.TextColor3 = theme.Text; info.Font = Enum.Font.GothamBold
		info.TextSize = 15; info.TextXAlignment = Enum.TextXAlignment.Left; info.TextYAlignment = Enum.TextYAlignment.Center
		info.RichText = true; info.Parent = row

		local buy = Instance.new("TextButton")
		buy.Size = UDim2.fromOffset(92, 40); buy.Position = UDim2.new(1, -100, 0.5, -20)
		buy.BackgroundColor3 = kindColor; buy.TextColor3 = Color3.fromRGB(255, 255, 255)
		buy.Font = Enum.Font.FredokaOne; buy.TextSize = 15; buy.AutoButtonColor = true; buy.BorderSizePixel = 0; buy.Parent = row
		local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 10); bc.Parent = buy
		buy.MouseButton1Click:Connect(function()
			Remotes.RequestUpgradePart:FireServer(part.id)
		end)

		rows[part.id] = { info = info, buy = buy, kindColor = kindColor }
	end

	local function refresh()
		local cashMult = GameData.getPCPartsCashMultiplier(myParts)
		local subsMult = GameData.getPCPartsSubsMultiplier(myParts)
		local line1 = ("<font color=\"#7CE38B\">%.2fx money</font>  \194\183  <font color=\"#FFD166\">%.2fx followers</font>"):format(cashMult, subsMult)
		if dealPartId and dealDiscount then
			local dp = GameData.getPCPart(dealPartId)
			subtitle.Text = ("%s\n<font color=\"#FF8A3D\">\240\159\148\165 Shopkeeper deal: %d%% off %s!</font>"):format(line1, math.floor(dealDiscount * 100 + 0.5), dp and dp.name or "a part")
		else
			subtitle.Text = line1
		end
		for _, part in ipairs(GameData.PCParts) do
			local r = rows[part.id]
			local level = myParts[part.id] or 0
			local maxLevel = GameData.getPCPartMaxLevel(part.id)
			local cur = GameData.getPCPartModel(part.id, level)
			local hex = (part.kind == "money") and "#7CE38B" or "#FFD166"
			if level >= maxLevel then
				r.info.Text = ("%s <b>%s</b>\n<font color=\"%s\" size=\"13\">%s</font> <font color=\"#B9BCC7\" size=\"12\">\194\183 MAXED</font>")
					:format(part.icon, part.name, hex, cur and cur.name or "")
				r.buy.Text = "MAX"
				r.buy.BackgroundColor3 = theme.Neutral
				r.buy.AutoButtonColor = false
			else
				local nextModel = GameData.getPCPartModel(part.id, level + 1)
				local gain = math.floor(((nextModel and nextModel.bonus or 0) - (cur and cur.bonus or 0)) * 100 + 0.5)
				r.info.Text = ("%s <b>%s</b>\n<font color=\"#B9BCC7\" size=\"12\">%s \226\134\146 </font><font color=\"%s\" size=\"12\">%s (+%d%%)</font>")
					:format(part.icon, part.name, cur and cur.name or "-", hex, nextModel and nextModel.name or "?", gain)
				local cost = GameData.getPCPartUpgradeCost(part.id, level) or 0
				r.buy.AutoButtonColor = true
				if part.id == dealPartId and dealDiscount then
					-- On sale: strike the old price, show the discounted one, orange button.
					local dealCost = math.floor(cost * (1 - dealDiscount))
					r.buy.RichText = true
					r.buy.Text = ("<s><font size=\"11\">$%s</font></s>\n$%s"):format(withCommas(cost), withCommas(dealCost))
					r.buy.BackgroundColor3 = (myCash >= dealCost) and Color3.fromRGB(255, 138, 61) or theme.Neutral
				else
					r.buy.RichText = false
					r.buy.Text = "$" .. withCommas(cost)
					r.buy.BackgroundColor3 = (myCash >= cost) and r.kindColor or theme.Neutral
				end
			end
		end
	end

	refresh()

	Remotes.PlayerStateUpdated.OnClientEvent:Connect(function(data)
		if data then
			myParts = data.pcParts or myParts
			myCash = data.cash or myCash
		end
		statusLabel.Text = ""
		refresh()
	end)

	Remotes.PCActionResult.OnClientEvent:Connect(function(success)
		if success then
			Sound.play("Purchase")
			Fx.rewardBurst("\240\159\150\165\239\184\143 PART UPGRADED!", theme.Accent)
		else
			statusLabel.Text = "Not enough cash!"
			Sound.play("Error")
		end
	end)

	-- Walking up to the PC Store shopkeeper asks the server for a fresh per-visit
	-- deal; the server replies with PCStoreOpen, which actually opens the shop.
	ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeringPlayer)
		if triggeringPlayer == player and prompt.Name == "PCStorePrompt" then
			Remotes.RequestPCStore:FireServer()
		end
	end)

	Remotes.PCStoreOpen.OnClientEvent:Connect(function(partId, discount)
		dealPartId = partId
		dealDiscount = discount
		screenGui.Enabled = true
		statusLabel.Text = ""
		refresh()
		Fx.popIn(frame)
	end)
end

return PCPanel

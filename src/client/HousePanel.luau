local ProximityPromptService = game:GetService("ProximityPromptService")
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local GameData = require(game.ReplicatedStorage.Shared.GameData)
local Sound = require(script.Parent.Sound)
local Fx = require(script.Parent.Fx)

local HousePanel = {}

function HousePanel.init(player, theme, playerState)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "HousePanelGui"
	screenGui.ResetOnSpawn = false
	screenGui.Enabled = false
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(340, 220)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = theme.Panel
	frame.BorderSizePixel = 0
	frame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = theme.Accent
	stroke.Thickness = 2
	stroke.Transparency = 0.4
	stroke.Parent = frame

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(theme.PanelLight, theme.Panel)
	gradient.Rotation = 90
	gradient.Parent = frame

	local headerBar = Instance.new("Frame")
	headerBar.Name = "HeaderBar"
	headerBar.Size = UDim2.new(1, 0, 0, 6)
	headerBar.Position = UDim2.fromScale(0, 0)
	headerBar.BackgroundColor3 = theme.Accent
	headerBar.BorderSizePixel = 0
	headerBar.Parent = frame
	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 6)
	headerCorner.Parent = headerBar

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 16)
	padding.PaddingBottom = UDim.new(0, 16)
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Text = "\240\159\143\162 Add a Floor"
	titleLabel.Size = UDim2.new(1, 0, 0, 30)
	titleLabel.LayoutOrder = 1
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = theme.Text
	titleLabel.Font = Enum.Font.FredokaOne
	titleLabel.TextSize = 24
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = frame

	local tierLabel = Instance.new("TextLabel")
	tierLabel.Text = ""
	tierLabel.Size = UDim2.new(1, 0, 0, 24)
	tierLabel.LayoutOrder = 2
	tierLabel.BackgroundTransparency = 1
	tierLabel.TextColor3 = theme.TextMuted
	tierLabel.Font = Enum.Font.GothamMedium
	tierLabel.TextSize = 15
	tierLabel.TextXAlignment = Enum.TextXAlignment.Left
	tierLabel.Parent = frame

	local actionButton = Instance.new("TextButton")
	actionButton.Size = UDim2.new(1, 0, 0, 44)
	actionButton.LayoutOrder = 3
	actionButton.BackgroundColor3 = theme.Accent
	actionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	actionButton.Font = Enum.Font.FredokaOne
	actionButton.TextSize = 16
	actionButton.TextWrapped = true
	actionButton.AutoButtonColor = false
	actionButton.BorderSizePixel = 0
	actionButton.Parent = frame

	local actionCorner = Instance.new("UICorner")
	actionCorner.CornerRadius = UDim.new(0, 10)
	actionCorner.Parent = actionButton

	local actionGradient = Instance.new("UIGradient")
	actionGradient.Color = ColorSequence.new(theme.Accent, theme.AccentDeep)
	actionGradient.Rotation = 90
	actionGradient.Parent = actionButton

	actionButton.MouseEnter:Connect(function()
		actionButton.BackgroundColor3 = theme.AccentDeep
	end)
	actionButton.MouseLeave:Connect(function()
		actionButton.BackgroundColor3 = theme.Accent
	end)

	actionButton.MouseButton1Click:Connect(function()
		Remotes.RequestUpgradeHouse:FireServer()
	end)

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Text = ""
	statusLabel.Size = UDim2.new(1, 0, 0, 20)
	statusLabel.LayoutOrder = 4
	statusLabel.BackgroundTransparency = 1
	statusLabel.TextColor3 = theme.Danger
	statusLabel.Font = Enum.Font.GothamMedium
	statusLabel.TextSize = 13
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.Parent = frame

	local closeButton = Instance.new("TextButton")
	closeButton.Text = "Close"
	closeButton.Size = UDim2.new(1, 0, 0, 32)
	closeButton.LayoutOrder = 5
	closeButton.BackgroundColor3 = theme.Neutral
	closeButton.TextColor3 = theme.Text
	closeButton.Font = Enum.Font.FredokaOne
	closeButton.TextSize = 16
	closeButton.AutoButtonColor = false
	closeButton.BorderSizePixel = 0
	closeButton.Parent = frame

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 10)
	closeCorner.Parent = closeButton

	closeButton.MouseButton1Click:Connect(function()
		screenGui.Enabled = false
	end)

	local function refresh()
		local tier = playerState.houseTier
		local nextMultiplier = GameData.getFloorMultiplier(tier + 1)
		tierLabel.Text = ("Floor %d of %d \194\183 costs & earnings x%d"):format(tier + 1, GameData.HouseTierCount, GameData.getFloorMultiplier(tier))

		if tier >= GameData.HouseTierCount - 1 then
			actionButton.Text = "Top floor reached!"
			actionButton.Visible = false
		else
			actionButton.Visible = true
			local cost = GameData.getHouseUpgradeCost(tier)
			actionButton.Text = ("Add Floor %d \194\183 $%d\n(then x%d cost & cash)"):format(tier + 2, cost, nextMultiplier)
		end
	end

	refresh()

	Remotes.PlayerStateUpdated.OnClientEvent:Connect(function()
		statusLabel.Text = ""
		refresh()
	end)

	Remotes.HouseActionResult.OnClientEvent:Connect(function(success)
		if success then
			Sound.play("Purchase")
			Fx.rewardBurst("\240\159\143\160 ROOM UPGRADED!", theme.Accent)
		else
			statusLabel.Text = "Not enough cash!"
			Sound.play("Error")
		end
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeringPlayer)
		if triggeringPlayer == player and prompt.Name == "HouseUpgradePrompt" then
			screenGui.Enabled = true
			statusLabel.Text = ""
			refresh()
			Fx.popIn(frame)
		end
	end)
end

return HousePanel

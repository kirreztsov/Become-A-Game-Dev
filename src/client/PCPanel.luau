local ProximityPromptService = game:GetService("ProximityPromptService")
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local GameData = require(game.ReplicatedStorage.Shared.GameData)

local PCPanel = {}

function PCPanel.init(player, theme, playerState)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "PCPanelGui"
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
	titleLabel.Text = "\240\159\146\187 PC Upgrade"
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
	actionButton.TextColor3 = theme.Text
	actionButton.Font = Enum.Font.FredokaOne
	actionButton.TextSize = 16
	actionButton.TextWrapped = true
	actionButton.AutoButtonColor = false
	actionButton.BorderSizePixel = 0
	actionButton.Parent = frame

	local actionCorner = Instance.new("UICorner")
	actionCorner.CornerRadius = UDim.new(0, 10)
	actionCorner.Parent = actionButton

	actionButton.MouseButton1Click:Connect(function()
		Remotes.RequestUpgradePC:FireServer()
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
		local tier = playerState.pcTier
		local multiplier = GameData.getPCCashMultiplier(tier)
		tierLabel.Text = ("Tier %d of %d \194\183 %.2fx cash"):format(tier, GameData.PCTierCount - 1, multiplier)

		if tier >= GameData.PCTierCount - 1 then
			actionButton.Text = "Max tier reached!"
			actionButton.Visible = false
		else
			actionButton.Visible = true
			local cost = GameData.getPCUpgradeCost(tier)
			actionButton.Text = ("Upgrade PC \194\183 $%d"):format(cost)
		end
	end

	refresh()

	Remotes.PlayerStateUpdated.OnClientEvent:Connect(function()
		statusLabel.Text = ""
		refresh()
	end)

	Remotes.PCActionResult.OnClientEvent:Connect(function(success)
		if not success then
			statusLabel.Text = "Not enough cash!"
		end
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeringPlayer)
		if triggeringPlayer == player and prompt.Name == "PCUpgradePrompt" then
			screenGui.Enabled = true
			statusLabel.Text = ""
			refresh()
		end
	end)
end

return PCPanel

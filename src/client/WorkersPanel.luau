local ProximityPromptService = game:GetService("ProximityPromptService")
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local GameData = require(game.ReplicatedStorage.Shared.GameData)
local Sound = require(script.Parent.Sound)

local WorkersPanel = {}

local ROLE_DISPLAY_NAMES = {
	Coding = "\226\154\161 Coding",
	MapBuilding = "\240\159\151\186\239\184\143 Map Building",
	Testing = "\226\156\168 Testing",
}

function WorkersPanel.init(player, theme, playerState)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "WorkersPanelGui"
	screenGui.ResetOnSpawn = false
	screenGui.Enabled = false
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(360, 320)
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
	headerBar.BackgroundColor3 = theme.Accent
	headerBar.BorderSizePixel = 0
	headerBar.ZIndex = 2
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
	titleLabel.Text = "\240\159\145\183 Workers"
	titleLabel.Size = UDim2.new(1, 0, 0, 30)
	titleLabel.LayoutOrder = 1
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = theme.Text
	titleLabel.Font = Enum.Font.FredokaOne
	titleLabel.TextSize = 24
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = frame

	local roleRows = {}
	local rarityBadges = {}

	for i, role in ipairs(GameData.Phases) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 60)
		row.LayoutOrder = i + 1
		row.BackgroundColor3 = theme.Neutral
		row.BorderSizePixel = 0
		row.Parent = frame

		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 10)
		rowCorner.Parent = row

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Text = ROLE_DISPLAY_NAMES[role]
		nameLabel.Size = UDim2.new(0.5, 0, 0, 26)
		nameLabel.Position = UDim2.fromOffset(10, 7)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextColor3 = theme.Text
		nameLabel.Font = Enum.Font.FredokaOne
		nameLabel.TextSize = 16
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = row

		-- Colored rarity badge under the name (from the worker's rolled rarity).
		local badge = Instance.new("Frame")
		badge.Size = UDim2.fromOffset(104, 20)
		badge.Position = UDim2.fromOffset(10, 33)
		badge.BackgroundColor3 = theme.Neutral
		badge.BorderSizePixel = 0
		badge.Parent = row
		local badgeCorner = Instance.new("UICorner")
		badgeCorner.CornerRadius = UDim.new(0, 6)
		badgeCorner.Parent = badge
		local badgeLabel = Instance.new("TextLabel")
		badgeLabel.Size = UDim2.fromScale(1, 1)
		badgeLabel.BackgroundTransparency = 1
		badgeLabel.Text = "—"
		badgeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		badgeLabel.Font = Enum.Font.FredokaOne
		badgeLabel.TextSize = 13
		badgeLabel.Parent = badge
		rarityBadges[role] = { frame = badge, label = badgeLabel }

		local actionButton = Instance.new("TextButton")
		actionButton.Size = UDim2.new(0.42, 0, 0, 40)
		actionButton.Position = UDim2.new(0.56, 0, 0.5, -20)
		actionButton.BackgroundColor3 = theme.Accent
		actionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		actionButton.Font = Enum.Font.FredokaOne
		actionButton.TextSize = 14
		actionButton.TextWrapped = true
		actionButton.AutoButtonColor = false
		actionButton.BorderSizePixel = 0
		actionButton.Parent = row

		local actionCorner = Instance.new("UICorner")
		actionCorner.CornerRadius = UDim.new(0, 8)
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
			local worker = playerState.workers[role]
			if worker.hired then
				Remotes.RequestUpgradeWorker:FireServer(role)
			else
				Remotes.RequestHireWorker:FireServer(role)
			end
		end)

		roleRows[role] = actionButton
	end

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Text = ""
	statusLabel.Size = UDim2.new(1, 0, 0, 20)
	statusLabel.LayoutOrder = 9
	statusLabel.BackgroundTransparency = 1
	statusLabel.TextColor3 = theme.Danger
	statusLabel.Font = Enum.Font.GothamMedium
	statusLabel.TextSize = 13
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.Parent = frame

	local closeButton = Instance.new("TextButton")
	closeButton.Text = "Close"
	closeButton.Size = UDim2.new(1, 0, 0, 32)
	closeButton.LayoutOrder = 10
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
		for role, actionButton in pairs(roleRows) do
			local worker = playerState.workers[role]
			if worker.hired then
				actionButton.Text = ("Upgrade\nLv%d \194\183 $%d"):format(worker.level, GameData.getWorkerUpgradeCost(worker.level, playerState.houseTier))
			else
				actionButton.Text = ("Hire\n$%d"):format(GameData.getWorkerHireCost(playerState.houseTier))
			end
			-- rarity badge
			local badge = rarityBadges[role]
			if badge then
				if worker.hired and worker.rarity then
					local info = GameData.getRarityInfo(worker.rarity)
					badge.frame.BackgroundColor3 = info.color
					badge.label.Text = worker.rarity
					badge.label.TextColor3 = Color3.fromRGB(30, 25, 35)
				elseif worker.hired then
					badge.frame.BackgroundColor3 = theme.Neutral
					badge.label.Text = "No rarity"
					badge.label.TextColor3 = theme.TextMuted
				else
					badge.frame.BackgroundColor3 = theme.Neutral
					badge.label.Text = "\226\128\148" -- em dash
					badge.label.TextColor3 = theme.TextMuted
				end
			end
		end
	end

	refresh()

	Remotes.PlayerStateUpdated.OnClientEvent:Connect(function()
		statusLabel.Text = ""
		refresh()
	end)

	Remotes.WorkerActionResult.OnClientEvent:Connect(function(role, action, success)
		if success then
			Sound.play("Hire")
		else
			statusLabel.Text = ("Not enough cash to %s the %s worker!"):format(action, role)
			Sound.play("Error")
		end
	end)

	-- Opened by the Worker Hub's "Upgrade Workers" app (no longer auto-opens on
	-- the WorkersPrompt -- the hub owns that prompt now).
	function WorkersPanel.open()
		screenGui.Enabled = true
		statusLabel.Text = ""
		refresh()
	end
end

return WorkersPanel

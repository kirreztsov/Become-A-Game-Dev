local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ProximityPromptService = game:GetService("ProximityPromptService")
local GameData = require(game.ReplicatedStorage.Shared.GameData)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local DecorBuilder = require(game.ReplicatedStorage.Shared.DecorBuilder)

local DecorPanel = {}

local GREEN = Color3.fromRGB(120, 235, 140)

local function corner(inst, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
	return c
end

function DecorPanel.init(player, theme, playerState)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DecorPanelGui"
	screenGui.ResetOnSpawn = false
	screenGui.Enabled = false
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(380, 400)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = theme.Panel
	frame.BorderSizePixel = 0
	frame.Parent = screenGui
	corner(frame, 18)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.5
	stroke.Transparency = 0
	stroke.Color = theme.Line or theme.Accent
	stroke.Parent = frame
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(theme.PanelLight, theme.Panel)
	gradient.Rotation = 90
	gradient.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 18)
	padding.PaddingBottom = UDim.new(0, 14)
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 28)
	title.LayoutOrder = 1
	title.BackgroundTransparency = 1
	title.TextColor3 = theme.Text
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 22
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "\240\159\143\160 Studio Decor"
	title.Parent = frame

	local hint = Instance.new("TextLabel")
	hint.Size = UDim2.new(1, 0, 0, 18)
	hint.LayoutOrder = 2
	hint.BackgroundTransparency = 1
	hint.TextColor3 = theme.TextMuted
	hint.Font = Enum.Font.GothamMedium
	hint.TextSize = 12
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Text = "Pick an item, then move your mouse and click to place it."
	hint.Parent = frame

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

	local buttonRow = Instance.new("Frame")
	buttonRow.Size = UDim2.new(1, 0, 0, 32)
	buttonRow.LayoutOrder = 4
	buttonRow.BackgroundTransparency = 1
	buttonRow.Parent = frame
	local clearBtn = Instance.new("TextButton")
	clearBtn.Size = UDim2.new(0.5, -4, 1, 0)
	clearBtn.Position = UDim2.fromScale(0, 0)
	clearBtn.BackgroundColor3 = Color3.fromRGB(150, 70, 70)
	clearBtn.TextColor3 = Color3.fromRGB(255, 240, 235)
	clearBtn.Font = Enum.Font.FredokaOne
	clearBtn.TextSize = 14
	clearBtn.BorderSizePixel = 0
	clearBtn.Text = "Clear all"
	clearBtn.Parent = buttonRow
	corner(clearBtn, 10)
	clearBtn.MouseButton1Click:Connect(function()
		Remotes.RequestClearDecor:FireServer()
	end)
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0.5, -4, 1, 0)
	closeBtn.Position = UDim2.fromScale(0.5, 0)
	closeBtn.AnchorPoint = Vector2.new(0, 0)
	closeBtn.Position = UDim2.new(0.5, 4, 0, 0)
	closeBtn.BackgroundColor3 = theme.Neutral
	closeBtn.TextColor3 = theme.Text
	closeBtn.Font = Enum.Font.FredokaOne
	closeBtn.TextSize = 14
	closeBtn.BorderSizePixel = 0
	closeBtn.Text = "Close"
	closeBtn.Parent = buttonRow
	corner(closeBtn, 10)
	closeBtn.MouseButton1Click:Connect(function()
		screenGui.Enabled = false
	end)

	-- ---- placement mode ----------------------------------------------------
	local placing = nil -- { item, ghost, yaw, x, y, z, valid }
	local renderConn, inputConn

	local overlay = Instance.new("ScreenGui")
	overlay.Name = "DecorPlacingOverlay"
	overlay.ResetOnSpawn = false
	overlay.Enabled = false
	overlay.Parent = player.PlayerGui
	local banner = Instance.new("TextLabel")
	banner.Size = UDim2.fromOffset(460, 40)
	banner.Position = UDim2.new(0.5, 0, 1, -70)
	banner.AnchorPoint = Vector2.new(0.5, 1)
	banner.BackgroundColor3 = Color3.fromRGB(30, 33, 48)
	banner.BackgroundTransparency = 0.1
	banner.TextColor3 = Color3.fromRGB(255, 255, 255)
	banner.Font = Enum.Font.FredokaOne
	banner.TextSize = 16
	banner.Text = "Click to place  \194\183  R to rotate  \194\183  Right-click to cancel"
	banner.Parent = overlay
	corner(banner, 12)

	local function endPlacement(reopen)
		if renderConn then
			renderConn:Disconnect()
			renderConn = nil
		end
		if inputConn then
			inputConn:Disconnect()
			inputConn = nil
		end
		if placing and placing.ghost then
			placing.ghost:Destroy()
		end
		placing = nil
		overlay.Enabled = false
		if reopen then
			screenGui.Enabled = true
		end
	end

	local function studioBounds()
		local index = player:GetAttribute("PlotIndex")
		if not index then
			return nil
		end
		return GameData.getStudioBase(index)
	end

	local function updateGhost()
		if not placing then
			return
		end
		local camera = Workspace.CurrentCamera
		local m = UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(m.X, m.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { placing.ghost, player.Character }
		local result = Workspace:Raycast(ray.Origin, ray.Direction * 600, params)
		if not result then
			return
		end
		local base = studioBounds()
		if not base then
			return
		end
		local cfg = GameData.PlotConfig
		local item = placing.item
		local margin = cfg.wallMargin + math.max(item.footprint.X, item.footprint.Y) / 2
		local x, z = GameData.snapToStudioGrid(base, result.Position.X, result.Position.Z)
		x = math.clamp(x, base.X - (cfg.buildingHalfW - margin), base.X + (cfg.buildingHalfW - margin))
		z = math.clamp(z, base.Z - (cfg.buildingHalfD - margin), base.Z + (cfg.buildingHalfD - margin))
		local f = math.clamp(math.floor((result.Position.Y - cfg.floorTop) / cfg.floorHeight + 0.5), 0, cfg.maxFloors - 1)
		local y = cfg.floorTop + f * cfg.floorHeight
		placing.x, placing.y, placing.z = x, y, z
		placing.ghost:PivotTo(CFrame.new(x, y, z) * CFrame.Angles(0, placing.yaw, 0))
	end

	local function beginPlacement(item)
		endPlacement(false)
		screenGui.Enabled = false
		local ghost = DecorBuilder.build(item, { ghost = true, tint = GREEN })
		ghost.Parent = Workspace
		placing = { item = item, ghost = ghost, yaw = 0, x = 0, y = GameData.PlotConfig.floorTop, z = 0 }
		overlay.Enabled = true
		renderConn = RunService.RenderStepped:Connect(updateGhost)
		inputConn = UserInputService.InputBegan:Connect(function(input, gpe)
			if gpe or not placing then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				Remotes.RequestPlaceDecor:FireServer(placing.item.id, placing.x, placing.y, placing.z, placing.yaw)
				endPlacement(true)
			elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.Escape then
				endPlacement(true)
			elseif input.KeyCode == Enum.KeyCode.R then
				placing.yaw = (placing.yaw + math.pi / 2) % (math.pi * 2)
			end
		end)
	end

	local function makeCard(item)
		local card = Instance.new("Frame")
		card.Size = UDim2.new(1, -4, 0, 64)
		card.BackgroundColor3 = theme.Neutral
		card.BorderSizePixel = 0
		card.Parent = list
		corner(card, 10)

		local iconHolder = Instance.new("Frame")
		iconHolder.Size = UDim2.fromOffset(46, 46)
		iconHolder.Position = UDim2.fromOffset(9, 9)
		iconHolder.BackgroundColor3 = item.color
		iconHolder.BorderSizePixel = 0
		iconHolder.Parent = card
		corner(iconHolder, 23)
		local icon = Instance.new("TextLabel")
		icon.Size = UDim2.fromScale(0.8, 0.8)
		icon.Position = UDim2.fromScale(0.1, 0.1)
		icon.BackgroundTransparency = 1
		icon.Text = item.icon
		icon.TextScaled = true
		icon.Font = Enum.Font.FredokaOne
		icon.Parent = iconHolder

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(0, 150, 0, 24)
		name.Position = UDim2.fromOffset(64, 9)
		name.BackgroundTransparency = 1
		name.TextColor3 = theme.Text
		name.Font = Enum.Font.FredokaOne
		name.TextSize = 16
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Text = item.name
		name.Parent = card

		local costLabel = Instance.new("TextLabel")
		costLabel.Size = UDim2.new(0, 150, 0, 18)
		costLabel.Position = UDim2.fromOffset(64, 34)
		costLabel.BackgroundTransparency = 1
		costLabel.TextColor3 = theme.TextMuted
		costLabel.Font = Enum.Font.GothamMedium
		costLabel.TextSize = 13
		costLabel.TextXAlignment = Enum.TextXAlignment.Left
		costLabel.Text = ("$%d"):format(item.cost)
		costLabel.Parent = card

		local place = Instance.new("TextButton")
		place.Size = UDim2.new(0, 96, 0, 42)
		place.Position = UDim2.new(1, -106, 0.5, -21)
		place.BackgroundColor3 = theme.Accent
		place.TextColor3 = Color3.fromRGB(255, 255, 255)
		place.Font = Enum.Font.FredokaOne
		place.TextSize = 15
		place.BorderSizePixel = 0
		place.Text = "Place"
		place.Parent = card
		corner(place, 8)
		place.MouseButton1Click:Connect(function()
			beginPlacement(item)
		end)
	end

	for _, item in ipairs(GameData.DecorCatalog) do
		makeCard(item)
	end

	ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeringPlayer)
		if triggeringPlayer == player and prompt.Name == "DecorPrompt" then
			endPlacement(false)
			screenGui.Enabled = true
		end
	end)
end

return DecorPanel

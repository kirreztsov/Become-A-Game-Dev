local GameData = require(game.ReplicatedStorage.Shared.GameData)

local PlotManager = {}

local FLOOR_TOP = 1
local PLOT_SIZE_X = 70
local PLOT_SIZE_Z = 90

local PLOT_ORIGINS = {
	Vector3.new(0, 0, 0),
	Vector3.new(160, 0, 0),
	Vector3.new(0, 0, 160),
	Vector3.new(160, 0, 160),
}

local PANEL_COLOR = Color3.fromRGB(36, 27, 54)
local ACCENT_COLOR = Color3.fromRGB(140, 92, 255)
local GOLD_COLOR = Color3.fromRGB(255, 209, 102)
local DARK_TRIM_COLOR = Color3.fromRGB(30, 22, 44)
local DESK_COLOR = Color3.fromRGB(58, 45, 78)
local CHAIR_COLOR = Color3.fromRGB(46, 36, 66)

local claimedBy = {}
local plotOfPlayer = {}

local function makePart(name, size, position, color, material, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = true
	part.Parent = parent
	return part
end

local function buildPlotFloor(plotFolder, origin)
	makePart("PlotFloor", Vector3.new(PLOT_SIZE_X, 1, PLOT_SIZE_Z), origin + Vector3.new(0, 0.5, 15), PANEL_COLOR, nil, plotFolder)
end

local function buildPlotSpawn(plotFolder, origin)
	local spawnPoint = Instance.new("Part")
	spawnPoint.Name = "PlotSpawnPoint"
	spawnPoint.Size = Vector3.new(1, 1, 1)
	spawnPoint.Position = origin + Vector3.new(0, FLOOR_TOP + 3, 0)
	spawnPoint.Anchored = true
	spawnPoint.CanCollide = false
	spawnPoint.Transparency = 1
	spawnPoint.Parent = plotFolder
end

local function buildWorkersDesk(plotFolder, origin)
	local deskTopSurfaceY = FLOOR_TOP + 2
	local legHeight = 2
	local legCenterY = FLOOR_TOP + legHeight / 2
	local deskCenterY = deskTopSurfaceY + 0.25
	local x, z = -12, 12

	makePart("WorkersDeskTop", Vector3.new(6, 0.5, 3), origin + Vector3.new(x, deskCenterY, z), DESK_COLOR, nil, plotFolder)
	makePart("WorkersDeskLegA", Vector3.new(0.4, legHeight, 0.4), origin + Vector3.new(x - 2.6, legCenterY, z + 1), DARK_TRIM_COLOR, nil, plotFolder)
	makePart("WorkersDeskLegB", Vector3.new(0.4, legHeight, 0.4), origin + Vector3.new(x + 2.6, legCenterY, z + 1), DARK_TRIM_COLOR, nil, plotFolder)
	makePart("WorkersDeskLegC", Vector3.new(0.4, legHeight, 0.4), origin + Vector3.new(x - 2.6, legCenterY, z - 1), DARK_TRIM_COLOR, nil, plotFolder)
	makePart("WorkersDeskLegD", Vector3.new(0.4, legHeight, 0.4), origin + Vector3.new(x + 2.6, legCenterY, z - 1), DARK_TRIM_COLOR, nil, plotFolder)

	local deskTopSurfaceTopY = deskTopSurfaceY + 0.5
	local monitorHeight = 1.6
	local monitorCenterY = deskTopSurfaceTopY + monitorHeight / 2
	makePart("WorkersMonitor", Vector3.new(2.2, monitorHeight, 0.2), origin + Vector3.new(x, monitorCenterY, z + 0.8), DARK_TRIM_COLOR, nil, plotFolder)
	local screen = makePart("WorkersMonitorScreen", Vector3.new(2, monitorHeight - 0.2, 0.05), origin + Vector3.new(x, monitorCenterY, z + 0.7), GOLD_COLOR, Enum.Material.Neon, plotFolder)
	screen.CanCollide = false

	local workersPrompt = Instance.new("ProximityPrompt")
	workersPrompt.Name = "WorkersPrompt"
	workersPrompt.ActionText = "Manage Workers"
	workersPrompt.ObjectText = "Computer"
	workersPrompt.HoldDuration = 0.5
	workersPrompt.MaxActivationDistance = 10
	workersPrompt.Parent = screen

	local chairHeight = 2.4
	makePart("WorkersChair", Vector3.new(2, chairHeight, 2), origin + Vector3.new(x, FLOOR_TOP + chairHeight / 2, 9), CHAIR_COLOR, nil, plotFolder)
end

local STATION_CONFIGS = {
	{ name = "NewProject", label = "\240\159\134\149 NEW PROJECT", deskX = 12, deskZ = 12, monitorColor = GOLD_COLOR },
	{ name = "Coding", label = "\226\154\161 CODING", deskX = -25, deskZ = -15, monitorColor = ACCENT_COLOR },
	{ name = "MapBuilding", label = "\240\159\151\186\239\184\143 MAP BUILDING", deskX = 0, deskZ = -20, monitorColor = ACCENT_COLOR },
	{ name = "Testing", label = "\226\156\168 TESTING", deskX = 25, deskZ = -15, monitorColor = ACCENT_COLOR },
}

-- The NewProject station's monitor doubles as the player's "PC" -- its size
-- and screen color scale with pcTier, and it carries the PCUpgradePrompt.
-- Rebuildable independently of the rest of the station (desk/seat/label
-- never change), the same way buildHouse rebuilds just the house folder.
local function buildStationMonitorRig(plotFolder, origin, config, tier)
	local existingRig = plotFolder:FindFirstChild(config.name .. "MonitorRig")
	if existingRig then
		existingRig:Destroy()
	end

	local rig = Instance.new("Folder")
	rig.Name = config.name .. "MonitorRig"
	rig.Parent = plotFolder

	local x, z = config.deskX, config.deskZ
	local deskTopSurfaceTopY = FLOOR_TOP + 2 + 0.5

	local monitorHeight = 1.6 + (tier * 0.3)
	local monitorWidth = 2.2 + (tier * 0.4)
	local monitorCenterY = deskTopSurfaceTopY + monitorHeight / 2

	makePart(config.name .. "Monitor", Vector3.new(monitorWidth, monitorHeight, 0.2), origin + Vector3.new(x, monitorCenterY, z + 0.8), DARK_TRIM_COLOR, nil, rig)
	local screenColor = (tier > 0) and GOLD_COLOR or config.monitorColor
	local screen = makePart(config.name .. "MonitorScreen", Vector3.new(monitorWidth - 0.2, monitorHeight - 0.2, 0.05), origin + Vector3.new(x, monitorCenterY, z + 0.7), screenColor, Enum.Material.Neon, rig)
	screen.CanCollide = false

	if config.name == "NewProject" and tier < GameData.PCTierCount - 1 then
		local upgradePrompt = Instance.new("ProximityPrompt")
		upgradePrompt.Name = "PCUpgradePrompt"
		upgradePrompt.ActionText = "Upgrade PC"
		upgradePrompt.ObjectText = "Computer"
		upgradePrompt.HoldDuration = 0.5
		upgradePrompt.MaxActivationDistance = 10
		upgradePrompt.Parent = screen
	end
end

local function buildStation(plotFolder, origin, config)
	local deskTopSurfaceY = FLOOR_TOP + 2
	local legHeight = 2
	local legCenterY = FLOOR_TOP + legHeight / 2
	local deskCenterY = deskTopSurfaceY + 0.25
	local x, z = config.deskX, config.deskZ

	makePart(config.name .. "DeskTop", Vector3.new(6, 0.5, 3), origin + Vector3.new(x, deskCenterY, z), DESK_COLOR, nil, plotFolder)
	makePart(config.name .. "DeskLegA", Vector3.new(0.4, legHeight, 0.4), origin + Vector3.new(x - 2.6, legCenterY, z + 1), DARK_TRIM_COLOR, nil, plotFolder)
	makePart(config.name .. "DeskLegB", Vector3.new(0.4, legHeight, 0.4), origin + Vector3.new(x + 2.6, legCenterY, z + 1), DARK_TRIM_COLOR, nil, plotFolder)
	makePart(config.name .. "DeskLegC", Vector3.new(0.4, legHeight, 0.4), origin + Vector3.new(x - 2.6, legCenterY, z - 1), DARK_TRIM_COLOR, nil, plotFolder)
	makePart(config.name .. "DeskLegD", Vector3.new(0.4, legHeight, 0.4), origin + Vector3.new(x + 2.6, legCenterY, z - 1), DARK_TRIM_COLOR, nil, plotFolder)

	local deskTopSurfaceTopY = deskTopSurfaceY + 0.5
	local monitorHeight = 1.6
	local monitorCenterY = deskTopSurfaceTopY + monitorHeight / 2
	buildStationMonitorRig(plotFolder, origin, config, 0)

	local seat = Instance.new("Seat")
	seat.Name = config.name .. "Seat"
	seat.Size = Vector3.new(2, 2.4, 2)
	seat.Anchored = true
	seat.Material = Enum.Material.SmoothPlastic
	seat.Color = CHAIR_COLOR
	-- A seat's default facing is -Z; the monitor sits north (+Z) of this seat,
	-- so rotate 180 degrees to face the player toward it when they sit down.
	seat.CFrame = CFrame.new(origin + Vector3.new(x, FLOOR_TOP + 1.2, z - 3)) * CFrame.Angles(0, math.rad(180), 0)
	seat.Parent = plotFolder

	local labelAnchor = Instance.new("Part")
	labelAnchor.Name = config.name .. "LabelAnchor"
	labelAnchor.Size = Vector3.new(0.1, 0.1, 0.1)
	labelAnchor.Position = origin + Vector3.new(x, monitorCenterY + 1.5, z + 0.7)
	labelAnchor.Transparency = 1
	labelAnchor.Anchored = true
	labelAnchor.CanCollide = false
	labelAnchor.Parent = plotFolder

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(220, 40)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 100
	billboard.Parent = labelAnchor

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = config.label
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.Parent = billboard
end

local function buildStations(plotFolder, origin)
	for _, config in ipairs(STATION_CONFIGS) do
		buildStation(plotFolder, origin, config)
	end
end

local function buildTrendsSign(plotFolder, origin)
	local signCenterY = FLOOR_TOP + 8

	makePart("TrendsSignPostLeft", Vector3.new(0.6, 8, 0.6), origin + Vector3.new(-7, FLOOR_TOP + 4, -28), DARK_TRIM_COLOR, nil, plotFolder)
	makePart("TrendsSignPostRight", Vector3.new(0.6, 8, 0.6), origin + Vector3.new(7, FLOOR_TOP + 4, -28), DARK_TRIM_COLOR, nil, plotFolder)

	-- A long physical board (not a floating BillboardGui) -- the text is
	-- painted onto its surface with a SurfaceGui, so it reads as a real
	-- sign standing in the world instead of 2D UI hovering in space.
	local backing = makePart("TrendsSignBacking", Vector3.new(16, 6, 0.5), origin + Vector3.new(0, signCenterY, -28), ACCENT_COLOR, Enum.Material.SmoothPlastic, plotFolder)
	backing.CanCollide = false

	-- Players approach from the stations area (+Z side of the board, which
	-- is at z = -28), so the visible face is Back (the +Z-facing side).
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "TrendsDisplay"
	surfaceGui.Face = Enum.NormalId.Back
	surfaceGui.CanvasSize = Vector2.new(600, 220)
	surfaceGui.LightInfluence = 0
	surfaceGui.Parent = backing

	local eyebrow = Instance.new("TextLabel")
	eyebrow.Name = "Eyebrow"
	eyebrow.Size = UDim2.new(1, 0, 0, 60)
	eyebrow.Position = UDim2.fromOffset(0, 0)
	eyebrow.BackgroundTransparency = 1
	eyebrow.Text = "\240\159\148\165 TRENDING NOW"
	eyebrow.Font = Enum.Font.GothamBold
	eyebrow.TextScaled = true
	eyebrow.TextColor3 = Color3.fromRGB(255, 158, 66)
	eyebrow.Parent = surfaceGui

	local text = Instance.new("TextLabel")
	text.Name = "TrendsText"
	text.Size = UDim2.new(1, 0, 1, -60)
	text.Position = UDim2.fromOffset(0, 60)
	text.BackgroundTransparency = 1
	text.Text = "Loading..."
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextWrapped = true
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.Parent = surfaceGui
end

-- Fence height per tier (index 1 = tier 1, index 2 = tier 2); tier 0 has no fence.
local PLOT_FENCE_HEIGHT_BY_TIER = { 6, 10 }

-- The "house" upgrade improves the whole plot -- floor finish, a perimeter
-- fence, and corner lamps -- rather than building a separate house
-- structure off to one side. Everyone still works in the same open area;
-- upgrading just makes that whole area look nicer.
local function buildHouse(plotFolder, origin, tier)
	local existing = plotFolder:FindFirstChild("PlotUpgrade")
	if existing then
		existing:Destroy()
	end

	local upgradeFolder = Instance.new("Folder")
	upgradeFolder.Name = "PlotUpgrade"
	upgradeFolder.Parent = plotFolder

	local floor = plotFolder:FindFirstChild("PlotFloor")
	if floor then
		if tier == 0 then
			floor.Color = PANEL_COLOR
			floor.Material = Enum.Material.SmoothPlastic
		elseif tier == 1 then
			floor.Color = DESK_COLOR
			floor.Material = Enum.Material.Marble
		else
			floor.Color = ACCENT_COLOR
			floor.Material = Enum.Material.Marble
		end
	end

	local floorCenterZ = 15
	local halfX = PLOT_SIZE_X / 2
	local halfZ = PLOT_SIZE_Z / 2
	local nearZ = floorCenterZ - halfZ
	local farZ = floorCenterZ + halfZ

	if tier >= 1 then
		local fenceHeight = PLOT_FENCE_HEIGHT_BY_TIER[tier]
		local fenceThickness = 0.6
		local fenceColor = (tier >= 2) and GOLD_COLOR or ACCENT_COLOR
		local fenceCenterY = FLOOR_TOP + fenceHeight / 2

		makePart("PlotFenceNear", Vector3.new(PLOT_SIZE_X, fenceHeight, fenceThickness), origin + Vector3.new(0, fenceCenterY, nearZ), fenceColor, Enum.Material.Neon, upgradeFolder)
		makePart("PlotFenceFar", Vector3.new(PLOT_SIZE_X, fenceHeight, fenceThickness), origin + Vector3.new(0, fenceCenterY, farZ), fenceColor, Enum.Material.Neon, upgradeFolder)
		makePart("PlotFenceLeft", Vector3.new(fenceThickness, fenceHeight, PLOT_SIZE_Z), origin + Vector3.new(-halfX, fenceCenterY, floorCenterZ), fenceColor, Enum.Material.Neon, upgradeFolder)
		makePart("PlotFenceRight", Vector3.new(fenceThickness, fenceHeight, PLOT_SIZE_Z), origin + Vector3.new(halfX, fenceCenterY, floorCenterZ), fenceColor, Enum.Material.Neon, upgradeFolder)

		local lampHeight = 6
		local lampCorners = {
			Vector3.new(-halfX + 3, 0, nearZ + 3),
			Vector3.new(halfX - 3, 0, nearZ + 3),
			Vector3.new(-halfX + 3, 0, farZ - 3),
			Vector3.new(halfX - 3, 0, farZ - 3),
		}
		for i, corner in ipairs(lampCorners) do
			makePart("PlotLampPost" .. i, Vector3.new(0.4, lampHeight, 0.4), origin + Vector3.new(corner.X, FLOOR_TOP + lampHeight / 2, corner.Z), DARK_TRIM_COLOR, nil, upgradeFolder)
			local bulb = makePart("PlotLampBulb" .. i, Vector3.new(1, 1, 1), origin + Vector3.new(corner.X, FLOOR_TOP + lampHeight + 0.3, corner.Z), GOLD_COLOR, Enum.Material.Neon, upgradeFolder)
			bulb.Shape = Enum.PartType.Ball
			bulb.CanCollide = false
		end
	end

	-- Central signpost near spawn -- reachable immediately, not tucked in a corner
	local signPost = makePart("PlotUpgradeSignPost", Vector3.new(0.4, 5, 0.4), origin + Vector3.new(0, FLOOR_TOP + 2.5, 8), DARK_TRIM_COLOR, nil, upgradeFolder)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(220, 40)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 100
	billboard.Parent = signPost

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = "\240\159\143\151\239\184\143 Upgrade your plot!"
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.Parent = billboard

	if tier < GameData.HouseTierCount - 1 then
		local upgradePrompt = Instance.new("ProximityPrompt")
		upgradePrompt.Name = "HouseUpgradePrompt"
		upgradePrompt.ActionText = "Upgrade Plot"
		upgradePrompt.ObjectText = "Plot"
		upgradePrompt.HoldDuration = 0.5
		upgradePrompt.MaxActivationDistance = 12
		upgradePrompt.Parent = signPost
	end
end

local function buildPlot(index)
	local origin = PLOT_ORIGINS[index]

	local plotFolder = Instance.new("Folder")
	plotFolder.Name = "Plot" .. index
	plotFolder.Parent = workspace.Plots

	buildPlotFloor(plotFolder, origin)
	buildPlotSpawn(plotFolder, origin)
	buildWorkersDesk(plotFolder, origin)
	buildStations(plotFolder, origin)
	buildTrendsSign(plotFolder, origin)
	buildHouse(plotFolder, origin, 0)
end

function PlotManager.build()
	local existing = workspace:FindFirstChild("Plots")
	if existing then
		existing:Destroy()
	end

	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = workspace

	for index = 1, #PLOT_ORIGINS do
		buildPlot(index)
	end
end

function PlotManager.assignPlot(player)
	for index = 1, #PLOT_ORIGINS do
		if not claimedBy[index] then
			claimedBy[index] = player.UserId
			plotOfPlayer[player.UserId] = index
			player:SetAttribute("PlotIndex", index)
			return index
		end
	end

	warn(("No free plot available for %s"):format(player.Name))
	return nil
end

function PlotManager.releasePlot(player)
	local index = plotOfPlayer[player.UserId]
	if index then
		claimedBy[index] = nil
		plotOfPlayer[player.UserId] = nil
	end
end

function PlotManager.getPlayerPlotIndex(player)
	return plotOfPlayer[player.UserId]
end

function PlotManager.getPlotFolder(index)
	if not index then
		return nil
	end
	return workspace.Plots:FindFirstChild("Plot" .. index)
end

function PlotManager.rebuildHouseForPlayer(player, tier)
	local index = plotOfPlayer[player.UserId]
	if not index then
		return
	end

	local plotFolder = PlotManager.getPlotFolder(index)
	if not plotFolder then
		return
	end

	buildHouse(plotFolder, PLOT_ORIGINS[index], tier)
end

function PlotManager.rebuildPCForPlayer(player, tier)
	local index = plotOfPlayer[player.UserId]
	if not index then
		return
	end

	local plotFolder = PlotManager.getPlotFolder(index)
	if not plotFolder then
		return
	end

	for _, config in ipairs(STATION_CONFIGS) do
		if config.name == "NewProject" then
			buildStationMonitorRig(plotFolder, PLOT_ORIGINS[index], config, tier)
			return
		end
	end
end

return PlotManager

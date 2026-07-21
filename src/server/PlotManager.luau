local GameData = require(game.ReplicatedStorage.Shared.GameData)

local PlotManager = {}

local FLOOR_TOP = 1
local PLOT_SIZE_X = 70
local PLOT_SIZE_Z = 90
local HOUSE_LOT_OFFSET = Vector3.new(0, 0, 45)

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
	makePart(config.name .. "Monitor", Vector3.new(2.2, monitorHeight, 0.2), origin + Vector3.new(x, monitorCenterY, z + 0.8), DARK_TRIM_COLOR, nil, plotFolder)
	local screen = makePart(config.name .. "MonitorScreen", Vector3.new(2, monitorHeight - 0.2, 0.05), origin + Vector3.new(x, monitorCenterY, z + 0.7), config.monitorColor, Enum.Material.Neon, plotFolder)
	screen.CanCollide = false

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

	makePart("TrendsSignPost", Vector3.new(0.6, 8, 0.6), origin + Vector3.new(0, FLOOR_TOP + 4, -28), DARK_TRIM_COLOR, nil, plotFolder)

	local backing = makePart("TrendsSignBacking", Vector3.new(10, 6, 0.5), origin + Vector3.new(0, signCenterY, -28), ACCENT_COLOR, Enum.Material.Neon, plotFolder)
	backing.CanCollide = false

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TrendsDisplay"
	billboard.Size = UDim2.fromOffset(300, 140)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 100
	billboard.Parent = backing

	local eyebrow = Instance.new("TextLabel")
	eyebrow.Name = "Eyebrow"
	eyebrow.Size = UDim2.new(1, 0, 0, 30)
	eyebrow.Position = UDim2.fromOffset(0, 0)
	eyebrow.BackgroundTransparency = 1
	eyebrow.Text = "\240\159\148\165 TRENDING NOW"
	eyebrow.Font = Enum.Font.GothamBold
	eyebrow.TextScaled = true
	eyebrow.TextColor3 = Color3.fromRGB(255, 158, 66)
	eyebrow.Parent = billboard

	local text = Instance.new("TextLabel")
	text.Name = "TrendsText"
	text.Size = UDim2.new(1, 0, 1, -30)
	text.Position = UDim2.fromOffset(0, 30)
	text.BackgroundTransparency = 1
	text.Text = "Loading..."
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextWrapped = true
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.Parent = billboard
end

local function buildHouse(plotFolder, origin, tier)
	local existing = plotFolder:FindFirstChild("House")
	if existing then
		existing:Destroy()
	end

	local houseFolder = Instance.new("Folder")
	houseFolder.Name = "House"
	houseFolder.Parent = plotFolder

	local base = origin + HOUSE_LOT_OFFSET
	local promptAnchor

	if tier == 0 then
		makePart("HouseFoundation", Vector3.new(16, 0.2, 16), base + Vector3.new(0, FLOOR_TOP + 0.1, 0), DARK_TRIM_COLOR, nil, houseFolder)

		local signPost = makePart("HouseSignPost", Vector3.new(0.4, 5, 0.4), base + Vector3.new(0, FLOOR_TOP + 2.5, 0), DARK_TRIM_COLOR, nil, houseFolder)

		local billboard = Instance.new("BillboardGui")
		billboard.Name = "Label"
		billboard.Size = UDim2.fromOffset(220, 40)
		billboard.AlwaysOnTop = true
		billboard.MaxDistance = 100
		billboard.Parent = signPost

		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Text = "\240\159\143\151\239\184\143 Build a house!"
		text.Font = Enum.Font.FredokaOne
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(255, 255, 255)
		text.Parent = billboard

		promptAnchor = signPost
	else
		local width = 14 + (tier - 1) * 8
		local depth = 14 + (tier - 1) * 8
		local wallHeight = 8 + (tier - 1) * 4
		local halfW = width / 2
		local halfD = depth / 2
		local wallThickness = 0.6
		local wallCenterY = FLOOR_TOP + wallHeight / 2

		makePart("HouseFloor", Vector3.new(width, 0.5, depth), base + Vector3.new(0, FLOOR_TOP + 0.25, 0), DESK_COLOR, nil, houseFolder)
		makePart("WallFront", Vector3.new(width, wallHeight, wallThickness), base + Vector3.new(0, wallCenterY, -halfD), PANEL_COLOR, nil, houseFolder)
		makePart("WallBack", Vector3.new(width, wallHeight, wallThickness), base + Vector3.new(0, wallCenterY, halfD), PANEL_COLOR, nil, houseFolder)
		makePart("WallLeft", Vector3.new(wallThickness, wallHeight, depth), base + Vector3.new(-halfW, wallCenterY, 0), PANEL_COLOR, nil, houseFolder)
		makePart("WallRight", Vector3.new(wallThickness, wallHeight, depth), base + Vector3.new(halfW, wallCenterY, 0), PANEL_COLOR, nil, houseFolder)

		local function buildPeakedRoof(name, roofWidth, roofDepth, baseY)
			local roofFolder = Instance.new("Folder")
			roofFolder.Name = name
			roofFolder.Parent = houseFolder

			local baseHeight = 1.4
			local midHeight = 1.2
			local peakHeight = 1.2

			local baseY0 = baseY + baseHeight / 2
			makePart("Base", Vector3.new(roofWidth + 2, baseHeight, roofDepth + 2), base + Vector3.new(0, baseY0, 0), ACCENT_COLOR, Enum.Material.Neon, roofFolder)

			local midY = baseY + baseHeight + midHeight / 2
			makePart("Mid", Vector3.new(roofWidth * 0.66, midHeight, roofDepth * 0.66), base + Vector3.new(0, midY, 0), ACCENT_COLOR, Enum.Material.Neon, roofFolder)

			local peakY = baseY + baseHeight + midHeight + peakHeight / 2
			makePart("Peak", Vector3.new(roofWidth * 0.3, peakHeight, roofDepth * 0.3), base + Vector3.new(0, peakY, 0), GOLD_COLOR, Enum.Material.Neon, roofFolder)

			return baseY + baseHeight + midHeight + peakHeight
		end

		local roofY = FLOOR_TOP + wallHeight + 0.5
		buildPeakedRoof("Roof", width, depth, roofY)

		local door = makePart("Door", Vector3.new(3, 5, 0.3), base + Vector3.new(0, FLOOR_TOP + 2.5, -halfD - 0.2), DARK_TRIM_COLOR, nil, houseFolder)
		door.CanCollide = false

		local doorKnob = makePart("DoorKnob", Vector3.new(0.3, 0.3, 0.3), base + Vector3.new(1, FLOOR_TOP + 2.2, -halfD - 0.35), GOLD_COLOR, Enum.Material.Neon, houseFolder)
		doorKnob.CanCollide = false

		local windowLeft = makePart("WindowLeft", Vector3.new(2, 2, 0.3), base + Vector3.new(-halfW + 3, wallCenterY + 1, -halfD - 0.2), GOLD_COLOR, Enum.Material.Neon, houseFolder)
		windowLeft.CanCollide = false

		local windowRight = makePart("WindowRight", Vector3.new(2, 2, 0.3), base + Vector3.new(halfW - 3, wallCenterY + 1, -halfD - 0.2), GOLD_COLOR, Enum.Material.Neon, houseFolder)
		windowRight.CanCollide = false

		local pathLength = 6
		local path = makePart("Path", Vector3.new(4, 0.15, pathLength), base + Vector3.new(0, FLOOR_TOP + 0.08, -halfD - 0.2 - pathLength / 2), DARK_TRIM_COLOR, nil, houseFolder)
		path.CanCollide = false

		if tier >= 2 then
			local upperHeight = 5
			local upperCenterY = FLOOR_TOP + wallHeight + 1 + upperHeight / 2
			makePart("UpperFloor", Vector3.new(width - 4, upperHeight, depth - 4), base + Vector3.new(0, upperCenterY, 0), PANEL_COLOR, nil, houseFolder)

			buildPeakedRoof("UpperRoof", width - 2, depth - 2, upperCenterY + upperHeight / 2 + 0.5)
		end

		promptAnchor = door
	end

	if tier < GameData.HouseTierCount - 1 then
		local upgradePrompt = Instance.new("ProximityPrompt")
		upgradePrompt.Name = "HouseUpgradePrompt"
		upgradePrompt.ActionText = (tier == 0) and "Build House" or "Upgrade House"
		upgradePrompt.ObjectText = "Home"
		upgradePrompt.HoldDuration = 0.5
		upgradePrompt.MaxActivationDistance = 12
		upgradePrompt.Parent = promptAnchor
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

return PlotManager

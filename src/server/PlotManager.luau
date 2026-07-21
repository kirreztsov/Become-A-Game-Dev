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
-- Low, waist-to-chest height -- a decorative border, not a wall blocking the view.
local PLOT_FENCE_HEIGHT_BY_TIER = { 3, 4 }

-- A real house building on the open lot at the far end of the plot (away
-- from the office stations), sized up and detailed further per tier.
-- Wedge roof math verified live in Studio: a wedge's tall face sits at its
-- local -Z edge and tapers to 0 height at local +Z. Rotating +90 degrees
-- around Y and centering at -run/2 puts the tall edge at the ridge (x=0)
-- and the thin edge at the left eave; rotating -90 and centering at
-- +run/2 mirrors that for the right half -- together they form a peak.
local function buildHouseStructure(houseFolder, base, tier)
	local width = (tier >= 2) and 22 or 16
	local depth = (tier >= 2) and 18 or 14
	local wallHeight = (tier >= 2) and 9 or 7
	local halfW = width / 2
	local halfD = depth / 2
	local wallThickness = 0.6
	local wallCenterY = FLOOR_TOP + wallHeight / 2

	local wallColor = Color3.fromRGB(214, 178, 122)
	local trimColor = Color3.fromRGB(255, 255, 255)
	local roofColor = (tier >= 2) and Color3.fromRGB(120, 45, 40) or Color3.fromRGB(96, 74, 68)

	makePart("HouseFloor", Vector3.new(width, 0.5, depth), base + Vector3.new(0, FLOOR_TOP + 0.25, 0), Color3.fromRGB(150, 120, 90), Enum.Material.WoodPlanks, houseFolder)
	makePart("WallFront", Vector3.new(width, wallHeight, wallThickness), base + Vector3.new(0, wallCenterY, -halfD), wallColor, Enum.Material.WoodPlanks, houseFolder)
	makePart("WallBack", Vector3.new(width, wallHeight, wallThickness), base + Vector3.new(0, wallCenterY, halfD), wallColor, Enum.Material.WoodPlanks, houseFolder)
	makePart("WallLeft", Vector3.new(wallThickness, wallHeight, depth), base + Vector3.new(-halfW, wallCenterY, 0), wallColor, Enum.Material.WoodPlanks, houseFolder)
	makePart("WallRight", Vector3.new(wallThickness, wallHeight, depth), base + Vector3.new(halfW, wallCenterY, 0), wallColor, Enum.Material.WoodPlanks, houseFolder)

	-- Peaked roof: two wedges meeting at a ridge running front-to-back (Z)
	local roofOverhang = 1.5
	local ridgeLength = depth + roofOverhang * 2
	local roofRun = halfW + roofOverhang
	local roofHeight = (tier >= 2) and 6 or 5
	local roofBaseY = FLOOR_TOP + wallHeight + roofHeight / 2

	local function makeRoofHalf(name, xOffset, yRotationDeg)
		local wedge = Instance.new("WedgePart")
		wedge.Name = name
		wedge.Size = Vector3.new(ridgeLength, roofHeight, roofRun)
		wedge.CFrame = CFrame.new(base + Vector3.new(xOffset, roofBaseY, 0)) * CFrame.Angles(0, math.rad(yRotationDeg), 0)
		wedge.Color = roofColor
		wedge.Material = Enum.Material.Slate
		wedge.Anchored = true
		wedge.Parent = houseFolder
	end

	makeRoofHalf("RoofLeft", -roofRun / 2, 90)
	makeRoofHalf("RoofRight", roofRun / 2, -90)

	local door = makePart("Door", Vector3.new(3, 5, 0.3), base + Vector3.new(0, FLOOR_TOP + 2.5, -halfD - 0.2), Color3.fromRGB(90, 60, 40), Enum.Material.Wood, houseFolder)
	door.CanCollide = false

	local doorKnob = makePart("DoorKnob", Vector3.new(0.3, 0.3, 0.3), base + Vector3.new(1, FLOOR_TOP + 2.2, -halfD - 0.35), GOLD_COLOR, Enum.Material.Metal, houseFolder)
	doorKnob.CanCollide = false

	local function makeWindow(name, x)
		local frame = makePart(name .. "Frame", Vector3.new(2.4, 2.4, 0.25), base + Vector3.new(x, wallCenterY + 1, -halfD - 0.2), trimColor, Enum.Material.SmoothPlastic, houseFolder)
		frame.CanCollide = false
		local pane = makePart(name .. "Pane", Vector3.new(2, 2, 0.1), base + Vector3.new(x, wallCenterY + 1, -halfD - 0.3), Color3.fromRGB(160, 210, 230), Enum.Material.Glass, houseFolder)
		pane.CanCollide = false
		pane.Transparency = 0.3
	end

	makeWindow("WindowLeft", -halfW + 3)
	makeWindow("WindowRight", halfW - 3)

	local frontClearance = halfD + 0.2
	if tier >= 2 then
		local chimneyHeight = wallHeight + roofHeight + 2
		makePart("Chimney", Vector3.new(1.5, chimneyHeight, 1.5), base + Vector3.new(halfW - 3, FLOOR_TOP + chimneyHeight / 2, halfD - 2), Color3.fromRGB(120, 60, 50), Enum.Material.Brick, houseFolder)

		local porchDepth = 4
		makePart("PorchFloor", Vector3.new(width - 4, 0.5, porchDepth), base + Vector3.new(0, FLOOR_TOP + 0.25, -halfD - porchDepth / 2), Color3.fromRGB(150, 120, 90), Enum.Material.WoodPlanks, houseFolder)

		local pillarHeight = 4.5
		local pillarPositions = { -(width / 2 - 4), (width / 2 - 4) }
		for i, px in ipairs(pillarPositions) do
			makePart("PorchPillar" .. i, Vector3.new(0.6, pillarHeight, 0.6), base + Vector3.new(px, FLOOR_TOP + pillarHeight / 2, -halfD - porchDepth + 0.5), trimColor, Enum.Material.SmoothPlastic, houseFolder)
		end

		makePart("PorchRoof", Vector3.new(width - 3, 0.4, porchDepth + 1), base + Vector3.new(0, FLOOR_TOP + pillarHeight + 0.2, -halfD - porchDepth / 2), roofColor, Enum.Material.Slate, houseFolder)

		frontClearance = halfD + porchDepth + 0.2
	end

	local pathLength = 6
	local path = makePart("Path", Vector3.new(4, 0.15, pathLength), base + Vector3.new(0, FLOOR_TOP + 0.08, -frontClearance - pathLength / 2), Color3.fromRGB(180, 175, 165), Enum.Material.Cobblestone, houseFolder)
	path.CanCollide = false
end

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
		-- Tier 1 reads as a basic wood picket fence; tier 2 upgrades it to a
		-- gold metal fence -- real Roblox materials instead of flat plastic,
		-- and posts + rails (with gaps) instead of a solid slab.
		local postMaterial = (tier >= 2) and Enum.Material.Metal or Enum.Material.Wood
		local postColor = (tier >= 2) and GOLD_COLOR or DESK_COLOR
		local railColor = (tier >= 2) and GOLD_COLOR or ACCENT_COLOR
		local postThickness = 0.5
		local railThickness = 0.25
		local postSpacing = 10

		local function buildFenceRun(name, fromOffset, toOffset)
			local delta = toOffset - fromOffset
			local length = delta.Magnitude
			local segments = math.max(1, math.floor(length / postSpacing + 0.5))
			local isAlongX = math.abs(delta.X) >= math.abs(delta.Z)

			for i = 0, segments do
				local t = i / segments
				local postPos = origin + fromOffset:Lerp(toOffset, t) + Vector3.new(0, FLOOR_TOP + fenceHeight / 2, 0)
				makePart(name .. "Post" .. i, Vector3.new(postThickness, fenceHeight, postThickness), postPos, postColor, postMaterial, upgradeFolder)
			end

			local midpoint = origin + fromOffset:Lerp(toOffset, 0.5)
			local railSizeAlong = isAlongX and Vector3.new(length, railThickness, railThickness) or Vector3.new(railThickness, railThickness, length)
			for railIndex, heightFraction in ipairs({ 0.4, 0.85 }) do
				local railY = FLOOR_TOP + fenceHeight * heightFraction
				makePart(name .. "Rail" .. railIndex, railSizeAlong, midpoint + Vector3.new(0, railY, 0), railColor, postMaterial, upgradeFolder)
			end
		end

		buildFenceRun("PlotFenceNear", Vector3.new(-halfX, 0, nearZ), Vector3.new(halfX, 0, nearZ))
		buildFenceRun("PlotFenceFar", Vector3.new(-halfX, 0, farZ), Vector3.new(halfX, 0, farZ))
		buildFenceRun("PlotFenceLeft", Vector3.new(-halfX, 0, nearZ), Vector3.new(-halfX, 0, farZ))
		buildFenceRun("PlotFenceRight", Vector3.new(halfX, 0, nearZ), Vector3.new(halfX, 0, farZ))

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

		-- A couple of landscaping bushes by the sign for a lived-in touch
		local bushOffsets = { Vector3.new(-2.5, 0, 8), Vector3.new(2.5, 0, 8) }
		for i, offset in ipairs(bushOffsets) do
			local bush = makePart("PlotBush" .. i, Vector3.new(2, 1.6, 2), origin + Vector3.new(offset.X, FLOOR_TOP + 0.8, offset.Z), Color3.fromRGB(58, 122, 74), Enum.Material.Grass, upgradeFolder)
			bush.Shape = Enum.PartType.Ball
		end

		local houseFolder = Instance.new("Folder")
		houseFolder.Name = "House"
		houseFolder.Parent = upgradeFolder
		buildHouseStructure(houseFolder, origin + HOUSE_LOT_OFFSET, tier)
	end

	-- Central signpost near spawn -- reachable immediately, not tucked in a corner
	local signPost = makePart("PlotUpgradeSignPost", Vector3.new(0.4, 5, 0.4), origin + Vector3.new(0, FLOOR_TOP + 2.5, 8), DARK_TRIM_COLOR, nil, upgradeFolder)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(220, 40)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 100
	billboard.Parent = signPost

	local isMaxTier = tier >= GameData.HouseTierCount - 1

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = isMaxTier and "\240\159\143\151\239\184\143 Plot fully upgraded!" or "\240\159\143\151\239\184\143 Upgrade your plot!"
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.Parent = billboard

	if not isMaxTier then
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

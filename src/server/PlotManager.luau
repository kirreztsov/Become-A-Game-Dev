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

local PANEL_COLOR = Color3.fromRGB(196, 172, 138)
local ACCENT_COLOR = Color3.fromRGB(140, 92, 255)
local GOLD_COLOR = Color3.fromRGB(255, 209, 102)
local DARK_TRIM_COLOR = Color3.fromRGB(30, 22, 44)
-- Light desk + a vibrant chair -- matches the real RoTube Life 2 studio
-- look (clean desk, colorful gaming chair) instead of a dark office box.
local DESK_COLOR = Color3.fromRGB(230, 222, 208)
local CHAIR_COLOR = Color3.fromRGB(200, 55, 50)

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

-- Adds a backrest, armrests, and a pedestal around a plain seat-cushion
-- part so it reads as an actual gaming chair instead of a colored cube.
-- seatCenter is the world position of the existing seat cushion (its
-- own geometry is left untouched -- for the real Seat instances that
-- matters for player-sitting behavior, this only adds decoration around it).
local function buildChairVisual(parent, namePrefix, seatCenter, color)
	local backrest = Instance.new("Part")
	backrest.Name = namePrefix .. "ChairBackrest"
	backrest.Size = Vector3.new(1.8, 2, 0.3)
	backrest.CFrame = CFrame.new(seatCenter + Vector3.new(0, 1.3, -0.9)) * CFrame.Angles(math.rad(-8), 0, 0)
	backrest.Color = color
	backrest.Material = Enum.Material.SmoothPlastic
	backrest.Anchored = true
	backrest.CanCollide = false
	backrest.Parent = parent

	for i, side in ipairs({ -1, 1 }) do
		local armrest = Instance.new("Part")
		armrest.Name = namePrefix .. "ChairArmrest" .. i
		armrest.Size = Vector3.new(0.2, 0.25, 1.4)
		armrest.Position = seatCenter + Vector3.new(side * 0.95, 0.7, -0.2)
		armrest.Color = color
		armrest.Material = Enum.Material.SmoothPlastic
		armrest.Anchored = true
		armrest.CanCollide = false
		armrest.Parent = parent
	end

	local pedestal = Instance.new("Part")
	pedestal.Name = namePrefix .. "ChairPedestal"
	pedestal.Size = Vector3.new(0.5, 1.1, 0.5)
	pedestal.Position = seatCenter - Vector3.new(0, 0.9, 0)
	pedestal.Color = DARK_TRIM_COLOR
	pedestal.Material = Enum.Material.Metal
	pedestal.Anchored = true
	pedestal.CanCollide = false
	pedestal.Parent = parent
end

local function buildPlotFloor(plotFolder, origin)
	makePart("PlotFloor", Vector3.new(PLOT_SIZE_X, 1, PLOT_SIZE_Z), origin + Vector3.new(0, 0.5, 15), PANEL_COLOR, nil, plotFolder)
end

-- Spawns just outside the studio door -- the studio (house) now contains
-- the actual work stations, so that's where a player needs to be.
local function buildPlotSpawn(plotFolder, origin)
	local spawnPoint = Instance.new("Part")
	spawnPoint.Name = "PlotSpawnPoint"
	spawnPoint.Size = Vector3.new(1, 1, 1)
	spawnPoint.Position = origin + HOUSE_LOT_OFFSET + Vector3.new(0, FLOOR_TOP + 3, -30)
	spawnPoint.Anchored = true
	spawnPoint.CanCollide = false
	spawnPoint.Transparency = 1
	spawnPoint.Parent = plotFolder
end

local function buildWorkersDesk(plotFolder, origin, x, z)
	local deskTopSurfaceY = FLOOR_TOP + 2
	local legHeight = 2
	local legCenterY = FLOOR_TOP + legHeight / 2
	local deskCenterY = deskTopSurfaceY + 0.25

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

	local chairHeight = 0.6
	local chairCenter = origin + Vector3.new(x, FLOOR_TOP + 1.3, z - 3)
	makePart("WorkersChair", Vector3.new(2, chairHeight, 2), chairCenter, CHAIR_COLOR, nil, plotFolder)
	buildChairVisual(plotFolder, "Workers", chairCenter, CHAIR_COLOR)
end

-- Desk positions are computed (see computeStudioLayout), not stored here --
-- the same 4 stations get placed differently depending on the studio's
-- current interior size.
local STATION_CONFIGS = {
	{ name = "NewProject", label = "\240\159\134\149 NEW PROJECT", monitorColor = GOLD_COLOR },
	{ name = "Coding", label = "\226\154\161 CODING", monitorColor = ACCENT_COLOR },
	{ name = "MapBuilding", label = "\240\159\151\186\239\184\143 MAP BUILDING", monitorColor = ACCENT_COLOR },
	{ name = "Testing", label = "\226\156\168 TESTING", monitorColor = ACCENT_COLOR },
}

-- The NewProject station's monitor doubles as the player's "PC" -- its size
-- and screen color scale with pcTier, and it carries the PCUpgradePrompt.
-- Rebuildable independently of the rest of the station (desk/seat/label
-- never change), the same way buildHouse rebuilds just the house folder.
local function buildStationMonitorRig(plotFolder, origin, config, tier, x, z)
	local existingRig = plotFolder:FindFirstChild(config.name .. "MonitorRig")
	if existingRig then
		existingRig:Destroy()
	end

	local rig = Instance.new("Folder")
	rig.Name = config.name .. "MonitorRig"
	rig.Parent = plotFolder

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

local function buildStation(plotFolder, origin, config, x, z)
	local deskTopSurfaceY = FLOOR_TOP + 2
	local legHeight = 2
	local legCenterY = FLOOR_TOP + legHeight / 2
	local deskCenterY = deskTopSurfaceY + 0.25

	makePart(config.name .. "DeskTop", Vector3.new(6, 0.5, 3), origin + Vector3.new(x, deskCenterY, z), DESK_COLOR, nil, plotFolder)
	makePart(config.name .. "DeskLegA", Vector3.new(0.4, legHeight, 0.4), origin + Vector3.new(x - 2.6, legCenterY, z + 1), DARK_TRIM_COLOR, nil, plotFolder)
	makePart(config.name .. "DeskLegB", Vector3.new(0.4, legHeight, 0.4), origin + Vector3.new(x + 2.6, legCenterY, z + 1), DARK_TRIM_COLOR, nil, plotFolder)
	makePart(config.name .. "DeskLegC", Vector3.new(0.4, legHeight, 0.4), origin + Vector3.new(x - 2.6, legCenterY, z - 1), DARK_TRIM_COLOR, nil, plotFolder)
	makePart(config.name .. "DeskLegD", Vector3.new(0.4, legHeight, 0.4), origin + Vector3.new(x + 2.6, legCenterY, z - 1), DARK_TRIM_COLOR, nil, plotFolder)

	local deskTopSurfaceTopY = deskTopSurfaceY + 0.5
	local monitorHeight = 1.6
	local monitorCenterY = deskTopSurfaceTopY + monitorHeight / 2
	buildStationMonitorRig(plotFolder, origin, config, 0, x, z)

	local seatCenter = origin + Vector3.new(x, FLOOR_TOP + 1.2, z - 3)

	local seat = Instance.new("Seat")
	seat.Name = config.name .. "Seat"
	seat.Size = Vector3.new(2, 2.4, 2)
	seat.Anchored = true
	seat.Material = Enum.Material.SmoothPlastic
	seat.Color = CHAIR_COLOR
	-- A seat's default facing is -Z; the monitor sits north (+Z) of this seat,
	-- so rotate 180 degrees to face the player toward it when they sit down.
	seat.CFrame = CFrame.new(seatCenter) * CFrame.Angles(0, math.rad(180), 0)
	seat.Parent = plotFolder

	-- Decoration only -- the seat's own geometry/CFrame (what actually
	-- matters for player-sitting behavior) is left untouched above.
	buildChairVisual(plotFolder, config.name, seatCenter, CHAIR_COLOR)

	local labelAnchor = Instance.new("Part")
	labelAnchor.Name = config.name .. "LabelAnchor"
	labelAnchor.Size = Vector3.new(0.1, 0.1, 0.1)
	labelAnchor.Position = origin + Vector3.new(x, monitorCenterY + 1.5, z + 0.7)
	labelAnchor.Transparency = 1
	labelAnchor.Anchored = true
	labelAnchor.CanCollide = false
	labelAnchor.Parent = plotFolder

	-- Stations now sit close together inside the studio (not spread across
	-- an open plot), so a long MaxDistance would cluster all 5 labels into
	-- one unreadable pile when viewed from outside -- keep it short so a
	-- label only shows once you're actually near that desk.
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(220, 40)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 18
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

-- Fixed layout for the 4 work stations + the Workers desk inside the
-- studio, in local (x, z) offsets from the studio's base position. Chosen
-- to fit inside the smallest studio tier (26 wide x 24 deep) -- bigger
-- tiers just have more spare room around the same layout, so stations are
-- built once and never need to move when the studio is upgraded.
-- Back row (3 stations) sits near the back wall; front row (Testing +
-- Workers) sits closer to the door, leaving a walking aisle between them.
local STUDIO_LAYOUT = {
	{ name = "NewProject", x = -7, z = 7 },
	{ name = "Coding", x = 0, z = 7 },
	{ name = "MapBuilding", x = 7, z = 7 },
	{ name = "Testing", x = -3.5, z = -2 },
	{ name = "Workers", x = 3.5, z = -2 },
}

local function buildStudioStations(plotFolder, base)
	for _, entry in ipairs(STUDIO_LAYOUT) do
		if entry.name == "Workers" then
			buildWorkersDesk(plotFolder, base, entry.x, entry.z)
		else
			for _, config in ipairs(STATION_CONFIGS) do
				if config.name == entry.name then
					buildStation(plotFolder, base, config, entry.x, entry.z)
					break
				end
			end
		end
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

-- Fence height per tier; tier 0 has no fence.
-- Low, waist-to-chest height -- a decorative border, not a wall blocking the view.
local PLOT_FENCE_HEIGHT_BY_TIER = { 3, 3.5, 4, 4.5 }

-- House size/detail per tier -- a longer progression like RoTube Life 2's
-- many home tiers (starter house up to a mansion), not just two steps.
-- All tiers, including 0, are sized at least as big as STUDIO_LAYOUT needs
-- (26 wide x 24 deep) so the fixed station layout always fits inside.
local HOUSE_TIER_CONFIG = {
	[0] = { width = 26, depth = 24, wallHeight = 6, secondStory = false, porch = false, chimney = false, hedges = false, driveway = false },
	[1] = { width = 28, depth = 25, wallHeight = 7, secondStory = false, porch = false, chimney = false, hedges = false, driveway = false },
	[2] = { width = 32, depth = 26, wallHeight = 8, secondStory = false, porch = true, chimney = true, hedges = false, driveway = false },
	[3] = { width = 34, depth = 27, wallHeight = 7, upperWallHeight = 6, secondStory = true, porch = true, chimney = true, hedges = true, driveway = false },
	[4] = { width = 38, depth = 28, wallHeight = 8, upperWallHeight = 7, secondStory = true, porch = true, chimney = true, hedges = true, driveway = true },
}

-- A real house building on the open lot at the far end of the plot (away
-- from the office stations), sized up and detailed further per tier.
-- Modern flat-roof, big-glass style -- matches the actual RoTube Life 2
-- house look (confirmed from its real Roblox store page), not a
-- pitched-roof cottage.
local function buildHouseStructure(houseFolder, base, tier)
	local config = HOUSE_TIER_CONFIG[tier]
	local width = config.width
	local depth = config.depth
	local wallHeight = config.wallHeight
	local halfW = width / 2
	local halfD = depth / 2
	local wallThickness = 0.6
	local wallCenterY = FLOOR_TOP + wallHeight / 2

	local wallColor = Color3.fromRGB(235, 232, 225)
	local glassColor = Color3.fromRGB(180, 215, 230)
	local trimColor = Color3.fromRGB(255, 255, 255)
	local roofColor = Color3.fromRGB(240, 240, 238)

	makePart("HouseFloor", Vector3.new(width, 0.5, depth), base + Vector3.new(0, FLOOR_TOP + 0.25, 0), Color3.fromRGB(200, 190, 175), Enum.Material.Concrete, houseFolder)

	-- Front wall has an actual doorway gap (not just a non-collide decal in
	-- front of a solid wall) so the house is really walkable-into.
	local doorWidth = 3.5
	local doorHeight = 5
	local sideWallWidth = halfW - doorWidth / 2
	local sideWallCenterX = (halfW + doorWidth / 2) / 2
	local lintelHeight = wallHeight - doorHeight

	makePart("WallFrontLeft", Vector3.new(sideWallWidth, wallHeight, wallThickness), base + Vector3.new(-sideWallCenterX, wallCenterY, -halfD), wallColor, Enum.Material.SmoothPlastic, houseFolder)
	makePart("WallFrontRight", Vector3.new(sideWallWidth, wallHeight, wallThickness), base + Vector3.new(sideWallCenterX, wallCenterY, -halfD), wallColor, Enum.Material.SmoothPlastic, houseFolder)
	if lintelHeight > 0 then
		makePart("WallFrontLintel", Vector3.new(doorWidth, lintelHeight, wallThickness), base + Vector3.new(0, FLOOR_TOP + doorHeight + lintelHeight / 2, -halfD), wallColor, Enum.Material.SmoothPlastic, houseFolder)
	end

	makePart("WallBack", Vector3.new(width, wallHeight, wallThickness), base + Vector3.new(0, wallCenterY, halfD), wallColor, Enum.Material.SmoothPlastic, houseFolder)

	-- Side walls are floor-to-ceiling glass (the reference house's defining
	-- feature) rather than solid -- still CanCollide, just see-through.
	makePart("WallLeft", Vector3.new(wallThickness, wallHeight, depth), base + Vector3.new(-halfW, wallCenterY, 0), glassColor, Enum.Material.Glass, houseFolder)
	makePart("WallRight", Vector3.new(wallThickness, wallHeight, depth), base + Vector3.new(halfW, wallCenterY, 0), glassColor, Enum.Material.Glass, houseFolder)

	-- Big, near-floor-to-ceiling front windows flanking the door (instead of
	-- small square windows) to match the reference's glass-wall look.
	local function makeWindow(name, x, y, windowHeight)
		local frame = makePart(name .. "Frame", Vector3.new(3.7, windowHeight + 0.3, 0.25), base + Vector3.new(x, y, -halfD - 0.2), trimColor, Enum.Material.SmoothPlastic, houseFolder)
		frame.CanCollide = false
		local pane = makePart(name .. "Pane", Vector3.new(3.4, windowHeight, 0.1), base + Vector3.new(x, y, -halfD - 0.3), glassColor, Enum.Material.Glass, houseFolder)
		pane.CanCollide = false
		pane.Transparency = 0.35
	end

	local frontWindowHeight = wallHeight - 1.5
	makeWindow("WindowLeft", -halfW + 3, wallCenterY, frontWindowHeight)
	makeWindow("WindowRight", halfW - 3, wallCenterY, frontWindowHeight)

	-- Second story: a shorter upper wall stack sitting directly on the
	-- ground floor, with its own window and a trim band at the seam. The
	-- roof then sits on top of this instead of the ground floor.
	local totalWallHeight = wallHeight
	if config.secondStory then
		local upperWallHeight = config.upperWallHeight
		local upperCenterY = FLOOR_TOP + wallHeight + upperWallHeight / 2

		makePart("UpperWallFront", Vector3.new(width, upperWallHeight, wallThickness), base + Vector3.new(0, upperCenterY, -halfD), wallColor, Enum.Material.SmoothPlastic, houseFolder)
		makePart("UpperWallBack", Vector3.new(width, upperWallHeight, wallThickness), base + Vector3.new(0, upperCenterY, halfD), wallColor, Enum.Material.SmoothPlastic, houseFolder)
		makePart("UpperWallLeft", Vector3.new(wallThickness, upperWallHeight, depth), base + Vector3.new(-halfW, upperCenterY, 0), glassColor, Enum.Material.Glass, houseFolder)
		makePart("UpperWallRight", Vector3.new(wallThickness, upperWallHeight, depth), base + Vector3.new(halfW, upperCenterY, 0), glassColor, Enum.Material.Glass, houseFolder)

		local trim = makePart("StoryTrim", Vector3.new(width + 0.3, 0.3, depth + 0.3), base + Vector3.new(0, FLOOR_TOP + wallHeight, 0), trimColor, Enum.Material.SmoothPlastic, houseFolder)
		trim.CanCollide = false

		makeWindow("UpperWindowLeft", -halfW + 3, upperCenterY, upperWallHeight - 1.5)
		makeWindow("UpperWindowRight", halfW - 3, upperCenterY, upperWallHeight - 1.5)

		totalWallHeight = wallHeight + upperWallHeight
	end

	-- Flat overhanging roof slab -- modern, not a pitched cottage roof.
	local roofOverhang = 1.5
	local roofThickness = 1
	local roofY = FLOOR_TOP + totalWallHeight + roofThickness / 2
	makePart("Roof", Vector3.new(width + roofOverhang * 2, roofThickness, depth + roofOverhang * 2), base + Vector3.new(0, roofY, 0), roofColor, Enum.Material.Concrete, houseFolder)

	-- Sits flush in the doorway gap (not offset in front of a solid wall)
	-- and stays non-collide so walking through the gap actually works.
	local door = makePart("Door", Vector3.new(doorWidth - 0.3, doorHeight, wallThickness), base + Vector3.new(0, FLOOR_TOP + doorHeight / 2, -halfD), Color3.fromRGB(90, 60, 40), Enum.Material.Wood, houseFolder)
	door.CanCollide = false

	local doorKnob = makePart("DoorKnob", Vector3.new(0.3, 0.3, 0.3), base + Vector3.new(1, FLOOR_TOP + 2.2, -halfD - 0.25), GOLD_COLOR, Enum.Material.Metal, houseFolder)
	doorKnob.CanCollide = false

	-- The studio floor is dominated by the fixed work-station layout (see
	-- STUDIO_LAYOUT), which always sits within x = -10..10, z = -5..8.5.
	-- Only tiers with room to spare beyond that (2+) get a bed/rug tucked
	-- into the side margin, so it never collides with the desks.
	if halfW >= 16 then
		local bedX = halfW - 3
		local bedZ = 0
		local bedFrameHeight = 1.2
		makePart("BedFrame", Vector3.new(3, bedFrameHeight, 5), base + Vector3.new(bedX, FLOOR_TOP + bedFrameHeight / 2, bedZ), Color3.fromRGB(90, 60, 40), Enum.Material.Wood, houseFolder)
		local mattress = makePart("Mattress", Vector3.new(2.8, 0.6, 4.8), base + Vector3.new(bedX, FLOOR_TOP + bedFrameHeight + 0.3, bedZ), Color3.fromRGB(235, 235, 240), Enum.Material.Fabric, houseFolder)
		mattress.CanCollide = false
		local pillow = makePart("Pillow", Vector3.new(2.4, 0.4, 1), base + Vector3.new(bedX, FLOOR_TOP + bedFrameHeight + 0.8, bedZ - 1.8), Color3.fromRGB(255, 255, 255), Enum.Material.Fabric, houseFolder)
		pillow.CanCollide = false

		local rug = makePart("Rug", Vector3.new(3, 0.1, 4), base + Vector3.new(bedX, FLOOR_TOP + 0.3, bedZ + 3.5), GOLD_COLOR, Enum.Material.Fabric, houseFolder)
		rug.CanCollide = false
	end

	local ceilingLight = makePart("CeilingLight", Vector3.new(1.2, 0.3, 1.2), base + Vector3.new(0, FLOOR_TOP + wallHeight - 0.3, 0), Color3.fromRGB(255, 244, 214), Enum.Material.Neon, houseFolder)
	ceilingLight.CanCollide = false
	local pointLight = Instance.new("PointLight")
	pointLight.Brightness = 2
	pointLight.Range = 20
	pointLight.Color = Color3.fromRGB(255, 244, 214)
	pointLight.Parent = ceilingLight

	local frontClearance = halfD + 0.2

	if config.chimney then
		-- A slim modern vent stack (not a brick cottage chimney) against the
		-- back exterior wall, not poking up through the interior floor.
		local chimneyHeight = totalWallHeight + roofThickness + 2
		makePart("Chimney", Vector3.new(1.2, chimneyHeight, 1.2), base + Vector3.new(halfW - 3, FLOOR_TOP + chimneyHeight / 2, halfD + 1), Color3.fromRGB(90, 90, 90), Enum.Material.Concrete, houseFolder)
	end

	if config.porch then
		local porchDepth = 4
		makePart("PorchFloor", Vector3.new(width - 4, 0.5, porchDepth), base + Vector3.new(0, FLOOR_TOP + 0.25, -halfD - porchDepth / 2), Color3.fromRGB(150, 120, 90), Enum.Material.WoodPlanks, houseFolder)

		-- Tall enough to clear above the ground-floor windows instead of
		-- cutting across them.
		local pillarHeight = wallHeight - 1
		local pillarPositions = { -(width / 2 - 4), (width / 2 - 4) }
		for i, px in ipairs(pillarPositions) do
			makePart("PorchPillar" .. i, Vector3.new(0.6, pillarHeight, 0.6), base + Vector3.new(px, FLOOR_TOP + pillarHeight / 2, -halfD - porchDepth + 0.5), trimColor, Enum.Material.SmoothPlastic, houseFolder)
		end

		makePart("PorchRoof", Vector3.new(width - 3, 0.4, porchDepth + 1), base + Vector3.new(0, FLOOR_TOP + pillarHeight + 0.2, -halfD - porchDepth / 2), roofColor, Enum.Material.Slate, houseFolder)

		frontClearance = halfD + porchDepth + 0.2
	end

	if config.hedges then
		local hedgeOffsets = { Vector3.new(-halfW + 1.5, 0, -frontClearance - 1.5), Vector3.new(halfW - 1.5, 0, -frontClearance - 1.5) }
		for i, offset in ipairs(hedgeOffsets) do
			local hedge = makePart("Hedge" .. i, Vector3.new(2, 1.4, 2), base + Vector3.new(offset.X, FLOOR_TOP + 0.7, offset.Z), Color3.fromRGB(58, 122, 74), Enum.Material.Grass, houseFolder)
			hedge.CanCollide = false
		end
	end

	local pathWidth = config.driveway and 8 or 4
	local pathLength = config.driveway and 10 or 6
	local pathMaterial = config.driveway and Enum.Material.Concrete or Enum.Material.Cobblestone
	local pathColor = config.driveway and Color3.fromRGB(120, 120, 120) or Color3.fromRGB(180, 175, 165)
	local path = makePart("Path", Vector3.new(pathWidth, 0.15, pathLength), base + Vector3.new(0, FLOOR_TOP + 0.08, -frontClearance - pathLength / 2), pathColor, pathMaterial, houseFolder)
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
		-- Tiers 1-2 read as a basic wood picket fence; tiers 3-4 upgrade to a
		-- gold metal fence -- real Roblox materials instead of flat plastic,
		-- and posts + rails (with gaps) instead of a solid slab.
		local postMaterial = (tier >= 3) and Enum.Material.Metal or Enum.Material.Wood
		local postColor = (tier >= 3) and GOLD_COLOR or DESK_COLOR
		local railColor = (tier >= 3) and GOLD_COLOR or ACCENT_COLOR
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
	end

	-- The studio building itself exists at every tier, including 0 -- it
	-- shelters the work stations from the start, not just once you can
	-- afford the plot-wide fence/floor upgrade above.
	local houseFolder = Instance.new("Folder")
	houseFolder.Name = "House"
	houseFolder.Parent = upgradeFolder
	buildHouseStructure(houseFolder, origin + HOUSE_LOT_OFFSET, tier)

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
	buildStudioStations(plotFolder, origin + HOUSE_LOT_OFFSET)
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

	local base = PLOT_ORIGINS[index] + HOUSE_LOT_OFFSET
	for _, layoutEntry in ipairs(STUDIO_LAYOUT) do
		if layoutEntry.name == "NewProject" then
			for _, config in ipairs(STATION_CONFIGS) do
				if config.name == "NewProject" then
					buildStationMonitorRig(plotFolder, base, config, tier, layoutEntry.x, layoutEntry.z)
					return
				end
			end
		end
	end
end

return PlotManager

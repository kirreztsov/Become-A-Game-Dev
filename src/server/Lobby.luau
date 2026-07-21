local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local PlotManager = require(script.Parent.PlotManager)

-- The shared arrival hub -- confirmed against RoTube Life 2's actual
-- structure ("the Park is where all players initially spawn... a
-- mailbox lets you select which Home to visit"). Everyone spawns here,
-- then a kiosk prompt sends each player to their own already-assigned
-- studio -- there's no home *choice* in this game (one studio per
-- player, upgraded in place), so one prompt is enough, no mailbox menu.
-- The area around the plaza reads as a small city block: a road with
-- moving cars, a skyscraper skyline, and a couple of background houses.
local Lobby = {}

local FLOOR_TOP = 1
local LOBBY_ORIGIN = Vector3.new(80, 0, -100)
local LOBBY_SIZE = 70

local ACCENT_COLOR = Color3.fromRGB(140, 92, 255)
local GOLD_COLOR = Color3.fromRGB(255, 209, 102)
local DARK_TRIM_COLOR = Color3.fromRGB(30, 22, 44)

local ROAD_Z = -45 -- offset from LOBBY_ORIGIN.Z; south of the plaza
local ROAD_WIDTH = 16
local ROAD_HALF_LENGTH = 110

-- A second road crossing Main Street, running north (toward the plot
-- neighborhoods, which start around world Z = -30) so the city reaches
-- toward the rest of the map instead of stopping at the plaza's edge.
-- Offset well east of the plaza (which has half-size 35) so the road
-- doesn't cut through the plaza itself -- it originally did, at X = 0,
-- before this was caught and fixed.
local CROSS_ROAD_X = 70 -- offset from LOBBY_ORIGIN.X
local CROSS_ROAD_HALF_LENGTH = 150

local activeCars = {}

local lobbySpawnPoint

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

local function buildWelcomeSign(lobbyFolder)
	-- Post stops exactly where the backing's bottom edge is (backing is
	-- 6 tall centered at FLOOR_TOP + 9, so its bottom is FLOOR_TOP + 6) so
	-- it doesn't rise up over the painted text.
	local signPost = makePart("WelcomeSignPost", Vector3.new(0.6, 6, 0.6), LOBBY_ORIGIN + Vector3.new(0, FLOOR_TOP + 3, -22), DARK_TRIM_COLOR, Enum.Material.Metal, lobbyFolder)

	local backing = makePart("WelcomeSignBacking", Vector3.new(20, 6, 0.5), LOBBY_ORIGIN + Vector3.new(0, FLOOR_TOP + 9, -22), ACCENT_COLOR, Enum.Material.SmoothPlastic, lobbyFolder)
	backing.CanCollide = false

	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "WelcomeDisplay"
	surfaceGui.Face = Enum.NormalId.Front
	surfaceGui.CanvasSize = Vector2.new(700, 200)
	surfaceGui.LightInfluence = 0
	surfaceGui.Parent = backing

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.6, 0)
	title.BackgroundTransparency = 1
	title.Text = "\240\159\142\174 Become a Game Developer"
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Parent = surfaceGui

	local subtitle = Instance.new("TextLabel")
	subtitle.Size = UDim2.new(1, 0, 0.4, 0)
	subtitle.Position = UDim2.fromScale(0, 0.6)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "Head to the kiosk to visit your studio!"
	subtitle.Font = Enum.Font.GothamMedium
	subtitle.TextScaled = true
	subtitle.TextColor3 = GOLD_COLOR
	subtitle.Parent = surfaceGui
end

local function buildStudioKiosk(lobbyFolder)
	local kiosk = makePart("StudioKiosk", Vector3.new(3, 4, 1.2), LOBBY_ORIGIN + Vector3.new(0, FLOOR_TOP + 2, 0), Color3.fromRGB(230, 222, 208), Enum.Material.SmoothPlastic, lobbyFolder)
	local screen = makePart("StudioKioskScreen", Vector3.new(2.4, 2, 0.1), LOBBY_ORIGIN + Vector3.new(0, FLOOR_TOP + 2.6, -0.65), GOLD_COLOR, Enum.Material.Neon, lobbyFolder)
	screen.CanCollide = false

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GoToStudioPrompt"
	prompt.ActionText = "Go to My Studio"
	prompt.ObjectText = "Studio Kiosk"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 10
	prompt.Parent = screen

	-- A real sign board above the kiosk (not a floating BillboardGui),
	-- readable from either direction.
	local signBoard = makePart("StudioKioskSign", Vector3.new(3.4, 1, 0.2), LOBBY_ORIGIN + Vector3.new(0, FLOOR_TOP + 4.5, 0), DARK_TRIM_COLOR, Enum.Material.SmoothPlastic, lobbyFolder)
	signBoard.CanCollide = false

	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local surfaceGui = Instance.new("SurfaceGui")
		surfaceGui.Name = "SignDisplay" .. face.Name
		surfaceGui.Face = face
		surfaceGui.CanvasSize = Vector2.new(340, 100)
		surfaceGui.LightInfluence = 0
		surfaceGui.Parent = signBoard

		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Text = "\240\159\143\160 My Studio"
		text.Font = Enum.Font.FredokaOne
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(255, 255, 255)
		text.Parent = surfaceGui
	end
end

local function buildLandscaping(lobbyFolder)
	local halfSize = LOBBY_SIZE / 2
	local treeSpots = {
		Vector3.new(-halfSize + 6, 0, -halfSize + 6),
		Vector3.new(halfSize - 6, 0, -halfSize + 6),
		Vector3.new(-halfSize + 6, 0, halfSize - 6),
		Vector3.new(halfSize - 6, 0, halfSize - 6),
	}

	for i, spot in ipairs(treeSpots) do
		local trunk = makePart("TreeTrunk" .. i, Vector3.new(1, 4, 1), LOBBY_ORIGIN + Vector3.new(spot.X, FLOOR_TOP + 2, spot.Z), Color3.fromRGB(90, 60, 40), Enum.Material.Wood, lobbyFolder)
		local leaves = makePart("TreeLeaves" .. i, Vector3.new(4, 4, 4), LOBBY_ORIGIN + Vector3.new(spot.X, FLOOR_TOP + 5, spot.Z), Color3.fromRGB(58, 122, 74), Enum.Material.Grass, lobbyFolder)
		leaves.CanCollide = false
		trunk.Name = "TreeTrunk" .. i
	end

	local benchSpots = { -10, 10 }
	for i, x in ipairs(benchSpots) do
		makePart("Bench" .. i, Vector3.new(4, 1, 1.4), LOBBY_ORIGIN + Vector3.new(x, FLOOR_TOP + 0.9, 10), Color3.fromRGB(150, 120, 90), Enum.Material.WoodPlanks, lobbyFolder)
	end
end

-- Main Street: a real road along the south edge of the plaza, with
-- sidewalks and a dashed center line, so the plaza reads as a city
-- block rather than an isolated park.
local function buildRoad(lobbyFolder)
	local roadLength = ROAD_HALF_LENGTH * 2
	makePart("MainStreetRoad", Vector3.new(roadLength, 0.4, ROAD_WIDTH), LOBBY_ORIGIN + Vector3.new(0, FLOOR_TOP + 0.2, ROAD_Z), Color3.fromRGB(58, 58, 62), Enum.Material.Asphalt, lobbyFolder)

	local sidewalkWidth = 5
	makePart("SidewalkNorth", Vector3.new(roadLength, 0.5, sidewalkWidth), LOBBY_ORIGIN + Vector3.new(0, FLOOR_TOP + 0.25, ROAD_Z + ROAD_WIDTH / 2 + sidewalkWidth / 2), Color3.fromRGB(190, 190, 185), Enum.Material.Concrete, lobbyFolder)
	makePart("SidewalkSouth", Vector3.new(roadLength, 0.5, sidewalkWidth), LOBBY_ORIGIN + Vector3.new(0, FLOOR_TOP + 0.25, ROAD_Z - ROAD_WIDTH / 2 - sidewalkWidth / 2), Color3.fromRGB(190, 190, 185), Enum.Material.Concrete, lobbyFolder)

	-- Dashed center line
	local dashCount = math.floor(roadLength / 8)
	for i = 0, dashCount do
		local dashX = -ROAD_HALF_LENGTH + i * 8
		local dash = makePart("RoadDash" .. i, Vector3.new(3, 0.45, 0.6), LOBBY_ORIGIN + Vector3.new(dashX, FLOOR_TOP + 0.21, ROAD_Z), Color3.fromRGB(255, 224, 110), Enum.Material.SmoothPlastic, lobbyFolder)
		dash.CanCollide = false
	end
end

-- Cross Street: perpendicular to Main Street, running north toward the
-- plot neighborhoods (which start around world Z = -30) so the city
-- reaches further across the map instead of stopping at one road.
local function buildCrossRoad(lobbyFolder)
	local roadLength = CROSS_ROAD_HALF_LENGTH * 2
	makePart("CrossStreetRoad", Vector3.new(ROAD_WIDTH, 0.4, roadLength), LOBBY_ORIGIN + Vector3.new(CROSS_ROAD_X, FLOOR_TOP + 0.2, 0), Color3.fromRGB(58, 58, 62), Enum.Material.Asphalt, lobbyFolder)

	local sidewalkWidth = 5
	makePart("CrossSidewalkEast", Vector3.new(sidewalkWidth, 0.5, roadLength), LOBBY_ORIGIN + Vector3.new(CROSS_ROAD_X + ROAD_WIDTH / 2 + sidewalkWidth / 2, FLOOR_TOP + 0.25, 0), Color3.fromRGB(190, 190, 185), Enum.Material.Concrete, lobbyFolder)
	makePart("CrossSidewalkWest", Vector3.new(sidewalkWidth, 0.5, roadLength), LOBBY_ORIGIN + Vector3.new(CROSS_ROAD_X - ROAD_WIDTH / 2 - sidewalkWidth / 2, FLOOR_TOP + 0.25, 0), Color3.fromRGB(190, 190, 185), Enum.Material.Concrete, lobbyFolder)

	local dashCount = math.floor(roadLength / 8)
	for i = 0, dashCount do
		local dashZ = -CROSS_ROAD_HALF_LENGTH + i * 8
		local dash = makePart("CrossRoadDash" .. i, Vector3.new(0.6, 0.45, 3), LOBBY_ORIGIN + Vector3.new(CROSS_ROAD_X, FLOOR_TOP + 0.21, dashZ), Color3.fromRGB(255, 224, 110), Enum.Material.SmoothPlastic, lobbyFolder)
		dash.CanCollide = false
	end
end

-- A circular roundabout where Main Street meets Cross Street. Built from
-- two flat cylinder "discs" (a Roblox Part with Shape = Cylinder, rotated
-- 90 degrees around Z, becomes a flat disc rather than a standing wheel
-- -- verified live in Studio with an isolated test part before using it
-- here). The disc is wide enough to cover the underlying "+" of straight
-- road beneath it, so the junction reads as a real circular intersection.
local function buildRoundabout(lobbyFolder)
	local center = LOBBY_ORIGIN + Vector3.new(CROSS_ROAD_X, 0, ROAD_Z)

	local ring = Instance.new("Part")
	ring.Name = "RoundaboutRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.5, 38, 38)
	ring.CFrame = CFrame.new(center + Vector3.new(0, FLOOR_TOP + 0.45, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Anchored = true
	ring.CanCollide = true
	ring.Color = Color3.fromRGB(58, 58, 62)
	ring.Material = Enum.Material.Asphalt
	ring.Parent = lobbyFolder

	local island = Instance.new("Part")
	island.Name = "RoundaboutIsland"
	island.Shape = Enum.PartType.Cylinder
	island.Size = Vector3.new(0.7, 16, 16)
	island.CFrame = CFrame.new(center + Vector3.new(0, FLOOR_TOP + 0.75, 0)) * CFrame.Angles(0, 0, math.rad(90))
	island.Anchored = true
	island.CanCollide = true
	island.Color = Color3.fromRGB(90, 165, 90)
	island.Material = Enum.Material.Grass
	island.Parent = lobbyFolder

	local trunk = makePart("RoundaboutTreeTrunk", Vector3.new(1, 5, 1), center + Vector3.new(0, FLOOR_TOP + 2.5, 0), Color3.fromRGB(90, 60, 40), Enum.Material.Wood, lobbyFolder)
	local leaves = makePart("RoundaboutTreeLeaves", Vector3.new(5, 5, 5), center + Vector3.new(0, FLOOR_TOP + 6, 0), Color3.fromRGB(58, 122, 74), Enum.Material.Grass, lobbyFolder)
	leaves.CanCollide = false
end

-- A basketball court and small pool in the corridor between the plaza
-- and Cross Street, for the recreational-area flavor from the reference.
local function buildRecreationArea(lobbyFolder)
	local courtCenter = LOBBY_ORIGIN + Vector3.new(46, 0, -10)
	makePart("BasketballCourt", Vector3.new(16, 0.3, 9), courtCenter + Vector3.new(0, FLOOR_TOP + 0.15, 0), Color3.fromRGB(180, 110, 70), Enum.Material.SmoothPlastic, lobbyFolder)

	local centerLine = makePart("CourtCenterLine", Vector3.new(0.3, 0.32, 9), courtCenter + Vector3.new(0, FLOOR_TOP + 0.16, 0), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, lobbyFolder)
	centerLine.CanCollide = false

	local circle = Instance.new("Part")
	circle.Name = "CourtCenterCircle"
	circle.Shape = Enum.PartType.Cylinder
	circle.Size = Vector3.new(0.34, 3, 3)
	circle.CFrame = CFrame.new(courtCenter + Vector3.new(0, FLOOR_TOP + 0.17, 0)) * CFrame.Angles(0, 0, math.rad(90))
	circle.Anchored = true
	circle.CanCollide = false
	circle.Color = Color3.fromRGB(255, 255, 255)
	circle.Material = Enum.Material.SmoothPlastic
	circle.Parent = lobbyFolder

	for _, side in ipairs({ -1, 1 }) do
		makePart("HoopPole" .. side, Vector3.new(0.4, 8, 0.4), courtCenter + Vector3.new(side * 7.6, FLOOR_TOP + 4, 0), DARK_TRIM_COLOR, Enum.Material.Metal, lobbyFolder)
		local backboard = makePart("HoopBackboard" .. side, Vector3.new(0.2, 2, 3), courtCenter + Vector3.new(side * 7.6, FLOOR_TOP + 7, 0), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, lobbyFolder)
		backboard.CanCollide = false
	end

	local poolCenter = LOBBY_ORIGIN + Vector3.new(46, 0, 15)
	makePart("PoolDeck", Vector3.new(18, 0.3, 10), poolCenter + Vector3.new(0, FLOOR_TOP + 0.15, 0), Color3.fromRGB(230, 222, 208), Enum.Material.Concrete, lobbyFolder)

	local water = makePart("PoolWater", Vector3.new(14, 0.35, 7), poolCenter + Vector3.new(0, FLOOR_TOP + 0.18, 0), Color3.fromRGB(70, 170, 220), Enum.Material.Glass, lobbyFolder)
	water.CanCollide = false
	water.Transparency = 0.25
end

local function buildPalmTree(lobbyFolder, name, position)
	makePart(name .. "Trunk", Vector3.new(0.8, 6, 0.8), position + Vector3.new(0, FLOOR_TOP + 3, 0), Color3.fromRGB(120, 90, 60), Enum.Material.Wood, lobbyFolder)

	for i = 1, 5 do
		local angle = (i - 1) * 72
		local frond = Instance.new("Part")
		frond.Name = name .. "Frond" .. i
		frond.Size = Vector3.new(3.5, 0.2, 1)
		frond.CFrame = CFrame.new(position + Vector3.new(0, FLOOR_TOP + 6.2, 0)) * CFrame.Angles(0, math.rad(angle), 0) * CFrame.new(1.6, 0, 0) * CFrame.Angles(0, 0, math.rad(15))
		frond.Anchored = true
		frond.CanCollide = false
		frond.Color = Color3.fromRGB(58, 140, 74)
		frond.Material = Enum.Material.Grass
		frond.Parent = lobbyFolder
	end
end

-- A beach + water edge on the west side of the plaza for the coastal
-- feel from the reference, since this game doesn't otherwise have one.
local function buildBeach(lobbyFolder)
	local halfSize = LOBBY_SIZE / 2
	local sandWidth = 26
	local sandCenterX = -halfSize - sandWidth / 2
	makePart("BeachSand", Vector3.new(sandWidth, 1, LOBBY_SIZE), LOBBY_ORIGIN + Vector3.new(sandCenterX, 0, 0), Color3.fromRGB(230, 205, 150), Enum.Material.Sand, lobbyFolder)

	local waterWidth = 60
	local waterCenterX = sandCenterX - sandWidth / 2 - waterWidth / 2
	local water = makePart("OceanWater", Vector3.new(waterWidth, 1, LOBBY_SIZE + 40), LOBBY_ORIGIN + Vector3.new(waterCenterX, -0.3, 0), Color3.fromRGB(60, 140, 200), Enum.Material.Glass, lobbyFolder)
	water.CanCollide = false
	water.Transparency = 0.2

	buildPalmTree(lobbyFolder, "Palm1", LOBBY_ORIGIN + Vector3.new(sandCenterX - 5, 0, -10))
	buildPalmTree(lobbyFolder, "Palm2", LOBBY_ORIGIN + Vector3.new(sandCenterX + 5, 0, 12))
end

-- A few simple boulder clusters around the outer edges for a
-- "surrounded by nature" feel instead of the city just stopping abruptly.
local function buildRockCluster(lobbyFolder, name, position)
	local rockSpecs = {
		{ size = Vector3.new(6, 5, 6), offset = Vector3.new(0, 0, 0) },
		{ size = Vector3.new(4, 3.5, 4), offset = Vector3.new(3, 0, 2) },
		{ size = Vector3.new(3, 2.5, 3), offset = Vector3.new(-2.5, 0, 3) },
	}

	for i, spec in ipairs(rockSpecs) do
		makePart(name .. i, spec.size, position + spec.offset + Vector3.new(0, spec.size.Y / 2, 0), Color3.fromRGB(120, 115, 110), Enum.Material.Rock, lobbyFolder)
	end
end

local function buildRockClusters(lobbyFolder)
	buildRockCluster(lobbyFolder, "RockClusterNorth", LOBBY_ORIGIN + Vector3.new(CROSS_ROAD_X, 0, 115))
	buildRockCluster(lobbyFolder, "RockClusterEast", LOBBY_ORIGIN + Vector3.new(150, 0, -45))
	buildRockCluster(lobbyFolder, "RockClusterSouth", LOBBY_ORIGIN + Vector3.new(-40, 0, -95))
end

-- The project's default 512x512 Baseplate was never restyled -- it still
-- looks like plain grey placeholder plastic everywhere outside the
-- plaza/road area. Recolor it to a neutral pavement tone so the rest of
-- the map reads as city ground instead of an obvious grey void.
local function restyleBaseplate()
	local baseplate = workspace:FindFirstChild("Baseplate")
	if not baseplate then
		return
	end

	baseplate.Material = Enum.Material.Concrete
	baseplate.Color = Color3.fromRGB(130, 130, 128)
end

local function buildTower(lobbyFolder, name, position, width, depth, height, color)
	makePart(name, Vector3.new(width, height, depth), position + Vector3.new(0, height / 2, 0), color, Enum.Material.Concrete, lobbyFolder)

	local bandCount = math.floor(height / 9)
	for band = 1, bandCount do
		local bandY = band * 9 - 3
		local windowBand = makePart(name .. "Window" .. band, Vector3.new(width - 1.5, 1, depth + 0.15), position + Vector3.new(0, bandY, 0), GOLD_COLOR, Enum.Material.Neon, lobbyFolder)
		windowBand.CanCollide = false
	end
end

-- A background skyline -- decorative, non-enterable towers giving the
-- plaza a "downtown" backdrop. Towers line both Main Street (south of
-- the plaza) and the cross street (which runs toward the plots), so the
-- skyline surrounds the plaza instead of sitting behind just one edge.
local function buildSkyline(lobbyFolder)
	local skylineZ = ROAD_Z - ROAD_WIDTH / 2 - 5 - 22
	local towerConfigs = {
		{ x = -90, z = skylineZ, width = 16, depth = 16, height = 50, color = Color3.fromRGB(225, 225, 228) },
		{ x = -65, z = skylineZ, width = 12, depth = 12, height = 34, color = Color3.fromRGB(200, 60, 55) },
		{ x = -40, z = skylineZ, width = 14, depth = 14, height = 64, color = Color3.fromRGB(210, 210, 214) },
		{ x = -12, z = skylineZ, width = 12, depth = 12, height = 42, color = ACCENT_COLOR },
		{ x = 16, z = skylineZ, width = 16, depth = 16, height = 78, color = Color3.fromRGB(230, 230, 232) },
		{ x = 46, z = skylineZ, width = 12, depth = 12, height = 38, color = Color3.fromRGB(200, 60, 55) },
		{ x = 72, z = skylineZ, width = 14, depth = 14, height = 56, color = Color3.fromRGB(215, 215, 218) },
		{ x = 98, z = skylineZ, width = 12, depth = 12, height = 30, color = ACCENT_COLOR },
	}

	for i, config in ipairs(towerConfigs) do
		buildTower(lobbyFolder, "Skyscraper" .. i, LOBBY_ORIGIN + Vector3.new(config.x, 0, config.z), config.width, config.depth, config.height, config.color)
	end

	-- Cross-street towers, north of the plaza, toward the plot area.
	local crossOffset = ROAD_WIDTH / 2 + 5 + 22
	local crossTowerConfigs = {
		{ x = CROSS_ROAD_X - crossOffset, z = 40, width = 14, depth = 14, height = 46, color = Color3.fromRGB(215, 215, 218) },
		{ x = CROSS_ROAD_X + crossOffset, z = 40, width = 12, depth = 12, height = 36, color = ACCENT_COLOR },
		{ x = CROSS_ROAD_X - crossOffset, z = 75, width = 12, depth = 12, height = 58, color = Color3.fromRGB(200, 60, 55) },
		{ x = CROSS_ROAD_X + crossOffset, z = 75, width = 16, depth = 16, height = 68, color = Color3.fromRGB(230, 230, 232) },
	}

	for i, config in ipairs(crossTowerConfigs) do
		buildTower(lobbyFolder, "CrossSkyscraper" .. i, LOBBY_ORIGIN + Vector3.new(config.x, 0, config.z), config.width, config.depth, config.height, config.color)
	end
end

-- A couple of small background houses for residential variety, distinct
-- from the players' own studios.
local function buildNeighborhoodHouses(lobbyFolder)
	local houseZ = ROAD_Z + ROAD_WIDTH / 2 + 5 + 12
	local houseSpots = { -85, -65 }

	for i, x in ipairs(houseSpots) do
		local position = LOBBY_ORIGIN + Vector3.new(x, 0, houseZ)
		local wallColor = Color3.fromRGB(235, 232, 225)
		makePart("NeighborHouse" .. i .. "Base", Vector3.new(10, 6, 8), position + Vector3.new(0, FLOOR_TOP + 3, 0), wallColor, Enum.Material.SmoothPlastic, lobbyFolder)
		makePart("NeighborHouse" .. i .. "Roof", Vector3.new(11, 1, 9), position + Vector3.new(0, FLOOR_TOP + 6.5, 0), Color3.fromRGB(240, 240, 238), Enum.Material.Concrete, lobbyFolder)
		local window = makePart("NeighborHouse" .. i .. "Window", Vector3.new(2.5, 2.5, 0.2), position + Vector3.new(0, FLOOR_TOP + 3.5, -4.05), Color3.fromRGB(180, 215, 230), Enum.Material.Glass, lobbyFolder)
		window.CanCollide = false
	end
end

-- axis "x" = drives along Main Street (varies X, fixed lane Z);
-- axis "z" = drives along Cross Street (varies Z, fixed lane X).
local CAR_CONFIGS = {
	{ color = Color3.fromRGB(200, 55, 50), axis = "x", startT = -70, lane = ROAD_Z + 3.5, half = ROAD_HALF_LENGTH },
	{ color = Color3.fromRGB(60, 110, 200), axis = "x", startT = 10, lane = ROAD_Z - 3.5, half = ROAD_HALF_LENGTH },
	{ color = Color3.fromRGB(235, 232, 225), axis = "x", startT = 55, lane = ROAD_Z + 3.5, half = ROAD_HALF_LENGTH },
	{ color = Color3.fromRGB(90, 180, 90), axis = "z", startT = -60, lane = CROSS_ROAD_X + 3.5, half = CROSS_ROAD_HALF_LENGTH },
	{ color = Color3.fromRGB(235, 209, 102), axis = "z", startT = 40, lane = CROSS_ROAD_X - 3.5, half = CROSS_ROAD_HALF_LENGTH },
}

local function buildCar(lobbyFolder, name, color)
	local carModel = Instance.new("Model")
	carModel.Name = name
	carModel.Parent = lobbyFolder

	local body = makePart("Body", Vector3.new(4, 1.2, 2), Vector3.new(0, FLOOR_TOP + 1.1, 0), color, Enum.Material.SmoothPlastic, carModel)
	local cabin = makePart("Cabin", Vector3.new(2, 0.8, 1.8), Vector3.new(0, FLOOR_TOP + 2, 0), color, Enum.Material.SmoothPlastic, carModel)
	cabin.CanCollide = false

	local wheelPositions = {
		Vector3.new(-1.3, FLOOR_TOP + 0.4, -0.9),
		Vector3.new(1.3, FLOOR_TOP + 0.4, -0.9),
		Vector3.new(-1.3, FLOOR_TOP + 0.4, 0.9),
		Vector3.new(1.3, FLOOR_TOP + 0.4, 0.9),
	}
	for i, offset in ipairs(wheelPositions) do
		local wheel = makePart("Wheel" .. i, Vector3.new(0.6, 0.6, 0.3), offset, DARK_TRIM_COLOR, Enum.Material.SmoothPlastic, carModel)
		wheel.CanCollide = false
	end

	carModel.PrimaryPart = body
	return carModel
end

local function buildCars(lobbyFolder)
	for i, config in ipairs(CAR_CONFIGS) do
		local carModel = buildCar(lobbyFolder, "Car" .. i, config.color)
		table.insert(activeCars, {
			model = carModel,
			t = config.startT,
			lane = config.lane,
			axis = config.axis,
			half = config.half,
			direction = 1,
			speed = 18 + i * 2,
		})
	end
end

local carAnimationConnection

local function startCarAnimation()
	if carAnimationConnection then
		carAnimationConnection:Disconnect()
	end

	carAnimationConnection = RunService.Heartbeat:Connect(function(dt)
		for _, car in ipairs(activeCars) do
			car.t += dt * car.speed * car.direction
			if car.t > car.half then
				car.t = car.half
				car.direction = -1
			elseif car.t < -car.half then
				car.t = -car.half
				car.direction = 1
			end

			local position, facingDeg
			if car.axis == "x" then
				-- The car body's long side (X=4) already runs along Main
				-- Street's X axis, so only a 180-degree flip is needed on
				-- reverse (not a 90-degree turn, which would point it off
				-- the road).
				position = LOBBY_ORIGIN + Vector3.new(car.t, FLOOR_TOP, car.lane)
				facingDeg = (car.direction > 0) and 0 or 180
			else
				-- Cross Street runs along Z, so the body needs a 90-degree
				-- base turn to align with it; verified live in Studio.
				position = LOBBY_ORIGIN + Vector3.new(car.lane, FLOOR_TOP, car.t)
				facingDeg = (car.direction > 0) and -90 or 90
			end

			car.model:PivotTo(CFrame.new(position) * CFrame.Angles(0, math.rad(facingDeg), 0))
		end
	end)
end

function Lobby.build()
	restyleBaseplate()

	local existing = workspace:FindFirstChild("Lobby")
	if existing then
		existing:Destroy()
	end

	local lobbyFolder = Instance.new("Folder")
	lobbyFolder.Name = "Lobby"
	lobbyFolder.Parent = workspace

	makePart("LobbyFloor", Vector3.new(LOBBY_SIZE, 1, LOBBY_SIZE), LOBBY_ORIGIN, Color3.fromRGB(90, 165, 90), Enum.Material.Grass, lobbyFolder)

	buildWelcomeSign(lobbyFolder)
	buildStudioKiosk(lobbyFolder)
	buildLandscaping(lobbyFolder)
	buildRoad(lobbyFolder)
	buildCrossRoad(lobbyFolder)
	buildRoundabout(lobbyFolder)
	buildRecreationArea(lobbyFolder)
	buildBeach(lobbyFolder)
	buildRockClusters(lobbyFolder)
	buildSkyline(lobbyFolder)
	buildNeighborhoodHouses(lobbyFolder)

	activeCars = {}
	buildCars(lobbyFolder)
	startCarAnimation()

	local spawnPart = Instance.new("Part")
	spawnPart.Name = "LobbySpawnPoint"
	spawnPart.Size = Vector3.new(1, 1, 1)
	spawnPart.Position = LOBBY_ORIGIN + Vector3.new(0, FLOOR_TOP + 3, 12)
	spawnPart.Anchored = true
	spawnPart.CanCollide = false
	spawnPart.Transparency = 1
	spawnPart.Parent = lobbyFolder
	lobbySpawnPoint = spawnPart
end

function Lobby.getSpawnPoint()
	return lobbySpawnPoint
end

function Lobby.start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt.Name ~= "GoToStudioPrompt" then
			return
		end

		local plotIndex = PlotManager.getPlayerPlotIndex(player)
		local plotFolder = PlotManager.getPlotFolder(plotIndex)
		if not plotFolder then
			return
		end

		local spawnPoint = plotFolder:FindFirstChild("PlotSpawnPoint")
		if not spawnPoint or not player.Character then
			return
		end

		player.Character:PivotTo(CFrame.new(spawnPoint.Position))
	end)
end

return Lobby

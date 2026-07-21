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
	local signPost = makePart("WelcomeSignPost", Vector3.new(0.6, 8, 0.6), LOBBY_ORIGIN + Vector3.new(0, FLOOR_TOP + 4, -22), DARK_TRIM_COLOR, Enum.Material.Metal, lobbyFolder)

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

-- A background skyline -- decorative, non-enterable towers south of the
-- road giving the plaza a "downtown" backdrop.
local function buildSkyline(lobbyFolder)
	local skylineZ = ROAD_Z - ROAD_WIDTH / 2 - 5 - 22
	local towerConfigs = {
		{ x = -90, width = 16, depth = 16, height = 50, color = Color3.fromRGB(225, 225, 228) },
		{ x = -65, width = 12, depth = 12, height = 34, color = Color3.fromRGB(200, 60, 55) },
		{ x = -40, width = 14, depth = 14, height = 64, color = Color3.fromRGB(210, 210, 214) },
		{ x = -12, width = 12, depth = 12, height = 42, color = ACCENT_COLOR },
		{ x = 16, width = 16, depth = 16, height = 78, color = Color3.fromRGB(230, 230, 232) },
		{ x = 46, width = 12, depth = 12, height = 38, color = Color3.fromRGB(200, 60, 55) },
		{ x = 72, width = 14, depth = 14, height = 56, color = Color3.fromRGB(215, 215, 218) },
		{ x = 98, width = 12, depth = 12, height = 30, color = ACCENT_COLOR },
	}

	for i, config in ipairs(towerConfigs) do
		local position = LOBBY_ORIGIN + Vector3.new(config.x, 0, skylineZ)
		makePart("Skyscraper" .. i, Vector3.new(config.width, config.height, config.depth), position + Vector3.new(0, config.height / 2, 0), config.color, Enum.Material.Concrete, lobbyFolder)

		local bandCount = math.floor(config.height / 9)
		for band = 1, bandCount do
			local bandY = band * 9 - 3
			local windowBand = makePart("Skyscraper" .. i .. "Window" .. band, Vector3.new(config.width - 1.5, 1, config.depth + 0.15), position + Vector3.new(0, bandY, 0), GOLD_COLOR, Enum.Material.Neon, lobbyFolder)
			windowBand.CanCollide = false
		end
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

local CAR_CONFIGS = {
	{ color = Color3.fromRGB(200, 55, 50), startT = -70, laneZ = ROAD_Z + 3.5 },
	{ color = Color3.fromRGB(60, 110, 200), startT = 10, laneZ = ROAD_Z - 3.5 },
	{ color = Color3.fromRGB(235, 232, 225), startT = 55, laneZ = ROAD_Z + 3.5 },
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
			laneZ = config.laneZ,
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
			if car.t > ROAD_HALF_LENGTH then
				car.t = ROAD_HALF_LENGTH
				car.direction = -1
			elseif car.t < -ROAD_HALF_LENGTH then
				car.t = -ROAD_HALF_LENGTH
				car.direction = 1
			end

			-- The car body's long side (X=4) already runs along the road's
			-- X axis, so only a 180-degree flip is needed when it reverses
			-- (not a 90-degree turn, which would point it off the road).
			local facingDeg = (car.direction > 0) and 0 or 180
			local position = LOBBY_ORIGIN + Vector3.new(car.t, FLOOR_TOP, car.laneZ)
			car.model:PivotTo(CFrame.new(position) * CFrame.Angles(0, math.rad(facingDeg), 0))
		end
	end)
end

function Lobby.build()
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

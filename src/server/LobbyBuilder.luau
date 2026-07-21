local LobbyBuilder = {}

local ROOM_SIZE = 70
local WALL_HEIGHT = 16
local WALL_THICKNESS = 1
local DOOR_WIDTH = 16
local FLOOR_TOP = 1

local PANEL_COLOR = Color3.fromRGB(36, 27, 54)
local ACCENT_COLOR = Color3.fromRGB(140, 92, 255)
local GOLD_COLOR = Color3.fromRGB(255, 209, 102)
local DARK_TRIM_COLOR = Color3.fromRGB(30, 22, 44)
local DESK_COLOR = Color3.fromRGB(58, 45, 78)
local CHAIR_COLOR = Color3.fromRGB(46, 36, 66)

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

local function buildFloor(lobbyFolder)
	makePart("RoomFloor", Vector3.new(ROOM_SIZE, 1, ROOM_SIZE), Vector3.new(0, 0.5, 0), PANEL_COLOR, nil, lobbyFolder)
end

local function buildWalls(lobbyFolder)
	local half = ROOM_SIZE / 2
	local wallCenterY = FLOOR_TOP + WALL_HEIGHT / 2
	local trimCenterY = FLOOR_TOP + WALL_HEIGHT

	makePart("WallNorth", Vector3.new(ROOM_SIZE, WALL_HEIGHT, WALL_THICKNESS), Vector3.new(0, wallCenterY, half), PANEL_COLOR, nil, lobbyFolder)
	makePart("WallEast", Vector3.new(WALL_THICKNESS, WALL_HEIGHT, ROOM_SIZE), Vector3.new(half, wallCenterY, 0), PANEL_COLOR, nil, lobbyFolder)
	makePart("WallWest", Vector3.new(WALL_THICKNESS, WALL_HEIGHT, ROOM_SIZE), Vector3.new(-half, wallCenterY, 0), PANEL_COLOR, nil, lobbyFolder)

	-- South wall has a doorway gap in the middle, built as two segments
	local segmentWidth = (ROOM_SIZE - DOOR_WIDTH) / 2
	local segmentOffsetX = DOOR_WIDTH / 2 + segmentWidth / 2
	makePart("WallSouthA", Vector3.new(segmentWidth, WALL_HEIGHT, WALL_THICKNESS), Vector3.new(-segmentOffsetX, wallCenterY, -half), PANEL_COLOR, nil, lobbyFolder)
	makePart("WallSouthB", Vector3.new(segmentWidth, WALL_HEIGHT, WALL_THICKNESS), Vector3.new(segmentOffsetX, wallCenterY, -half), PANEL_COLOR, nil, lobbyFolder)

	-- Violet neon trim strip along the top of each wall
	makePart("TrimNorth", Vector3.new(ROOM_SIZE, 0.6, WALL_THICKNESS + 0.2), Vector3.new(0, trimCenterY, half), ACCENT_COLOR, Enum.Material.Neon, lobbyFolder)
	makePart("TrimEast", Vector3.new(WALL_THICKNESS + 0.2, 0.6, ROOM_SIZE), Vector3.new(half, trimCenterY, 0), ACCENT_COLOR, Enum.Material.Neon, lobbyFolder)
	makePart("TrimWest", Vector3.new(WALL_THICKNESS + 0.2, 0.6, ROOM_SIZE), Vector3.new(-half, trimCenterY, 0), ACCENT_COLOR, Enum.Material.Neon, lobbyFolder)
end

local function buildSign(lobbyFolder)
	local half = ROOM_SIZE / 2
	local signCenterY = FLOOR_TOP + WALL_HEIGHT - 3

	local signBacking = makePart("SignBacking", Vector3.new(16, 4, 0.5), Vector3.new(0, signCenterY, half - 0.3), ACCENT_COLOR, Enum.Material.Neon, lobbyFolder)
	signBacking.CanCollide = false

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "SignText"
	billboard.Size = UDim2.fromOffset(300, 60)
	billboard.AlwaysOnTop = true
	billboard.Parent = signBacking

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "\240\159\142\174 GAME STUDIO"
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Parent = billboard

	local glow = Instance.new("PointLight")
	glow.Color = ACCENT_COLOR
	glow.Range = 24
	glow.Brightness = 2
	glow.Parent = signBacking
end

local function buildDesk(lobbyFolder)
	local deskTopSurfaceY = FLOOR_TOP + 2
	local legHeight = 2
	local legCenterY = FLOOR_TOP + legHeight / 2
	local deskCenterY = deskTopSurfaceY + 0.25

	makePart("DeskTop", Vector3.new(6, 0.5, 3), Vector3.new(-12, deskCenterY, 12), DESK_COLOR, nil, lobbyFolder)
	makePart("DeskLegA", Vector3.new(0.4, legHeight, 0.4), Vector3.new(-14.6, legCenterY, 13), DARK_TRIM_COLOR, nil, lobbyFolder)
	makePart("DeskLegB", Vector3.new(0.4, legHeight, 0.4), Vector3.new(-9.4, legCenterY, 13), DARK_TRIM_COLOR, nil, lobbyFolder)
	makePart("DeskLegC", Vector3.new(0.4, legHeight, 0.4), Vector3.new(-14.6, legCenterY, 11), DARK_TRIM_COLOR, nil, lobbyFolder)
	makePart("DeskLegD", Vector3.new(0.4, legHeight, 0.4), Vector3.new(-9.4, legCenterY, 11), DARK_TRIM_COLOR, nil, lobbyFolder)

	local deskTopSurfaceTopY = deskTopSurfaceY + 0.5
	local monitorHeight = 1.6
	local monitorCenterY = deskTopSurfaceTopY + monitorHeight / 2
	makePart("Monitor", Vector3.new(2.2, monitorHeight, 0.2), Vector3.new(-12, monitorCenterY, 12.8), DARK_TRIM_COLOR, nil, lobbyFolder)
	local screen = makePart("MonitorScreen", Vector3.new(2, monitorHeight - 0.2, 0.05), Vector3.new(-12, monitorCenterY, 12.7), GOLD_COLOR, Enum.Material.Neon, lobbyFolder)
	screen.CanCollide = false

	local workersPrompt = Instance.new("ProximityPrompt")
	workersPrompt.Name = "WorkersPrompt"
	workersPrompt.ActionText = "Manage Workers"
	workersPrompt.ObjectText = "Computer"
	workersPrompt.HoldDuration = 0.5
	workersPrompt.MaxActivationDistance = 10
	workersPrompt.Parent = screen

	-- Chair sits in front of the desk (south side, facing the monitor across the desk)
	local chairHeight = 2.4
	makePart("Chair", Vector3.new(2, chairHeight, 2), Vector3.new(-12, FLOOR_TOP + chairHeight / 2, 9), CHAIR_COLOR, nil, lobbyFolder)
end

local STATION_CONFIGS = {
	{ name = "NewProject", label = "\240\159\134\149 NEW PROJECT", deskX = 12, deskZ = 12, monitorColor = GOLD_COLOR },
	{ name = "Coding", label = "\226\154\161 CODING", deskX = -25, deskZ = -15, monitorColor = ACCENT_COLOR },
	{ name = "MapBuilding", label = "\240\159\151\186\239\184\143 MAP BUILDING", deskX = 0, deskZ = -20, monitorColor = ACCENT_COLOR },
	{ name = "Testing", label = "\226\156\168 TESTING", deskX = 25, deskZ = -15, monitorColor = ACCENT_COLOR },
}

local function buildStation(lobbyFolder, config)
	local deskTopSurfaceY = FLOOR_TOP + 2
	local legHeight = 2
	local legCenterY = FLOOR_TOP + legHeight / 2
	local deskCenterY = deskTopSurfaceY + 0.25
	local x, z = config.deskX, config.deskZ

	makePart(config.name .. "DeskTop", Vector3.new(6, 0.5, 3), Vector3.new(x, deskCenterY, z), DESK_COLOR, nil, lobbyFolder)
	makePart(config.name .. "DeskLegA", Vector3.new(0.4, legHeight, 0.4), Vector3.new(x - 2.6, legCenterY, z + 1), DARK_TRIM_COLOR, nil, lobbyFolder)
	makePart(config.name .. "DeskLegB", Vector3.new(0.4, legHeight, 0.4), Vector3.new(x + 2.6, legCenterY, z + 1), DARK_TRIM_COLOR, nil, lobbyFolder)
	makePart(config.name .. "DeskLegC", Vector3.new(0.4, legHeight, 0.4), Vector3.new(x - 2.6, legCenterY, z - 1), DARK_TRIM_COLOR, nil, lobbyFolder)
	makePart(config.name .. "DeskLegD", Vector3.new(0.4, legHeight, 0.4), Vector3.new(x + 2.6, legCenterY, z - 1), DARK_TRIM_COLOR, nil, lobbyFolder)

	local deskTopSurfaceTopY = deskTopSurfaceY + 0.5
	local monitorHeight = 1.6
	local monitorCenterY = deskTopSurfaceTopY + monitorHeight / 2
	makePart(config.name .. "Monitor", Vector3.new(2.2, monitorHeight, 0.2), Vector3.new(x, monitorCenterY, z + 0.8), DARK_TRIM_COLOR, nil, lobbyFolder)
	local screen = makePart(config.name .. "MonitorScreen", Vector3.new(2, monitorHeight - 0.2, 0.05), Vector3.new(x, monitorCenterY, z + 0.7), config.monitorColor, Enum.Material.Neon, lobbyFolder)
	screen.CanCollide = false

	local seat = Instance.new("Seat")
	seat.Name = config.name .. "Seat"
	seat.Size = Vector3.new(2, 2.4, 2)
	seat.Position = Vector3.new(x, FLOOR_TOP + 1.2, z - 3)
	seat.Anchored = true
	seat.Material = Enum.Material.SmoothPlastic
	seat.Color = CHAIR_COLOR
	seat.Parent = lobbyFolder

	local labelAnchor = Instance.new("Part")
	labelAnchor.Name = config.name .. "LabelAnchor"
	labelAnchor.Size = Vector3.new(0.1, 0.1, 0.1)
	labelAnchor.Position = Vector3.new(x, monitorCenterY + 1.5, z + 0.7)
	labelAnchor.Transparency = 1
	labelAnchor.Anchored = true
	labelAnchor.CanCollide = false
	labelAnchor.Parent = lobbyFolder

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(220, 40)
	billboard.AlwaysOnTop = true
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

local function buildStations(lobbyFolder)
	for _, config in ipairs(STATION_CONFIGS) do
		buildStation(lobbyFolder, config)
	end
end

local function buildTrendsWallSign(lobbyFolder)
	local half = ROOM_SIZE / 2
	local signCenterY = FLOOR_TOP + WALL_HEIGHT - 4

	local backing = makePart("TrendsSignBacking", Vector3.new(0.5, 6, 14), Vector3.new(half - 0.3, signCenterY, 0), ACCENT_COLOR, Enum.Material.Neon, lobbyFolder)
	backing.CanCollide = false

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TrendsDisplay"
	billboard.Size = UDim2.fromOffset(360, 160)
	billboard.AlwaysOnTop = true
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

local function buildSpawn(lobbyFolder)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(0, FLOOR_TOP + 0.5, 0)
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Color = CHAIR_COLOR
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = lobbyFolder

	local glow = Instance.new("PointLight")
	glow.Color = ACCENT_COLOR
	glow.Range = 16
	glow.Brightness = 1.5
	glow.Parent = spawn
end

function LobbyBuilder.build()
	local existing = workspace:FindFirstChild("Lobby")
	if existing then
		existing:Destroy()
	end

	local lobbyFolder = Instance.new("Folder")
	lobbyFolder.Name = "Lobby"
	lobbyFolder.Parent = workspace

	buildFloor(lobbyFolder)
	buildWalls(lobbyFolder)
	buildSign(lobbyFolder)
	buildDesk(lobbyFolder)
	buildSpawn(lobbyFolder)
	buildStations(lobbyFolder)
	buildTrendsWallSign(lobbyFolder)
end

return LobbyBuilder

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

	-- Chair sits in front of the desk (south side, facing the monitor across the desk)
	local chairHeight = 2.4
	makePart("Chair", Vector3.new(2, chairHeight, 2), Vector3.new(-12, FLOOR_TOP + chairHeight / 2, 9), CHAIR_COLOR, nil, lobbyFolder)
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
end

return LobbyBuilder

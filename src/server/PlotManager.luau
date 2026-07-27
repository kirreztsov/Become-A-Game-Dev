local ProximityPromptService = game:GetService("ProximityPromptService")
local Players = game:GetService("Players")
local GameData = require(game.ReplicatedStorage.Shared.GameData)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local DecorBuilder = require(game.ReplicatedStorage.Shared.DecorBuilder)
local PlayerData = require(script.Parent.PlayerData)
local StudioModels = require(script.Parent.StudioModels)

local PlotManager = {}

local FLOOR_TOP = 1
local PLOT_SIZE_X = 70
local PLOT_SIZE_Z = 90
local HOUSE_LOT_OFFSET = Vector3.new(0, 0, 45)

-- The plot is now just the studio building itself (a futuristic tower).
-- These are its interior half-extents and per-floor height. Sized so the
-- fixed STUDIO_LAYOUT (stations spanning x -10..10, z -5..8.5) fits inside
-- every floor with an aisle and an elevator corner to spare.
local BUILDING_HALF_W = 24 -- 48 wide: a grander, less tall-and-narrow studio
local BUILDING_HALF_D = 16
local WALL_HEIGHT = 12
local SLAB_THICKNESS = 1
local FLOOR_HEIGHT = WALL_HEIGHT + SLAB_THICKNESS -- 13; vertical spacing between floor slabs
local DOOR_WIDTH = 4
local DOOR_HEIGHT = 6

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

-- Places a Blender interior prop (Desk / Chair) with its base at worldBasePos,
-- scaled to `targetHeight` studs, painted by name. Returns the model or nil.
local function placeInteriorProp(name, parent, worldBasePos, targetHeight, yaw, paint)
	local model = StudioModels.get(name)
	if not model then
		return nil
	end
	local _, size = model:GetBoundingBox()
	if size.Y > 0 then
		model:ScaleTo(model:GetScale() * (targetHeight / size.Y))
	end
	model:PivotTo(CFrame.new(worldBasePos) * CFrame.Angles(0, yaw or 0, 0))
	local cf, sz = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + Vector3.new(0, worldBasePos.Y - (cf.Position.Y - sz.Y / 2), 0))
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			paint(p)
			p.Anchored = true
		end
	end
	model.Parent = parent
	return model
end

-- Blender desk (top surface at floor+2.5, so the monitor still sits on it).
-- Returns true if a mesh was placed (caller skips the procedural desk).
local function placeDeskMesh(parent, origin, x, z, deskName)
	if not StudioModels.has("Desk") then
		return false
	end
	local m = placeInteriorProp("Desk", parent, origin + Vector3.new(x, FLOOR_TOP, z), 2.5, 0, function(p)
		if p.Name:find("Top") then
			p.Color, p.Material, p.CanCollide = DESK_COLOR, Enum.Material.Wood, true
		else
			p.Color, p.Material, p.CanCollide = DARK_TRIM_COLOR, Enum.Material.Metal, true
		end
	end)
	if m then
		m.Name = deskName
	end
	return m ~= nil
end

-- Blender office chair placed so its cushion lands at `center` (the seat spot).
-- Returns true if placed (caller skips the procedural chair visual).
local function placeChairMesh(parent, center, chairName)
	if not StudioModels.has("Chair") then
		return false
	end
	local m = placeInteriorProp("Chair", parent, center - Vector3.new(0, 1.2, 0), 3.2, 0, function(p)
		if p.Name:find("Seat") then
			p.Color, p.Material = CHAIR_COLOR, Enum.Material.Fabric
		else
			p.Color, p.Material = DARK_TRIM_COLOR, Enum.Material.Metal
		end
		p.CanCollide = false
	end)
	if m then
		m.Name = chairName
	end
	return m ~= nil
end

-- The plot is now just the building's own lot: a foundation pad under the
-- tower plus a short entrance apron reaching out toward the road (-Z),
-- rather than a big open yard. This is persistent (the ground floor always
-- has something to stand on even while the tower shell is rebuilt on
-- upgrade).
local function buildPlotFloor(plotFolder, origin)
	local base = origin + HOUSE_LOT_OFFSET
	local padW = BUILDING_HALF_W * 2 + 6
	local padD = BUILDING_HALF_D * 2 + 6
	makePart("PlotFloor", Vector3.new(padW, 1, padD), base + Vector3.new(0, FLOOR_TOP - 0.5, 0), Color3.fromRGB(176, 178, 184), Enum.Material.Concrete, plotFolder)

	-- Entrance apron + path out the front door toward the street.
	local apronDepth = 14
	makePart("EntranceApron", Vector3.new(DOOR_WIDTH + 8, 1, apronDepth), base + Vector3.new(0, FLOOR_TOP - 0.5, -BUILDING_HALF_D - apronDepth / 2), Color3.fromRGB(150, 150, 155), Enum.Material.Concrete, plotFolder)
end

-- Spawns just outside the studio door -- the studio (house) contains the
-- actual work stations, so that's where a player needs to be.
local function buildPlotSpawn(plotFolder, origin)
	local spawnPoint = Instance.new("Part")
	spawnPoint.Name = "PlotSpawnPoint"
	spawnPoint.Size = Vector3.new(1, 1, 1)
	spawnPoint.Position = origin + HOUSE_LOT_OFFSET + Vector3.new(0, FLOOR_TOP + 3, -BUILDING_HALF_D - 6)
	spawnPoint.Anchored = true
	spawnPoint.CanCollide = false
	spawnPoint.Transparency = 1
	spawnPoint.Parent = plotFolder
end

-- parent/namePrefix let the same desk be built on any floor: ground floor
-- uses parent = plotFolder and namePrefix = "" (so the client's direct-child
-- lookups keep working); upper floors use the rebuildable building folder
-- and a "F2_"-style prefix so their part names never collide. The
-- WorkersPrompt keeps its plain name on every floor since workers are a
-- single shared roster -- any floor's desk opens the same panel.
local function buildWorkersDesk(parent, origin, x, z, namePrefix)
	namePrefix = namePrefix or ""
	local deskTopSurfaceY = FLOOR_TOP + 2
	local legHeight = 2
	local legCenterY = FLOOR_TOP + legHeight / 2
	local deskCenterY = deskTopSurfaceY + 0.25

	if not placeDeskMesh(parent, origin, x, z, namePrefix .. "WorkersDesk") then
		makePart(namePrefix .. "WorkersDeskTop", Vector3.new(6, 0.5, 3), origin + Vector3.new(x, deskCenterY, z), DESK_COLOR, nil, parent)
		makePart(namePrefix .. "WorkersDeskLegA", Vector3.new(0.4, legHeight, 0.4), origin + Vector3.new(x - 2.6, legCenterY, z + 1), DARK_TRIM_COLOR, nil, parent)
		makePart(namePrefix .. "WorkersDeskLegB", Vector3.new(0.4, legHeight, 0.4), origin + Vector3.new(x + 2.6, legCenterY, z + 1), DARK_TRIM_COLOR, nil, parent)
		makePart(namePrefix .. "WorkersDeskLegC", Vector3.new(0.4, legHeight, 0.4), origin + Vector3.new(x - 2.6, legCenterY, z - 1), DARK_TRIM_COLOR, nil, parent)
		makePart(namePrefix .. "WorkersDeskLegD", Vector3.new(0.4, legHeight, 0.4), origin + Vector3.new(x + 2.6, legCenterY, z - 1), DARK_TRIM_COLOR, nil, parent)
	end

	local deskTopSurfaceTopY = deskTopSurfaceY + 0.5
	local monitorHeight = 1.6
	local standH = 1.0
	local monitorCenterY = deskTopSurfaceTopY + standH + monitorHeight / 2
	local dark = Color3.fromRGB(34, 36, 42)
	makePart(namePrefix .. "WorkersMonitorBase", Vector3.new(1.0, 0.18, 0.9), origin + Vector3.new(x, deskTopSurfaceTopY + 0.09, z + 0.85), dark, Enum.Material.Metal, parent)
	makePart(namePrefix .. "WorkersMonitorNeck", Vector3.new(0.35, standH, 0.35), origin + Vector3.new(x, deskTopSurfaceTopY + standH / 2, z + 0.85), dark, Enum.Material.Metal, parent)
	makePart(namePrefix .. "WorkersMonitor", Vector3.new(2.2, monitorHeight, 0.25), origin + Vector3.new(x, monitorCenterY, z + 0.85), dark, nil, parent)
	local screen = makePart(namePrefix .. "WorkersMonitorScreen", Vector3.new(1.85, monitorHeight - 0.35, 0.06), origin + Vector3.new(x, monitorCenterY, z + 0.71), GOLD_COLOR, Enum.Material.Neon, parent)
	screen.CanCollide = false

	local workersPrompt = Instance.new("ProximityPrompt")
	workersPrompt.Name = "WorkersPrompt"
	workersPrompt.ActionText = "Manage Workers"
	workersPrompt.ObjectText = "Computer"
	workersPrompt.HoldDuration = 0 -- instant tap, no holding
	workersPrompt.RequiresLineOfSight = false -- easy to trigger, no precise aiming
	workersPrompt.MaxActivationDistance = 14
	workersPrompt.Parent = screen

	local chairCenter = origin + Vector3.new(x, FLOOR_TOP + 1.3, z - 3)
	if not placeChairMesh(parent, chairCenter, namePrefix .. "WorkersChairModel") then
		makePart(namePrefix .. "WorkersChair", Vector3.new(2, 0.6, 2), chairCenter, CHAIR_COLOR, nil, parent)
		buildChairVisual(parent, namePrefix .. "Workers", chairCenter, CHAIR_COLOR)
	end
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
local function buildStationMonitorRig(parent, origin, config, tier, x, z, namePrefix)
	namePrefix = namePrefix or ""
	local rigName = namePrefix .. config.name .. "MonitorRig"
	local existingRig = parent:FindFirstChild(rigName)
	if existingRig then
		existingRig:Destroy()
	end

	local rig = Instance.new("Folder")
	rig.Name = rigName
	rig.Parent = parent

	local deskTopSurfaceTopY = FLOOR_TOP + 2 + 0.5

	local monitorHeight = 1.6 + (tier * 0.3)
	local monitorWidth = 2.2 + (tier * 0.4)
	local standH = 1.0
	local monitorCenterY = deskTopSurfaceTopY + standH + monitorHeight / 2
	local dark = Color3.fromRGB(34, 36, 42)

	-- Stand: a base foot on the desk + a neck up to the screen, so the monitor
	-- reads as a real monitor instead of a flat box sitting on the desk.
	makePart(namePrefix .. config.name .. "MonitorBase", Vector3.new(monitorWidth * 0.45, 0.18, 0.9), origin + Vector3.new(x, deskTopSurfaceTopY + 0.09, z + 0.85), dark, Enum.Material.Metal, rig)
	makePart(namePrefix .. config.name .. "MonitorNeck", Vector3.new(0.35, standH, 0.35), origin + Vector3.new(x, deskTopSurfaceTopY + standH / 2, z + 0.85), dark, Enum.Material.Metal, rig)
	-- Bezel body + glowing screen inset (a bit smaller, so the bezel shows).
	makePart(namePrefix .. config.name .. "Monitor", Vector3.new(monitorWidth, monitorHeight, 0.25), origin + Vector3.new(x, monitorCenterY, z + 0.85), dark, nil, rig)
	local screenColor = (tier > 0) and GOLD_COLOR or config.monitorColor
	local screen = makePart(namePrefix .. config.name .. "MonitorScreen", Vector3.new(monitorWidth - 0.35, monitorHeight - 0.35, 0.06), origin + Vector3.new(x, monitorCenterY, z + 0.71), screenColor, Enum.Material.Neon, rig)
	screen.CanCollide = false

	-- Every floor's NewProject monitor carries the PC upgrade prompt (the PC
	-- is a single shared tier, so any floor opens the same upgrade panel).
	if config.name == "NewProject" and tier < GameData.PCTierCount - 1 then
		local upgradePrompt = Instance.new("ProximityPrompt")
		upgradePrompt.Name = "PCUpgradePrompt"
		upgradePrompt.ActionText = "Upgrade PC"
		upgradePrompt.ObjectText = "Computer"
		upgradePrompt.HoldDuration = 0 -- instant tap, no holding
		upgradePrompt.RequiresLineOfSight = false -- easy to trigger, no precise aiming
		upgradePrompt.MaxActivationDistance = 14
		upgradePrompt.Parent = screen
	end
end

local function buildStation(parent, origin, config, x, z, namePrefix, monitorTier)
	namePrefix = namePrefix or ""
	monitorTier = monitorTier or 0
	local deskTopSurfaceY = FLOOR_TOP + 2
	local legHeight = 2
	local legCenterY = FLOOR_TOP + legHeight / 2
	local deskCenterY = deskTopSurfaceY + 0.25

	if not placeDeskMesh(parent, origin, x, z, namePrefix .. config.name .. "Desk") then
		makePart(namePrefix .. config.name .. "DeskTop", Vector3.new(6, 0.5, 3), origin + Vector3.new(x, deskCenterY, z), DESK_COLOR, nil, parent)
		makePart(namePrefix .. config.name .. "DeskLegA", Vector3.new(0.4, legHeight, 0.4), origin + Vector3.new(x - 2.6, legCenterY, z + 1), DARK_TRIM_COLOR, nil, parent)
		makePart(namePrefix .. config.name .. "DeskLegB", Vector3.new(0.4, legHeight, 0.4), origin + Vector3.new(x + 2.6, legCenterY, z + 1), DARK_TRIM_COLOR, nil, parent)
		makePart(namePrefix .. config.name .. "DeskLegC", Vector3.new(0.4, legHeight, 0.4), origin + Vector3.new(x - 2.6, legCenterY, z - 1), DARK_TRIM_COLOR, nil, parent)
		makePart(namePrefix .. config.name .. "DeskLegD", Vector3.new(0.4, legHeight, 0.4), origin + Vector3.new(x + 2.6, legCenterY, z - 1), DARK_TRIM_COLOR, nil, parent)
	end

	local deskTopSurfaceTopY = deskTopSurfaceY + 0.5
	local monitorHeight = 1.6
	-- Matches the raised monitor in buildStationMonitorRig (stand height 1.0)
	-- so the nameplate still sits just above the screen.
	local monitorCenterY = deskTopSurfaceTopY + 1.0 + monitorHeight / 2
	buildStationMonitorRig(parent, origin, config, monitorTier, x, z, namePrefix)

	local seatCenter = origin + Vector3.new(x, FLOOR_TOP + 1.2, z - 3)

	local seat = Instance.new("Seat")
	seat.Name = namePrefix .. config.name .. "Seat"
	seat.Size = Vector3.new(2, 2.4, 2)
	seat.Anchored = true
	seat.Material = Enum.Material.SmoothPlastic
	seat.Color = CHAIR_COLOR
	-- A seat's default facing is -Z; the monitor sits north (+Z) of this seat,
	-- so rotate 180 degrees to face the player toward it when they sit down.
	seat.CFrame = CFrame.new(seatCenter) * CFrame.Angles(0, math.rad(180), 0)
	seat.Parent = parent

	-- Decoration only -- the seat's own CFrame (what matters for sitting) is
	-- untouched. A Blender office chair replaces the blocky visual if synced;
	-- the functional Seat is hidden (still sittable) so the mesh cushion shows.
	if placeChairMesh(parent, seatCenter, namePrefix .. config.name .. "ChairModel") then
		seat.Transparency = 1
	else
		buildChairVisual(parent, namePrefix .. config.name, seatCenter, CHAIR_COLOR)
	end

	-- A real painted nameplate (not a floating BillboardGui) facing the
	-- seat, so it reads as a physical placard on the desk.
	local nameplate = makePart(namePrefix .. config.name .. "Nameplate", Vector3.new(2.2, 0.6, 0.1), origin + Vector3.new(x, monitorCenterY + 1.5, z + 0.7), DARK_TRIM_COLOR, Enum.Material.SmoothPlastic, parent)
	nameplate.CanCollide = false

	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "NameplateDisplay"
	surfaceGui.Face = Enum.NormalId.Front
	surfaceGui.CanvasSize = Vector2.new(300, 80)
	surfaceGui.LightInfluence = 0
	surfaceGui.Parent = nameplate

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = config.label
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.Parent = surfaceGui
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

local function buildStudioStations(parent, base, namePrefix, monitorTier)
	namePrefix = namePrefix or ""
	for _, entry in ipairs(STUDIO_LAYOUT) do
		if entry.name == "Workers" then
			buildWorkersDesk(parent, base, entry.x, entry.z, namePrefix)
		else
			for _, config in ipairs(STATION_CONFIGS) do
				if config.name == entry.name then
					buildStation(parent, base, config, entry.x, entry.z, namePrefix, monitorTier)
					break
				end
			end
		end
	end
end

-- A visible worker NPC SEATED on the chair facing the monitor (+Z), with a
-- keyboard in front, shirt-coloured by rarity and a floating "<Rarity> <Role>"
-- tag. `seatPos` is the world point at the seat base (Y = FLOOR_TOP). Arms are
-- named ...ArmL/ArmR so the typing animation can find them.
local function buildWorkerNPC(parent, prefix, seatPos, shirtColor, rarityName, role)
	local skin = Color3.fromRGB(240, 205, 165)
	local pants = Color3.fromRGB(60, 62, 74)
	local function part(sub, size, offset, color, mat)
		local p = makePart(prefix .. sub, size, seatPos + offset, color, mat or Enum.Material.SmoothPlastic, parent)
		p.CanCollide = false
		return p
	end
	-- Thighs forward (+Z), shins down -- the "sitting" shape.
	part("ThighL", Vector3.new(0.7, 0.7, 1.9), Vector3.new(-0.45, 1.8, 0.75), pants)
	part("ThighR", Vector3.new(0.7, 0.7, 1.9), Vector3.new(0.45, 1.8, 0.75), pants)
	part("ShinL", Vector3.new(0.7, 1.7, 0.7), Vector3.new(-0.45, 0.85, 1.6), pants)
	part("ShinR", Vector3.new(0.7, 1.7, 0.7), Vector3.new(0.45, 0.85, 1.6), pants)
	part("Torso", Vector3.new(2, 2.2, 1), Vector3.new(0, 3.05, 0), shirtColor)
	-- Arms reach forward toward the keyboard.
	part("ArmL", Vector3.new(0.6, 0.6, 1.9), Vector3.new(-1.1, 2.9, 0.9), shirtColor)
	part("ArmR", Vector3.new(0.6, 0.6, 1.9), Vector3.new(1.1, 2.9, 0.9), shirtColor)
	local head = part("Head", Vector3.new(1.3, 1.3, 1.3), Vector3.new(0, 4.55, 0.05), skin)
	-- eyes on the +Z face (facing the monitor)
	part("EyeL", Vector3.new(0.22, 0.22, 0.1), Vector3.new(-0.3, 4.65, 0.66), Color3.fromRGB(40, 40, 40))
	part("EyeR", Vector3.new(0.22, 0.22, 0.1), Vector3.new(0.3, 4.65, 0.66), Color3.fromRGB(40, 40, 40))
	part("Hair", Vector3.new(1.4, 0.5, 1.4), Vector3.new(0, 5.25, 0), Color3.fromRGB(70, 50, 40))
	-- keyboard on the desk in front of the hands
	part("Keyboard", Vector3.new(2.2, 0.2, 1), Vector3.new(0, 2.1, 2.0), Color3.fromRGB(34, 38, 48))
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(150, 40)
	bb.StudsOffset = Vector3.new(0, 3.5, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = head
	bb.Parent = head
	local tag = Instance.new("TextLabel")
	tag.Size = UDim2.fromScale(1, 1)
	tag.BackgroundTransparency = 1
	tag.Text = ("%s\n%s"):format(rarityName, role)
	tag.TextColor3 = shirtColor
	tag.Font = Enum.Font.FredokaOne
	tag.TextScaled = true
	tag.TextStrokeTransparency = 0.4
	tag.Parent = bb
end

-- Rebuild the visible worker NPCs for a player from their hired workers.
function PlotManager.refreshWorkerNPCs(player)
	local index = plotOfPlayer[player.UserId]
	local plotFolder = index and PlotManager.getPlotFolder(index)
	local data = PlayerData.get(player)
	if not (plotFolder and data) then
		return
	end
	local folder = plotFolder:FindFirstChild("WorkerNPCs")
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "WorkerNPCs"
	folder.Parent = plotFolder
	local base = PLOT_ORIGINS[index] + HOUSE_LOT_OFFSET
	-- Workers sit at their station on EVERY floor the studio has, not just the
	-- ground floor -- so a hired worker is visible wherever you are.
	local floorCount = (data.houseTier or 0) + 1
	for f = 0, floorCount - 1 do
		local floorBase = base + Vector3.new(0, f * FLOOR_HEIGHT, 0)
		for _, entry in ipairs(STUDIO_LAYOUT) do
			local worker = data.workers[entry.name]
			if worker and worker.hired then
				local info = GameData.getRarityInfo(worker.rarity)
				-- seat is 3 studs in front of the station desk (matches buildStation).
				local seatPos = floorBase + Vector3.new(entry.x, FLOOR_TOP, entry.z - 3)
				buildWorkerNPC(folder, ("%sWorkerF%d"):format(entry.name, f), seatPos, info.color, worker.rarity or "Common", entry.name)
			end
		end
	end
end

-- Bob a seated worker's arms up/down for `duration` seconds to look like they
-- are typing on the keyboard while auto-completing their phase.
function PlotManager.playWorkerTyping(player, role, duration)
	local index = plotOfPlayer[player.UserId]
	local plotFolder = index and PlotManager.getPlotFolder(index)
	local folder = plotFolder and plotFolder:FindFirstChild("WorkerNPCs")
	if not folder then
		return
	end
	-- This role's worker sits on every floor now, so bob ALL of its copies.
	local arms = {}
	for f = 0, 8 do
		local prefix = ("%sWorkerF%d"):format(role, f)
		local armL = folder:FindFirstChild(prefix .. "ArmL")
		local armR = folder:FindFirstChild(prefix .. "ArmR")
		if armL and armR then
			table.insert(arms, { armL, armL.CFrame, armR, armR.CFrame })
		end
	end
	if #arms == 0 then
		return
	end
	task.spawn(function()
		local steps = math.max(1, math.floor((duration or 3) / 0.1))
		for i = 1, steps do
			local down = (i % 2 == 0)
			for _, a in ipairs(arms) do
				if a[1].Parent and a[3].Parent then
					a[1].CFrame = a[2] * CFrame.new(0, down and -0.18 or 0.04, 0)
					a[3].CFrame = a[4] * CFrame.new(0, down and 0.04 or -0.18, 0)
				end
			end
			task.wait(0.1)
		end
		for _, a in ipairs(arms) do
			if a[1].Parent then
				a[1].CFrame = a[2]
			end
			if a[3].Parent then
				a[3].CFrame = a[4]
			end
		end
	end)
end

-- A Trends board mounted flat on a floor's back interior wall (no more
-- free-standing posts out in a yard, since the plot is now just the
-- building). Ground floor uses namePrefix "" so the client keeps finding
-- "TrendsSignBacking" as a direct child of the plot and driving its text.
local function buildTrendsSign(parent, base, namePrefix)
	namePrefix = namePrefix or ""
	local signCenterY = FLOOR_TOP + 8
	local backZ = BUILDING_HALF_D - 0.4

	local backing = makePart(namePrefix .. "TrendsSignBacking", Vector3.new(14, 5, 0.4), base + Vector3.new(0, signCenterY, backZ), ACCENT_COLOR, Enum.Material.SmoothPlastic, parent)
	backing.CanCollide = false

	-- The room is on the -Z side of the back wall, so the face pointing into
	-- the room (NormalId.Front = -Z) is the one that carries the display.
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "TrendsDisplay"
	surfaceGui.Face = Enum.NormalId.Front
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

-- Bright modern-mansion palette: warm white walls, wood accents, big bright
-- glass, warm interior light, gold trim. Real materials on big surfaces;
-- glow reserved for small warm lights only (no big neon slabs).
local WALL_WHITE = Color3.fromRGB(247, 244, 238)
local TRIM_WHITE = Color3.fromRGB(253, 251, 247)
local WOOD_COLOR = Color3.fromRGB(156, 116, 78)
local WOOD_DARK = Color3.fromRGB(120, 86, 56)
local GLASS_TINT = Color3.fromRGB(206, 227, 236)
local WARM_LIGHT = Color3.fromRGB(255, 240, 210)
local STONE_COLOR = Color3.fromRGB(226, 222, 214)

-- Each floor is a visually distinct storey rather than a repeated box:
-- its own wall colour + material, accent colour, floor finish and a
-- signature prop. Floor 1 = cozy warm home, Floor 2 = a warmer beige
-- creative loft, Floor 3 = a bright marble penthouse.
local FLOOR_THEMES = {
	[1] = {
		wall = Color3.fromRGB(247, 244, 238), wallMat = Enum.Material.SmoothPlastic,
		accent = Color3.fromRGB(226, 190, 122), slab = Color3.fromRGB(156, 116, 78), slabMat = Enum.Material.WoodPlanks,
		motif = "hearth",
	},
	[2] = {
		wall = Color3.fromRGB(228, 221, 204), wallMat = Enum.Material.SmoothPlastic,
		accent = Color3.fromRGB(203, 128, 92), slab = Color3.fromRGB(122, 88, 58), slabMat = Enum.Material.WoodPlanks,
		motif = "garden",
	},
	[3] = {
		wall = Color3.fromRGB(240, 238, 233), wallMat = Enum.Material.Marble,
		accent = Color3.fromRGB(230, 198, 132), slab = Color3.fromRGB(224, 220, 212), slabMat = Enum.Material.Marble,
		motif = "penthouse",
	},
}

local function floorTheme(f)
	return FLOOR_THEMES[math.clamp(f + 1, 1, #FLOOR_THEMES)]
end

-- Crisp white framing for corner columns, window mullions and door frames.
local FRAME_COLOR = TRIM_WHITE

local ELEVATOR_HALF = 2.5

local function buildElevatorPad(parent, base, f, targetFloor, direction, accent)
	local cornerX = (direction == "up") and (BUILDING_HALF_W - 4) or (-(BUILDING_HALF_W - 4))
	local cornerZ = BUILDING_HALF_D - 4
	local slabTop = FLOOR_TOP + f * FLOOR_HEIGHT
	local padName = "Floor" .. (f + 1) .. "_Elevator" .. (direction == "up" and "Up" or "Down")

	-- A tidy marble platform with a thin wood trim, not a glowing neon slab.
	local pad = makePart(padName, Vector3.new(ELEVATOR_HALF * 2, 0.3, ELEVATOR_HALF * 2), base + Vector3.new(cornerX, slabTop + 0.15, cornerZ), STONE_COLOR, Enum.Material.Marble, parent)
	pad.CanCollide = false
	local ring = makePart(padName .. "Ring", Vector3.new(ELEVATOR_HALF * 2 + 0.4, 0.12, ELEVATOR_HALF * 2 + 0.4), base + Vector3.new(cornerX, slabTop + 0.05, cornerZ), WOOD_DARK, Enum.Material.WoodPlanks, parent)
	ring.CanCollide = false

	-- Target: the same corner on the destination floor, at stand height.
	local targetWorld = base + Vector3.new(cornerX, FLOOR_TOP + targetFloor * FLOOR_HEIGHT + 3.5, cornerZ)
	pad:SetAttribute("TargetX", targetWorld.X)
	pad:SetAttribute("TargetY", targetWorld.Y)
	pad:SetAttribute("TargetZ", targetWorld.Z)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ElevatorPrompt"
	prompt.ActionText = (direction == "up") and ("Go up to Floor " .. (targetFloor + 1)) or ("Go down to Floor " .. (targetFloor + 1))
	prompt.ObjectText = "Elevator"
	prompt.HoldDuration = 0.3
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 6
	prompt.Parent = pad
end

-- A signature prop that makes each floor unmistakably different: a
-- fireplace lounge (floor 1), an indoor garden (floor 2), or a marble
-- penthouse bar (floor 3). Tucked against the back wall, clear of the
-- work stations and elevator corners.
local function buildFloorMotif(parent, floorBase, prefix, theme)
	local hx, hz = -4, BUILDING_HALF_D - 4
	local function putM(name, size, dx, dy, dz, color, mat)
		local p = makePart(prefix .. name, size, floorBase + Vector3.new(hx + dx, FLOOR_TOP + dy, hz + dz), color, mat, parent)
		p.CanCollide = false
		return p
	end

	if theme.motif == "hearth" then
		putM("HearthSurround", Vector3.new(5, 4.5, 1), 0, 2.25, 0, STONE_COLOR, Enum.Material.Marble)
		putM("HearthMantel", Vector3.new(5.6, 0.5, 1.4), 0, 4, -0.1, WOOD_DARK, Enum.Material.Wood)
		local fire = putM("HearthFire", Vector3.new(2.4, 1.8, 0.3), 0, 1.4, -0.5, Color3.fromRGB(255, 150, 70), Enum.Material.Neon)
		fire.Transparency = 0.1
		local rug = putM("HearthRug", Vector3.new(6, 0.1, 5), 0, 0.05, -4, theme.accent, Enum.Material.Fabric)
		rug.Transparency = 0.1
	elseif theme.motif == "garden" then
		for i = -1, 1 do
			putM("GardenPlanter" .. (i + 2), Vector3.new(1.6, 1, 1.6), i * 2.4, 0.5, 0, WOOD_DARK, Enum.Material.WoodPlanks)
			local plant = putM("GardenPlant" .. (i + 2), Vector3.new(1.4, 3, 1.4), i * 2.4, 2.4, 0, Color3.fromRGB(74, 132, 84), Enum.Material.Grass)
			plant.Shape = Enum.PartType.Ball
		end
		putM("GardenBench", Vector3.new(5, 0.5, 1.4), 0, 1, -3.5, WOOD_COLOR, Enum.Material.WoodPlanks)
	elseif theme.motif == "penthouse" then
		putM("BarCounter", Vector3.new(6, 1.7, 1.6), 0, 0.85, 0, STONE_COLOR, Enum.Material.Marble)
		putM("BarShelf", Vector3.new(6, 3, 0.4), 0, 3, 0.6, WOOD_DARK, Enum.Material.Wood)
		for i, sx in ipairs({ -2, 0, 2 }) do
			putM("BarStool" .. i, Vector3.new(0.9, 1.4, 0.9), sx, 0.7, -1.8, theme.accent, Enum.Material.Metal)
		end
	end
end

local function buildOneFloorShell(parent, base, f, floorCount, pcTier)
	local slabTop = FLOOR_TOP + f * FLOOR_HEIGHT
	local wallCenterY = slabTop + WALL_HEIGHT / 2
	local width = BUILDING_HALF_W * 2
	local depth = BUILDING_HALF_D * 2
	local halfW = BUILDING_HALF_W
	local halfD = BUILDING_HALF_D
	local wallThickness = 0.6
	local theme = floorTheme(f)
	local wallColor = theme.wall
	local accent = theme.accent
	local prefix = "Floor" .. (f + 1) .. "_"
	local stationPrefix = (f == 0) and "" or ("F" .. (f + 1) .. "_")

	-- M7: the Blender facade/roof meshes are DISABLED -- on these boxy walls they
	-- looked worse than the clean procedural walls (floating frames, gaps). The
	-- procedural shell below is used instead. (The good Blender sign + scenery
	-- meshes are unaffected.) Flip these back to StudioModels.has(...) to retry.
	local useFacade = false
	local useRoofCrown = false
	-- Blender RoTube front facade, applied to EVERY floor (replaces the plain
	-- front wall only; door, glass sides, roof, interior stay procedural). More
	-- floors from upgrades => more detailed windowed facades => richer building.
	local useStudioFacade = StudioModels.has("StudioFacade")
	-- Each upgrade tier restyles the WHOLE studio (RoTube-style glow-up):
	--   tier 0 = coral+blue starter, 1 = white+blue "shop", 2 = purple luxury.
	local tier = math.clamp(floorCount - 1, 0, 2)
	local TIER_STYLE = {
		[0] = { body = Color3.fromRGB(203, 198, 188), accent = Color3.fromRGB(158, 148, 132), trim = Color3.fromRGB(228, 226, 220), win = Color3.fromRGB(150, 182, 205), winGlow = false }, -- humble: muted beige/grey
		[1] = { body = Color3.fromRGB(244, 246, 250), accent = Color3.fromRGB(66, 138, 210), trim = Color3.fromRGB(250, 250, 252), win = Color3.fromRGB(255, 226, 150), winGlow = true },
		[2] = { body = Color3.fromRGB(120, 82, 170), accent = Color3.fromRGB(160, 104, 214), trim = Color3.fromRGB(232, 200, 110), win = Color3.fromRGB(255, 222, 168), winGlow = true },
	}
	local style = TIER_STYLE[tier]

	-- Each tier can have its OWN Blender facade model (distinct shape), falling
	-- back to the base StudioFacade if that tier's model isn't made yet.
	local TIER_FACADE = { [0] = "StudioL1", [1] = "StudioFacade", [2] = "StudioL3" }
	local function placeStudioFacade()
		local facadeName = TIER_FACADE[tier] or "StudioFacade"
		if not StudioModels.has(facadeName) then
			facadeName = "StudioFacade"
		end
		local facadeCF = CFrame.new(base + Vector3.new(0, slabTop, -halfD))
		StudioModels.placeColored(facadeName, parent, facadeCF, width, function(p)
			local n = p.Name
			if n:find("Win") then
				if style.winGlow then
					p.Color, p.Material, p.Transparency = style.win, Enum.Material.SmoothPlastic, 0
				else
					p.Color, p.Material, p.Transparency = style.win, Enum.Material.Glass, 0.25
				end
			elseif n:find("Planter") then
				p.Color, p.Material = Color3.fromRGB(120, 80, 52), Enum.Material.WoodPlanks
			elseif n:find("Stem") then
				p.Color, p.Material = Color3.fromRGB(70, 140, 74), Enum.Material.Grass
			elseif n:find("Center") then
				p.Color, p.Material = Color3.fromRGB(240, 196, 70), Enum.Material.SmoothPlastic
			elseif n:find("Leaf") then
				p.Color, p.Material = Color3.fromRGB(74, 138, 78), Enum.Material.Grass
			elseif n:find("FlowerA") then
				p.Color, p.Material = Color3.fromRGB(226, 86, 92), Enum.Material.SmoothPlastic
			elseif n:find("FlowerB") then
				p.Color, p.Material = Color3.fromRGB(244, 200, 84), Enum.Material.SmoothPlastic
			elseif n:find("FlowerC") then
				p.Color, p.Material = Color3.fromRGB(232, 138, 196), Enum.Material.SmoothPlastic
			elseif n:find("Gold") then
				p.Color, p.Material = Color3.fromRGB(232, 196, 96), Enum.Material.Metal
			elseif n:find("Trim") then
				p.Color, p.Material = style.trim, Enum.Material.SmoothPlastic
			elseif n:find("Accent") then
				p.Color, p.Material = style.accent, Enum.Material.SmoothPlastic
			else
				p.Color, p.Material = style.body, Enum.Material.SmoothPlastic
			end
			p.CanCollide = not (n:find("Flower") or n:find("Leaf") or n:find("Awning"))
		end, prefix .. "Facade", nil, 0)

		-- Ground-floor creator entrance props, growing with tier.
		if f == 0 and StudioModels.has("StudioEntrance") then
			local ent = StudioModels.place("StudioEntrance", parent,
				CFrame.new(base + Vector3.new(0, FLOOR_TOP, -halfD)),
				{ name = prefix .. "Entrance", targetWidth = 20 })
			if ent then
				for _, ep in ipairs(ent:GetDescendants()) do
					if ep:IsA("BasePart") then
						local tnum = tonumber(ep.Name:match("^T(%d)_"))
						if tnum and (tnum - 1) > tier then
							ep:Destroy()
						else
							ep.Anchored, ep.CanCollide = true, false
							local en = ep.Name
							if en:find("Carpet") then
								ep.Color, ep.Material = Color3.fromRGB(190, 46, 54), Enum.Material.Fabric
							elseif en:find("OnAir") then
								ep.Color, ep.Material = Color3.fromRGB(232, 54, 54), Enum.Material.SmoothPlastic
							elseif en:find("PlayTri") then
								ep.Color, ep.Material = Color3.fromRGB(250, 250, 252), Enum.Material.SmoothPlastic
							elseif en:find("Plaque") then
								ep.Color = tier >= 2 and Color3.fromRGB(232, 196, 96) or Color3.fromRGB(206, 210, 220)
								ep.Material = Enum.Material.Metal
							elseif en:find("SpotBox") then
								ep.Color, ep.Material = Color3.fromRGB(245, 245, 248), Enum.Material.SmoothPlastic
							elseif en:find("Banner") and not en:find("Pole") then
								ep.Color, ep.Material = style.accent, Enum.Material.SmoothPlastic
							else
								ep.Color, ep.Material = Color3.fromRGB(44, 46, 54), Enum.Material.SmoothPlastic
							end
						end
					end
				end
			end
		end
	end

	-- Upper floors get this floor's own floor finish; the ground floor stands
	-- on the persistent foundation.
	if f > 0 then
		makePart(prefix .. "Slab", Vector3.new(width, SLAB_THICKNESS, depth), base + Vector3.new(0, slabTop - SLAB_THICKNESS / 2, 0), theme.slab, theme.slabMat, parent)
	end

	-- Framed-window strip for the opaque walls so they aren't blank (RoTube-studio
	-- look). The dark frame sits BEHIND the glass pane (clear gap) so they never
	-- z-fight. `sign` = +1 faces +Z (back), -1 faces -Z (front).
	local function windowStrip(nameKey, centerX, segW, faceZ, sign)
		local cols = math.max(1, math.floor(segW / 5.5))
		local winW = (segW / cols) * 0.5
		local winH = WALL_HEIGHT * 0.42
		local wy = wallCenterY + 0.4
		for c = 1, cols do
			local x = centerX - segW / 2 + (c - 0.5) * (segW / cols)
			local fr = makePart(prefix .. nameKey .. "WinFrame" .. c, Vector3.new(winW + 0.5, winH + 0.5, 0.18), base + Vector3.new(x, wy, faceZ + sign * 0.10), Color3.fromRGB(46, 50, 60), Enum.Material.SmoothPlastic, parent)
			fr.CanCollide = false
			local pane = makePart(prefix .. nameKey .. "Win" .. c, Vector3.new(winW, winH, 0.12), base + Vector3.new(x, wy, faceZ + sign * 0.30), GLASS_TINT, Enum.Material.Glass, parent)
			pane.CanCollide = false
			pane.Transparency = 0.35
		end
	end

	-- Solid back wall + accent band. With the tier facade on, they follow the
	-- tier's body/accent colours so the WHOLE studio recolours on each upgrade.
	local backColor = useStudioFacade and style.body or wallColor
	local bandColor = useStudioFacade and style.accent or accent
	if not useFacade then
		makePart(prefix .. "WallBack", Vector3.new(width, WALL_HEIGHT, wallThickness), base + Vector3.new(0, wallCenterY, halfD), backColor, theme.wallMat, parent)
		windowStrip("Back", 0, width, halfD, 1)
		-- Colour accent band wrapping the building just under the roofline.
		local band = makePart(prefix .. "AccentBand", Vector3.new(width + 1.6, 0.8, depth + 1.6), base + Vector3.new(0, slabTop + WALL_HEIGHT - 1.3, 0), bandColor, Enum.Material.SmoothPlastic, parent)
		band.CanCollide = false
	end
	local function glassWall(nameKey, size, pos)
		local g = makePart(prefix .. nameKey, size, pos, GLASS_TINT, Enum.Material.Glass, parent)
		g.Transparency = 0.4
	end
	glassWall("WallLeft", Vector3.new(wallThickness, WALL_HEIGHT, depth), base + Vector3.new(-halfW, wallCenterY, 0))
	glassWall("WallRight", Vector3.new(wallThickness, WALL_HEIGHT, depth), base + Vector3.new(halfW, wallCenterY, 0))

	-- White window mullions/frames turn the glass into real windows.
	local topRailY = wallCenterY + WALL_HEIGHT / 2 - 0.25
	local botRailY = wallCenterY - WALL_HEIGHT / 2 + 0.25
	local function frameGlass(nameKey, alongZ, planeCoord)
		if alongZ then
			local top = makePart(prefix .. nameKey .. "RailTop", Vector3.new(0.35, 0.35, depth), base + Vector3.new(planeCoord, topRailY, 0), TRIM_WHITE, Enum.Material.SmoothPlastic, parent)
			top.CanCollide = false
			local bot = makePart(prefix .. nameKey .. "RailBot", Vector3.new(0.35, 0.35, depth), base + Vector3.new(planeCoord, botRailY, 0), TRIM_WHITE, Enum.Material.SmoothPlastic, parent)
			bot.CanCollide = false
			for i, z in ipairs({ -depth / 4, 0, depth / 4 }) do
				local m = makePart(prefix .. nameKey .. "Mull" .. i, Vector3.new(0.3, WALL_HEIGHT, 0.3), base + Vector3.new(planeCoord, wallCenterY, z), TRIM_WHITE, Enum.Material.SmoothPlastic, parent)
				m.CanCollide = false
			end
		else
			local top = makePart(prefix .. nameKey .. "RailTop", Vector3.new(width, 0.35, 0.35), base + Vector3.new(0, topRailY, planeCoord), TRIM_WHITE, Enum.Material.SmoothPlastic, parent)
			top.CanCollide = false
			local bot = makePart(prefix .. nameKey .. "RailBot", Vector3.new(width, 0.35, 0.35), base + Vector3.new(0, botRailY, planeCoord), TRIM_WHITE, Enum.Material.SmoothPlastic, parent)
			bot.CanCollide = false
			for i, x in ipairs({ -width / 4, 0, width / 4 }) do
				local m = makePart(prefix .. nameKey .. "Mull" .. i, Vector3.new(0.3, WALL_HEIGHT, 0.3), base + Vector3.new(x, wallCenterY, planeCoord), TRIM_WHITE, Enum.Material.SmoothPlastic, parent)
				m.CanCollide = false
			end
		end
	end
	if not useFacade then
		frameGlass("Left", true, -halfW)
		frameGlass("Right", true, halfW)
	end

	if f == 0 then
		local sideWallWidth = halfW - DOOR_WIDTH / 2
		local sideWallCenterX = (halfW + DOOR_WIDTH / 2) / 2
		local lintelHeight = WALL_HEIGHT - DOOR_HEIGHT
		if useStudioFacade then
			placeStudioFacade()
		else
			makePart(prefix .. "WallFrontLeft", Vector3.new(sideWallWidth, WALL_HEIGHT, wallThickness), base + Vector3.new(-sideWallCenterX, wallCenterY, -halfD), wallColor, theme.wallMat, parent)
			makePart(prefix .. "WallFrontRight", Vector3.new(sideWallWidth, WALL_HEIGHT, wallThickness), base + Vector3.new(sideWallCenterX, wallCenterY, -halfD), wallColor, theme.wallMat, parent)
			-- Framed windows on the two front-side walls (flanking the door).
			windowStrip("FrontLeft", -sideWallCenterX, sideWallWidth, -halfD, -1)
			windowStrip("FrontRight", sideWallCenterX, sideWallWidth, -halfD, -1)
			if lintelHeight > 0 then
				makePart(prefix .. "WallFrontLintel", Vector3.new(DOOR_WIDTH, lintelHeight, wallThickness), base + Vector3.new(0, FLOOR_TOP + DOOR_HEIGHT + lintelHeight / 2, -halfD), wallColor, theme.wallMat, parent)
			end
		end

		-- Warm wood-framed glass double-door with a wood canopy on posts and
		-- glowing entrance lamps -- a welcoming mansion entrance.
		local jambCenterY = FLOOR_TOP + DOOR_HEIGHT / 2
		makePart(prefix .. "DoorJambLeft", Vector3.new(0.5, DOOR_HEIGHT + 0.5, 1), base + Vector3.new(-DOOR_WIDTH / 2, jambCenterY, -halfD), WOOD_DARK, Enum.Material.Wood, parent)
		makePart(prefix .. "DoorJambRight", Vector3.new(0.5, DOOR_HEIGHT + 0.5, 1), base + Vector3.new(DOOR_WIDTH / 2, jambCenterY, -halfD), WOOD_DARK, Enum.Material.Wood, parent)
		makePart(prefix .. "DoorHeader", Vector3.new(DOOR_WIDTH + 1, 0.6, 1), base + Vector3.new(0, FLOOR_TOP + DOOR_HEIGHT + 0.3, -halfD), WOOD_DARK, Enum.Material.Wood, parent)
		local doorLeaf = makePart(prefix .. "Door", Vector3.new(DOOR_WIDTH - 0.5, DOOR_HEIGHT - 0.2, 0.15), base + Vector3.new(0, FLOOR_TOP + (DOOR_HEIGHT - 0.2) / 2, -halfD - 0.05), Color3.fromRGB(150, 195, 215), Enum.Material.Glass, parent)
		doorLeaf.CanCollide = false
		doorLeaf.Transparency = 0.45
		local doorMull = makePart(prefix .. "DoorCenterMull", Vector3.new(0.2, DOOR_HEIGHT - 0.2, 0.25), base + Vector3.new(0, FLOOR_TOP + (DOOR_HEIGHT - 0.2) / 2, -halfD - 0.08), WOOD_DARK, Enum.Material.Wood, parent)
		doorMull.CanCollide = false

		-- Detailed Blender entrance canopy + glowing sign, if the model is synced;
		-- otherwise the original procedural canopy/posts/lamps (fallback).
		if StudioModels.has("EntranceSign") then
			-- Push the sign forward so it sits clearly IN FRONT of the facade
			-- (its windows/lintel/band stick out ~1 stud) instead of being clipped.
			local signCF = CFrame.new(base + Vector3.new(0, FLOOR_TOP, -halfD - 1.4))
			local sign = StudioModels.place("EntranceSign", parent, signCF, {
				name = prefix .. "EntranceSign",
				targetWidth = DOOR_WIDTH + 6, -- 10 studs, matches the canopy footprint
			})
			-- Imported meshes lose their colours, so paint each piece by name.
			local paint = {
				Canopy = { WOOD_COLOR, Enum.Material.WoodPlanks },
				PostL = { TRIM_WHITE, Enum.Material.SmoothPlastic },
				PostR = { TRIM_WHITE, Enum.Material.SmoothPlastic },
				Board = { Color3.fromRGB(30, 33, 48), Enum.Material.SmoothPlastic },
				StudioText = { Color3.fromRGB(255, 220, 90), Enum.Material.Neon },
			}
			if sign then
				for _, part in ipairs(sign:GetDescendants()) do
					if part:IsA("BasePart") then
						local spec = paint[part.Name]
						if spec then
							part.Color = spec[1]
							part.Material = spec[2]
						end
						part.CanCollide = false
						part.Anchored = true
					end
				end
			end
		else
			local canopy = makePart(prefix .. "DoorCanopy", Vector3.new(DOOR_WIDTH + 6, 0.5, 4), base + Vector3.new(0, FLOOR_TOP + DOOR_HEIGHT + 1.1, -halfD - 2), WOOD_COLOR, Enum.Material.WoodPlanks, parent)
			canopy.CanCollide = false
			for i, sx in ipairs({ -(DOOR_WIDTH / 2 + 2.5), (DOOR_WIDTH / 2 + 2.5) }) do
				makePart(prefix .. "CanopyPost" .. i, Vector3.new(0.5, DOOR_HEIGHT + 1, 0.5), base + Vector3.new(sx, FLOOR_TOP + (DOOR_HEIGHT + 1) / 2, -halfD - 3.7), TRIM_WHITE, Enum.Material.SmoothPlastic, parent)
				local lamp = makePart(prefix .. "EntranceLamp" .. i, Vector3.new(0.5, 0.5, 0.5), base + Vector3.new(sx, FLOOR_TOP + DOOR_HEIGHT, -halfD - 3.7), WARM_LIGHT, Enum.Material.Neon, parent)
				lamp.CanCollide = false
				local l = Instance.new("PointLight")
				l.Color = WARM_LIGHT
				l.Range = 7
				l.Brightness = 0.5
				l.Parent = lamp
			end
		end
	else
		-- Upper floor: the RoTube facade (if synced) or a glass front, plus a
		-- projecting balcony -- the visible per-floor payoff as the studio grows.
		if useStudioFacade then
			placeStudioFacade()
		else
			makePart(prefix .. "WallFront", Vector3.new(width, WALL_HEIGHT, wallThickness), base + Vector3.new(0, wallCenterY, -halfD), GLASS_TINT, Enum.Material.Glass, parent)
			if not useFacade then
				frameGlass("Front", false, -halfD)
			end
		end

		local balconyDepth = 5
		local balconyW = width * 0.6
		local balconyZ = -halfD - balconyDepth / 2
		makePart(prefix .. "BalconyDeck", Vector3.new(balconyW, 0.5, balconyDepth), base + Vector3.new(0, slabTop + 0.25, balconyZ), WOOD_COLOR, Enum.Material.WoodPlanks, parent)
		local railFz = -halfD - balconyDepth + 0.2
		local glassRail = makePart(prefix .. "BalconyRailGlass", Vector3.new(balconyW, 2.2, 0.15), base + Vector3.new(0, slabTop + 1.35, railFz), GLASS_TINT, Enum.Material.Glass, parent)
		glassRail.Transparency = 0.5
		makePart(prefix .. "BalconyRailTop", Vector3.new(balconyW, 0.25, 0.25), base + Vector3.new(0, slabTop + 2.5, railFz), TRIM_WHITE, Enum.Material.SmoothPlastic, parent)
		for i, sx in ipairs({ -balconyW / 2, balconyW / 2 }) do
			local sr = makePart(prefix .. "BalconyRailSide" .. i, Vector3.new(0.15, 2.2, balconyDepth - 0.2), base + Vector3.new(sx, slabTop + 1.35, balconyZ), GLASS_TINT, Enum.Material.Glass, parent)
			sr.Transparency = 0.5
			makePart(prefix .. "BalconyRailSideTop" .. i, Vector3.new(0.25, 0.25, balconyDepth - 0.2), base + Vector3.new(sx, slabTop + 2.5, balconyZ), TRIM_WHITE, Enum.Material.SmoothPlastic, parent)
		end
		makePart(prefix .. "BalconyPlanter", Vector3.new(3, 0.8, 1), base + Vector3.new(-balconyW / 2 + 1.6, slabTop + 0.9, -halfD - 1.2), WOOD_DARK, Enum.Material.WoodPlanks, parent)
		local shrub = makePart(prefix .. "BalconyShrub", Vector3.new(2.6, 1.2, 0.8), base + Vector3.new(-balconyW / 2 + 1.6, slabTop + 1.7, -halfD - 1.2), Color3.fromRGB(74, 132, 84), Enum.Material.Grass, parent)
		shrub.CanCollide = false
	end

	-- White corner columns; a white story band with a thin warm reveal line
	-- to separate the floors crisply.
	if not useFacade then
		for i, corner in ipairs({ { -halfW, -halfD }, { halfW, -halfD }, { -halfW, halfD }, { halfW, halfD } }) do
			makePart(prefix .. "Column" .. i, Vector3.new(1.4, WALL_HEIGHT, 1.4), base + Vector3.new(corner[1], wallCenterY, corner[2]), TRIM_WHITE, Enum.Material.SmoothPlastic, parent)
		end
		local storyBand = makePart(prefix .. "StoryBand", Vector3.new(width + 1.8, 0.9, depth + 1.8), base + Vector3.new(0, slabTop + 0.45, 0), TRIM_WHITE, Enum.Material.SmoothPlastic, parent)
		storyBand.CanCollide = false
	end

	-- Wood cornice bands just under the ceiling (thin, warm -- not a big slab).
	if not useFacade then
		local corniceY = slabTop + WALL_HEIGHT - 0.35
		local corniceBack = makePart(prefix .. "CorniceBack", Vector3.new(width, 0.4, 0.4), base + Vector3.new(0, corniceY, halfD - 0.4), WOOD_COLOR, Enum.Material.WoodPlanks, parent)
		corniceBack.CanCollide = false
		local corniceLeft = makePart(prefix .. "CorniceLeft", Vector3.new(0.4, 0.4, depth), base + Vector3.new(-halfW + 0.4, corniceY, 0), WOOD_COLOR, Enum.Material.WoodPlanks, parent)
		corniceLeft.CanCollide = false
		local corniceRight = makePart(prefix .. "CorniceRight", Vector3.new(0.4, 0.4, depth), base + Vector3.new(halfW - 0.4, corniceY, 0), WOOD_COLOR, Enum.Material.WoodPlanks, parent)
		corniceRight.CanCollide = false
	end

	-- Per-tier glow-up extras (RoTube style). Tier 1: an arched/domed entrance
	-- over the door. Tier 2: a luxury crown + antennas on the roof.
	if useStudioFacade then
		if f == 0 and tier >= 1 then
			local archY = FLOOR_TOP + DOOR_HEIGHT + 1.4
			local canopy = makePart(prefix .. "TierCanopy", Vector3.new(DOOR_WIDTH + 5, 0.7, 3.6), base + Vector3.new(0, archY, -halfD - 1.7), style.trim, Enum.Material.SmoothPlastic, parent)
			canopy.CanCollide = false
			local dome = makePart(prefix .. "TierDome", Vector3.new(DOOR_WIDTH + 4.5, DOOR_WIDTH + 3, 2.4), base + Vector3.new(0, archY + 0.6, -halfD - 1.5), style.accent, Enum.Material.SmoothPlastic, parent)
			dome.Shape = Enum.PartType.Ball
			dome.CanCollide = false
		end
		if f == floorCount - 1 and tier >= 2 then
			local crownBaseY = slabTop + WALL_HEIGHT + SLAB_THICKNESS + 2
			local crown = makePart(prefix .. "TierCrown", Vector3.new(width * 0.5, 4, depth * 0.5), base + Vector3.new(0, crownBaseY, 0), style.accent, Enum.Material.SmoothPlastic, parent)
			crown.CanCollide = false
			local cap = makePart(prefix .. "TierCrownCap", Vector3.new(width * 0.56, 1, depth * 0.56), base + Vector3.new(0, crownBaseY + 2.5, 0), style.trim, Enum.Material.SmoothPlastic, parent)
			cap.CanCollide = false
			for i, ax in ipairs({ -1, 0, 1 }) do
				local ant = makePart(prefix .. "TierAntenna" .. i, Vector3.new(0.4, 7, 0.4), base + Vector3.new(ax * width * 0.16, crownBaseY + 6, 0), style.trim, Enum.Material.SmoothPlastic, parent)
				ant.CanCollide = false
			end
		end
	end

	-- M7: place the Blender facade shell for this floor (replaces the opaque
	-- pieces skipped above). Colours + collision are set per piece name.
	if useFacade then
		local facadeCF = CFrame.new(base + Vector3.new(0, slabTop, 0))
		local facade = StudioModels.place("FacadeModule", parent, facadeCF, {
			name = prefix .. "Facade",
			targetWidth = width,
		})
		if facade then
			for _, part in ipairs(facade:GetDescendants()) do
				if part:IsA("BasePart") then
					local n = part.Name
					if n:sub(1, 8) == "WallBack" then
						part.Color, part.Material = wallColor, theme.wallMat
					elseif n:sub(1, 3) == "Col" then
						part.Color, part.Material = TRIM_WHITE, Enum.Material.SmoothPlastic
					elseif n:sub(1, 7) == "Cornice" then
						part.Color, part.Material = WOOD_COLOR, Enum.Material.WoodPlanks
					elseif n:sub(1, 4) == "Base" then
						part.Color, part.Material = TRIM_WHITE, Enum.Material.SmoothPlastic
					elseif n:sub(1, 5) == "Frame" then
						part.Color, part.Material = Color3.fromRGB(70, 74, 84), Enum.Material.SmoothPlastic
					else
						part.Color, part.Material = wallColor, theme.wallMat
					end
					part.Anchored = true
					-- only the solid back wall + pillars need collision.
					part.CanCollide = (n:sub(1, 8) == "WallBack") or (n:sub(1, 3) == "Col")
				end
			end
		end
	end

	-- A soft ceiling fixture -- a plain warm-white panel (not glowing neon)
	-- with a gentle, short-range light so stacked floors don't wash the
	-- screen out.
	local ceilingLight = makePart(prefix .. "CeilingLight", Vector3.new(2.4, 0.3, 2.4), base + Vector3.new(0, slabTop + WALL_HEIGHT - 0.3, 0), Color3.fromRGB(250, 246, 236), Enum.Material.SmoothPlastic, parent)
	ceilingLight.CanCollide = false
	local pointLight = Instance.new("PointLight")
	pointLight.Brightness = 0.5
	pointLight.Range = 14
	pointLight.Color = WARM_LIGHT
	pointLight.Parent = ceilingLight

	-- Rooftop terrace on the top floor: wood deck, glass railing, a pergola,
	-- planters and warm lamps -- a proper luxury roof, not a bare slab.
	if f == floorCount - 1 then
		local roofY = slabTop + WALL_HEIGHT + SLAB_THICKNESS / 2
		if not useRoofCrown then
			makePart(prefix .. "Roof", Vector3.new(width + 2, SLAB_THICKNESS, depth + 2), base + Vector3.new(0, roofY, 0), wallColor, Enum.Material.Concrete, parent)
		else
			local roofCF = CFrame.new(base + Vector3.new(0, slabTop + WALL_HEIGHT, 0))
			local crown = StudioModels.place("RoofCrown", parent, roofCF, {
				name = prefix .. "RoofCrown",
				targetWidth = width + 2,
			})
			if crown then
				for _, part in ipairs(crown:GetDescendants()) do
					if part:IsA("BasePart") then
						if part.Name:sub(1, 7) == "Parapet" then
							part.Color, part.Material = TRIM_WHITE, Enum.Material.SmoothPlastic
						else
							part.Color, part.Material = wallColor, Enum.Material.Concrete
						end
						part.Anchored = true
						part.CanCollide = true
					end
				end
			end
		end
		local deckY = roofY + SLAB_THICKNESS / 2 + 0.15
		makePart(prefix .. "RoofDeck", Vector3.new(width - 2, 0.3, depth - 2), base + Vector3.new(0, deckY, 0), WOOD_COLOR, Enum.Material.WoodPlanks, parent)

		local railY = deckY + 1.4
		local rw, rd = width - 1, depth - 1
		local function roofRailRun(nameKey, size, pos)
			local g = makePart(prefix .. nameKey .. "Glass", size, pos, GLASS_TINT, Enum.Material.Glass, parent)
			g.Transparency = 0.5
			g.CanCollide = false
		end
		roofRailRun("RoofRailFront", Vector3.new(rw, 2.2, 0.15), base + Vector3.new(0, railY, -rd / 2))
		roofRailRun("RoofRailBack", Vector3.new(rw, 2.2, 0.15), base + Vector3.new(0, railY, rd / 2))
		roofRailRun("RoofRailLeft", Vector3.new(0.15, 2.2, rd), base + Vector3.new(-rw / 2, railY, 0))
		roofRailRun("RoofRailRight", Vector3.new(0.15, 2.2, rd), base + Vector3.new(rw / 2, railY, 0))
		makePart(prefix .. "RoofRailCap", Vector3.new(rw + 0.3, 0.2, rd + 0.3), base + Vector3.new(0, railY + 1.2, 0), TRIM_WHITE, Enum.Material.SmoothPlastic, parent).CanCollide = false

		-- Pergola: 4 posts + wood slats.
		local pergolaY = deckY + 3.2
		for i, corner in ipairs({ { -5, 3 }, { 5, 3 }, { -5, -3 }, { 5, -3 } }) do
			makePart(prefix .. "PergolaPost" .. i, Vector3.new(0.5, 3.4, 0.5), base + Vector3.new(corner[1], deckY + 1.7, corner[2]), WOOD_DARK, Enum.Material.Wood, parent)
		end
		for i = -2, 2 do
			local slat = makePart(prefix .. "PergolaSlat" .. (i + 3), Vector3.new(0.3, 0.25, 7), base + Vector3.new(i * 2.4, pergolaY, 0), WOOD_COLOR, Enum.Material.WoodPlanks, parent)
			slat.CanCollide = false
		end

		-- Planters + warm roof lamps.
		for i, sx in ipairs({ -(rw / 2 - 2), (rw / 2 - 2) }) do
			makePart(prefix .. "RoofPlanter" .. i, Vector3.new(2.5, 1, 2.5), base + Vector3.new(sx, deckY + 0.5, rd / 2 - 2), WOOD_DARK, Enum.Material.WoodPlanks, parent)
			local bush = makePart(prefix .. "RoofBush" .. i, Vector3.new(2.4, 1.6, 2.4), base + Vector3.new(sx, deckY + 1.7, rd / 2 - 2), Color3.fromRGB(74, 132, 84), Enum.Material.Grass, parent)
			bush.Shape = Enum.PartType.Ball
			bush.CanCollide = false
			local lampPost = makePart(prefix .. "RoofLampPost" .. i, Vector3.new(0.3, 3, 0.3), base + Vector3.new(sx, deckY + 1.5, -rd / 2 + 2), TRIM_WHITE, Enum.Material.SmoothPlastic, parent)
			-- Small warm bulb, no point light (the roof is outdoors, lit by the
			-- sky) -- keeps things from getting too bright.
			local bulb = makePart(prefix .. "RoofLampBulb" .. i, Vector3.new(0.6, 0.6, 0.6), base + Vector3.new(sx, deckY + 3, -rd / 2 + 2), WARM_LIGHT, Enum.Material.Neon, parent)
			bulb.Shape = Enum.PartType.Ball
			bulb.CanCollide = false
		end
	end

	-- Furnish upper floors (ground floor's stations are persistent, built in
	-- buildPlot).
	local floorBase = base + Vector3.new(0, f * FLOOR_HEIGHT, 0)
	if f > 0 then
		buildStudioStations(parent, floorBase, stationPrefix, pcTier)
		buildTrendsSign(parent, floorBase, stationPrefix)
	end

	-- Each floor's signature prop (fireplace / garden / penthouse bar).
	buildFloorMotif(parent, floorBase, prefix, theme)

	-- Elevator pads: up on every floor but the top, down on every floor but
	-- the ground.
	if f < floorCount - 1 then
		buildElevatorPad(parent, base, f, f + 1, "up", accent)
	end
	if f > 0 then
		buildElevatorPad(parent, base, f, f - 1, "down", accent)
	end

	-- A small wood floor-number plaque with gold text on the back wall.
	local numberSign = makePart(prefix .. "FloorNumberSign", Vector3.new(3, 1.4, 0.15), base + Vector3.new(-halfW + 3, slabTop + 3, halfD - 0.4), WOOD_DARK, Enum.Material.Wood, parent)
	numberSign.CanCollide = false
	local numGui = Instance.new("SurfaceGui")
	numGui.Face = Enum.NormalId.Front
	numGui.CanvasSize = Vector2.new(200, 100)
	numGui.LightInfluence = 0
	numGui.Parent = numberSign
	local numLabel = Instance.new("TextLabel")
	numLabel.Size = UDim2.fromScale(1, 1)
	numLabel.BackgroundTransparency = 1
	numLabel.Text = "FLOOR " .. (f + 1)
	numLabel.Font = Enum.Font.FredokaOne
	numLabel.TextScaled = true
	numLabel.TextColor3 = accent
	numLabel.Parent = numGui
end

-- A friendly architect NPC (a blocky character, not a plain block) who
-- stands by the ground-floor entrance and adds another floor when talked
-- to. The prompt keeps the name HouseUpgradePrompt so the client panel is
-- unchanged.
local function buildUpgradeNPC(parent, base)
	local x = BUILDING_HALF_W - 5
	local z = -BUILDING_HALF_D + 5
	local skin = Color3.fromRGB(240, 205, 165)
	local shirt = Color3.fromRGB(70, 120, 200)
	local pants = Color3.fromRGB(60, 62, 72)
	local hat = Color3.fromRGB(245, 200, 70)

	local model = Instance.new("Model")
	model.Name = "ArchitectNPC"
	model.Parent = parent

	local function part(name, size, dx, dy, dz, color)
		local p = makePart("Architect" .. name, size, base + Vector3.new(x + dx, FLOOR_TOP + dy, z + dz), color, Enum.Material.SmoothPlastic, parent)
		p.CanCollide = false
		p.Parent = model
		return p
	end

	part("LegL", Vector3.new(0.7, 2.6, 0.7), -0.4, 1.3, 0, pants)
	part("LegR", Vector3.new(0.7, 2.6, 0.7), 0.4, 1.3, 0, pants)
	local torso = part("Torso", Vector3.new(2, 2.6, 1), 0, 3.9, 0, shirt)
	part("ArmL", Vector3.new(0.6, 2.4, 0.7), -1.3, 3.9, 0, skin)
	part("ArmR", Vector3.new(0.6, 2.4, 0.7), 1.3, 3.9, 0, skin)
	part("Head", Vector3.new(1.3, 1.3, 1.3), 0, 5.85, 0, skin)
	-- Eyes/brim on the +Z (back) face so he looks INTO the house (toward the
	-- interior/stations), not at the front wall he stands beside.
	part("EyeL", Vector3.new(0.22, 0.22, 0.1), -0.3, 5.95, 0.65, Color3.fromRGB(40, 40, 40))
	part("EyeR", Vector3.new(0.22, 0.22, 0.1), 0.3, 5.95, 0.65, Color3.fromRGB(40, 40, 40))
	-- Hard hat marks him as the builder.
	part("Hat", Vector3.new(1.5, 0.55, 1.5), 0, 6.65, 0, hat)
	part("HatBrim", Vector3.new(1.7, 0.15, 0.6), 0, 6.4, 0.7, hat)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HouseUpgradePrompt"
	prompt.ActionText = "Add a Floor"
	prompt.ObjectText = "Architect"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 12
	prompt.Parent = torso
end

-- "Expand to a side": each upgrade adds a money-earning side room in a row
-- extending left from the mansion, so the property sprawls outward. Each
-- room is an open-fronted pavilion (entered from the front yard) holding one
-- interactive station that pays cash on a short cooldown.
local WING_W = 15
local WING_D = 16
local WING_H = 9

local function buildInteractiveRoom(parent, base, roomKey, centerX, activity)
	local prefix = roomKey .. "_"
	local centerZ = -BUILDING_HALF_D + WING_D / 2
	local wallCenterY = FLOOR_TOP + WING_H / 2
	local wt = 0.6
	local halfW, halfD = WING_W / 2, WING_D / 2

	makePart(prefix .. "Floor", Vector3.new(WING_W, 1, WING_D), base + Vector3.new(centerX, FLOOR_TOP - 0.5, centerZ), WOOD_COLOR, Enum.Material.WoodPlanks, parent)
	makePart(prefix .. "WallBack", Vector3.new(WING_W, WING_H, wt), base + Vector3.new(centerX, wallCenterY, centerZ + halfD), WALL_WHITE, Enum.Material.SmoothPlastic, parent)
	makePart(prefix .. "WallLeft", Vector3.new(wt, WING_H, WING_D), base + Vector3.new(centerX - halfW, wallCenterY, centerZ), WALL_WHITE, Enum.Material.SmoothPlastic, parent)
	makePart(prefix .. "WallRight", Vector3.new(wt, WING_H, WING_D), base + Vector3.new(centerX + halfW, wallCenterY, centerZ), WALL_WHITE, Enum.Material.SmoothPlastic, parent)
	-- Open front (a wide header beam only) so you can walk straight in.
	makePart(prefix .. "FrontBeam", Vector3.new(WING_W, 1.4, wt), base + Vector3.new(centerX, FLOOR_TOP + WING_H - 0.7, centerZ - halfD), WALL_WHITE, Enum.Material.SmoothPlastic, parent)
	makePart(prefix .. "Roof", Vector3.new(WING_W + 2, 0.6, WING_D + 2), base + Vector3.new(centerX, FLOOR_TOP + WING_H, centerZ), WALL_WHITE, Enum.Material.SmoothPlastic, parent)
	makePart(prefix .. "RoofTrim", Vector3.new(WING_W + 2.4, 0.4, WING_D + 2.4), base + Vector3.new(centerX, FLOOR_TOP + WING_H + 0.35, centerZ), WOOD_COLOR, Enum.Material.WoodPlanks, parent).CanCollide = false

	-- Painted sign over the entrance.
	local sign = makePart(prefix .. "Sign", Vector3.new(WING_W - 3, 1.6, 0.2), base + Vector3.new(centerX, FLOOR_TOP + WING_H - 0.6, centerZ - halfD - 0.2), WOOD_DARK, Enum.Material.Wood, parent)
	sign.CanCollide = false
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.CanvasSize = Vector2.new(420, 90)
	signGui.LightInfluence = 0
	signGui.Parent = sign
	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.fromScale(1, 1)
	signLabel.BackgroundTransparency = 1
	signLabel.Text = activity.title
	signLabel.Font = Enum.Font.FredokaOne
	signLabel.TextScaled = true
	signLabel.TextColor3 = Color3.fromRGB(255, 240, 210)
	signLabel.Parent = signGui

	-- The money station -- it EARNS CASH ON ITS OWN over time (idle income);
	-- walk up and collect the pile it's built up. A glowing tally sign shows
	-- how much is waiting.
	local stationPos = base + Vector3.new(centerX, FLOOR_TOP, centerZ + 2)
	local promptParent
	if activity.kind == "arcade" then
		makePart(prefix .. "CabinetBase", Vector3.new(3, 5, 2), stationPos + Vector3.new(0, 2.5, 0), Color3.fromRGB(60, 64, 78), Enum.Material.SmoothPlastic, parent)
		local screen = makePart(prefix .. "CabinetScreen", Vector3.new(2.2, 2, 0.1), stationPos + Vector3.new(0, 3.6, -1.05), Color3.fromRGB(120, 200, 255), Enum.Material.Neon, parent)
		screen.CanCollide = false
		promptParent = screen
	else
		local body = makePart(prefix .. "Counter", Vector3.new(6, 2, 2), stationPos + Vector3.new(0, 1, 0), WOOD_COLOR, Enum.Material.WoodPlanks, parent)
		makePart(prefix .. "CounterShelf", Vector3.new(6, 3, 0.5), stationPos + Vector3.new(0, 3.5, 1.2), WOOD_DARK, Enum.Material.Wood, parent)
		for i, sx in ipairs({ -2, 0, 2 }) do
			local boxc = (i == 1 and Color3.fromRGB(210, 130, 90)) or (i == 2 and Color3.fromRGB(110, 170, 140)) or Color3.fromRGB(120, 160, 220)
			makePart(prefix .. "MerchBox" .. i, Vector3.new(1.2, 1.2, 1.2), stationPos + Vector3.new(sx, 3.3, 1.2), boxc, Enum.Material.SmoothPlastic, parent)
		end
		promptParent = body
	end

	-- Tally sign above the station showing accumulated (updated by the idle loop).
	local tally = makePart(prefix .. "Tally", Vector3.new(4, 1.4, 0.2), stationPos + Vector3.new(0, 6, 0), WOOD_DARK, Enum.Material.Wood, parent)
	tally.CanCollide = false
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local g = Instance.new("SurfaceGui")
		g.Name = "TallyDisplay" .. face.Name
		g.Face = face
		g.CanvasSize = Vector2.new(300, 100)
		g.LightInfluence = 0
		g.Parent = tally
		local lbl = Instance.new("TextLabel")
		lbl.Name = "TallyText"
		lbl.Size = UDim2.fromScale(1, 1)
		lbl.BackgroundTransparency = 1
		lbl.Text = activity.title .. "\n$0"
		lbl.Font = Enum.Font.FredokaOne
		lbl.TextScaled = true
		lbl.TextColor3 = Color3.fromRGB(120, 255, 170)
		lbl.Parent = g
	end

	-- (No collect prompt: once bought, the room AUTO-earns cash straight into
	-- your wallet every few seconds -- the idle loop credits it.)
	local _ = promptParent

	-- Tycoon-style BUY BUTTON in front of the room: a bright pad + a sign
	-- showing the price and earnings, with a prompt to purchase. Removed once
	-- the room is owned (see applyRoomVisual).
	local buyModel = Instance.new("Model")
	buyModel.Name = roomKey .. "_BuyButton"
	buyModel.Parent = parent
	local padPos = base + Vector3.new(centerX, FLOOR_TOP, centerZ - halfD - 4.5)
	local pad = makePart(prefix .. "BuyPad", Vector3.new(WING_W - 2, 1, 6), padPos + Vector3.new(0, 0.5, 0), Color3.fromRGB(86, 204, 120), Enum.Material.SmoothPlastic, parent)
	pad.Parent = buyModel
	local padTop = makePart(prefix .. "BuyPadTop", Vector3.new(WING_W - 3, 0.2, 5), padPos + Vector3.new(0, 1.05, 0), Color3.fromRGB(150, 240, 175), Enum.Material.SmoothPlastic, parent)
	padTop.CanCollide = false
	padTop.Parent = buyModel
	local post = makePart(prefix .. "BuyPost", Vector3.new(0.5, 6, 0.5), padPos + Vector3.new(0, 4, 2.2), DARK_TRIM_COLOR, Enum.Material.Metal, parent)
	post.CanCollide = false
	post.Parent = buyModel
	local signPart = makePart(prefix .. "BuySign", Vector3.new(WING_W - 0.5, 4, 0.3), padPos + Vector3.new(0, 8, 2.2), DARK_TRIM_COLOR, Enum.Material.SmoothPlastic, parent)
	signPart.CanCollide = false
	signPart.Parent = buyModel
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local g = Instance.new("SurfaceGui")
		g.Face = face
		g.CanvasSize = Vector2.new(360, 160)
		g.LightInfluence = 0
		g.Parent = signPart
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.fromScale(1, 1)
		lbl.BackgroundTransparency = 1
		lbl.RichText = true
		lbl.Text = ("%s\n<font color=\"#8CF0A0\">BUY  $%s</font>\n<font size=\"22\">+$%d every 3s</font>"):format(activity.title, tostring(activity.buyCost), activity.perTick)
		lbl.Font = Enum.Font.FredokaOne
		lbl.TextScaled = true
		lbl.TextColor3 = Color3.fromRGB(255, 240, 210)
		lbl.Parent = g
	end
	local buyPrompt = Instance.new("ProximityPrompt")
	buyPrompt.Name = "BuyRoomPrompt"
	buyPrompt.ActionText = ("Buy $%s"):format(tostring(activity.buyCost))
	buyPrompt.ObjectText = activity.title
	buyPrompt.HoldDuration = 0.3
	buyPrompt.MaxActivationDistance = 10
	buyPrompt.RequiresLineOfSight = false
	buyPrompt:SetAttribute("Room", activity.room)
	buyPrompt:SetAttribute("Cost", activity.buyCost)
	buyPrompt.Parent = pad
end

-- Room costs + how much each earns per idle tick (3s). Rooms are now BOUGHT
-- with a tycoon buy-button (not unlocked by floor); they only earn once owned.
local ROOM_COSTS = { Arcade = 1500, Merch = 15000 }
local ROOM_PER_TICK = { Arcade = 30, Merch = 220 }

local function buildSideExpansion(parent, base)
	-- Both money rooms sit in a row extending left. Each shows a tycoon buy
	-- button until purchased.
	buildInteractiveRoom(parent, base, "ArcadeRoom", -BUILDING_HALF_W - WING_W / 2 - 1, {
		kind = "arcade", title = "\240\159\149\185\239\184\143 Arcade", room = "Arcade",
		buyCost = ROOM_COSTS.Arcade, perTick = ROOM_PER_TICK.Arcade,
	})
	buildInteractiveRoom(parent, base, "MerchRoom", -BUILDING_HALF_W - WING_W * 1.5 - 3, {
		kind = "merch", title = "\240\159\155\141\239\184\143 Merch Shop", room = "Merch",
		buyCost = ROOM_COSTS.Merch, perTick = ROOM_PER_TICK.Merch,
	})
end

-- Reflect room ownership: once bought, remove the buy button and flip the
-- tally sign to show it's actively earning. (Recursive find because the buy
-- button lives under the rebuildable StudioBuilding folder, not the plot root.)
local function applyRoomVisual(plotFolder, room, owned)
	if not owned then
		return
	end
	local buyBtn = plotFolder:FindFirstChild(room .. "Room_BuyButton", true)
	if buyBtn then
		buyBtn:Destroy()
	end
	local perTick = ROOM_PER_TICK[room] or 0
	for _, inst in ipairs(plotFolder:GetDescendants()) do
		if inst.Name == "TallyText" and inst:IsA("TextLabel") and inst.Parent and inst.Parent.Parent and inst.Parent.Parent.Name == (room .. "Room_Tally") then
			inst.Text = ("EARNING\n+$%d / 3s"):format(perTick)
		end
	end
end

function PlotManager.applyRoomOwnership(player)
	local index = plotOfPlayer[player.UserId]
	local plotFolder = index and PlotManager.getPlotFolder(index)
	local data = PlayerData.get(player)
	if not (plotFolder and data) then
		return
	end
	local owned = data.roomsOwned or {}
	applyRoomVisual(plotFolder, "Arcade", owned.Arcade)
	applyRoomVisual(plotFolder, "Merch", owned.Merch)
end

local function buildStudioBuilding(parent, base, houseTier, pcTier)
	local floorCount = houseTier + 1
	for f = 0, floorCount - 1 do
		buildOneFloorShell(parent, base, f, floorCount, pcTier)
	end

	-- Money-earning rooms (bought via tycoon buy-buttons, not floor-gated).
	buildSideExpansion(parent, base)

	if houseTier < GameData.HouseTierCount - 1 then
		buildUpgradeNPC(parent, base)
	end
end

-- Rebuildable wrapper: the whole tower shell lives in a "StudioBuilding"
-- folder so an upgrade (adding a floor) can rebuild it wholesale without
-- touching the persistent ground-floor stations/sign the client holds.
local function buildHouse(plotFolder, origin, houseTier, pcTier)
	pcTier = pcTier or 0
	local existing = plotFolder:FindFirstChild("StudioBuilding")
	if existing then
		existing:Destroy()
	end

	local buildingFolder = Instance.new("Folder")
	buildingFolder.Name = "StudioBuilding"
	buildingFolder.Parent = plotFolder

	buildStudioBuilding(buildingFolder, origin + HOUSE_LOT_OFFSET, houseTier, pcTier)
end

-- Persistent yard dressing so the mansion reads as a real home, not a box
-- on a slab: planters + lamps flanking the entrance path, a low hedge
-- border, a couple of trees, and a small pool off to the side.
local function buildLandscaping(plotFolder, origin)
	local base = origin + HOUSE_LOT_OFFSET
	local halfW = BUILDING_HALF_W
	local halfD = BUILDING_HALF_D
	local groundY = FLOOR_TOP - 0.5
	local hedgeColor = Color3.fromRGB(74, 132, 84)

	-- Warm lamp posts flanking the path. (Entrance planters + flowers now come
	-- from the Blender facade model, so no landscaping bush here -- it overlapped.)
	for i, sx in ipairs({ -(DOOR_WIDTH / 2 + 4), (DOOR_WIDTH / 2 + 4) }) do
		makePart("PathLampPost" .. i, Vector3.new(0.3, 5, 0.3), base + Vector3.new(sx + (sx > 0 and 2.5 or -2.5), FLOOR_TOP + 2.5, -halfD - 9), TRIM_WHITE, Enum.Material.SmoothPlastic, plotFolder)
		local bulb = makePart("PathLampBulb" .. i, Vector3.new(0.7, 0.7, 0.7), base + Vector3.new(sx + (sx > 0 and 2.5 or -2.5), FLOOR_TOP + 5, -halfD - 9), WARM_LIGHT, Enum.Material.Neon, plotFolder)
		bulb.Shape = Enum.PartType.Ball
		bulb.CanCollide = false
		local l = Instance.new("PointLight")
		l.Color = WARM_LIGHT
		l.Range = 8
		l.Brightness = 0.5
		l.Parent = bulb
	end

	-- Low hedge border along the front edge of the lot, split around the path.
	for i, sx in ipairs({ -1, 1 }) do
		local hedge = makePart("FrontHedge" .. i, Vector3.new(halfW - DOOR_WIDTH, 1.4, 1.2), base + Vector3.new(sx * (halfW / 2 + DOOR_WIDTH / 4), FLOOR_TOP + 0.7, -halfD - 13.5), hedgeColor, Enum.Material.Grass, plotFolder)
		hedge.CanCollide = false
	end

	-- A couple of trees at the front outer corners (Blender tree if synced).
	for i, sx in ipairs({ -(halfW - 1), (halfW - 1) }) do
		local treeCF = CFrame.new(base + Vector3.new(sx, FLOOR_TOP, -halfD - 2))
		if not StudioModels.placeTree(plotFolder, treeCF, 5.5, "YardTree" .. i) then
			makePart("YardTreeTrunk" .. i, Vector3.new(1, 5, 1), base + Vector3.new(sx, FLOOR_TOP + 2.5, -halfD - 2), WOOD_DARK, Enum.Material.Wood, plotFolder)
			local leaves = makePart("YardTreeLeaves" .. i, Vector3.new(5, 5, 5), base + Vector3.new(sx, FLOOR_TOP + 6, -halfD - 2), hedgeColor, Enum.Material.Grass, plotFolder)
			leaves.Shape = Enum.PartType.Ball
			leaves.CanCollide = false
		end
	end

end

-- A "Decorate" kiosk just inside the studio's front-left corner: a little
-- stand with a screen and a prompt that opens the decoration shop client-side.
local function buildDecorKiosk(plotFolder, origin)
	local base = origin + HOUSE_LOT_OFFSET
	local pos = base + Vector3.new(-BUILDING_HALF_W + 4, 0, -BUILDING_HALF_D + 5)
	makePart("DecorKioskBase", Vector3.new(2.4, 3, 1.4), pos + Vector3.new(0, FLOOR_TOP + 1.5, 0), ACCENT_COLOR, Enum.Material.SmoothPlastic, plotFolder)
	local screen = makePart("DecorKioskScreen", Vector3.new(2.6, 2, 0.3), pos + Vector3.new(0, FLOOR_TOP + 3.8, 0), DARK_TRIM_COLOR, Enum.Material.SmoothPlastic, plotFolder)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.CanvasSize = Vector2.new(200, 150)
	sg.LightInfluence = 0
	sg.Parent = screen
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Text = "\240\159\143\160\nDecorate"
	lbl.TextColor3 = Color3.fromRGB(255, 240, 210)
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextScaled = true
	lbl.Parent = sg
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DecorPrompt"
	prompt.ActionText = "Decorate"
	prompt.ObjectText = "Studio Decor"
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = screen
end

local function buildPlot(index)
	local origin = PLOT_ORIGINS[index]

	local plotFolder = Instance.new("Folder")
	plotFolder.Name = "Plot" .. index
	plotFolder.Parent = workspace.Plots

	buildPlotFloor(plotFolder, origin)
	buildPlotSpawn(plotFolder, origin)
	buildLandscaping(plotFolder, origin)
	-- Persistent ground-floor studio: stations + trends sign live directly
	-- under the plot folder (unprefixed) because the client resolves them
	-- there and holds live references, so they must survive tower rebuilds.
	buildStudioStations(plotFolder, origin + HOUSE_LOT_OFFSET, "", 0)
	buildTrendsSign(plotFolder, origin + HOUSE_LOT_OFFSET, "")
	buildHouse(plotFolder, origin, 0, 0)
	buildDecorKiosk(plotFolder, origin)

	-- A folder that holds this plot's placed decorations. It lives under the
	-- plot (not the rebuildable StudioBuilding folder) so decorations survive
	-- house upgrades.
	local decorFolder = Instance.new("Folder")
	decorFolder.Name = "Decorations"
	decorFolder.Parent = plotFolder
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
	-- Pick a random unclaimed plot rather than always the lowest free
	-- index, so two players joining together don't predictably land on
	-- plots 1 and 2 every time.
	local freeIndices = {}
	for index = 1, #PLOT_ORIGINS do
		if not claimedBy[index] then
			table.insert(freeIndices, index)
		end
	end

	if #freeIndices == 0 then
		warn(("No free plot available for %s"):format(player.Name))
		return nil
	end

	local index = freeIndices[math.random(1, #freeIndices)]
	claimedBy[index] = player.UserId
	plotOfPlayer[player.UserId] = index
	player:SetAttribute("PlotIndex", index)
	return index
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

function PlotManager.rebuildHouseForPlayer(player, tier, pcTier)
	local index = plotOfPlayer[player.UserId]
	if not index then
		return
	end

	local plotFolder = PlotManager.getPlotFolder(index)
	if not plotFolder then
		return
	end

	buildHouse(plotFolder, PLOT_ORIGINS[index], tier, pcTier or 0)
	-- Rooms are rebuilt with their buy buttons showing; restore ownership.
	PlotManager.applyRoomOwnership(player)
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

	-- Update the persistent ground-floor NewProject monitor in place (this
	-- is the one that drives the dev flow the client tracks). Upper-floor
	-- monitors reflect the PC tier from the next time the tower is rebuilt.
	local base = PLOT_ORIGINS[index] + HOUSE_LOT_OFFSET
	for _, layoutEntry in ipairs(STUDIO_LAYOUT) do
		if layoutEntry.name == "NewProject" then
			for _, config in ipairs(STATION_CONFIGS) do
				if config.name == "NewProject" then
					buildStationMonitorRig(plotFolder, base, config, tier, layoutEntry.x, layoutEntry.z, "")
					return
				end
			end
		end
	end
end

-- ---- Studio decorations ----------------------------------------------------
local function spawnDecoration(plotFolder, item, x, y, z, yaw)
	local decorFolder = plotFolder:FindFirstChild("Decorations")
	if not decorFolder then
		decorFolder = Instance.new("Folder")
		decorFolder.Name = "Decorations"
		decorFolder.Parent = plotFolder
	end
	local model = DecorBuilder.build(item, { solid = true })
	model:PivotTo(CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0))
	model.Parent = decorFolder
	return model
end

-- Clamp a requested (x,y,z) to the player's studio interior and snap Y to the
-- nearest floor slab, so a decoration can only ever land inside the player's
-- own studio. Returns clamped x, y, z.
local function clampToStudio(index, item, x, y, z)
	local base = PLOT_ORIGINS[index] + HOUSE_LOT_OFFSET
	local margin = GameData.PlotConfig.wallMargin + math.max(item.footprint.X, item.footprint.Y) / 2
	x, z = GameData.snapToStudioGrid(base, x, z)
	x = math.clamp(x, base.X - (BUILDING_HALF_W - margin), base.X + (BUILDING_HALF_W - margin))
	z = math.clamp(z, base.Z - (BUILDING_HALF_D - margin), base.Z + (BUILDING_HALF_D - margin))
	local f = math.clamp(math.floor((y - FLOOR_TOP) / FLOOR_HEIGHT + 0.5), 0, GameData.PlotConfig.maxFloors - 1)
	y = FLOOR_TOP + f * FLOOR_HEIGHT
	return x, y, z
end

function PlotManager.rebuildDecorForPlayer(player, decorations)
	local index = plotOfPlayer[player.UserId]
	if not index then
		return
	end
	local plotFolder = PlotManager.getPlotFolder(index)
	if not plotFolder then
		return
	end
	local decorFolder = plotFolder:FindFirstChild("Decorations")
	if decorFolder then
		decorFolder:ClearAllChildren()
	end
	for _, d in ipairs(decorations or {}) do
		local item = GameData.findDecorItem(d.id)
		if item then
			spawnDecoration(plotFolder, item, d.x, d.y, d.z, d.yaw or 0)
		end
	end
end

-- ---- Subscriber Play Button trophies --------------------------------------
-- A framed play-button plaque on a pedestal; awarded at each sub milestone and
-- lined up along the ground-floor back wall.
local function buildPlayButton(parent, index, milestone, base)
	local root = base + Vector3.new(-12 + (index - 1) * 6, 0, BUILDING_HALF_D - 3)
	local prefix = "PlayButton" .. index .. "_"
	makePart(prefix .. "Pedestal", Vector3.new(2.6, 2, 2.6), root + Vector3.new(0, FLOOR_TOP + 1, 0), Color3.fromRGB(40, 34, 52), Enum.Material.Marble, parent)
	local plaque = makePart(prefix .. "Plaque", Vector3.new(3.6, 3.6, 0.4), root + Vector3.new(0, FLOOR_TOP + 4.1, 0), Color3.fromRGB(24, 20, 32), Enum.Material.SmoothPlastic, parent)
	plaque.CanCollide = false
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front -- -Z, toward the room
	sg.CanvasSize = Vector2.new(200, 200)
	sg.LightInfluence = 0
	sg.Parent = plaque

	-- The award "plate" (like a YouTube play-button plate) carrying a wrench +
	-- a Roblox-style tilted square, instead of a play triangle.
	local plate = Instance.new("Frame")
	plate.Size = UDim2.new(0.8, 0, 0.5, 0)
	plate.Position = UDim2.new(0.1, 0, 0.07, 0)
	plate.BackgroundColor3 = milestone.color
	plate.BorderSizePixel = 0
	plate.Parent = sg
	local pcorner = Instance.new("UICorner")
	pcorner.CornerRadius = UDim.new(0.14, 0)
	pcorner.Parent = plate

	local wrench = Instance.new("TextLabel")
	wrench.Size = UDim2.fromScale(0.46, 1)
	wrench.Position = UDim2.fromScale(0.03, 0)
	wrench.BackgroundTransparency = 1
	wrench.Text = "\240\159\148\167" -- 🔧
	wrench.TextScaled = true
	wrench.Font = Enum.Font.FredokaOne
	wrench.Parent = plate

	-- Roblox-style rounded tilted square (dark, with a square hole).
	local rbx = Instance.new("Frame")
	rbx.Size = UDim2.fromScale(0.34, 0.5)
	rbx.Position = UDim2.fromScale(0.54, 0.25)
	rbx.Rotation = 12
	rbx.BackgroundColor3 = Color3.fromRGB(28, 24, 36)
	rbx.BorderSizePixel = 0
	rbx.Parent = plate
	local rcorner = Instance.new("UICorner")
	rcorner.CornerRadius = UDim.new(0.24, 0)
	rcorner.Parent = rbx
	local hole = Instance.new("Frame")
	hole.Size = UDim2.fromScale(0.4, 0.4)
	hole.Position = UDim2.fromScale(0.3, 0.3)
	hole.BackgroundColor3 = milestone.color
	hole.BorderSizePixel = 0
	hole.Parent = rbx
	local hcorner = Instance.new("UICorner")
	hcorner.CornerRadius = UDim.new(0.22, 0)
	hcorner.Parent = hole

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0.32, 0)
	lbl.Position = UDim2.fromScale(0, 0.64)
	lbl.BackgroundTransparency = 1
	lbl.Text = milestone.label
	lbl.TextColor3 = Color3.fromRGB(240, 238, 250)
	lbl.Font = Enum.Font.GothamBold
	lbl.TextScaled = true
	lbl.Parent = sg
end

function PlotManager.rebuildPlayButtons(player, count)
	local index = plotOfPlayer[player.UserId]
	if not index then
		return
	end
	local plotFolder = PlotManager.getPlotFolder(index)
	if not plotFolder then
		return
	end
	local folder = plotFolder:FindFirstChild("PlayButtons")
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "PlayButtons"
	folder.Parent = plotFolder
	local base = PLOT_ORIGINS[index] + HOUSE_LOT_OFFSET
	for i = 1, math.min(count or 0, #GameData.SubMilestones) do
		buildPlayButton(folder, i, GameData.SubMilestones[i], base)
	end
end

-- Add subscribers and process any Play Button milestones crossed (cash bonus +
-- trophies). Returns the newly-reached milestone index (0 if none) so the
-- caller can tell the client to celebrate.
function PlotManager.grantSubscribers(player, data, amount)
	data.subscribers = (data.subscribers or 0) + amount
	local newIndex = GameData.getSubMilestoneIndex(data.subscribers)
	local reachedNew = 0
	if newIndex > (data.subMilestone or 0) then
		for i = (data.subMilestone or 0) + 1, newIndex do
			data.cash += GameData.SubMilestones[i].cash
		end
		data.subMilestone = newIndex
		reachedNew = newIndex
		PlotManager.rebuildPlayButtons(player, newIndex)
	end
	return reachedNew
end

-- Idle income: each OWNED money room earns cash on its own over time; walk up
-- and collect the pile. Rates are per tick (3s): Arcade +64, Merch +500. Only
-- an active shop boost multiplies these; the pool caps at ~15 min of earnings.
local IDLE_TICK = 3
local IDLE_RATES = { Arcade = ROOM_PER_TICK.Arcade / 3, Merch = ROOM_PER_TICK.Merch / 3 } -- cash/sec

local function idlePool(data, room)
	data.idle = data.idle or { Arcade = 0, Merch = 0 }
	data.idle[room] = data.idle[room] or 0
	return data.idle[room]
end

-- Refresh the collect prompt + tally sign for a room to show its pool.
local function refreshRoomDisplay(plotFolder, room, amount)
	for _, inst in ipairs(plotFolder:GetDescendants()) do
		if inst:IsA("ProximityPrompt") and inst.Name == "CollectPrompt" and inst:GetAttribute("Room") == room then
			inst.ActionText = ("Collect $%d"):format(amount)
		elseif inst.Name == "TallyText" and inst:IsA("TextLabel") and inst.Parent and inst.Parent.Parent and inst.Parent.Parent.Name == (room .. "Room_Tally") then
			local title = inst.Text:match("^(.-)\n") or inst.Text
			inst.Text = ("%s\n$%d"):format(title, amount)
		end
	end
end

function PlotManager.start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		-- Every prompt handled below lives inside a player's PRIVATE plot
		-- (elevator, collect, buy-room, PC/House/Workers upgrades). Only the
		-- plot's OWNER may use them -- otherwise you could stand in someone
		-- else's studio and open their menus / manage their things.
		local ownPlot = PlotManager.getPlotFolder(plotOfPlayer[player.UserId])
		if not ownPlot or not prompt:IsDescendantOf(ownPlot) then
			return
		end

		if prompt.Name == "ElevatorPrompt" then
			local pad = prompt.Parent
			if not pad or not player.Character then
				return
			end
			local tx = pad:GetAttribute("TargetX")
			local ty = pad:GetAttribute("TargetY")
			local tz = pad:GetAttribute("TargetZ")
			if tx and ty and tz then
				player.Character:PivotTo(CFrame.new(tx, ty, tz))
			end
		elseif prompt.Name == "CollectPrompt" then
			local data = PlayerData.get(player)
			if not data then
				return
			end
			local room = prompt:GetAttribute("Room")
			if not (data.roomsOwned and data.roomsOwned[room]) then
				return
			end
			local amount = math.floor(idlePool(data, room))
			if amount <= 0 then
				return
			end
			data.idle[room] = 0
			data.cash += amount
			Remotes.PlayerStateUpdated:FireClient(player, data)
			local plotFolder = PlotManager.getPlotFolder(plotOfPlayer[player.UserId])
			if plotFolder then
				refreshRoomDisplay(plotFolder, room, 0)
			end
		elseif prompt.Name == "BuyRoomPrompt" then
			-- Tycoon buy button: purchase a money room.
			local data = PlayerData.get(player)
			local index = plotOfPlayer[player.UserId]
			if not data or not index then
				return
			end
			local room = prompt:GetAttribute("Room")
			local cost = ROOM_COSTS[room]
			if not cost or (data.roomsOwned and data.roomsOwned[room]) then
				return
			end
			if data.cash < cost then
				Remotes.PlayerStateUpdated:FireClient(player, data)
				return
			end
			data.cash -= cost
			data.roomsOwned = data.roomsOwned or {}
			data.roomsOwned[room] = true
			local plotFolder = PlotManager.getPlotFolder(index)
			if plotFolder then
				applyRoomVisual(plotFolder, room, true)
			end
			Remotes.PlayerStateUpdated:FireClient(player, data)
		end
	end)

	-- Studio decorations: the client sends where it wants an item; the server
	-- prices it, clamps it into the player's own studio, spawns it and records
	-- it for persistence.
	Remotes.RequestPlaceDecor.OnServerEvent:Connect(function(player, itemId, x, y, z, yaw)
		if typeof(itemId) ~= "string" or typeof(x) ~= "number" or typeof(y) ~= "number" or typeof(z) ~= "number" then
			return
		end
		yaw = (typeof(yaw) == "number") and yaw or 0
		local item = GameData.findDecorItem(itemId)
		local data = PlayerData.get(player)
		local index = plotOfPlayer[player.UserId]
		if not item or not data or not index then
			return
		end
		if #data.decorations >= GameData.MaxDecorations or data.cash < item.cost then
			Remotes.PlayerStateUpdated:FireClient(player, data)
			return
		end
		x, y, z = clampToStudio(index, item, x, y, z)
		data.cash -= item.cost
		table.insert(data.decorations, { id = itemId, x = x, y = y, z = z, yaw = yaw })
		local plotFolder = PlotManager.getPlotFolder(index)
		if plotFolder then
			spawnDecoration(plotFolder, item, x, y, z, yaw)
		end
		Remotes.PlayerStateUpdated:FireClient(player, data)
	end)

	Remotes.RequestClearDecor.OnServerEvent:Connect(function(player)
		local data = PlayerData.get(player)
		local index = plotOfPlayer[player.UserId]
		if not data or not index then
			return
		end
		data.decorations = {}
		local plotFolder = PlotManager.getPlotFolder(index)
		local decorFolder = plotFolder and plotFolder:FindFirstChild("Decorations")
		if decorFolder then
			decorFolder:ClearAllChildren()
		end
		Remotes.PlayerStateUpdated:FireClient(player, data)
	end)

	-- Prestige / Rebirth: reset progression for a permanent earnings bonus.
	-- KEEPS cosmetics (outfit + placed decorations), the daily streak and the
	-- prestige level; RESETS cash, games, studio floors, PC, workers,
	-- subscribers, milestones and money rooms. Server-authoritative.
	Remotes.RequestPrestige.OnServerEvent:Connect(function(player)
		local data = PlayerData.get(player)
		local index = plotOfPlayer[player.UserId]
		if not data or not index then
			return
		end
		if not GameData.canPrestige(data.subscribers, data.prestigeLevel) then
			Remotes.PlayerStateUpdated:FireClient(player, data)
			return
		end

		data.prestigeLevel = (data.prestigeLevel or 0) + 1
		data.cash = GameData.StartingCash
		data.gamesReleased = 0
		data.houseTier = 0
		data.pcTier = 0
		data.workers = {
			Coding = { hired = false, level = 0 },
			MapBuilding = { hired = false, level = 0 },
			Testing = { hired = false, level = 0 },
		}
		data.subscribers = 0
		data.subMilestone = 0
		data.subAdAccum = 0
		data.roomsOwned = { Arcade = false, Merch = false }
		data.idle = { Arcade = 0, Merch = 0 }

		-- Rebuild the world to the fresh state (tier 0 studio, no rooms/trophies,
		-- but keep their decorations).
		PlotManager.rebuildHouseForPlayer(player, 0, 0)
		PlotManager.rebuildPCForPlayer(player, 0)
		PlotManager.rebuildPlayButtons(player, 0)
		PlotManager.rebuildDecorForPlayer(player, data.decorations)

		Remotes.PlayerStateUpdated:FireClient(player, data)
		Remotes.PrestigeResult:FireClient(player, data.prestigeLevel)
	end)

	-- Idle accrual loop.
	task.spawn(function()
		while true do
			task.wait(IDLE_TICK)
			for _, player in ipairs(Players:GetPlayers()) do
				local data = PlayerData.get(player)
				local index = plotOfPlayer[player.UserId]
				local plotFolder = index and PlotManager.getPlotFolder(index)
				if data and plotFolder then
					local now = workspace:GetServerTimeNow()
					-- Boost + prestige bonus + game passes (2x Cash / VIP) all scale
					-- idle earnings, matching how active game-release cash scales.
					local boostMult = GameData.getBoostMultiplier(data, now) * GameData.getPrestigeMultiplier(data.prestigeLevel) * GameData.getPassCashMultiplier(data)
					local owned = data.roomsOwned or {}
					local credited = false

					-- Owned money rooms auto-drop their cash straight into your
					-- wallet each tick (Arcade +$64/3s, Merch +$500/3s, x boost).
					-- data.idle[room] carries the fractional remainder.
					for room, rate in pairs(IDLE_RATES) do
						if owned[room] then
							local acc = (idlePool(data, room)) + rate * boostMult * IDLE_TICK
							local whole = math.floor(acc)
							data.idle[room] = acc - whole
							if whole > 0 then
								data.cash += whole
								credited = true
							end
						end
					end

					-- Subscriber ad revenue: auto-credited cash from your audience,
					-- accumulated across ticks so small counts aren't lost to floor().
					local adRate = (data.subscribers or 0) * GameData.SubAdRevenuePerSec * boostMult
					data.subAdAccum = (data.subAdAccum or 0) + adRate * IDLE_TICK
					local adWhole = math.floor(data.subAdAccum)
					if adWhole >= 1 then
						data.subAdAccum -= adWhole
						data.cash += adWhole
						credited = true
					end

					if credited then
						Remotes.PlayerStateUpdated:FireClient(player, data)
					end
				end
			end
		end
	end)
end

return PlotManager

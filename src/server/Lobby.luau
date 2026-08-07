local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local PlotManager = require(script.Parent.PlotManager)
local PlayerData = require(script.Parent.PlayerData)
local StudioModels = require(script.Parent.StudioModels)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local GameData = require(game.ReplicatedStorage.Shared.GameData)

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
-- Asymmetric bounds (not a symmetric half-length) since the west end
-- must stop clear of the beach/water (which starts at relative X = -61)
-- while the east end continues toward the skyline/cross street. This
-- used to be a single ROAD_HALF_LENGTH = 110, which let the road run
-- straight out across the water -- caught live and fixed.
local ROAD_MIN_X = -55
local ROAD_MAX_X = 110

-- A second road crossing Main Street, running north (toward the plot
-- neighborhoods, which start around world Z = -30) so the city reaches
-- toward the rest of the map instead of stopping at the plaza's edge.
-- Offset well east of the plaza (which has half-size 35) so the road
-- doesn't cut through the plaza itself -- it originally did, at X = 0,
-- before this was caught and fixed.
local CROSS_ROAD_X = 70 -- offset from LOBBY_ORIGIN.X
-- Asymmetric bounds: the north end must stop clear of Plot 2's floor
-- (world Z starts at -30, i.e. relative Z = 70) -- it used to be a
-- symmetric CROSS_ROAD_HALF_LENGTH = 150, which reached all the way to
-- relative Z = 150 and overlapped the plot. South end is unaffected.
local CROSS_ROAD_MIN_Z = -150
local CROSS_ROAD_MAX_Z = 65

local activeCars = {}

local lobbySpawnPoint

-- Basketball mini-game state (see buildBasketballCourtGame / Lobby.start).
local BASKETBALL_SCORE_CASH = 15
local basketball
local basketballRestPosition
local basketballResetPending = false
local basketballShooterUserId
local basketballHoopPositions = {}
local basketballResetConnection

-- Day/night cycle state (see buildStreetlamps / startDayNightCycle).
local NIGHT_LAMP_COLOR = Color3.fromRGB(255, 244, 200)
-- Day/night is a TIMED HOLD, not a uniform sweep: it stays bright day for
-- DAY_SECONDS, dips through a sunset, holds night for NIGHT_SECONDS, then a
-- sunrise, and repeats.
local DAY_SECONDS = 15 * 60 -- 15 real minutes of daytime
local NIGHT_SECONDS = 3 * 60 -- 3 real minutes of nighttime
local streetlamps = {}
local dayNightConnection
local dayNightGen = 0
local isNight = false

-- Lobby "life": walking pedestrian NPCs + swimming fish.
local activeNPCs = {}
local activeFish = {}
local lobbyLifeConnection
local hologramSpinConnection
local plazaHologram

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

-- Places a Blender prop mesh (by asset name) with its base resting on the
-- ground at worldBasePos, uniformly scaled so the model stands `targetHeight`
-- studs tall, spun to `yaw`, then runs paint(part) on each BasePart. Returns
-- the Model, or nil if the asset isn't synced yet (caller falls back to a
-- procedural build). Independent of the asset's import scale.
local function placeProp(name, parent, worldBasePos, targetSize, yaw, paint, byWidth)
	local model = StudioModels.get(name)
	if not model then
		return nil
	end
	local _, size = model:GetBoundingBox()
	-- Normally scale to a target HEIGHT (bounding Y); byWidth scales to a target
	-- WIDTH (bounding X) instead -- used for the ultrawide monitor, which would
	-- be absurdly wide if scaled by height.
	local dim = byWidth and size.X or size.Y
	if dim > 0 then
		model:ScaleTo(model:GetScale() * (targetSize / dim))
	end
	model:PivotTo(CFrame.new(worldBasePos) * CFrame.Angles(0, yaw or 0, 0))
	local cf, sz = model:GetBoundingBox()
	local delta = worldBasePos.Y - (cf.Position.Y - sz.Y / 2)
	model:PivotTo(model:GetPivot() + Vector3.new(0, delta, 0))
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			paint(part)
			part.Anchored = true
		end
	end
	model.Parent = parent
	return model
end

-- Paints the "Become a Game Developer" title + subtitle on both faces of the
-- given sign board part (used by both the mesh and procedural welcome signs).
local function addWelcomeGui(board)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local surfaceGui = Instance.new("SurfaceGui")
		surfaceGui.Name = "WelcomeDisplay" .. face.Name
		surfaceGui.Face = face
		surfaceGui.CanvasSize = Vector2.new(700, 200)
		surfaceGui.LightInfluence = 0
		surfaceGui.Parent = board

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
end

local function buildWelcomeSign(lobbyFolder)
	-- Detailed Blender monument (framed board on posts, pediment) if synced.
	if StudioModels.has("WelcomeSign") then
		local m = placeProp("WelcomeSign", lobbyFolder, LOBBY_ORIGIN + Vector3.new(0, FLOOR_TOP, -22), 15, 0, function(p)
			local n = p.Name
			if n:find("SignBoard") then
				p.Color, p.Material, p.CanCollide = ACCENT_COLOR, Enum.Material.SmoothPlastic, false
			elseif n:find("SignPost") then
				p.Color, p.Material, p.CanCollide = Color3.fromRGB(120, 86, 56), Enum.Material.Wood, true
			else
				p.Color, p.Material, p.CanCollide = DARK_TRIM_COLOR, Enum.Material.SmoothPlastic, false
			end
		end)
		if m then
			local board = m:FindFirstChild("SignBoard", true)
			if board then
				addWelcomeGui(board)
			end
		end
		return
	end

	local signPost = makePart("WelcomeSignPost", Vector3.new(0.6, 6, 0.6), LOBBY_ORIGIN + Vector3.new(0, FLOOR_TOP + 3, -22), DARK_TRIM_COLOR, Enum.Material.Metal, lobbyFolder)
	local backing = makePart("WelcomeSignBacking", Vector3.new(20, 6, 0.5), LOBBY_ORIGIN + Vector3.new(0, FLOOR_TOP + 9, -22), ACCENT_COLOR, Enum.Material.SmoothPlastic, lobbyFolder)
	backing.CanCollide = false
	addWelcomeGui(backing)
end

-- Paints "My Studio" on both faces of a kiosk sign part.
local function addKioskGui(signBoard)
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

local function addStudioPrompt(part)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GoToStudioPrompt"
	prompt.ActionText = "Go to My Studio"
	prompt.ObjectText = "Studio Kiosk"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 10
	prompt.Parent = part
end

local function buildStudioKiosk(lobbyFolder)
	-- Detailed Blender terminal if synced (angled console + glowing screen).
	if StudioModels.has("Kiosk") then
		local m = placeProp("Kiosk", lobbyFolder, LOBBY_ORIGIN + Vector3.new(0, FLOOR_TOP, 0), 5, 0, function(p)
			local n = p.Name
			if n:find("Screen") then
				p.Color, p.Material, p.CanCollide = GOLD_COLOR, Enum.Material.Neon, false
			elseif n:find("Sign") then
				p.Color, p.Material, p.CanCollide = DARK_TRIM_COLOR, Enum.Material.SmoothPlastic, false
			elseif n:find("Body") then
				p.Color, p.Material, p.CanCollide = Color3.fromRGB(230, 222, 208), Enum.Material.SmoothPlastic, true
			else
				p.Color, p.Material, p.CanCollide = DARK_TRIM_COLOR, Enum.Material.SmoothPlastic, true
			end
		end)
		if m then
			local screen = m:FindFirstChild("KioskScreen", true)
			if screen then
				addStudioPrompt(screen)
			end
			local sign = m:FindFirstChild("KioskSign", true)
			if sign then
				addKioskGui(sign)
			end
		end
		return
	end

	makePart("StudioKiosk", Vector3.new(3, 4, 1.2), LOBBY_ORIGIN + Vector3.new(0, FLOOR_TOP + 2, 0), Color3.fromRGB(230, 222, 208), Enum.Material.SmoothPlastic, lobbyFolder)
	local screen = makePart("StudioKioskScreen", Vector3.new(2.4, 2, 0.1), LOBBY_ORIGIN + Vector3.new(0, FLOOR_TOP + 2.6, -0.65), GOLD_COLOR, Enum.Material.Neon, lobbyFolder)
	screen.CanCollide = false
	addStudioPrompt(screen)
	local signBoard = makePart("StudioKioskSign", Vector3.new(3.4, 1, 0.2), LOBBY_ORIGIN + Vector3.new(0, FLOOR_TOP + 4.5, 0), DARK_TRIM_COLOR, Enum.Material.SmoothPlastic, lobbyFolder)
	signBoard.CanCollide = false
	addKioskGui(signBoard)
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
		local treeCF = CFrame.new(LOBBY_ORIGIN + Vector3.new(spot.X, FLOOR_TOP, spot.Z))
		if not StudioModels.placeTree(lobbyFolder, treeCF, 5, "LobbyTree" .. i) then
			local trunk = makePart("TreeTrunk" .. i, Vector3.new(1, 4, 1), LOBBY_ORIGIN + Vector3.new(spot.X, FLOOR_TOP + 2, spot.Z), Color3.fromRGB(90, 60, 40), Enum.Material.Wood, lobbyFolder)
			local leaves = makePart("TreeLeaves" .. i, Vector3.new(4, 4, 4), LOBBY_ORIGIN + Vector3.new(spot.X, FLOOR_TOP + 5, spot.Z), Color3.fromRGB(58, 122, 74), Enum.Material.Grass, lobbyFolder)
			leaves.CanCollide = false
			trunk.Name = "TreeTrunk" .. i
		end
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
	local roadLength = ROAD_MAX_X - ROAD_MIN_X
	local roadCenterX = (ROAD_MIN_X + ROAD_MAX_X) / 2
	makePart("MainStreetRoad", Vector3.new(roadLength, 0.4, ROAD_WIDTH), LOBBY_ORIGIN + Vector3.new(roadCenterX, FLOOR_TOP + 0.2, ROAD_Z), Color3.fromRGB(58, 58, 62), Enum.Material.Asphalt, lobbyFolder)

	local sidewalkWidth = 5
	makePart("SidewalkNorth", Vector3.new(roadLength, 0.5, sidewalkWidth), LOBBY_ORIGIN + Vector3.new(roadCenterX, FLOOR_TOP + 0.25, ROAD_Z + ROAD_WIDTH / 2 + sidewalkWidth / 2), Color3.fromRGB(190, 190, 185), Enum.Material.Concrete, lobbyFolder)
	makePart("SidewalkSouth", Vector3.new(roadLength, 0.5, sidewalkWidth), LOBBY_ORIGIN + Vector3.new(roadCenterX, FLOOR_TOP + 0.25, ROAD_Z - ROAD_WIDTH / 2 - sidewalkWidth / 2), Color3.fromRGB(190, 190, 185), Enum.Material.Concrete, lobbyFolder)

	-- Dashed center line
	local dashCount = math.floor(roadLength / 8)
	for i = 0, dashCount do
		local dashX = ROAD_MIN_X + i * 8
		local dash = makePart("RoadDash" .. i, Vector3.new(3, 0.45, 0.6), LOBBY_ORIGIN + Vector3.new(dashX, FLOOR_TOP + 0.21, ROAD_Z), Color3.fromRGB(255, 224, 110), Enum.Material.SmoothPlastic, lobbyFolder)
		dash.CanCollide = false
	end
end

-- Cross Street: perpendicular to Main Street, running north toward the
-- plot neighborhoods (which start around world Z = -30) so the city
-- reaches further across the map instead of stopping at one road.
local function buildCrossRoad(lobbyFolder)
	local roadLength = CROSS_ROAD_MAX_Z - CROSS_ROAD_MIN_Z
	local roadCenterZ = (CROSS_ROAD_MIN_Z + CROSS_ROAD_MAX_Z) / 2
	makePart("CrossStreetRoad", Vector3.new(ROAD_WIDTH, 0.4, roadLength), LOBBY_ORIGIN + Vector3.new(CROSS_ROAD_X, FLOOR_TOP + 0.2, roadCenterZ), Color3.fromRGB(58, 58, 62), Enum.Material.Asphalt, lobbyFolder)

	local sidewalkWidth = 5
	makePart("CrossSidewalkEast", Vector3.new(sidewalkWidth, 0.5, roadLength), LOBBY_ORIGIN + Vector3.new(CROSS_ROAD_X + ROAD_WIDTH / 2 + sidewalkWidth / 2, FLOOR_TOP + 0.25, roadCenterZ), Color3.fromRGB(190, 190, 185), Enum.Material.Concrete, lobbyFolder)
	makePart("CrossSidewalkWest", Vector3.new(sidewalkWidth, 0.5, roadLength), LOBBY_ORIGIN + Vector3.new(CROSS_ROAD_X - ROAD_WIDTH / 2 - sidewalkWidth / 2, FLOOR_TOP + 0.25, roadCenterZ), Color3.fromRGB(190, 190, 185), Enum.Material.Concrete, lobbyFolder)

	local dashCount = math.floor(roadLength / 8)
	for i = 0, dashCount do
		local dashZ = CROSS_ROAD_MIN_Z + i * 8
		local dash = makePart("CrossRoadDash" .. i, Vector3.new(0.6, 0.45, 3), LOBBY_ORIGIN + Vector3.new(CROSS_ROAD_X, FLOOR_TOP + 0.21, dashZ), Color3.fromRGB(255, 224, 110), Enum.Material.SmoothPlastic, lobbyFolder)
		dash.CanCollide = false
	end
end

-- A single streetlamp: pole + arm + bulb. The bulb starts off (day) and
-- is toggled to a lit Neon look by startDayNightCycle -- kept as a small
-- accent light rather than a big glowing surface, matching this game's
-- "Neon only for small accents" look.
local function buildStreetlamp(lobbyFolder, name, position)
	-- Detailed Blender lamp post if synced: the "Lantern" part is the glowing
	-- glass that the day/night cycle toggles; the rest is dark metal.
	local model = placeProp("StreetLamp", lobbyFolder, position + Vector3.new(0, FLOOR_TOP, 0), 11, 0, function(part)
		if part.Name:find("Lantern") then
			part.Color, part.Material = Color3.fromRGB(90, 88, 80), Enum.Material.SmoothPlastic
			part.CanCollide = false
		else
			part.Color, part.Material = Color3.fromRGB(48, 48, 52), Enum.Material.Metal
			part.CanCollide = true
		end
	end)
	if model then
		model.Name = name
		local lantern = model:FindFirstChild("LampLantern", true)
		if lantern then
			local light = Instance.new("PointLight")
			light.Color = NIGHT_LAMP_COLOR
			light.Range = 22
			light.Brightness = 2.5
			light.Enabled = isNight
			light.Parent = lantern
			if isNight then
				lantern.Material, lantern.Color = Enum.Material.Neon, NIGHT_LAMP_COLOR
			end
			table.insert(streetlamps, lantern)
		end
		return
	end

	makePart(name .. "Pole", Vector3.new(0.35, 9, 0.35), position + Vector3.new(0, FLOOR_TOP + 4.5, 0), Color3.fromRGB(50, 50, 54), Enum.Material.Metal, lobbyFolder)

	local arm = makePart(name .. "Arm", Vector3.new(2.2, 0.3, 0.3), position + Vector3.new(1, FLOOR_TOP + 8.7, 0), Color3.fromRGB(50, 50, 54), Enum.Material.Metal, lobbyFolder)
	arm.CanCollide = false

	local bulb = Instance.new("Part")
	bulb.Name = name .. "Bulb"
	bulb.Shape = Enum.PartType.Ball
	bulb.Size = Vector3.new(0.9, 0.9, 0.9)
	bulb.Position = position + Vector3.new(2, FLOOR_TOP + 8.5, 0)
	bulb.Color = Color3.fromRGB(90, 88, 80)
	bulb.Material = Enum.Material.SmoothPlastic
	bulb.Anchored = true
	bulb.CanCollide = false
	bulb.Parent = lobbyFolder

	local light = Instance.new("PointLight")
	light.Color = NIGHT_LAMP_COLOR
	light.Range = 22
	light.Brightness = 2.5
	light.Enabled = false
	light.Parent = bulb

	table.insert(streetlamps, bulb)
end

-- Lines both roads with evenly spaced lamps, set back past each
-- sidewalk so they don't sit in the road or block the dashed lane line.
-- The roundabout ring has radius 19 (Size.X/Z = 38 in buildRoundabout) --
-- any lamp whose (x,z) falls within that plus a small margin would sit
-- on top of it, so skip placing one there.
local ROUNDABOUT_LAMP_CLEARANCE = 20

local function tooCloseToRoundabout(x, z)
	local dx = x - CROSS_ROAD_X
	local dz = z - ROAD_Z
	return (dx * dx + dz * dz) < ROUNDABOUT_LAMP_CLEARANCE * ROUNDABOUT_LAMP_CLEARANCE
end

local function buildStreetlamps(lobbyFolder)
	streetlamps = {}
	local setback = ROAD_WIDTH / 2 + 5 + 2 -- sidewalk width (5) + 2-stud gap past it
	local spacing = 40

	local mainNorthZ = ROAD_Z + setback
	local mainSouthZ = ROAD_Z - setback
	local mainCount = math.floor((ROAD_MAX_X - ROAD_MIN_X) / spacing)
	for i = 0, mainCount do
		local x = ROAD_MIN_X + i * spacing
		if not tooCloseToRoundabout(x, mainNorthZ) then
			buildStreetlamp(lobbyFolder, "StreetlampMainN" .. i, LOBBY_ORIGIN + Vector3.new(x, 0, mainNorthZ))
		end
		if not tooCloseToRoundabout(x, mainSouthZ) then
			buildStreetlamp(lobbyFolder, "StreetlampMainS" .. i, LOBBY_ORIGIN + Vector3.new(x, 0, mainSouthZ))
		end
	end

	local crossEastX = CROSS_ROAD_X + setback
	local crossWestX = CROSS_ROAD_X - setback
	local crossCount = math.floor((CROSS_ROAD_MAX_Z - CROSS_ROAD_MIN_Z) / spacing)
	for i = 0, crossCount do
		local z = CROSS_ROAD_MIN_Z + i * spacing
		if not tooCloseToRoundabout(crossEastX, z) then
			buildStreetlamp(lobbyFolder, "StreetlampCrossE" .. i, LOBBY_ORIGIN + Vector3.new(crossEastX, 0, z))
		end
		if not tooCloseToRoundabout(crossWestX, z) then
			buildStreetlamp(lobbyFolder, "StreetlampCrossW" .. i, LOBBY_ORIGIN + Vector3.new(crossWestX, 0, z))
		end
	end
end

-- Benches + trash cans on the Main Street sidewalks. Mesh props only -- they
-- simply don't appear until the Blender assets are synced (no procedural
-- fallback needed for pure decor). Set on the sidewalk centre, offset from the
-- lamps, and turned to face the road.
local function buildStreetFurniture(lobbyFolder)
	if not StudioModels.has("Bench") then
		return
	end
	local sidewalkZ = ROAD_WIDTH / 2 + 2.5 -- sidewalk centre, offset from ROAD_Z
	local wood = Color3.fromRGB(156, 110, 66)
	local dark = Color3.fromRGB(44, 44, 50)
	local function paintBench(part)
		part.Color, part.Material = part.Name:find("Wood")
			and wood or dark, part.Name:find("Wood") and Enum.Material.WoodPlanks or Enum.Material.Metal
		part.CanCollide = true
	end
	local function paintCan(part)
		if part.Name:find("Lid") then
			part.Color, part.Material = dark, Enum.Material.Metal
		else
			part.Color, part.Material = Color3.fromRGB(64, 132, 88), Enum.Material.Metal
		end
		part.CanCollide = true
	end

	local spacing = 40
	local count = math.floor((ROAD_MAX_X - ROAD_MIN_X) / spacing)
	for i = 0, count do
		local x = ROAD_MIN_X + 20 + i * spacing
		if x <= ROAD_MAX_X - 6 then
			local northZ, southZ = ROAD_Z + sidewalkZ, ROAD_Z - sidewalkZ
			if not tooCloseToRoundabout(x, northZ) then
				local b = placeProp("Bench", lobbyFolder, LOBBY_ORIGIN + Vector3.new(x, FLOOR_TOP + 0.5, northZ), 3.0, 0, paintBench)
				if b then b.Name = "BenchN" .. i end
				if StudioModels.has("TrashCan") then
					local c = placeProp("TrashCan", lobbyFolder, LOBBY_ORIGIN + Vector3.new(x + 4, FLOOR_TOP + 0.5, northZ), 2.8, 0, paintCan)
					if c then c.Name = "CanN" .. i end
				end
			end
			if not tooCloseToRoundabout(x, southZ) then
				local b = placeProp("Bench", lobbyFolder, LOBBY_ORIGIN + Vector3.new(x, FLOOR_TOP + 0.5, southZ), 3.0, math.pi, paintBench)
				if b then b.Name = "BenchS" .. i end
			end
		end
	end
end

-- Static parked cars along the Main Street curb (pure decor; the moving cars
-- are a separate system). Mesh only -- nothing appears until Car is synced.
local function buildParkedCars(lobbyFolder)
	if not StudioModels.has("Car") then
		return
	end
	local colors = {
		Color3.fromRGB(210, 74, 74), Color3.fromRGB(70, 120, 210),
		Color3.fromRGB(240, 200, 90), Color3.fromRGB(90, 180, 130),
		Color3.fromRGB(238, 238, 244),
	}
	local carY = FLOOR_TOP + 0.4 -- Main Street road top
	local edge = ROAD_WIDTH / 2 - 2.0 -- park just inside the curb
	-- The car mesh faces +X; yaw 0 faces east down the street, math.pi west.
	local spots = {
		{ x = -30, z = ROAD_Z + edge, yaw = 0 },
		{ x = 30, z = ROAD_Z - edge, yaw = math.pi },
		{ x = 100, z = ROAD_Z + edge, yaw = 0 },
		{ x = 132, z = ROAD_Z - edge, yaw = math.pi },
	}
	for i, s in ipairs(spots) do
		if not tooCloseToRoundabout(s.x, s.z) then
			local color = colors[((i - 1) % #colors) + 1]
			local c = placeProp("Car", lobbyFolder, LOBBY_ORIGIN + Vector3.new(s.x, carY, s.z), 2.9, s.yaw, function(part)
				local n = part.Name
				if n:find("Wheel") then
					part.Color, part.Material = Color3.fromRGB(28, 28, 32), Enum.Material.SmoothPlastic
				elseif n:find("Window") then
					part.Color, part.Material, part.Transparency = Color3.fromRGB(120, 150, 170), Enum.Material.Glass, 0.3
				elseif n:find("Trim") then
					part.Color, part.Material = Color3.fromRGB(60, 60, 66), Enum.Material.Metal
				else
					part.Color, part.Material = color, Enum.Material.SmoothPlastic
				end
				part.CanCollide = true
			end)
			if c then c.Name = "ParkedCar" .. i end
		end
	end
end

-- Advances Lighting.ClockTime on a loop and flips all streetlamps on/off
-- at the day/night boundary, so the whole city visibly changes mood
-- instead of just decorating a static scene.
local function setStreetlampsOn(on)
	for _, bulb in ipairs(streetlamps) do
		bulb.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
		bulb.Color = on and NIGHT_LAMP_COLOR or Color3.fromRGB(90, 88, 80)
		local light = bulb:FindFirstChildOfClass("PointLight")
		if light then
			light.Enabled = on
		end
	end
end

-- One-time atmospheric polish: better lighting technology, a subtle haze for
-- depth on the distant mountains, and gentle bloom + colour grading. Coexists
-- with the day/night cycle (which only drives ClockTime + Brightness).
local function buildAtmosphere()
	-- NOTE: Lighting.Technology can only be set in Studio/the place file, not
	-- from a runtime server script (it needs the RobloxScript capability and
	-- throws otherwise) -- so it's intentionally NOT set here.
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.Ambient = Color3.fromRGB(70, 72, 80)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 146, 160)
	Lighting.ExposureCompensation = 0.1

	local function ensure(class, name, props)
		local inst = Lighting:FindFirstChild(name)
		if not inst then
			inst = Instance.new(class)
			inst.Name = name
			inst.Parent = Lighting
		end
		for k, v in pairs(props) do
			inst[k] = v
		end
	end

	-- Lighter haze = crisper distances; punchier grade + a touch more bloom =
	-- a richer, more vibrant look across the WHOLE game (every screen).
	ensure("Atmosphere", "TownAtmosphere", {
		Density = 0.28, Offset = 0.1, Haze = 1.1, Glare = 0.2,
		Color = Color3.fromRGB(210, 218, 230), Decay = Color3.fromRGB(96, 110, 140),
	})
	ensure("BloomEffect", "TownBloom", { Intensity = 0.6, Size = 24, Threshold = 1.05 })
	ensure("ColorCorrectionEffect", "TownGrade", {
		Saturation = 0.2, Contrast = 0.1, Brightness = 0, TintColor = Color3.fromRGB(255, 252, 245),
	})
	ensure("SunRaysEffect", "TownSunRays", { Intensity = 0.06, Spread = 0.9 })
end

local function startDayNightCycle()
	if dayNightConnection then
		dayNightConnection:Disconnect()
		dayNightConnection = nil
	end
	dayNightGen += 1
	local myGen = dayNightGen

	local function setNight(night)
		isNight = night
		setStreetlampsOn(night)
		Lighting.Brightness = night and 0.8 or 2
	end

	-- Smoothly move the clock from `from` to `to` over `seconds` (manual loop;
	-- TweenService is unreliable in this project).
	local function tweenClock(from, to, seconds)
		local steps = math.max(1, math.floor(seconds / 0.1))
		for i = 1, steps do
			if myGen ~= dayNightGen then
				return
			end
			Lighting.ClockTime = (from + (to - from) * (i / steps)) % 24
			task.wait(0.1)
		end
	end

	task.spawn(function()
		Lighting.ClockTime = 14 -- bright midday
		setNight(false)
		while myGen == dayNightGen do
			task.wait(DAY_SECONDS)
			if myGen ~= dayNightGen then
				break
			end
			tweenClock(14, 24, 5) -- afternoon -> sunset -> midnight
			setNight(true)
			Lighting.ClockTime = 0
			task.wait(NIGHT_SECONDS)
			if myGen ~= dayNightGen then
				break
			end
			tweenClock(0, 14, 6) -- midnight -> sunrise -> midday
			setNight(false)
		end
	end)
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

	-- Centerpiece: a two-tier stone fountain if synced, else a tree.
	local fountain = placeProp("Fountain", lobbyFolder, center + Vector3.new(0, FLOOR_TOP + 0.1, 0), 7, 0, function(part)
		if part.Name:find("Water") then
			part.Color, part.Material, part.Transparency = Color3.fromRGB(96, 178, 224), Enum.Material.Glass, 0.25
			part.CanCollide = false
		else
			part.Color, part.Material = Color3.fromRGB(206, 202, 194), Enum.Material.Concrete
			part.CanCollide = true
		end
	end)
	if fountain then
		fountain.Name = "RoundaboutFountain"
	else
		local roundTreeCF = CFrame.new(center + Vector3.new(0, FLOOR_TOP, 0))
		if not StudioModels.placeTree(lobbyFolder, roundTreeCF, 6.5, "RoundaboutTree") then
			local trunk = makePart("RoundaboutTreeTrunk", Vector3.new(1, 5, 1), center + Vector3.new(0, FLOOR_TOP + 2.5, 0), Color3.fromRGB(90, 60, 40), Enum.Material.Wood, lobbyFolder)
			local leaves = makePart("RoundaboutTreeLeaves", Vector3.new(5, 5, 5), center + Vector3.new(0, FLOOR_TOP + 6, 0), Color3.fromRGB(58, 122, 74), Enum.Material.Grass, lobbyFolder)
			leaves.CanCollide = false
		end
	end
end

-- A basketball court and small pool in the corridor between the plaza
-- and Cross Street, for the recreational-area flavor from the reference.
-- Fires a physics-driven arc shot from the ball's current spot toward a
-- rim target, given a flight time T. Standard projectile math: horizontal
-- speed = distance/T, vertical speed solved from dy = vy*T - 0.5*g*T^2.
-- A small random offset on the target is added so shots aren't a
-- guaranteed make -- gives the "shootout" a real make/miss outcome.
local function shootBasketballToward(target)
	if not basketball then
		return
	end

	local jitter = Vector3.new((math.random() - 0.5) * 3, 0, (math.random() - 0.5) * 3)
	local aimPoint = target + jitter
	local source = basketball.Position
	local delta = aimPoint - source
	local horizontalDist = Vector3.new(delta.X, 0, delta.Z).Magnitude
	local flightTime = math.clamp(horizontalDist / 22, 0.7, 1.5)
	local gravity = workspace.Gravity

	local vx = delta.X / flightTime
	local vz = delta.Z / flightTime
	local vy = (delta.Y + 0.5 * gravity * flightTime ^ 2) / flightTime

	basketball.AssemblyLinearVelocity = Vector3.new(vx, vy, vz)
end

-- A full-size court (nearly doubled from the original cramped 16x9) with
-- a real functional hoop game: walk up to the ball and use the prompt to
-- take a shot. Scoring is detected by an invisible sensor just under each
-- rim, and a made shot pays out cash to whoever took it.
local function buildBasketballCourtGame(lobbyFolder, courtCenter, hoopOffset)
	basketballRestPosition = courtCenter + Vector3.new(0, FLOOR_TOP + 1.1, 0)

	basketball = Instance.new("Part")
	basketball.Name = "Basketball"
	basketball.Shape = Enum.PartType.Ball
	basketball.Size = Vector3.new(1.6, 1.6, 1.6)
	basketball.Position = basketballRestPosition
	basketball.Color = Color3.fromRGB(224, 122, 40)
	basketball.Material = Enum.Material.SmoothPlastic
	basketball.CustomPhysicalProperties = PhysicalProperties.new(0.6, 0.4, 0.6)
	basketball.Anchored = false
	basketball.CanCollide = true
	basketball.Parent = lobbyFolder

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShootBasketballPrompt"
	prompt.ActionText = "Shoot!"
	prompt.ObjectText = "Basketball"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.Parent = basketball

	basketballHoopPositions = {}

	local hoopSensorY = FLOOR_TOP + 6.2
	for _, side in ipairs({ -1, 1 }) do
		local rimPosition = courtCenter + Vector3.new(side * hoopOffset, hoopSensorY, 0)
		table.insert(basketballHoopPositions, rimPosition)

		local rim = Instance.new("Part")
		rim.Name = "HoopRim" .. side
		rim.Shape = Enum.PartType.Cylinder
		rim.Size = Vector3.new(0.25, 2.2, 2.2)
		rim.CFrame = CFrame.new(rimPosition) * CFrame.Angles(0, 0, math.rad(90))
		rim.Anchored = true
		rim.CanCollide = false
		rim.Color = Color3.fromRGB(255, 120, 30)
		rim.Material = Enum.Material.Metal
		rim.Parent = lobbyFolder

		local sensor = makePart("HoopSensor" .. side, Vector3.new(1.8, 0.2, 1.8), rimPosition, Color3.fromRGB(255, 120, 30), Enum.Material.Neon, lobbyFolder)
		sensor.Transparency = 1
		sensor.CanCollide = false

		local scoreCooldown = false
		sensor.Touched:Connect(function(hit)
			if hit ~= basketball or scoreCooldown then
				return
			end
			if basketball.AssemblyLinearVelocity.Y >= 0 then
				return
			end

			scoreCooldown = true
			task.delay(1, function()
				scoreCooldown = false
			end)

			local shooter = basketballShooterUserId and Players:GetPlayerByUserId(basketballShooterUserId)
			if shooter then
				local data = PlayerData.get(shooter)
				if data then
					data.cash += math.floor(BASKETBALL_SCORE_CASH * GameData.getBoostMultiplier(data, workspace:GetServerTimeNow()))
					Remotes.PlayerStateUpdated:FireClient(shooter, data)
				end
			end
		end)
	end
end

local function buildRecreationArea(lobbyFolder)
	local courtCenter = LOBBY_ORIGIN + Vector3.new(46, 0, -10)
	local hoopOffset = 12
	makePart("BasketballCourt", Vector3.new(28, 0.3, 20), courtCenter + Vector3.new(0, FLOOR_TOP + 0.15, 0), Color3.fromRGB(180, 110, 70), Enum.Material.SmoothPlastic, lobbyFolder)

	local centerLine = makePart("CourtCenterLine", Vector3.new(0.3, 0.32, 20), courtCenter + Vector3.new(0, FLOOR_TOP + 0.16, 0), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, lobbyFolder)
	centerLine.CanCollide = false

	local circle = Instance.new("Part")
	circle.Name = "CourtCenterCircle"
	circle.Shape = Enum.PartType.Cylinder
	circle.Size = Vector3.new(0.34, 5, 5)
	circle.CFrame = CFrame.new(courtCenter + Vector3.new(0, FLOOR_TOP + 0.17, 0)) * CFrame.Angles(0, 0, math.rad(90))
	circle.Anchored = true
	circle.CanCollide = false
	circle.Color = Color3.fromRGB(255, 255, 255)
	circle.Material = Enum.Material.SmoothPlastic
	circle.Parent = lobbyFolder

	for _, side in ipairs({ -1, 1 }) do
		makePart("HoopPole" .. side, Vector3.new(0.4, 8, 0.4), courtCenter + Vector3.new(side * hoopOffset, FLOOR_TOP + 4, 0), DARK_TRIM_COLOR, Enum.Material.Metal, lobbyFolder)
		local backboard = makePart("HoopBackboard" .. side, Vector3.new(0.2, 2, 3), courtCenter + Vector3.new(side * hoopOffset, FLOOR_TOP + 7, 0), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, lobbyFolder)
		backboard.CanCollide = false
	end

	buildBasketballCourtGame(lobbyFolder, courtCenter, hoopOffset)

	-- Decorative Blender skate ramp just south of the court (optional -- skipped
	-- cleanly if the mesh isn't synced).
	local ramp = StudioModels.place("SkateRamp", lobbyFolder,
		CFrame.new(courtCenter + Vector3.new(0, 6, 18)), { name = "SkateRamp", targetWidth = 12 })
	if ramp and ramp:IsA("Model") then
		local bcf, bsz = ramp:GetBoundingBox()
		ramp:PivotTo(ramp:GetPivot() + Vector3.new(0, FLOOR_TOP - (bcf.Y - bsz.Y / 2), 0))
		for _, d in ipairs(ramp:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = true
				if d.Name:find("Coping") then
					d.Color, d.Material = Color3.fromRGB(200, 205, 215), Enum.Material.Metal
				elseif d.Name:find("Deck") then
					d.Color, d.Material = Color3.fromRGB(120, 124, 133), Enum.Material.Concrete
				else
					d.Color, d.Material = Color3.fromRGB(150, 154, 163), Enum.Material.Concrete
				end
			end
		end
	end
end

-- Watches the ball and returns it to the center rest spot a second after
-- it settles (make or miss), so the next shot always starts from a known
-- position. Same disconnect-then-reconnect guard as startCarAnimation,
-- since Lobby.build() can rebuild the whole Lobby folder more than once.
local function startBasketballWatchdog()
	if basketballResetConnection then
		basketballResetConnection:Disconnect()
	end

	basketballResetConnection = RunService.Heartbeat:Connect(function()
		if not basketball or basketballResetPending then
			return
		end

		if basketball.AssemblyLinearVelocity.Magnitude < 1 and (basketball.Position - basketballRestPosition).Magnitude > 3 then
			basketballResetPending = true
			task.delay(1, function()
				basketball.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
				basketball.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
				basketball.CFrame = CFrame.new(basketballRestPosition)
				basketballResetPending = false
			end)
		end
	end)
end

local function buildPalmTree(lobbyFolder, name, position)
	-- Detailed Blender palm if synced (curved trunk, drooping fronds, coconuts).
	local model = placeProp("PalmTree", lobbyFolder, position + Vector3.new(0, FLOOR_TOP, 0),
		14 * (0.85 + math.random() * 0.35), math.random() * 2 * math.pi, function(part)
			local n = part.Name
			if n:find("Frond") then
				part.Color, part.Material = StudioModels.tinted(Color3.fromRGB(58, 140, 74), 0.85 + math.random() * 0.3), Enum.Material.Grass
				part.CanCollide = false
			elseif n:find("Coconut") then
				part.Color, part.Material = Color3.fromRGB(96, 66, 42), Enum.Material.SmoothPlastic
				part.CanCollide = false
			else
				part.Color, part.Material = Color3.fromRGB(120, 90, 60), Enum.Material.Wood
				part.CanCollide = true
			end
		end)
	if model then
		model.Name = name
		return
	end

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

-- ---- Beach decor builders --------------------------------------------------
-- All of these place props sitting on the sand (sand top = FLOOR_TOP + 0.5).
-- Bright but NON-neon (SmoothPlastic), so the beach reads as a lively resort
-- shore without the glow. Decor is CanCollide=false unless you'd stand on it.
local SAND_TOP = FLOOR_TOP + 0.5

-- A beach umbrella: slim pole + a wide tilted canopy disc + a little top knob.
local function buildUmbrella(parent, name, x, z, canopyColor)
	-- Detailed Blender umbrella if synced: striped canopy (A = colour, B = white).
	local model = placeProp("Umbrella", parent, Vector3.new(x, SAND_TOP, z), 9, math.random() * 2 * math.pi, function(part)
		local n = part.Name
		if n:find("CanopyA") then
			part.Color, part.Material = canopyColor, Enum.Material.SmoothPlastic
			part.CanCollide = false
		elseif n:find("CanopyB") then
			part.Color, part.Material = Color3.fromRGB(248, 248, 244), Enum.Material.SmoothPlastic
			part.CanCollide = false
		else
			part.Color, part.Material = Color3.fromRGB(235, 230, 222), Enum.Material.SmoothPlastic
			part.CanCollide = false
		end
	end)
	if model then
		model.Name = name
		return
	end

	local pole = makePart(name .. "Pole", Vector3.new(0.4, 7, 0.4), Vector3.new(x, SAND_TOP + 3.5, z), Color3.fromRGB(235, 230, 222), Enum.Material.SmoothPlastic, parent)
	pole.CanCollide = false
	local canopy = makePart(name .. "Canopy", Vector3.new(0.5, 9, 9), Vector3.new(x, SAND_TOP + 7.1, z), canopyColor, Enum.Material.SmoothPlastic, parent)
	canopy.Shape = Enum.PartType.Cylinder
	canopy.CFrame = CFrame.new(canopy.Position) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(math.rad(9), 0, 0)
	canopy.CanCollide = false
	local knob = makePart(name .. "Knob", Vector3.new(0.9, 0.9, 0.9), Vector3.new(x, SAND_TOP + 7.5, z), Color3.fromRGB(245, 245, 240), Enum.Material.SmoothPlastic, parent)
	knob.Shape = Enum.PartType.Ball
	knob.CanCollide = false
end

-- A striped beach towel laid flat on the sand.
local function buildTowel(parent, name, x, z, color, yaw)
	local cf = CFrame.new(Vector3.new(x, SAND_TOP + 0.12, z)) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	local mat = makePart(name, Vector3.new(4, 0.16, 6), cf.Position, color, Enum.Material.SmoothPlastic, parent)
	mat.CFrame = cf
	mat.CanCollide = false
	local stripe = makePart(name .. "Stripe", Vector3.new(4, 0.18, 1.3), cf.Position, Color3.fromRGB(248, 248, 244), Enum.Material.SmoothPlastic, parent)
	stripe.CFrame = cf
	stripe.CanCollide = false
end

-- A reclined lounge chair (seat + tilted back on little legs).
local function buildLoungeChair(parent, name, x, z, color, yaw)
	-- Detailed Blender lounger if synced (slatted frame + wooden legs).
	local model = placeProp("LoungeChair", parent, Vector3.new(x, SAND_TOP, z), 2.2, math.rad(yaw or 0), function(part)
		if part.Name:find("Leg") then
			part.Color, part.Material = Color3.fromRGB(150, 110, 70), Enum.Material.Wood
		else
			part.Color, part.Material = color, Enum.Material.SmoothPlastic
		end
		part.CanCollide = false
	end)
	if model then
		model.Name = name
		return
	end

	local base = CFrame.new(Vector3.new(x, SAND_TOP, z)) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	local function place(sub, size, offset, col, ang)
		local p = makePart(name .. sub, size, (base * CFrame.new(offset)).Position, col or color, Enum.Material.SmoothPlastic, parent)
		p.CFrame = base * CFrame.new(offset) * (ang or CFrame.new())
		p.CanCollide = false
		return p
	end
	place("Seat", Vector3.new(2.4, 0.3, 5), Vector3.new(0, 1.2, 0.4))
	place("Back", Vector3.new(2.4, 0.3, 3), Vector3.new(0, 2.0, -2.3), nil, CFrame.Angles(math.rad(-48), 0, 0))
	local wood = Color3.fromRGB(150, 110, 70)
	for _, ox in ipairs({ -1, 1 }) do
		for _, oz in ipairs({ -2, 2 }) do
			place("Leg", Vector3.new(0.3, 1.2, 0.3), Vector3.new(ox, 0.6, oz), wood)
		end
	end
end

-- A cluster of low boulders (breaks up the straight water corners).
local function buildBoulders(parent, name, x, z)
	-- A cluster of random jagged boulder variants if synced; else procedural.
	if StudioModels.has("Rock") then
		local spots = { { Vector3.new(0, 0, 0), 8 }, { Vector3.new(3.6, 0, 2), 5 }, { Vector3.new(-2.8, 0, 2.6), 4 } }
		for i, sp in ipairs(spots) do
			local grey = StudioModels.tinted(Color3.fromRGB(120, 114, 106), 0.85 + math.random() * 0.3)
			StudioModels.placeRandomVariant("Rock", parent, Vector3.new(x, FLOOR_TOP, z) + sp[1], sp[2], function(p)
				p.Color, p.Material, p.CanCollide = grey, Enum.Material.Rock, true
			end, name .. i, 0.25)
		end
		return
	end
	local specs = {
		{ s = Vector3.new(6, 5, 6), o = Vector3.new(0, 0, 0) },
		{ s = Vector3.new(4, 3.4, 4), o = Vector3.new(3.6, -0.4, 2), },
		{ s = Vector3.new(3, 2.6, 3), o = Vector3.new(-2.6, -0.4, 2.6) },
	}
	for i, sp in ipairs(specs) do
		local rock = makePart(name .. i, sp.s, Vector3.new(x + sp.o.X, FLOOR_TOP + sp.s.Y / 2 + sp.o.Y, z + sp.o.Z), Color3.fromRGB(122, 116, 108):Lerp(Color3.fromRGB(98, 92, 86), (i - 1) / 3), Enum.Material.Rock, parent)
		rock.CFrame = CFrame.new(rock.Position) * CFrame.Angles(0, math.rad((i * 37 + x) % 90), 0)
	end
end

-- A tuft of dune grass -- a few thin blades fanned out.
local function buildDuneGrass(parent, name, x, z)
	for i = 1, 5 do
		local ang = (i - 1) * 72 + (math.floor(x) % 40)
		local rad = math.rad(ang)
		-- Spread each blade out from the tuft centre (they used to all sit on
		-- the exact same point, which caused z-fighting). Now they genuinely fan out.
		local base = Vector3.new(x + math.cos(rad) * 0.35, SAND_TOP + 1.1, z + math.sin(rad) * 0.35)
		local blade = makePart(name .. i, Vector3.new(0.25, 2.4, 0.25), base, Color3.fromRGB(150, 178, 92), Enum.Material.Grass, parent)
		blade.CFrame = CFrame.new(base) * CFrame.Angles(0, rad, 0) * CFrame.Angles(math.rad(20), 0, 0)
		blade.CanCollide = false
	end
end

-- The signature piece: a wooden pier walking out over the water. Deck sits
-- just above the water surface; posts drop to the seabed; low rails on both
-- sides. `fromX` is the beach end, `toX` the far (over-water) end.
local function buildPier(parent, name, fromX, toX, z, deckY)
	local length = math.abs(fromX - toX)
	local midX = (fromX + toX) / 2
	local deck = makePart(name .. "Deck", Vector3.new(length, 0.5, 9), Vector3.new(midX, deckY, z), Color3.fromRGB(158, 116, 74), Enum.Material.WoodPlanks, parent)
	deck.CanCollide = true
	-- a few darker plank seams across the deck
	local seams = 6
	for i = 1, seams do
		local sx = toX + (length) * (i / (seams + 1))
		local seam = makePart(name .. "Seam" .. i, Vector3.new(0.3, 0.55, 9), Vector3.new(sx, deckY, z), Color3.fromRGB(120, 86, 54), Enum.Material.Wood, parent)
		seam.CanCollide = false
	end
	-- support posts + side rails
	local step = 9
	local px = math.min(fromX, toX) + 3
	while px <= math.max(fromX, toX) - 3 do
		for _, oz in ipairs({ -3.6, 3.6 }) do
			makePart(name .. "Post", Vector3.new(0.8, deckY - (FLOOR_TOP - 1), 0.8), Vector3.new(px, (FLOOR_TOP - 1 + deckY) / 2, z + oz), Color3.fromRGB(120, 86, 54), Enum.Material.Wood, parent)
			local railPostTop = makePart(name .. "RailPost", Vector3.new(0.4, 2.2, 0.4), Vector3.new(px, deckY + 1.1, z + oz), Color3.fromRGB(150, 110, 70), Enum.Material.Wood, parent)
			railPostTop.CanCollide = false
		end
		px += step
	end
	for _, oz in ipairs({ -3.9, 3.9 }) do
		local rail = makePart(name .. "Rail", Vector3.new(length, 0.35, 0.35), Vector3.new(midX, deckY + 2.1, z + oz), Color3.fromRGB(150, 110, 70), Enum.Material.Wood, parent)
		rail.CanCollide = false
	end
end

-- A classic lifeguard tower: hut on stilts with an open front facing the sea,
-- a slanted roof and a ladder. `yaw` turns the open side (+Z) toward the water.
local function buildLifeguardTower(parent, name, x, z, yaw)
	-- Detailed Blender tower if synced (stilts, cream hut, red roof, ladder).
	local model = placeProp("LifeguardTower", parent, Vector3.new(x, FLOOR_TOP, z), 11, math.rad(yaw or 0), function(part)
		local n = part.Name
		if n:find("Wall") then
			part.Color, part.Material = Color3.fromRGB(238, 232, 220), Enum.Material.SmoothPlastic
		elseif n:find("Red") then
			part.Color, part.Material = Color3.fromRGB(214, 84, 74), Enum.Material.SmoothPlastic
		else
			part.Color, part.Material = Color3.fromRGB(150, 110, 70), Enum.Material.Wood
		end
		part.CanCollide = true
	end)
	if model then
		model.Name = name
		return
	end

	local base = CFrame.new(Vector3.new(x, FLOOR_TOP, z)) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	local platY = 6
	local function place(sub, size, offset, col, mat, ang, collide)
		local p = makePart(name .. sub, size, (base * CFrame.new(offset)).Position, col, mat or Enum.Material.Wood, parent)
		p.CFrame = base * CFrame.new(offset) * (ang or CFrame.new())
		if collide ~= nil then
			p.CanCollide = collide
		end
		return p
	end
	local wood = Color3.fromRGB(150, 110, 70)
	local red = Color3.fromRGB(214, 84, 74)
	local cream = Color3.fromRGB(238, 232, 220)
	for _, ox in ipairs({ -3, 3 }) do
		for _, oz in ipairs({ -3, 3 }) do
			place("Leg", Vector3.new(0.6, platY, 0.6), Vector3.new(ox, platY / 2, oz), wood)
		end
	end
	place("Platform", Vector3.new(8, 0.5, 8), Vector3.new(0, platY, 0), wood)
	place("WallBack", Vector3.new(8, 4, 0.4), Vector3.new(0, platY + 2, -3.8), red, Enum.Material.SmoothPlastic)
	place("WallL", Vector3.new(0.4, 4, 8), Vector3.new(-3.8, platY + 2, 0), cream, Enum.Material.SmoothPlastic)
	place("WallR", Vector3.new(0.4, 4, 8), Vector3.new(3.8, platY + 2, 0), cream, Enum.Material.SmoothPlastic)
	place("RailFront", Vector3.new(8, 1.2, 0.4), Vector3.new(0, platY + 0.8, 3.8), cream, Enum.Material.SmoothPlastic)
	place("Roof", Vector3.new(9.2, 0.4, 9.4), Vector3.new(0, platY + 4.5, 0), red, Enum.Material.SmoothPlastic, CFrame.Angles(math.rad(-12), 0, 0))
	for i = 1, 5 do
		place("Rung", Vector3.new(4, 0.3, 0.3), Vector3.new(0, i * 1.0, 4.0), wood, nil, nil, true)
	end
end

-- A beach + water edge on the west side of the plaza for the coastal
-- feel from the reference, since this game doesn't otherwise have one.
local function buildBeach(lobbyFolder)
	-- The ground is one solid grass slab (can't be dug into), so the beach is
	-- laid on TOP of it: a big flat sand area with a terrain-water lagoon set
	-- into the middle of it. The sand is deliberately huge -- it stretches
	-- from the edge of the plaza all the way west to the mountains, so the
	-- shore reads as a proper wide beach that meets the rocks, not a thin
	-- strip floating on grass.
	local sandColor = Color3.fromRGB(232, 208, 152)
	local wetSandColor = Color3.fromRGB(196, 176, 128)
	local sandTopY = FLOOR_TOP + 0.5

	-- The sea sits in a COVE pushed against the mountains on the west, so the
	-- whole east half of the beach opens up as a wide sandy foreground facing
	-- the plaza -- room for a pier, umbrellas, chairs and a lifeguard tower,
	-- instead of a rectangle wedged between the plaza and the mountains.
	local waterMinX, waterMaxX = -95, -15
	local waterMinZ, waterMaxZ = -150, -55
	local waterCenterX = (waterMinX + waterMaxX) / 2
	local waterCenterZ = (waterMinZ + waterMaxZ) / 2
	local waterWidth = waterMaxX - waterMinX -- along X
	local waterLength = waterMaxZ - waterMinZ -- along Z
	local waterBottomY = FLOOR_TOP -- water starts at ground level
	local waterTopY = FLOOR_TOP + 6 -- deep enough to submerge + swim

	-- One big sand slab covering the whole beach zone: from the plaza's west
	-- edge (x = 45) out west to the mountains (x = -150), and a bit past the
	-- lagoon on the north/south ends. The lagoon sits on top of it.
	local beachMinX, beachMaxX = -150, 45
	local beachMinZ, beachMaxZ = -175, -25
	local beachSizeX = beachMaxX - beachMinX
	local beachSizeZ = beachMaxZ - beachMinZ
	local beachCenter = Vector3.new((beachMinX + beachMaxX) / 2, sandTopY - 0.7, (beachMinZ + beachMaxZ) / 2)
	makePart("BeachSand", Vector3.new(beachSizeX, 1.4, beachSizeZ), beachCenter, sandColor, Enum.Material.Sand, lobbyFolder)

	-- A sloped sand ramp (WedgePart) on each side of the lagoon, rising from
	-- the flat beach up to the water's surface, so there is no vertical "wall
	-- of water" anywhere around the shore -- you walk smoothly up the sand
	-- into the sea from any direction (and back out).
	local rampRun = 14
	local rampH = waterTopY - FLOOR_TOP
	local function buildRamp(name, center, sizeXZ, yawDeg)
		local ramp = Instance.new("WedgePart")
		ramp.Name = name
		-- Size.X = width along the shore, Size.Z = slope run; the tall edge is
		-- local +Z, which yawDeg rotates to face the water.
		ramp.Size = Vector3.new(sizeXZ.X, rampH, sizeXZ.Y)
		-- Damp (wet) sand on the sloped shoreline, so the flat dry beach reads
		-- lighter than the water's edge -- a free bit of realism.
		ramp.Color = wetSandColor
		ramp.Material = Enum.Material.Sand
		ramp.Anchored = true
		ramp.CFrame = CFrame.new(Vector3.new(center.X, FLOOR_TOP + rampH / 2, center.Z)) * CFrame.Angles(0, math.rad(yawDeg), 0)
		ramp.Parent = lobbyFolder
	end
	-- East shore: tall edge faces -X (into the water). Runs along Z.
	buildRamp("BeachRampE", Vector3.new(waterMaxX + rampRun / 2, 0, waterCenterZ), Vector2.new(waterLength, rampRun), -90)
	-- West shore: tall edge faces +X. Runs along Z.
	buildRamp("BeachRampW", Vector3.new(waterMinX - rampRun / 2, 0, waterCenterZ), Vector2.new(waterLength, rampRun), 90)
	-- North shore: tall edge faces +Z. Runs along X.
	buildRamp("BeachRampN", Vector3.new(waterCenterX, 0, waterMinZ - rampRun / 2), Vector2.new(waterWidth, rampRun), 0)
	-- South shore: tall edge faces -Z. Runs along X.
	buildRamp("BeachRampS", Vector3.new(waterCenterX, 0, waterMaxZ + rampRun / 2), Vector2.new(waterWidth, rampRun), 180)

	-- Real swimming only works with TERRAIN water (a Part with Water material
	-- just looks wet -- you walk through it). Fill the sea region with actual
	-- water terrain so the player genuinely swims. Clear it first so repeated
	-- builds don't leave stale water.
	local waterCFrame = CFrame.new(Vector3.new(waterCenterX, (waterTopY + waterBottomY) / 2, waterCenterZ))
	local waterSize = Vector3.new(waterWidth, waterTopY - waterBottomY, waterLength)
	local terrain = workspace.Terrain
	-- Clear a broad box over the WHOLE beach zone first, so water left over
	-- from an earlier build at a different spot doesn't linger.
	terrain:FillBlock(CFrame.new(-40, 5, -100), Vector3.new(140, 16, 130), Enum.Material.Air)
	terrain:FillBlock(waterCFrame, waterSize, Enum.Material.Water)

	-- ---- Decor: fill the open sandy foreground so it reads as a real resort
	-- beach, not an empty sand lot. The pier is the signature piece; umbrellas,
	-- chairs, a lifeguard tower, boulders and dune grass do the rest.
	buildPier(lobbyFolder, "Pier", 30, -58, -102, waterTopY + 0.6)

	buildUmbrella(lobbyFolder, "Umbrella1", 10, -66, Color3.fromRGB(224, 92, 82))
	buildUmbrella(lobbyFolder, "Umbrella2", 25, -122, Color3.fromRGB(72, 176, 176))
	buildUmbrella(lobbyFolder, "Umbrella3", 4, -134, Color3.fromRGB(232, 196, 88))

	buildTowel(lobbyFolder, "Towel1", 14, -66, Color3.fromRGB(224, 92, 82), 12)
	buildTowel(lobbyFolder, "Towel2", 29, -122, Color3.fromRGB(72, 176, 176), -8)
	buildTowel(lobbyFolder, "Towel3", 8, -134, Color3.fromRGB(232, 196, 88), 20)

	buildLoungeChair(lobbyFolder, "Lounge1", 18, -78, Color3.fromRGB(238, 232, 220), 90)
	buildLoungeChair(lobbyFolder, "Lounge2", 32, -92, Color3.fromRGB(238, 232, 220), 90)

	local ball = makePart("BeachBall", Vector3.new(3, 3, 3), Vector3.new(20, SAND_TOP + 1.5, -104), Color3.fromRGB(230, 90, 90), Enum.Material.SmoothPlastic, lobbyFolder)
	ball.Shape = Enum.PartType.Ball
	ball.CanCollide = true

	-- Open side (+Z) rotated to face -X (the water) with yaw -90.
	buildLifeguardTower(lobbyFolder, "Lifeguard", 39, -100, -90)

	buildBoulders(lobbyFolder, "BeachRockNE", -14, -54)
	buildBoulders(lobbyFolder, "BeachRockW", -92, -70)
	buildBoulders(lobbyFolder, "BeachRockSW", -90, -146)

	for i, spec in ipairs({
		{ 36, -40 }, { 20, -34 }, { 42, -66 }, { 40, -148 }, { 30, -168 }, { 6, -168 }, { -6, -36 },
	}) do
		buildDuneGrass(lobbyFolder, "Dune" .. i, spec[1], spec[2])
	end

	-- Little fish drifting inside the water column (animated in startLobbyLife),
	-- each at its own depth well clear of the seabed and surface.
	activeFish = {}
	local fishColors = { Color3.fromRGB(240, 140, 70), Color3.fromRGB(90, 170, 230), Color3.fromRGB(240, 210, 90), Color3.fromRGB(230, 120, 160), Color3.fromRGB(120, 220, 170) }
	for i = 1, 6 do
		local laneZ = ((i - 3.5) / 3) * (waterLength * 0.55)
		local depth = FLOOR_TOP + 1.5 + ((i * 1.1) % (waterTopY - waterBottomY - 3))
		local color = fishColors[((i - 1) % #fishColors) + 1]
		local bodyPos = Vector3.new(waterCenterX, depth, waterCenterZ + laneZ)
		local model = Instance.new("Model")
		model.Name = "Fish" .. i
		model.Parent = lobbyFolder
		local body = makePart("Fish" .. i .. "Body", Vector3.new(1.6, 0.9, 0.8), bodyPos, color, Enum.Material.SmoothPlastic, lobbyFolder)
		body.Shape = Enum.PartType.Ball
		body.CanCollide = false
		body.Parent = model
		local tail = makePart("Fish" .. i .. "Tail", Vector3.new(0.6, 0.8, 0.15), bodyPos + Vector3.new(-1, 0, 0), color, Enum.Material.SmoothPlastic, lobbyFolder)
		tail.CanCollide = false
		tail.Parent = model
		model.PrimaryPart = body
		table.insert(activeFish, {
			model = model,
			from = bodyPos + Vector3.new(-waterWidth * 0.35, 0, 0),
			to = bodyPos + Vector3.new(waterWidth * 0.35, 0, 0),
			t = (i / 6),
			dir = (i % 2 == 0) and 1 or -1,
			speed = 0.05 + (i % 3) * 0.02,
		})
	end

	-- A few palms dotted around the open foreground beach (world coords).
	buildPalmTree(lobbyFolder, "Palm1", Vector3.new(40, 0, -48))
	buildPalmTree(lobbyFolder, "Palm2", Vector3.new(43, 0, -152))
	buildPalmTree(lobbyFolder, "Palm3", Vector3.new(-22, 0, -26))
	buildPalmTree(lobbyFolder, "Palm4", Vector3.new(-4, 0, -160))
end

-- A few simple boulder clusters around the outer edges for a
-- "surrounded by nature" feel instead of the city just stopping abruptly.
local function buildRockCluster(lobbyFolder, name, position)
	if StudioModels.has("Rock") then
		local spots = { { Vector3.new(0, 0, 0), 8 }, { Vector3.new(3, 0, 2), 5 }, { Vector3.new(-2.5, 0, 3), 4 } }
		for i, sp in ipairs(spots) do
			local grey = StudioModels.tinted(Color3.fromRGB(120, 115, 110), 0.85 + math.random() * 0.3)
			StudioModels.placeRandomVariant("Rock", lobbyFolder, position + Vector3.new(0, FLOOR_TOP, 0) + sp[1], sp[2], function(p)
				p.Color, p.Material, p.CanCollide = grey, Enum.Material.Rock, true
			end, name .. i, 0.25)
		end
		return
	end
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

-- A road grid through the gap in the middle of the 2x2 plot layout
-- (PLOT_ORIGINS in PlotManager.luau: (0,0), (160,0), (0,160), (160,160),
-- each a 70x90 floor) so every plot has road presence nearby, not just
-- the one Cross Street happened to reach by accident. Positions are in
-- world space directly (this grid isn't relative to the lobby, which
-- sits well south of it) -- the column gap is X 35..125, the row gap is
-- Z 60..130, so a road centered in each gap clears every plot floor.
local NEIGHBORHOOD_ROAD_X = 80
local NEIGHBORHOOD_ROAD_Z = 95
local NEIGHBORHOOD_ROAD_WIDTH = 16

local function buildNeighborhoodRoads(lobbyFolder)
	local sidewalkWidth = 5

	-- North-South: connects down toward the plaza link road and up
	-- past the far row of plots.
	local nsMinZ, nsMaxZ = -55, 230
	local nsLength = nsMaxZ - nsMinZ
	local nsCenterZ = (nsMinZ + nsMaxZ) / 2
	makePart("NeighborhoodRoadNS", Vector3.new(NEIGHBORHOOD_ROAD_WIDTH, 0.4, nsLength), Vector3.new(NEIGHBORHOOD_ROAD_X, FLOOR_TOP + 0.2, nsCenterZ), Color3.fromRGB(58, 58, 62), Enum.Material.Asphalt, lobbyFolder)
	makePart("NeighborhoodSidewalkNSEast", Vector3.new(sidewalkWidth, 0.5, nsLength), Vector3.new(NEIGHBORHOOD_ROAD_X + NEIGHBORHOOD_ROAD_WIDTH / 2 + sidewalkWidth / 2, FLOOR_TOP + 0.25, nsCenterZ), Color3.fromRGB(190, 190, 185), Enum.Material.Concrete, lobbyFolder)
	makePart("NeighborhoodSidewalkNSWest", Vector3.new(sidewalkWidth, 0.5, nsLength), Vector3.new(NEIGHBORHOOD_ROAD_X - NEIGHBORHOOD_ROAD_WIDTH / 2 - sidewalkWidth / 2, FLOOR_TOP + 0.25, nsCenterZ), Color3.fromRGB(190, 190, 185), Enum.Material.Concrete, lobbyFolder)

	for i = 0, math.floor(nsLength / 8) do
		local dash = makePart("NeighborhoodDashNS" .. i, Vector3.new(0.6, 0.45, 3), Vector3.new(NEIGHBORHOOD_ROAD_X, FLOOR_TOP + 0.21, nsMinZ + i * 8), Color3.fromRGB(255, 224, 110), Enum.Material.SmoothPlastic, lobbyFolder)
		dash.CanCollide = false
	end

	-- East-West: runs through the row gap, reaching past both columns.
	local ewMinX, ewMaxX = -40, 230
	local ewLength = ewMaxX - ewMinX
	local ewCenterX = (ewMinX + ewMaxX) / 2
	makePart("NeighborhoodRoadEW", Vector3.new(ewLength, 0.4, NEIGHBORHOOD_ROAD_WIDTH), Vector3.new(ewCenterX, FLOOR_TOP + 0.2, NEIGHBORHOOD_ROAD_Z), Color3.fromRGB(58, 58, 62), Enum.Material.Asphalt, lobbyFolder)
	makePart("NeighborhoodSidewalkEWNorth", Vector3.new(ewLength, 0.5, sidewalkWidth), Vector3.new(ewCenterX, FLOOR_TOP + 0.25, NEIGHBORHOOD_ROAD_Z + NEIGHBORHOOD_ROAD_WIDTH / 2 + sidewalkWidth / 2), Color3.fromRGB(190, 190, 185), Enum.Material.Concrete, lobbyFolder)
	makePart("NeighborhoodSidewalkEWSouth", Vector3.new(ewLength, 0.5, sidewalkWidth), Vector3.new(ewCenterX, FLOOR_TOP + 0.25, NEIGHBORHOOD_ROAD_Z - NEIGHBORHOOD_ROAD_WIDTH / 2 - sidewalkWidth / 2), Color3.fromRGB(190, 190, 185), Enum.Material.Concrete, lobbyFolder)

	for i = 0, math.floor(ewLength / 8) do
		local dash = makePart("NeighborhoodDashEW" .. i, Vector3.new(3, 0.45, 0.6), Vector3.new(ewMinX + i * 8, FLOOR_TOP + 0.21, NEIGHBORHOOD_ROAD_Z), Color3.fromRGB(255, 224, 110), Enum.Material.SmoothPlastic, lobbyFolder)
		dash.CanCollide = false
	end

	-- Link road: the missing connector that makes the whole network one system.
	-- Runs E-W at Z = -55 (clear north of the plaza, south of the plot row) from
	-- the N-S neighborhood road (X=80) east to Cross Street (X=150), so you can
	-- drive plaza <-> plots. Overlaps both roads at its ends for clean junctions.
	local linkMinX, linkMaxX = NEIGHBORHOOD_ROAD_X, 150
	local linkZ = -55
	local linkLen = (linkMaxX - linkMinX) + NEIGHBORHOOD_ROAD_WIDTH
	local linkCenterX = (linkMinX + linkMaxX) / 2
	makePart("LinkRoad", Vector3.new(linkLen, 0.4, NEIGHBORHOOD_ROAD_WIDTH), Vector3.new(linkCenterX, FLOOR_TOP + 0.2, linkZ), Color3.fromRGB(58, 58, 62), Enum.Material.Asphalt, lobbyFolder)
	makePart("LinkSidewalkN", Vector3.new(linkMaxX - linkMinX, 0.5, sidewalkWidth), Vector3.new(linkCenterX, FLOOR_TOP + 0.25, linkZ + NEIGHBORHOOD_ROAD_WIDTH / 2 + sidewalkWidth / 2), Color3.fromRGB(190, 190, 185), Enum.Material.Concrete, lobbyFolder)
	makePart("LinkSidewalkS", Vector3.new(linkMaxX - linkMinX, 0.5, sidewalkWidth), Vector3.new(linkCenterX, FLOOR_TOP + 0.25, linkZ - NEIGHBORHOOD_ROAD_WIDTH / 2 - sidewalkWidth / 2), Color3.fromRGB(190, 190, 185), Enum.Material.Concrete, lobbyFolder)
	for i = 0, math.floor((linkMaxX - linkMinX) / 8) do
		local dash = makePart("LinkDash" .. i, Vector3.new(3, 0.45, 0.6), Vector3.new(linkMinX + i * 8, FLOOR_TOP + 0.21, linkZ), Color3.fromRGB(255, 224, 110), Enum.Material.SmoothPlastic, lobbyFolder)
		dash.CanCollide = false
	end
end

-- Zebra crosswalks across the N-S roads at every junction, so the connected
-- network reads as a real road grid with proper crossings.
local function buildCrosswalks(lobbyFolder)
	local white = Color3.fromRGB(240, 240, 236)
	-- Each spot crosses a N-S road (traffic along Z): bars run along Z, spaced
	-- across the road width in X.
	local spots = {
		{ x = 80, z = -55 }, { x = 80, z = 23 }, { x = 80, z = 95 }, { x = 80, z = 183 }, { x = 150, z = -55 },
	}
	for si, s in ipairs(spots) do
		for i = -4, 4 do
			local bar = makePart("Crosswalk" .. si .. "_" .. (i + 5), Vector3.new(0.9, 0.46, 4.5), Vector3.new(s.x + i * 1.6, FLOOR_TOP + 0.22, s.z), white, Enum.Material.SmoothPlastic, lobbyFolder)
			bar.CanCollide = false
		end
	end
end

-- ==== Unified road network =================================================
-- The whole road grid as data (world coords): EW roads run along X at a fixed
-- Z; NS roads run along Z at a fixed X. buildRoads lays clean asphalt but
-- BREAKS the sidewalks and lane dashes at every crossing, so intersections read
-- logically instead of sidewalks cutting straight across other roads. Same
-- centerlines as before -> cars are unaffected.
local ROAD_ASPHALT = Color3.fromRGB(58, 58, 62)
local ROAD_SIDEWALK = Color3.fromRGB(190, 190, 185)
local ROAD_DASH = Color3.fromRGB(255, 224, 110)
local SIDEWALK_W = 5
local EW_ROADS = {
	{ name = "MainStreet", z = -145, x0 = 25, x1 = 190 },
	{ name = "LinkRoad", z = -55, x0 = 72, x1 = 158 },
	{ name = "AvenueFront", z = 23, x0 = -25, x1 = 185 },
	{ name = "NeighborhoodEW", z = 95, x0 = -40, x1 = 230 },
	{ name = "AvenueBack", z = 183, x0 = -25, x1 = 185 },
}
local NS_ROADS = {
	{ name = "NeighborhoodNS", x = 80, z0 = -55, z1 = 230 },
	{ name = "CrossStreet", x = 150, z0 = -250, z1 = -35 },
}

-- Split [from,to] into the segments left after removing each gap {c=centre,h=half}.
local function segmentsWithGaps(from, to, gaps)
	table.sort(gaps, function(a, b) return a.c < b.c end)
	local segs, cur = {}, from
	for _, g in ipairs(gaps) do
		local lo, hi = g.c - g.h, g.c + g.h
		if hi > cur and lo < to then
			if lo > cur then segs[#segs + 1] = { cur, lo } end
			cur = math.max(cur, hi)
		end
	end
	if cur < to then segs[#segs + 1] = { cur, to } end
	return segs
end

local function buildRoads(lobbyFolder)
	local halfR = ROAD_WIDTH / 2
	local y = FLOOR_TOP
	-- Asphalt (NS a hair higher so it covers EW cleanly where they overlap).
	for _, r in ipairs(EW_ROADS) do
		makePart("Road_" .. r.name, Vector3.new(r.x1 - r.x0, 0.4, ROAD_WIDTH), Vector3.new((r.x0 + r.x1) / 2, y + 0.20, r.z), ROAD_ASPHALT, Enum.Material.Asphalt, lobbyFolder)
	end
	for _, r in ipairs(NS_ROADS) do
		makePart("Road_" .. r.name, Vector3.new(ROAD_WIDTH, 0.4, r.z1 - r.z0), Vector3.new(r.x, y + 0.22, (r.z0 + r.z1) / 2), ROAD_ASPHALT, Enum.Material.Asphalt, lobbyFolder)
	end
	-- EW sidewalks + dashes, broken where an NS road crosses.
	for _, r in ipairs(EW_ROADS) do
		local gaps = {}
		for _, n in ipairs(NS_ROADS) do
			if n.x >= r.x0 and n.x <= r.x1 and r.z >= n.z0 and r.z <= n.z1 then
				gaps[#gaps + 1] = { c = n.x, h = halfR + SIDEWALK_W }
			end
		end
		for _, side in ipairs({ 1, -1 }) do
			local sz = r.z + side * (halfR + SIDEWALK_W / 2)
			for si, seg in ipairs(segmentsWithGaps(r.x0, r.x1, gaps)) do
				if seg[2] - seg[1] > 0.5 then
					makePart(r.name .. "Walk" .. (side > 0 and "N" or "S") .. si, Vector3.new(seg[2] - seg[1], 0.5, SIDEWALK_W), Vector3.new((seg[1] + seg[2]) / 2, y + 0.25, sz), ROAD_SIDEWALK, Enum.Material.Concrete, lobbyFolder)
				end
			end
		end
		local x = r.x0 + 4
		while x < r.x1 do
			local blocked = false
			for _, g in ipairs(gaps) do if math.abs(x - g.c) < g.h then blocked = true break end end
			if not blocked then
				makePart(r.name .. "Dash", Vector3.new(3, 0.2, 0.6), Vector3.new(x, y + 0.42, r.z), ROAD_DASH, Enum.Material.SmoothPlastic, lobbyFolder).CanCollide = false
			end
			x += 8
		end
	end
	-- NS sidewalks + dashes, broken where an EW road crosses.
	for _, r in ipairs(NS_ROADS) do
		local gaps = {}
		for _, e in ipairs(EW_ROADS) do
			if e.z >= r.z0 and e.z <= r.z1 and r.x >= e.x0 and r.x <= e.x1 then
				gaps[#gaps + 1] = { c = e.z, h = halfR + SIDEWALK_W }
			end
		end
		for _, side in ipairs({ 1, -1 }) do
			local sx = r.x + side * (halfR + SIDEWALK_W / 2)
			for si, seg in ipairs(segmentsWithGaps(r.z0, r.z1, gaps)) do
				if seg[2] - seg[1] > 0.5 then
					makePart(r.name .. "Walk" .. (side > 0 and "E" or "W") .. si, Vector3.new(SIDEWALK_W, 0.5, seg[2] - seg[1]), Vector3.new(sx, y + 0.25, (seg[1] + seg[2]) / 2), ROAD_SIDEWALK, Enum.Material.Concrete, lobbyFolder)
				end
			end
		end
		local z = r.z0 + 4
		while z < r.z1 do
			local blocked = false
			for _, g in ipairs(gaps) do if math.abs(z - g.c) < g.h then blocked = true break end end
			if not blocked then
				makePart(r.name .. "DashZ", Vector3.new(0.6, 0.2, 3), Vector3.new(r.x, y + 0.44, z), ROAD_DASH, Enum.Material.SmoothPlastic, lobbyFolder).CanCollide = false
			end
			z += 8
		end
	end
end

-- The project's default 512x512 Baseplate was never restyled -- it still
-- looks like plain grey placeholder plastic everywhere outside the
-- plaza/road area. Recolor it to a neutral pavement tone so the rest of
-- the map reads as city ground instead of an obvious grey void.
-- The whole town sits on the FLOOR_TOP = 1 ground convention, but the
-- default baseplate's top was at Y = 0, leaving a 1-stud gap that made
-- everything look like it floated and left the grey placeholder plate
-- showing everywhere. Raise the plate so its TOP is exactly at FLOOR_TOP
-- and turn it into a big grass field, so nothing floats and no baseplate
-- is visible anywhere on the map.
local function restyleBaseplate()
	local baseplate = workspace:FindFirstChild("Baseplate")
	if not baseplate then
		return
	end

	-- Enlarge it so there is room for a mountain ring WELL outside the town
	-- (buildings reach out to ~230 studs; the mountains sit past that), and
	-- so no grass edge is ever visible.
	local thickness = baseplate.Size.Y
	baseplate.Size = Vector3.new(1000, thickness, 1000)
	baseplate.Position = Vector3.new(0, FLOOR_TOP - thickness / 2, 0)
	baseplate.Material = Enum.Material.Grass
	baseplate.Color = Color3.fromRGB(96, 158, 86)
end

-- A detailed background skyscraper: concrete tower body, glass window bands
-- framed with white mullions, corner pilasters, a glass ground-floor lobby,
-- and a capped roof. These are just the city backdrop -- the actual shops
-- are separate, low buildings (see buildShops), so towers no longer wear
-- shop signs and pretend to be shoppable.
local function buildTower(lobbyFolder, name, position, width, depth, height, color)
	-- Detailed Blender skyscraper (glass curtain wall + mullion frame). A random
	-- variant is stretched to this slot, its glass tinted from a palette so the
	-- skyline varies like real downtown towers. Else the procedural tower below.
	if StudioModels.has("Tower") then
		-- RoTube-Life-2 look: bright solid body, contrasting trim, warm-lit windows.
		local bodyColors = {
			Color3.fromRGB(244, 244, 248), -- white
			Color3.fromRGB(246, 232, 214), -- cream
			Color3.fromRGB(120, 178, 226), -- sky blue
			Color3.fromRGB(232, 132, 128), -- coral
			Color3.fromRGB(150, 206, 190), -- mint
			Color3.fromRGB(120, 136, 200), -- periwinkle
		}
		local trimColors = {
			Color3.fromRGB(250, 250, 252), -- white
			Color3.fromRGB(60, 74, 120), -- navy
			Color3.fromRGB(150, 62, 58), -- maroon
			Color3.fromRGB(120, 126, 140), -- slate grey
		}
		local body = bodyColors[math.random(#bodyColors)]
		local trim = trimColors[math.random(#trimColors)]
		-- Don't let body and trim be the same near-white pair (low contrast).
		if body == bodyColors[1] and trim == trimColors[1] then
			trim = trimColors[2]
		end
		StudioModels.placeTower("Tower", lobbyFolder, position,
			Vector3.new(width, height, depth), body, trim,
			Color3.fromRGB(255, 226, 150), name)
		return
	end

	makePart(name, Vector3.new(width, height, depth), position + Vector3.new(0, height / 2, 0), color, Enum.Material.Concrete, lobbyFolder)

	-- Corner pilasters for crisp edges.
	for i, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		local p = makePart(name .. "Pilaster" .. i, Vector3.new(1, height, 1), position + Vector3.new(c[1] * (width / 2 - 0.2), height / 2, c[2] * (depth / 2 - 0.2)), Color3.fromRGB(250, 250, 252), Enum.Material.SmoothPlastic, lobbyFolder)
		p.CanCollide = false
	end

	-- Glass window bands (front + back faces) with a white sill line -- no
	-- more big neon bands (keeps the skyline bright but not glaring).
	local bandCount = math.floor((height - 8) / 6)
	for band = 1, bandCount do
		local bandY = 8 + band * 6 - 3
		for _, sz in ipairs({ -1, 1 }) do
			local win = makePart(name .. "Win" .. band .. "_" .. (sz > 0 and "F" or "B"), Vector3.new(width - 3, 3, 0.3), position + Vector3.new(0, bandY, sz * (depth / 2 + 0.05)), Color3.fromRGB(150, 200, 230), Enum.Material.Glass, lobbyFolder)
			win.CanCollide = false
			win.Transparency = 0.35
			local sill = makePart(name .. "Sill" .. band .. "_" .. (sz > 0 and "F" or "B"), Vector3.new(width - 2.5, 0.4, 0.35), position + Vector3.new(0, bandY - 1.7, sz * (depth / 2 + 0.05)), Color3.fromRGB(250, 250, 252), Enum.Material.SmoothPlastic, lobbyFolder)
			sill.CanCollide = false
		end
	end

	-- Glass ground-floor lobby (just a building entrance, not a shop).
	local frontZ = position.Z - depth / 2
	local lobbyGlass = makePart(name .. "GroundGlass", Vector3.new(width - 2, 6, 0.3), Vector3.new(position.X, FLOOR_TOP + 3, frontZ - 0.05), Color3.fromRGB(150, 200, 230), Enum.Material.Glass, lobbyFolder)
	lobbyGlass.CanCollide = false
	lobbyGlass.Transparency = 0.3

	-- Capped roof + a small rooftop unit.
	makePart(name .. "RoofCap", Vector3.new(width + 1.5, 1, depth + 1.5), position + Vector3.new(0, height + 0.5, 0), Color3.fromRGB(210, 210, 214), Enum.Material.Concrete, lobbyFolder)
	makePart(name .. "RoofUnit", Vector3.new(width * 0.4, 2.5, depth * 0.4), position + Vector3.new(width * 0.15, height + 2.2, depth * 0.15), Color3.fromRGB(150, 150, 155), Enum.Material.Metal, lobbyFolder)
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
		-- (removed the x=72 tower: world X 152 landed right on the cross street)
		{ x = 98, z = skylineZ, width = 12, depth = 12, height = 30, color = ACCENT_COLOR },
	}

	for i, config in ipairs(towerConfigs) do
		buildTower(lobbyFolder, "Skyscraper" .. i, LOBBY_ORIGIN + Vector3.new(config.x, 0, config.z), config.width, config.depth, config.height, config.color)
	end

	-- Cross-street towers, north of the plaza, toward the plot area.
	local crossOffset = ROAD_WIDTH / 2 + 5 + 22
	local crossTowerConfigs = {
		-- (removed the z=40 west tower: world (115,-60) landed on the new link road)
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
	-- Was at x = -85/-65, which sat directly inside the beach/water zone
	-- built later (water spans roughly x -121 to -61). Moved to open
	-- ground north of the plaza, clear of both the water and the cross
	-- street's skyscrapers (at x = CROSS_ROAD_X +/- 35).
	local houseZ = 45
	local houseSpots = { -10, 10 }

	-- Roof tones so the two houses differ a little.
	local roofTones = { Color3.fromRGB(176, 72, 60), Color3.fromRGB(96, 116, 150) }

	for i, x in ipairs(houseSpots) do
		local position = LOBBY_ORIGIN + Vector3.new(x, 0, houseZ)

		-- Detailed Blender house (front faces -Z, toward the plaza) if synced.
		if StudioModels.has("House") then
			local roof = roofTones[i] or roofTones[1]
			StudioModels.placeColored("House", lobbyFolder,
				CFrame.new(position + Vector3.new(0, FLOOR_TOP, 0)), 13, function(p)
					local n = p.Name
					if n:find("Roof") then
						p.Color, p.Material = roof, Enum.Material.Slate
					elseif n:find("Door") and not n:find("Frame") then
						p.Color, p.Material = Color3.fromRGB(120, 80, 50), Enum.Material.Wood
					elseif n:find("Window") and not n:find("Frame") then
						p.Color, p.Material, p.Transparency = Color3.fromRGB(175, 212, 235), Enum.Material.Glass, 0.3
					elseif n:find("Chimney") then
						p.Color, p.Material = Color3.fromRGB(150, 92, 80), Enum.Material.Brick
					elseif n:find("Foundation") then
						p.Color, p.Material = Color3.fromRGB(150, 148, 142), Enum.Material.Concrete
					else
						p.Color, p.Material = Color3.fromRGB(235, 232, 225), Enum.Material.SmoothPlastic
					end
					p.CanCollide = true
				end, "NeighborHouse" .. i, 0.06, 0)
		else
			local wallColor = Color3.fromRGB(235, 232, 225)
			makePart("NeighborHouse" .. i .. "Base", Vector3.new(10, 6, 8), position + Vector3.new(0, FLOOR_TOP + 3, 0), wallColor, Enum.Material.SmoothPlastic, lobbyFolder)
			makePart("NeighborHouse" .. i .. "Roof", Vector3.new(11, 1, 9), position + Vector3.new(0, FLOOR_TOP + 6.5, 0), Color3.fromRGB(240, 240, 238), Enum.Material.Concrete, lobbyFolder)
			local window = makePart("NeighborHouse" .. i .. "Window", Vector3.new(2.5, 2.5, 0.2), position + Vector3.new(0, FLOOR_TOP + 3.5, -4.05), Color3.fromRGB(180, 215, 230), Enum.Material.Glass, lobbyFolder)
			window.CanCollide = false
		end
	end
end

-- Two kinds of car:
--  * straight cars ping-pong along a road segment. Their bounds stop clear
--    of the roundabout island so they never need to swerve (axis "x" =
--    Main Street, "z" = Cross Street).
--  * orbit cars circle the roundabout at a constant angular speed, so the
--    junction has smooth, real-looking circulating traffic (this replaces
--    the old position-snapping that made cars slide sideways).
-- The whole car assembly's resting height (used both when building it and
-- when the animation loop re-pivots it every frame). Road surface top is
-- at FLOOR_TOP + 0.4 (road center FLOOR_TOP + 0.2, half-thickness 0.2);
-- wheels (radius 0.3) need their center at FLOOR_TOP + 0.7 so their
-- bottom sits flush on the road. This used to only be applied to the
-- part offsets built in buildCar -- the animation loop's PivotTo pinned
-- the body back down to plain FLOOR_TOP every frame, burying the whole
-- car under the road surface. Caught live: read back the actual Car1
-- part positions after a Play restart and found Wheel.Y = 0.3 (below
-- the road's own top at Y = 1.4) despite buildCar looking correct.
local CAR_BODY_REST_Y = FLOOR_TOP + 1.4

local function buildCar(lobbyFolder, name, color, height, modelName)
	-- Detailed Blender car if synced. The animation pivots every car at world
	-- Y = CAR_BODY_REST_Y (2.4); the road top is at 1.4, so we set the model's
	-- pivot 1.0 stud above the wheel bottom, which lands the wheels on the road.
	-- `modelName` picks the body type (Car / Van / Truck / SportsCar), falling
	-- back to the base Car if that type isn't synced; `height` varies the size.
	modelName = (modelName and StudioModels.has(modelName)) and modelName or "Car"
	local m = StudioModels.get(modelName)
	-- Guard against an empty/failed import (asset exists but has no parts):
	-- discard it and fall back to the base Car so a car is never invisible.
	if m and not m:FindFirstChildWhichIsA("BasePart", true) then
		m:Destroy()
		m = (modelName ~= "Car") and StudioModels.get("Car") or nil
	end
	if m then
		m.Name = name
		local _, size = m:GetBoundingBox()
		if size.Y > 0 then
			m:ScaleTo(m:GetScale() * ((height or 3.0) / size.Y))
		end
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then
				local n = p.Name
				if n:find("Wheel") then
					p.Color, p.Material = Color3.fromRGB(28, 28, 32), Enum.Material.SmoothPlastic
				elseif n:find("Window") then
					p.Color, p.Material, p.Transparency = Color3.fromRGB(120, 150, 170), Enum.Material.Glass, 0.3
				elseif n:find("Trim") then
					p.Color, p.Material = Color3.fromRGB(60, 60, 66), Enum.Material.Metal
				else
					p.Color, p.Material = color, Enum.Material.SmoothPlastic
				end
				p.Anchored = true
				p.CanCollide = false
			end
		end
		local cf, sz = m:GetBoundingBox()
		m.WorldPivot = CFrame.new(cf.Position.X, cf.Position.Y - sz.Y / 2 + 1.0, cf.Position.Z)
		m.Parent = lobbyFolder
		return m
	end

	local carModel = Instance.new("Model")
	carModel.Name = name
	carModel.Parent = lobbyFolder

	-- clipping 0.3 studs into it -- the original FLOOR_TOP + 0.4 center
	-- put the wheel bottom below the road surface, hiding the wheels.
	local body = makePart("Body", Vector3.new(4, 1.2, 2), Vector3.new(0, CAR_BODY_REST_Y, 0), color, Enum.Material.SmoothPlastic, carModel)
	local cabin = makePart("Cabin", Vector3.new(2, 0.8, 1.8), Vector3.new(0, FLOOR_TOP + 2.3, 0), color, Enum.Material.SmoothPlastic, carModel)
	cabin.CanCollide = false

	local wheelPositions = {
		Vector3.new(-1.3, FLOOR_TOP + 0.7, -0.9),
		Vector3.new(1.3, FLOOR_TOP + 0.7, -0.9),
		Vector3.new(-1.3, FLOOR_TOP + 0.7, 0.9),
		Vector3.new(1.3, FLOOR_TOP + 0.7, 0.9),
	}
	for i, offset in ipairs(wheelPositions) do
		local wheel = makePart("Wheel" .. i, Vector3.new(0.6, 0.6, 0.3), offset, DARK_TRIM_COLOR, Enum.Material.SmoothPlastic, carModel)
		wheel.CanCollide = false
	end

	carModel.PrimaryPart = body
	return carModel
end

local ROUNDABOUT_CENTER_OFFSET = Vector3.new(CROSS_ROAD_X, 0, ROAD_Z)

-- Cars follow waypoint ROUTES across the whole connected network, driving out
-- to the end of a route and back (so they cover the entire road, not one
-- stretch). Routes that touch the roundabout arc around it and leave by a
-- chosen exit, so cars are seen circling the roundabout and picking a road.
local RB = Vector3.new(150, CAR_BODY_REST_Y, -145) -- roundabout centre (world)
local RB_R = 13 -- driving radius on the roundabout

local function wp(x, z)
	return Vector3.new(x, CAR_BODY_REST_Y, z)
end
-- Arc waypoints around the roundabout from angle a0 to a1 (degrees).
local function arcPts(a0, a1, steps)
	local pts = {}
	for k = 0, steps do
		local a = math.rad(a0 + (a1 - a0) * (k / steps))
		pts[#pts + 1] = Vector3.new(RB.X + math.cos(a) * RB_R, CAR_BODY_REST_Y, RB.Z + math.sin(a) * RB_R)
	end
	return pts
end
local function appendAll(t, more)
	for _, v in ipairs(more) do
		t[#t + 1] = v
	end
end

-- Roundabout arms (point = centre + R*(cos,sin)): east=0, south=90, west=180,
-- north=270 (in world Z, +Z is south of the roundabout).
local function buildCarRoutes()
	-- West Main Street -> roundabout (west->north quarter) -> up Cross Street.
	local r1 = { wp(30, -145), wp(137, -145) }
	appendAll(r1, arcPts(180, 270, 5))
	appendAll(r1, { wp(150, -240) })
	-- East Main Street -> roundabout (east->south quarter) -> Cross St south ->
	-- link road -> up the neighborhood road to the plots.
	local r2 = { wp(188, -145), wp(163, -145) }
	appendAll(r2, arcPts(0, 90, 5))
	appendAll(r2, { wp(150, -55), wp(80, -55), wp(80, 210) })
	-- Neighborhood east-west road, and the two plot avenues (straight runs).
	local r3 = { wp(-35, 95), wp(225, 95) }
	local r4 = { wp(-20, 23), wp(180, 23) }
	local r5 = { wp(-20, 183), wp(180, 183) }
	return { r1, r2, r3, r4, r5 }
end

-- Cars spread across the routes, mixing distinct body types (Car sedan / Van /
-- Truck / SportsCar -- fall back to Car until each mesh is synced), each sized
-- to suit its type.
local CAR_SPAWN = {
	{ route = 1, off = 0.0, speed = 22, h = 3.0, model = "Car", color = Color3.fromRGB(200, 55, 50) },
	{ route = 1, off = 0.4, speed = 16, h = 3.4, model = "Van", color = Color3.fromRGB(70, 80, 92) },
	{ route = 1, off = 0.75, speed = 26, h = 2.7, model = "SportsCar", color = Color3.fromRGB(235, 232, 225) },
	{ route = 2, off = 0.0, speed = 20, h = 3.0, model = "Car", color = Color3.fromRGB(60, 110, 200) },
	{ route = 2, off = 0.35, speed = 15, h = 3.5, model = "Truck", color = Color3.fromRGB(120, 92, 60) },
	{ route = 2, off = 0.7, speed = 26, h = 2.7, model = "SportsCar", color = Color3.fromRGB(90, 180, 90) },
	{ route = 3, off = 0.0, speed = 24, h = 3.0, model = "Car", color = Color3.fromRGB(235, 209, 102) },
	{ route = 3, off = 0.5, speed = 17, h = 3.4, model = "Van", color = Color3.fromRGB(150, 90, 210) },
	{ route = 4, off = 0.0, speed = 21, h = 2.8, model = "Car", color = Color3.fromRGB(230, 120, 60) },
	{ route = 4, off = 0.5, speed = 15, h = 3.5, model = "Truck", color = Color3.fromRGB(60, 170, 180) },
	{ route = 5, off = 0.0, speed = 20, h = 3.0, model = "Car", color = Color3.fromRGB(80, 190, 200) },
	{ route = 5, off = 0.5, speed = 17, h = 3.4, model = "Van", color = Color3.fromRGB(212, 90, 140) },
}

local function buildCars(lobbyFolder)
	local routes = buildCarRoutes()
	for _, route in ipairs(routes) do
		local cum, total = { 0 }, 0
		for i = 1, #route - 1 do
			total += (route[i + 1] - route[i]).Magnitude
			cum[i + 1] = total
		end
		route.cum, route.total = cum, total
	end
	for i, cfg in ipairs(CAR_SPAWN) do
		local model = buildCar(lobbyFolder, "Car" .. i, cfg.color, cfg.h, cfg.model)
		local route = routes[cfg.route]
		table.insert(activeCars, { model = model, route = route, dist = route.total * cfg.off, dir = 1, speed = cfg.speed })
	end
end

local carAnimationConnection

-- Position + travel direction at arc-length `dist` along a route's polyline.
local function posAlong(route, dist)
	local cum = route.cum
	for i = 1, #route - 1 do
		if dist <= cum[i + 1] or i == #route - 1 then
			local segLen = cum[i + 1] - cum[i]
			local f = segLen > 0 and math.clamp((dist - cum[i]) / segLen, 0, 1) or 0
			return route[i]:Lerp(route[i + 1], f), (route[i + 1] - route[i])
		end
	end
	return route[1], route[2] - route[1]
end

local function startCarAnimation()
	if carAnimationConnection then
		carAnimationConnection:Disconnect()
	end
	carAnimationConnection = RunService.Heartbeat:Connect(function(dt)
		for _, car in ipairs(activeCars) do
			car.dist += dt * car.speed * car.dir
			if car.dist >= car.route.total then
				car.dist, car.dir = car.route.total, -1
			elseif car.dist <= 0 then
				car.dist, car.dir = 0, 1
			end
			local pos, vel = posAlong(car.route, car.dist)
			vel = vel * car.dir
			if vel.Magnitude > 0.001 then
				-- +180: the imported car meshes' visual front ends up on -X, so
				-- point that (not +X) along the travel direction.
				local facingDeg = math.deg(math.atan2(-vel.Z, vel.X)) + 180
				car.model:PivotTo(CFrame.new(pos) * CFrame.Angles(0, math.rad(facingDeg), 0))
			end
		end
	end)
end

-- A simple blocky NPC (torso is the PrimaryPart so it can be pivoted around
-- as one rigid model). Built at a ground position; parts stack upward from it.
local function buildNPC(lobbyFolder, name, position, shirt, pants, skin, hat)
	-- Detailed Blender person if synced. Built to the walk loop's proportions
	-- (feet on the ground, Torso centre 3.9 up = the model's PrimaryPart), so
	-- pedestrians glide + bob and shopkeepers stand put. Single mesh = no
	-- per-leg swing (returns nil legs).
	if StudioModels.has("Person") then
		local m = StudioModels.get("Person")
		m.Name = name
		local _, size = m:GetBoundingBox()
		if size.Y > 0 then
			m:ScaleTo(m:GetScale() * (7 / size.Y))
		end
		local torso
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then
				local n = p.Name
				if n:find("Torso") then
					p.Color, torso = shirt, p
				elseif n:find("Pants") then
					p.Color = pants
				elseif n:find("Hair") then
					p.Color = hat or Color3.fromRGB(70, 50, 40)
				elseif n:find("Eye") then
					p.Color = Color3.fromRGB(40, 40, 40)
				else
					p.Color = skin
				end
				p.Material, p.Anchored, p.CanCollide = Enum.Material.SmoothPlastic, true, false
			end
		end
		m.Parent = lobbyFolder
		-- Sit the feet on the ground at `position`.
		m:PivotTo(CFrame.new(position))
		local cf, sz = m:GetBoundingBox()
		m:PivotTo(m:GetPivot() + Vector3.new(0, position.Y - (cf.Position.Y - sz.Y / 2), 0))
		-- Invisible IDENTITY-oriented root as the PrimaryPart, 3.9 above the
		-- feet. The walk loop PivotTo's a look-at CFrame; with an identity root
		-- that is a pure yaw, so the mesh stays UPRIGHT. (Using a mesh part as
		-- the PrimaryPart stripped the import's up-axis rotation and laid the
		-- character flat on its back.)
		local root = Instance.new("Part")
		root.Name = "NPCRoot"
		root.Size = Vector3.new(1, 1, 1)
		root.Transparency = 1
		root.CanCollide = false
		root.Anchored = true
		root.CFrame = CFrame.new(position + Vector3.new(0, 3.9, 0))
		root.Parent = m
		m.PrimaryPart = root
		return m, nil, nil
	end

	local model = Instance.new("Model")
	model.Name = name
	model.Parent = lobbyFolder

	local function part(pname, size, offset, color)
		local p = makePart(name .. pname, size, position + offset, color, Enum.Material.SmoothPlastic, lobbyFolder)
		p.CanCollide = false
		p.Parent = model
		return p
	end

	local legL = part("LegL", Vector3.new(0.7, 2.6, 0.7), Vector3.new(-0.4, 1.3, 0), pants)
	local legR = part("LegR", Vector3.new(0.7, 2.6, 0.7), Vector3.new(0.4, 1.3, 0), pants)
	local torso = part("Torso", Vector3.new(2, 2.6, 1), Vector3.new(0, 3.9, 0), shirt)
	part("ArmL", Vector3.new(0.6, 2.4, 0.7), Vector3.new(-1.3, 3.9, 0), skin)
	part("ArmR", Vector3.new(0.6, 2.4, 0.7), Vector3.new(1.3, 3.9, 0), skin)
	part("Head", Vector3.new(1.3, 1.3, 1.3), Vector3.new(0, 5.85, 0), skin)
	-- Eyes on the -Z (forward) face so they look where they walk.
	part("EyeL", Vector3.new(0.22, 0.22, 0.1), Vector3.new(-0.3, 5.95, -0.65), Color3.fromRGB(40, 40, 40))
	part("EyeR", Vector3.new(0.22, 0.22, 0.1), Vector3.new(0.3, 5.95, -0.65), Color3.fromRGB(40, 40, 40))
	part("Hair", Vector3.new(1.4, 0.5, 1.4), Vector3.new(0, 6.55, 0), hat or Color3.fromRGB(70, 50, 40))

	model.PrimaryPart = torso
	-- Return the legs too so the walk loop can swing them. Their rest offset
	-- from the torso: hip at torso + (+-0.4, -1.3, 0), leg centre 1.3 below.
	return model, legL, legR
end

local NPC_PALETTE = {
	{ shirt = Color3.fromRGB(220, 90, 90), pants = Color3.fromRGB(60, 62, 74), skin = Color3.fromRGB(240, 205, 165) },
	{ shirt = Color3.fromRGB(80, 150, 220), pants = Color3.fromRGB(70, 60, 50), skin = Color3.fromRGB(210, 160, 120) },
	{ shirt = Color3.fromRGB(110, 200, 140), pants = Color3.fromRGB(50, 52, 62), skin = Color3.fromRGB(245, 220, 185) },
	{ shirt = Color3.fromRGB(240, 200, 90), pants = Color3.fromRGB(60, 62, 74), skin = Color3.fromRGB(190, 140, 100) },
	{ shirt = Color3.fromRGB(180, 120, 220), pants = Color3.fromRGB(55, 57, 68), skin = Color3.fromRGB(235, 195, 160) },
}

-- A tiered fountain centrepiece for the plaza: a round basin with water and
-- a bubbling top tier.
local function buildFountain(lobbyFolder)
	local center = LOBBY_ORIGIN + Vector3.new(0, 0, -10)

	local function disc(pname, diameter, thickness, y, color, material)
		local d = Instance.new("Part")
		d.Name = pname
		d.Shape = Enum.PartType.Cylinder
		d.Size = Vector3.new(thickness, diameter, diameter)
		d.CFrame = CFrame.new(center + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.rad(90))
		d.Anchored = true
		d.Color = color
		d.Material = material
		d.Parent = lobbyFolder
		return d
	end

	disc("FountainBasin", 18, 1.6, FLOOR_TOP + 0.8, Color3.fromRGB(226, 222, 214), Enum.Material.Marble)
	local water1 = disc("FountainWater1", 15, 0.4, FLOOR_TOP + 1.5, Color3.fromRGB(90, 180, 220), Enum.Material.Water)
	water1.CanCollide = false
	water1.Transparency = 0.3
	disc("FountainTier2", 9, 2.4, FLOOR_TOP + 2.6, Color3.fromRGB(226, 222, 214), Enum.Material.Marble)
	local water2 = disc("FountainWater2", 7, 0.4, FLOOR_TOP + 3.9, Color3.fromRGB(90, 180, 220), Enum.Material.Water)
	water2.CanCollide = false
	water2.Transparency = 0.3
	makePart("FountainStem", Vector3.new(1.4, 3, 1.4), center + Vector3.new(0, FLOOR_TOP + 5, 0), Color3.fromRGB(226, 222, 214), Enum.Material.Marble, lobbyFolder)
	local spout = makePart("FountainSpout", Vector3.new(2.4, 2.4, 2.4), center + Vector3.new(0, FLOOR_TOP + 6.8, 0), Color3.fromRGB(150, 205, 235), Enum.Material.Glass, lobbyFolder)
	spout.Shape = Enum.PartType.Ball
	spout.CanCollide = false
	spout.Transparency = 0.35

	-- Real benches (seat + backrest + legs) ringing the fountain, each facing
	-- inward toward the water.
	for i, ang in ipairs({ 45, 135, 225, 315 }) do
		local rad = math.rad(ang)
		local seatPos = center + Vector3.new(math.cos(rad) * 14, FLOOR_TOP + 1, math.sin(rad) * 14)
		-- Face the fountain: bench -Z points at the centre.
		local cf = CFrame.new(seatPos, Vector3.new(center.X, seatPos.Y, center.Z))
		local wood, dark = Color3.fromRGB(156, 116, 78), Color3.fromRGB(90, 66, 44)
		local function benchPart(pname, size, localOffset, color)
			local p = makePart("FountainBench" .. i .. pname, size, Vector3.new(0, 0, 0), color, Enum.Material.WoodPlanks, lobbyFolder)
			p.CFrame = cf * CFrame.new(localOffset)
			p.CanCollide = false
			return p
		end
		benchPart("Seat", Vector3.new(4.5, 0.3, 1.6), Vector3.new(0, 0, 0), wood)
		benchPart("Back", Vector3.new(4.5, 1.6, 0.3), Vector3.new(0, 0.9, 0.65), wood)
		for _, lx in ipairs({ -1.8, 1.8 }) do
			benchPart("Leg" .. (lx > 0 and "R" or "L"), Vector3.new(0.3, 2, 0.3), Vector3.new(lx, -1, 0), dark)
		end
	end
end

-- A food-court row of vendor stalls with awnings + a standing vendor NPC at
-- each, giving the plaza somewhere lively to wander.
-- A ring of rocky mountains around the outer edge of the map, so the town
-- feels nestled in a valley instead of floating on an empty plate. World
-- coords (the baseplate is 512 wide, centred on the origin).
-- A low-poly, ANGULAR mountain (RoTube-Life style): a tapering stack of
-- boxy rock layers, each rotated a bit so the faces read as craggy facets,
-- with a pointed snowy summit. Not a sphere/ball. Every peak varies by its
-- seed. Base is buried so nothing floats.
-- Named mountain landmarks: the RoTube Peaks massif + the two tunnel mouths.
-- Ring peaks that land near these are skipped so nothing overlaps them.
local ROTUBE_POS = Vector3.new(-135, 0, -110)
local TUNNEL_N = Vector3.new(150, 0, -256)
local TUNNEL_S = Vector3.new(150, 0, 296)
local function nearMountainLandmark(x, z)
	-- RoTube Peaks needs a wide clearing; the tunnels only need a portal-width
	-- gap (~27 wide) so the wall stays solid right up to each side of them.
	local checks = { { ROTUBE_POS, 46 }, { TUNNEL_N, 40 }, { TUNNEL_S, 40 } }
	for _, c in ipairs(checks) do
		local p, r = c[1], c[2]
		local dx, dz = x - p.X, z - p.Z
		if dx * dx + dz * dz < r * r then
			return true
		end
	end
	return false
end

local function buildMountainPeak(lobbyFolder, name, worldPos, seed)
	-- Detailed Blender mountain if synced; else the procedural block-stack peak.
	do
		local scale = 1.0 + (seed % 5) * 0.24
		local baseW = 48 * scale
		local yaw = math.rad((seed * 37) % 360)
		local cf = CFrame.new(Vector3.new(worldPos.X, worldPos.Y - 6, worldPos.Z)) * CFrame.Angles(0, yaw, 0)
		local peakGreen = StudioModels.tinted(
			Color3.fromRGB(90, 142, 80):Lerp(Color3.fromRGB(104, 158, 90), (seed % 3) / 3),
			0.82 + math.random() * 0.34)
		local rockGrey = StudioModels.tinted(Color3.fromRGB(122, 118, 112), 0.85 + (seed % 4) * 0.08)
		local placed = StudioModels.placeColored("Mountain", lobbyFolder, cf, baseW, function(p)
			if p.Name:sub(1, 4) == "Snow" then
				p.Color, p.Material, p.CanCollide = Color3.fromRGB(246, 248, 252), Enum.Material.Sand, false
			elseif p.Name:find("Rock") then
				p.Color, p.Material, p.CanCollide = rockGrey, Enum.Material.Rock, true
			else
				p.Color, p.Material, p.CanCollide = peakGreen, Enum.Material.Grass, true
			end
		end, name, 0.18)
		if placed then
			return
		end
	end

	local greens = {
		Color3.fromRGB(96, 150, 84), Color3.fromRGB(80, 132, 72), Color3.fromRGB(104, 158, 90),
	}
	local grass = greens[(seed % #greens) + 1]
	local rock = Color3.fromRGB(122, 118, 112):Lerp(Color3.fromRGB(98, 94, 90), (seed % 3) / 3)
	local snow = Color3.fromRGB(246, 248, 252)
	local buried = 12

	local scale = 1.0 + (seed % 5) * 0.24
	local baseW = 48 * scale
	local totalH = baseW * (1.25 + (seed % 4) * 0.3)

	local layers = 5
	local y = worldPos.Y - buried
	local topY = y
	for L = 1, layers do
		local t = (L - 1) / layers
		local w = baseW * (1 - t * 0.82) -- taper to a point
		local h = (totalH / layers) * (1.15 - t * 0.15)
		-- lower layers grassy, upper layers rock.
		local color = (L >= layers - 1) and rock or grass:Lerp(rock, t * 0.35)
		local mat = (L >= layers - 1) and Enum.Material.Rock or Enum.Material.Grass
		local rot = math.rad((seed * 13 + L * 41) % 90) -- faceted, not round
		local block = makePart(name .. "L" .. L, Vector3.new(w, h, w * 0.9), Vector3.new(worldPos.X, y + h / 2, worldPos.Z), color, mat, lobbyFolder)
		block.CFrame = CFrame.new(block.Position) * CFrame.Angles(0, rot, 0)
		block.CanCollide = true -- solid so you can't walk through the mountains
		topY = y + h
		y = y + h * 0.62 -- overlap so the stack reads as one solid mass
	end

	-- Pointed snowy summit (a small rotated block cap).
	local cap = makePart(name .. "Snow", Vector3.new(baseW * 0.22, totalH * 0.16, baseW * 0.2), Vector3.new(worldPos.X, topY, worldPos.Z), snow, Enum.Material.Sand, lobbyFolder)
	cap.CFrame = CFrame.new(cap.Position) * CFrame.Angles(0, math.rad((seed * 7) % 90), 0)
	cap.CanCollide = false
end

local function buildMountains(lobbyFolder)
	-- Ring the whole town in a rectangle placed WELL outside every building
	-- (skyscrapers, plots and roads reach ~230 studs; these sit past that so
	-- nothing overlaps). Peaks sit on the rectangle edges, jittered outward.
	local xMin, xMax = -150, 290
	local zMin, zMax = -260, 300
	local step = 24 -- tight so the squared mesas overlap into a continuous wall
	local specs = {}
	local seed = 0

	local x = xMin
	while x <= xMax do
		seed += 1
		table.insert(specs, { x = x, z = zMin - (seed % 2) * 8, seed = seed })
		seed += 1
		table.insert(specs, { x = x, z = zMax + (seed % 2) * 8, seed = seed })
		x += step
	end
	local z = zMin + step
	while z < zMax do
		seed += 1
		table.insert(specs, { x = xMin - (seed % 2) * 8, z = z, seed = seed })
		seed += 1
		table.insert(specs, { x = xMax + (seed % 2) * 8, z = z, seed = seed })
		z += step
	end

	for i, s in ipairs(specs) do
		if not nearMountainLandmark(s.x, s.z) then
			buildMountainPeak(lobbyFolder, "Mountain" .. i, Vector3.new(s.x, 0, s.z), s.seed)
		end
	end
end

-- RoTube Peaks: the big landmark massif with a walkable switchback trail up to
-- a summit viewpoint (sign + flag), plus the Mountain Plunge waterfall on its
-- seaward face. Mesh + procedural detail; no-op until RoTubePeak is synced.
local function buildRoTubePeaks(lobbyFolder)
	if not StudioModels.has("RoTubePeak") then
		return
	end
	local rockGrey = Color3.fromRGB(120, 116, 110)
	local model = StudioModels.placeColored("RoTubePeak", lobbyFolder, CFrame.new(ROTUBE_POS), 78, function(p)
		if p.Name:sub(1, 4) == "Snow" then
			p.Color, p.Material, p.CanCollide = Color3.fromRGB(246, 248, 252), Enum.Material.Sand, false
		elseif p.Name:find("Rock") then
			p.Color, p.Material, p.CanCollide = rockGrey, Enum.Material.Rock, true
		else
			p.Color, p.Material, p.CanCollide = Color3.fromRGB(92, 146, 84), Enum.Material.Grass, true
		end
	end, "RoTubePeak", nil, 0)
	if not model then
		return
	end
	-- Sit the base ~3 studs into the ground, then measure the summit.
	local cf, size = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + Vector3.new(0, FLOOR_TOP - (cf.Position.Y - size.Y / 2) - 3, 0))
	cf, size = model:GetBoundingBox()
	local cx, cz = cf.Position.X, cf.Position.Z
	local summitY = cf.Position.Y + size.Y / 2

	-- Viewpoint platform + railing on the flat summit.
	local platY = summitY - 1.5
	makePart("RoTubeSummit", Vector3.new(16, 1, 16), Vector3.new(cx, platY, cz), Color3.fromRGB(146, 140, 132), Enum.Material.Rock, lobbyFolder)
	for _, o in ipairs({ Vector3.new(0, 0, 8), Vector3.new(0, 0, -8), Vector3.new(8, 0, 0), Vector3.new(-8, 0, 0) }) do
		local rail = makePart("RoTubeRail", Vector3.new(o.X == 0 and 16 or 0.4, 1.4, o.Z == 0 and 16 or 0.4), Vector3.new(cx + o.X, platY + 1.2, cz + o.Z), Color3.fromRGB(90, 66, 44), Enum.Material.Wood, lobbyFolder)
		rail.CanCollide = false
	end
	local pole = makePart("RoTubeFlagPole", Vector3.new(0.4, 11, 0.4), Vector3.new(cx, platY + 6, cz), Color3.fromRGB(120, 120, 128), Enum.Material.Metal, lobbyFolder)
	pole.CanCollide = false
	local flag = makePart("RoTubeFlag", Vector3.new(0.2, 2.6, 4.4), Vector3.new(cx + 2.4, platY + 9.5, cz), Color3.fromRGB(150, 92, 255), Enum.Material.SmoothPlastic, lobbyFolder)
	flag.CanCollide = false
	local signBack = makePart("RoTubeSign", Vector3.new(13, 3, 0.5), Vector3.new(cx, platY + 3.2, cz - 7), Color3.fromRGB(60, 44, 30), Enum.Material.WoodPlanks, lobbyFolder)
	signBack.CanCollide = false
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local sg = Instance.new("SurfaceGui")
		sg.Face, sg.CanvasSize, sg.LightInfluence, sg.Parent = face, Vector2.new(480, 120), 0, signBack
		local lb = Instance.new("TextLabel")
		lb.Size, lb.BackgroundTransparency = UDim2.fromScale(1, 1), 1
		lb.Text, lb.Font, lb.TextScaled, lb.TextColor3, lb.Parent = "RoTube Peaks", Enum.Font.FredokaOne, true, Color3.fromRGB(255, 240, 210), sg
	end

	-- Switchback trail up the +X (town-facing) slope: ramps + landings.
	local groundY = FLOOR_TOP + 1
	local n = 4
	local pts = {}
	for i = 0, n do
		local t = i / n
		local r = 33 * (1 - t) + 7
		local side = (i % 2 == 0) and -1 or 1
		pts[i + 1] = Vector3.new(cx + r, groundY + (platY - groundY) * t, cz + side * 13)
	end
	for i = 1, n do
		local a, b = pts[i], pts[i + 1]
		local mid = (a + b) / 2
		local ramp = makePart("RoTubeTrail" .. i, Vector3.new(6, 0.6, (b - a).Magnitude), mid, Color3.fromRGB(150, 120, 84), Enum.Material.Ground, lobbyFolder)
		ramp.CFrame = CFrame.lookAt(mid, b)
		makePart("RoTubeLanding" .. i, Vector3.new(6.5, 0.6, 6.5), b, Color3.fromRGB(150, 120, 84), Enum.Material.Ground, lobbyFolder)
	end

	-- Mountain Plunge waterfall on the -Z (seaward) face, into a plunge pool.
	local fallTop = Vector3.new(cx, summitY - 8, cz - 20)
	local fallBot = Vector3.new(cx, groundY + 1, cz - 40)
	local fmid = (fallTop + fallBot) / 2
	local fall = makePart("PlungeFall", Vector3.new(8, 0.8, (fallBot - fallTop).Magnitude + 4), fmid, Color3.fromRGB(150, 205, 235), Enum.Material.Glass, lobbyFolder)
	fall.CFrame = CFrame.lookAt(fmid, fallBot)
	fall.Transparency, fall.CanCollide = 0.35, false
	for i = 1, 6 do
		local foam = makePart("PlungeFoam" .. i, Vector3.new(2.2, 2.2, 2.2), fallBot + Vector3.new((i - 3.5) * 1.7, math.abs(i - 3.5) * 0.5, (i % 2) * 1.3), Color3.fromRGB(240, 248, 255), Enum.Material.Foil, lobbyFolder)
		foam.Shape, foam.CanCollide, foam.Transparency = Enum.PartType.Ball, false, 0.1
	end
	local pool = makePart("PlungePool", Vector3.new(22, 1, 16), fallBot + Vector3.new(0, -0.4, -9), Color3.fromRGB(96, 186, 220), Enum.Material.Water, lobbyFolder)
	pool.CanCollide, pool.Transparency = false, 0.25
	local psign = makePart("PlungeSign", Vector3.new(10, 2.6, 0.5), fallBot + Vector3.new(0, 2.2, -17), Color3.fromRGB(60, 44, 30), Enum.Material.WoodPlanks, lobbyFolder)
	psign.CanCollide = false
	local psg = Instance.new("SurfaceGui")
	psg.Face, psg.CanvasSize, psg.LightInfluence, psg.Parent = Enum.NormalId.Front, Vector2.new(420, 110), 0, psign
	local plb = Instance.new("TextLabel")
	plb.Size, plb.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	plb.Text, plb.Font, plb.TextScaled, plb.TextColor3, plb.Parent = "Mountain Plunge", Enum.Font.FredokaOne, true, Color3.fromRGB(200, 240, 255), psg
end

-- Cosmetic stone tunnel mouths carved into the north & south mountain ring, so
-- a road looks like it disappears into the mountains. No-op until synced.
local function buildTunnels(lobbyFolder)
	if not StudioModels.has("TunnelMouth") then
		return
	end
	local function paint(part)
		if part.Name:find("Dark") then
			part.Color, part.Material = Color3.fromRGB(18, 18, 22), Enum.Material.SmoothPlastic
		else
			part.Color, part.Material = Color3.fromRGB(120, 116, 110), Enum.Material.Rock
		end
		part.CanCollide = true
	end
	local north = placeProp("TunnelMouth", lobbyFolder, Vector3.new(TUNNEL_N.X, FLOOR_TOP, TUNNEL_N.Z), 30, math.pi, paint)
	if north then north.Name = "TunnelNorth" end
	local south = placeProp("TunnelMouth", lobbyFolder, Vector3.new(TUNNEL_S.X, FLOOR_TOP, TUNNEL_S.Z), 30, 0, paint)
	if south then south.Name = "TunnelSouth" end

	-- Solid rock slab BEHIND each portal so the portal-width gap in the ring
	-- never shows sky or the bare baseplate through it -- the tunnel reads as
	-- carved into a mountain mass.
	local function backing(name, x, z)
		local s = makePart(name, Vector3.new(150, 115, 28), Vector3.new(x, FLOOR_TOP + 46, z), Color3.fromRGB(118, 114, 108), Enum.Material.Rock, lobbyFolder)
		s.CanCollide = true
		s.CastShadow = false
	end
	backing("TunnelBackNorth", TUNNEL_N.X, TUNNEL_N.Z - 26)
	backing("TunnelBackSouth", TUNNEL_S.X, TUNNEL_S.Z + 26)
end

-- A tall INVISIBLE wall ringing the map along the mountain line, so even if a
-- player finds a gap between peaks or tries to climb over, they can't leave the
-- map. Very tall (can't jump/fly over) and thick (can't clip through). Bounds
-- match buildMountains' ring.
local function buildBoundaryWalls(lobbyFolder)
	local xMin, xMax = -150, 290
	local zMin, zMax = -260, 300
	local wallH = 400
	local thickness = 8
	local centerY = FLOOR_TOP + wallH / 2 - 12 -- sunk 12 below ground, rises 388 up
	local midX = (xMin + xMax) / 2
	local midZ = (zMin + zMax) / 2
	local lenZ = zMax - zMin
	local lenX = xMax - xMin
	local function wall(name, size, pos)
		local w = makePart(name, size, pos, Color3.fromRGB(120, 120, 120), Enum.Material.SmoothPlastic, lobbyFolder)
		w.Transparency = 1 -- invisible barrier
		w.CanCollide = true
		w.CastShadow = false
		return w
	end
	wall("BoundaryWallWest", Vector3.new(thickness, wallH, lenZ + thickness), Vector3.new(xMin, centerY, midZ))
	wall("BoundaryWallEast", Vector3.new(thickness, wallH, lenZ + thickness), Vector3.new(xMax, centerY, midZ))
	wall("BoundaryWallSouth", Vector3.new(lenX + thickness, wallH, thickness), Vector3.new(midX, centerY, zMin))
	wall("BoundaryWallNorth", Vector3.new(lenX + thickness, wallH, thickness), Vector3.new(midX, centerY, zMax))
end

-- A row of small ENTERABLE shops along the south side of Main Street: real
-- doorway gaps, a simple interior with a counter and a shopkeeper NPC.
-- key matches GameData.ShopCatalog so each shop sells its own distinct items.
local SHOP_DEFS = {
	{ key = "Snacks", name = "\240\159\141\148 Snacks", color = Color3.fromRGB(224, 120, 90) },
	{ key = "Clothes", name = "\240\159\145\149 Clothes", color = Color3.fromRGB(110, 170, 210) },
	{ key = "GameStore", name = "\240\159\142\174 Game Store", color = Color3.fromRGB(150, 120, 220) },
	{ key = "Grocery", name = "\240\159\143\170 Grocery", color = Color3.fromRGB(120, 190, 130) },
	-- The PC Store opens the PC Parts Shop (its keeper prompt is "PCStorePrompt",
	-- handled by PCService/PCPanel, NOT the generic ShopPanel).
	{ key = "PCParts", name = "\240\159\150\165\239\184\143 PC Store", color = Color3.fromRGB(90, 130, 220), physical = true },
}

local function buildShop(lobbyFolder, index, def, center, yaw)
	local w, d, h = 15, 12, 8
	local halfW, halfD = w / 2, d / 2
	local wt = 0.6
	local wallCenterY = FLOOR_TOP + h / 2
	local wallColor = Color3.fromRGB(245, 242, 236)
	local prefix = "Shop" .. index .. "_"

	-- The shops sit SOUTH of Main Street, so the storefront (door, window,
	-- awning, sign) must face +Z toward the street/plaza where players walk;
	-- the blank back wall (-Z) is the one that backs onto the skyline towers.
	-- Floor top sits 0.15 ABOVE the grass (was exactly level -> z-fighting that
	-- read as a "broken" flickering texture on the shop floor).
	makePart(prefix .. "Floor", Vector3.new(w, 1, d), center + Vector3.new(0, FLOOR_TOP - 0.35, 0), Color3.fromRGB(210, 205, 196), Enum.Material.Concrete, lobbyFolder)
	makePart(prefix .. "WallBack", Vector3.new(w, h, wt), center + Vector3.new(0, wallCenterY, -halfD), wallColor, Enum.Material.SmoothPlastic, lobbyFolder)
	makePart(prefix .. "WallLeft", Vector3.new(wt, h, d), center + Vector3.new(-halfW, wallCenterY, 0), wallColor, Enum.Material.SmoothPlastic, lobbyFolder)
	makePart(prefix .. "WallRight", Vector3.new(wt, h, d), center + Vector3.new(halfW, wallCenterY, 0), wallColor, Enum.Material.SmoothPlastic, lobbyFolder)

	-- Flat roof over the shop (always).
	local doorW, doorH = 4, 6
	local sideW = (w - doorW) / 2
	makePart(prefix .. "Roof", Vector3.new(w + 1, 0.6, d + 1), center + Vector3.new(0, FLOOR_TOP + h, 0), Color3.fromRGB(225, 222, 216), Enum.Material.Concrete, lobbyFolder)

	-- Storefront: a detailed Blender facade (display windows, framed door,
	-- striped awning) if synced, else the plain procedural front wall. Either
	-- way the doorway gap (X +/-2) stays open so players can walk in.
	if StudioModels.has("ShopFront") then
		placeProp("ShopFront", lobbyFolder, center + Vector3.new(0, FLOOR_TOP, halfD), h, 0, function(p)
			local n = p.Name
			if n:find("Awning") then
				p.Color, p.Material, p.CanCollide = def.color, Enum.Material.Fabric, false
			elseif n:find("Win") then
				p.Color, p.Material, p.Transparency, p.CanCollide = Color3.fromRGB(160, 205, 230), Enum.Material.Glass, 0.35, false
			elseif n:find("Trim") then
				p.Color, p.Material, p.CanCollide = Color3.fromRGB(70, 60, 54), Enum.Material.SmoothPlastic, true
			else
				p.Color, p.Material, p.CanCollide = wallColor, Enum.Material.SmoothPlastic, true
			end
		end)
	else
		makePart(prefix .. "FrontLeft", Vector3.new(sideW, h, wt), center + Vector3.new(-(doorW + sideW) / 2, wallCenterY, halfD), wallColor, Enum.Material.SmoothPlastic, lobbyFolder)
		local winFrame = makePart(prefix .. "Window", Vector3.new(sideW - 1, h - 3, 0.2), center + Vector3.new(-(doorW + sideW) / 2, FLOOR_TOP + (h - 3) / 2 + 0.5, halfD + 0.05), Color3.fromRGB(160, 205, 230), Enum.Material.Glass, lobbyFolder)
		winFrame.CanCollide = false
		winFrame.Transparency = 0.35
		makePart(prefix .. "FrontRight", Vector3.new(sideW, h, wt), center + Vector3.new((doorW + sideW) / 2, wallCenterY, halfD), wallColor, Enum.Material.SmoothPlastic, lobbyFolder)
		makePart(prefix .. "Lintel", Vector3.new(doorW, h - doorH, wt), center + Vector3.new(0, FLOOR_TOP + doorH + (h - doorH) / 2, halfD), wallColor, Enum.Material.SmoothPlastic, lobbyFolder)
		local awning = makePart(prefix .. "Awning", Vector3.new(w, 0.5, 2.5), center + Vector3.new(0, FLOOR_TOP + h - 1.5, halfD + 1.2), def.color, Enum.Material.Fabric, lobbyFolder)
		awning.CanCollide = false
	end
	local signBoard = makePart(prefix .. "Sign", Vector3.new(w - 2, 1.6, 0.2), center + Vector3.new(0, FLOOR_TOP + h + 1, halfD + 0.1), DARK_TRIM_COLOR, Enum.Material.SmoothPlastic, lobbyFolder)
	signBoard.CanCollide = false
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Back -- the +Z face of the board (toward the street)
	sg.CanvasSize = Vector2.new(400, 80)
	sg.LightInfluence = 0
	sg.Parent = signBoard
	local sl = Instance.new("TextLabel")
	sl.Size = UDim2.fromScale(1, 1)
	sl.BackgroundTransparency = 1
	sl.Text = def.name
	sl.Font = Enum.Font.FredokaOne
	sl.TextScaled = true
	sl.TextColor3 = Color3.fromRGB(255, 240, 210)
	sl.Parent = sg

	-- Interior: a counter with the shopkeeper NPC standing BEHIND it. The buy
	-- prompt lives on the keeper, so you just walk up to the front of the
	-- counter and talk to them -- no squeezing past the NPC to reach a block.
	local counter = makePart(prefix .. "Counter", Vector3.new(w - 4, 2, 2), center + Vector3.new(0, FLOOR_TOP + 1, -(halfD - 4)), Color3.fromRGB(150, 116, 78), Enum.Material.WoodPlanks, lobbyFolder)
	local pal = NPC_PALETTE[((index - 1) % #NPC_PALETTE) + 1]
	local keeper = buildNPC(lobbyFolder, prefix .. "Keeper", center + Vector3.new(0, FLOOR_TOP, -(halfD - 1.6)), pal.shirt, pal.pants, pal.skin, def.color)
	-- NPCs are built facing -Z; the keeper stands behind the counter, so turn
	-- it to face +Z (the door and the customer at the counter).
	keeper:PivotTo(keeper:GetPivot() * CFrame.Angles(0, math.rad(180), 0))
	-- A "physical" shop (the PC Store) has no counter menu prompt -- you buy at
	-- the shelves themselves (buildPCStoreShelves). The keeper stays for flavour.
	if not def.physical then
		local shopPrompt = Instance.new("ProximityPrompt")
		shopPrompt.Name = def.promptName or "ShopPrompt"
		shopPrompt.ActionText = def.actionText or "Shop"
		shopPrompt.ObjectText = def.name
		shopPrompt.HoldDuration = 0.2
		shopPrompt.MaxActivationDistance = 10
		shopPrompt.RequiresLineOfSight = false -- the counter sits between you and the keeper
		shopPrompt:SetAttribute("ShopKey", def.key) -- which catalog this shop sells
		shopPrompt.Parent = keeper.PrimaryPart
	end

	-- The shop is built facing +Z; rotate the whole thing (every part named
	-- with this shop's prefix, keeper included) about its centre so the front
	-- can face any direction on the map.
	if yaw and yaw ~= 0 then
		local pivot = Vector3.new(center.X, 0, center.Z)
		local rot = CFrame.new(pivot) * CFrame.Angles(0, math.rad(yaw), 0) * CFrame.new(-pivot)
		for _, part in ipairs(lobbyFolder:GetDescendants()) do
			if part:IsA("BasePart") and part.Name:sub(1, #prefix) == prefix then
				part.CFrame = rot * part.CFrame
			end
		end
	end
end

-- Shops line the two plot avenues (the roads that run past the studio plots),
-- one in each plot gap -- so they're right on a road and spread across the
-- map, instead of crammed in one row on Main Street (where the street lamps
-- and a pedestrian route ran straight through them). Centres are world coords;
-- each faces +Z toward its avenue. Spots were probed clear of roads, sidewalks,
-- houses, plots and the beach.
local SHOP_PLACEMENTS = {
	{ x = 55, z = -5, yaw = 0 }, -- front avenue, west gap (faces the avenue)
	{ x = 110, z = -5, yaw = 0 }, -- front avenue, east gap
	{ x = 55, z = 160, yaw = 0 }, -- back avenue, west gap (by Plot 3)
	{ x = 110, z = 160, yaw = 0 }, -- back avenue, east gap (by Plot 4)
	{ x = 165, z = -5, yaw = 0 }, -- PC Store: front avenue, east end (verify clear)
}

-- Physical PC Store interior: one shelf per PC-part category around the store,
-- each with a placeholder component prop, a floating info label (filled in
-- per-player on the client), and a "Buy" ProximityPrompt (PCBuyPrompt carrying
-- the PartId). No screen menu -- you walk the aisle and buy at the shelf. A
-- hidden PCStoreZone part lets the client roll the shopkeeper's per-visit deal
-- when you step inside. Placeholder props get swapped for Blender models later.
local PC_SHELF_SPOTS = {
	{ x = -6.2, z = -4.0 }, { x = -6.2, z = -1.3 }, { x = -6.2, z = 1.3 }, { x = -6.2, z = 4.0 },
	{ x = 6.2, z = -1.3 }, { x = 6.2, z = 1.3 }, { x = 6.2, z = 4.0 },
}

-- Detailed Blender display models for the shelves, keyed by PC-part id. Each is
-- placed on the pedestal via placeProp (scaled to `height` studs tall, base on
-- the pedestal top), painted by mesh-part name, then falls back to the coloured
-- placeholder box when the asset isn't synced yet. `extraYaw` fine-tunes the
-- facing on top of the aisle-facing turn. Categories without an entry (CPU/RAM/
-- Storage/Cooling) keep the placeholder box until their models are built.
local function paintPCGpu(p)
	local n = p.Name
	if n:find("Accent") then
		p.Color, p.Material = Color3.fromRGB(90, 220, 255), Enum.Material.SmoothPlastic
	elseif n:find("Bracket") then
		p.Color, p.Material = Color3.fromRGB(150, 155, 165), Enum.Material.Metal
	elseif n:find("Fan") then
		p.Color, p.Material = Color3.fromRGB(200, 205, 215), Enum.Material.SmoothPlastic -- silver fan frames
	elseif n:find("Backplate") then
		p.Color, p.Material = Color3.fromRGB(22, 22, 28), Enum.Material.SmoothPlastic
	else -- Shroud (gunmetal, MSI Gaming Trio style)
		p.Color, p.Material = Color3.fromRGB(74, 78, 90), Enum.Material.Metal
	end
	p.CanCollide = false
end
local function paintPCMonitor(p)
	local n = p.Name
	if n:find("Screen") then
		p.Color, p.Material = Color3.fromRGB(70, 130, 225), Enum.Material.SmoothPlastic
	elseif n:find("Accent") then
		p.Color, p.Material = Color3.fromRGB(235, 95, 220), Enum.Material.SmoothPlastic
	elseif n:find("Neck") then
		p.Color, p.Material = Color3.fromRGB(40, 42, 50), Enum.Material.SmoothPlastic
	elseif n:find("Base") then
		p.Color, p.Material = Color3.fromRGB(34, 36, 44), Enum.Material.SmoothPlastic
	else -- Bezel
		p.Color, p.Material = Color3.fromRGB(26, 28, 34), Enum.Material.SmoothPlastic
	end
	p.CanCollide = false
end
local TOWER_FAN_COLORS = { Color3.fromRGB(90, 220, 255), Color3.fromRGB(235, 95, 220), Color3.fromRGB(120, 240, 150) }
local function paintPCTower(p)
	local n = p.Name
	local fanIdx = n:match("^Fan(%d)")
	if fanIdx then
		p.Color, p.Material = TOWER_FAN_COLORS[tonumber(fanIdx)] or TOWER_FAN_COLORS[1], Enum.Material.SmoothPlastic
	elseif n:find("Glass") then
		p.Color, p.Material, p.Transparency = Color3.fromRGB(150, 190, 220), Enum.Material.Glass, 0.55
	elseif n:find("Cooler") then
		p.Color, p.Material = Color3.fromRGB(120, 125, 140), Enum.Material.Metal
	elseif n:find("InnerBoard") then
		p.Color, p.Material = Color3.fromRGB(30, 70, 55), Enum.Material.SmoothPlastic -- motherboard green
	elseif n:find("Accent") then
		p.Color, p.Material = Color3.fromRGB(90, 220, 255), Enum.Material.SmoothPlastic
	elseif n:find("Front") then
		p.Color, p.Material = Color3.fromRGB(22, 24, 30), Enum.Material.SmoothPlastic
	elseif n:find("Feet") then
		p.Color, p.Material = Color3.fromRGB(20, 20, 24), Enum.Material.SmoothPlastic
	else -- Case
		p.Color, p.Material = Color3.fromRGB(30, 32, 40), Enum.Material.SmoothPlastic
	end
	p.CanCollide = false
end
-- `size` is a target HEIGHT in studs, unless `byWidth` (then it's a target WIDTH
-- -- the ultrawide monitor scales by width so it doesn't tower over the shelf).
local PC_SHELF_MODELS = {
	GPU = { asset = "PCGpu", size = 2.6, extraYaw = 0, paint = paintPCGpu },
	Monitor = { asset = "PCMonitor", size = 3.0, byWidth = true, extraYaw = 0, paint = paintPCMonitor },
	RGB = { asset = "PCTower", size = 3.0, extraYaw = 0, paint = paintPCTower },
}

local function buildPCStoreShelves(lobbyFolder, center)
	for i, part in ipairs(GameData.PCParts) do
		local spot = PC_SHELF_SPOTS[i]
		if not spot then break end
		local propColor = (part.kind == "money") and Color3.fromRGB(90, 200, 150) or Color3.fromRGB(150, 110, 230)
		-- Pedestal (the named anchor the client + prompt hang off).
		local pedestal = makePart("PCShelf_" .. part.id, Vector3.new(1.8, 3, 1.8), center + Vector3.new(spot.x, FLOOR_TOP + 1.5, spot.z), Color3.fromRGB(60, 62, 72), Enum.Material.SmoothPlastic, lobbyFolder)
		-- The display component sits on the pedestal top: a detailed Blender model
		-- if synced, otherwise the coloured placeholder box. Shelves face the aisle
		-- (west wall looks +X, east wall looks -X); the tower gets a 3/4 turn.
		local shelfYaw = (spot.x < 0) and -math.pi / 2 or math.pi / 2
		local pedestalTop = center + Vector3.new(spot.x, FLOOR_TOP + 3, spot.z)
		local cfg = PC_SHELF_MODELS[part.id]
		local model = cfg and placeProp(cfg.asset, lobbyFolder, pedestalTop, cfg.size, shelfYaw + cfg.extraYaw, cfg.paint, cfg.byWidth)
		if model then
			model.Name = "PCShelfProp_" .. part.id
		else
			-- Placeholder component prop on top (swapped for a Blender model later).
			local prop = makePart("PCShelfProp_" .. part.id, Vector3.new(1.2, 0.9, 1.2), center + Vector3.new(spot.x, FLOOR_TOP + 3.45, spot.z), propColor, Enum.Material.SmoothPlastic, lobbyFolder)
			prop.CanCollide = false
		end
		-- Floating info label -- text is set PER-PLAYER on the client (each player
		-- has different owned tiers / prices / deal), so leave it blank here.
		local bb = Instance.new("BillboardGui")
		bb.Name = "Info"
		bb.Size = UDim2.fromOffset(210, 96)
		bb.StudsOffset = Vector3.new(0, 3.0, 0)
		bb.MaxDistance = 45
		bb.Parent = pedestal
		local lbl = Instance.new("TextLabel")
		lbl.Name = "Text"
		lbl.Size = UDim2.fromScale(1, 1)
		lbl.BackgroundTransparency = 1
		lbl.RichText = true
		lbl.TextScaled = true
		lbl.Font = Enum.Font.FredokaOne
		lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
		lbl.TextStrokeTransparency = 0.35
		lbl.Text = part.name
		lbl.Parent = bb
		-- Buy prompt (server buys the triggering player's next tier of this part).
		local buy = Instance.new("ProximityPrompt")
		buy.Name = "PCBuyPrompt"
		buy.ActionText = "Buy"
		buy.ObjectText = part.name
		buy.HoldDuration = 0.2
		buy.MaxActivationDistance = 9
		buy.RequiresLineOfSight = false
		buy:SetAttribute("PartId", part.id)
		buy.Parent = pedestal
	end
	-- Invisible zone the client watches to roll the shopkeeper's per-visit deal.
	local zone = makePart("PCStoreZone", Vector3.new(13, 7, 10), center + Vector3.new(0, FLOOR_TOP + 3.5, 0), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, lobbyFolder)
	zone.Transparency = 1
	zone.CanCollide = false
	zone.CanQuery = false
end

local function buildShops(lobbyFolder)
	for i, def in ipairs(SHOP_DEFS) do
		local p = SHOP_PLACEMENTS[i]
		buildShop(lobbyFolder, i, def, Vector3.new(p.x, 0, p.z), p.yaw)
		if def.physical then
			buildPCStoreShelves(lobbyFolder, Vector3.new(p.x, 0, p.z))
		end
	end
end

-- Roads reaching every plot: two east-west avenues passing the front-row
-- and back-row plot entrances, tied into the existing north-south
-- neighborhood road. World coordinates (plots are at world (0,0),(160,0),
-- (0,160),(160,160); their entrances sit at the -Z front of each).
local function buildAvenue(lobbyFolder, name, minX, maxX, z)
	local length = maxX - minX
	local centerX = (minX + maxX) / 2
	makePart(name, Vector3.new(length, 0.4, 16), Vector3.new(centerX, FLOOR_TOP + 0.2, z), Color3.fromRGB(58, 58, 62), Enum.Material.Asphalt, lobbyFolder)
	makePart(name .. "WalkN", Vector3.new(length, 0.5, 5), Vector3.new(centerX, FLOOR_TOP + 0.25, z + 10.5), Color3.fromRGB(190, 190, 185), Enum.Material.Concrete, lobbyFolder)
	makePart(name .. "WalkS", Vector3.new(length, 0.5, 5), Vector3.new(centerX, FLOOR_TOP + 0.25, z - 10.5), Color3.fromRGB(190, 190, 185), Enum.Material.Concrete, lobbyFolder)
	for i = 0, math.floor(length / 8) do
		local dash = makePart(name .. "Dash" .. i, Vector3.new(3, 0.45, 0.6), Vector3.new(minX + i * 8, FLOOR_TOP + 0.21, z), Color3.fromRGB(255, 224, 110), Enum.Material.SmoothPlastic, lobbyFolder)
		dash.CanCollide = false
	end
end

local function buildPlotAvenues(lobbyFolder)
	buildAvenue(lobbyFolder, "PlotAvenueFront", -25, 185, 23) -- passes plots 1 & 2 entrances
	buildAvenue(lobbyFolder, "PlotAvenueBack", -25, 185, 183) -- passes plots 3 & 4 entrances
end

-- (Townsfolk delivery quests removed for now -- planned to return as a proper
-- quest/task system in a later roadmap milestone.)

-- Flower beds, planters and hedges scattered around the plaza edge, plus
-- string lights strung between a couple of points, to make it feel lush.
local function buildParkDecor(lobbyFolder)
	local flowerColors = { Color3.fromRGB(235, 100, 120), Color3.fromRGB(240, 200, 90), Color3.fromRGB(150, 120, 220), Color3.fromRGB(240, 240, 245) }
	local bedSpots = {
		Vector3.new(-28, 0, 20), Vector3.new(28, 0, 20), Vector3.new(-28, 0, -20), Vector3.new(28, 0, -20),
		Vector3.new(0, 0, 26), Vector3.new(-14, 0, 24), Vector3.new(14, 0, 24),
	}
	local useMesh = StudioModels.has("FlowerBed")
	for i, spot in ipairs(bedSpots) do
		if useMesh then
			local m = placeProp("FlowerBed", lobbyFolder, LOBBY_ORIGIN + spot + Vector3.new(0, FLOOR_TOP, 0), 3.2, (i % 2 == 0) and math.pi / 2 or 0, function(part)
				local n = part.Name
				if n:find("BedWood") then
					part.Color, part.Material, part.CanCollide = Color3.fromRGB(120, 86, 56), Enum.Material.WoodPlanks, true
				elseif n:find("Soil") then
					part.Color, part.Material, part.CanCollide = Color3.fromRGB(78, 54, 38), Enum.Material.Ground, false
				elseif n:find("Stem") then
					part.Color, part.Material, part.CanCollide = Color3.fromRGB(74, 132, 84), Enum.Material.Grass, false
				elseif n:find("Center") then
					part.Color, part.Material, part.CanCollide = Color3.fromRGB(244, 206, 70), Enum.Material.SmoothPlastic, false
				elseif n:find("PetalA") then
					part.Color, part.Material, part.CanCollide = Color3.fromRGB(226, 86, 92), Enum.Material.SmoothPlastic, false
				elseif n:find("PetalB") then
					part.Color, part.Material, part.CanCollide = Color3.fromRGB(244, 200, 84), Enum.Material.SmoothPlastic, false
				elseif n:find("PetalC") then
					part.Color, part.Material, part.CanCollide = Color3.fromRGB(200, 120, 220), Enum.Material.SmoothPlastic, false
				else -- PetalW
					part.Color, part.Material, part.CanCollide = Color3.fromRGB(248, 248, 244), Enum.Material.SmoothPlastic, false
				end
			end)
			if m then m.Name = "FlowerBed" .. i end
		else
			makePart("FlowerBed" .. i, Vector3.new(5, 1, 3), LOBBY_ORIGIN + spot + Vector3.new(0, FLOOR_TOP + 0.5, 0), Color3.fromRGB(120, 86, 56), Enum.Material.WoodPlanks, lobbyFolder)
			for j = 1, 4 do
				local fx = (j - 2.5) * 1.1
				makePart("FlowerBed" .. i .. "Stem" .. j, Vector3.new(0.15, 1, 0.15), LOBBY_ORIGIN + spot + Vector3.new(fx, FLOOR_TOP + 1.5, 0), Color3.fromRGB(74, 132, 84), Enum.Material.Grass, lobbyFolder)
				local bloom = makePart("FlowerBed" .. i .. "Bloom" .. j, Vector3.new(0.7, 0.7, 0.7), LOBBY_ORIGIN + spot + Vector3.new(fx, FLOOR_TOP + 2.1, 0), flowerColors[((i + j) % #flowerColors) + 1], Enum.Material.SmoothPlastic, lobbyFolder)
				bloom.Shape = Enum.PartType.Ball
				bloom.CanCollide = false
			end
		end
	end
end

-- A little playground (slide + swing set) on the grass east of the plaza.
-- Mesh only -- appears once Slide/SwingSet are synced.
local function buildPlayground(lobbyFolder)
	if not StudioModels.has("Slide") then
		return
	end
	local function paintPlay(part)
		local n = part.Name
		if n:find("Chute") then
			part.Color, part.Material = Color3.fromRGB(240, 180, 60), Enum.Material.SmoothPlastic
		elseif n:find("Seat") then
			part.Color, part.Material = Color3.fromRGB(210, 74, 74), Enum.Material.SmoothPlastic
		elseif n:find("Step") then
			part.Color, part.Material = Color3.fromRGB(90, 170, 90), Enum.Material.Metal
		else
			part.Color, part.Material = Color3.fromRGB(80, 150, 210), Enum.Material.Metal
		end
		part.CanCollide = true
	end
	local s = placeProp("Slide", lobbyFolder, LOBBY_ORIGIN + Vector3.new(62, FLOOR_TOP, 30), 4.2, math.pi / 2, paintPlay)
	if s then s.Name = "PlaygroundSlide" end
	if StudioModels.has("SwingSet") then
		local sw = placeProp("SwingSet", lobbyFolder, LOBBY_ORIGIN + Vector3.new(48, FLOOR_TOP, 32), 4.6, 0, paintPlay)
		if sw then sw.Name = "PlaygroundSwing" end
	end
end

-- ---- Plaza extras: more life in the central hub ---------------------------
-- Everything is placed relative to LOBBY_ORIGIN (the plaza centre) and sits on
-- the FLOOR_TOP grass. Bright but non-neon, matching the town's storybook look.
local function plazaPart(parent, name, size, rel, color, material)
	local p = makePart(name, size, LOBBY_ORIGIN + Vector3.new(rel.X, FLOOR_TOP + rel.Y, rel.Z), color, material or Enum.Material.SmoothPlastic, parent)
	return p
end

-- A wheeled food cart: body, a striped canopy, two wheels and an emoji sign.
local function buildFoodCart(parent, name, rx, rz, bodyColor, canopyColor, emoji)
	-- Detailed Blender cart if synced (body, striped canopy, wheels, emoji sign).
	local model = placeProp("FoodCart", parent, LOBBY_ORIGIN + Vector3.new(rx, FLOOR_TOP, rz), 5.0, 0, function(part)
		local n = part.Name
		if n:find("Wheel") then
			part.Color, part.Material = Color3.fromRGB(40, 40, 44), Enum.Material.SmoothPlastic
		elseif n:find("CanopyA") then
			part.Color, part.Material = canopyColor, Enum.Material.SmoothPlastic
		elseif n:find("CanopyB") then
			part.Color, part.Material = Color3.fromRGB(245, 245, 240), Enum.Material.SmoothPlastic
		elseif n:find("Trim") then
			part.Color, part.Material = Color3.fromRGB(235, 232, 226), Enum.Material.SmoothPlastic
		else
			part.Color, part.Material = bodyColor, Enum.Material.SmoothPlastic
		end
		part.CanCollide = not (n:find("Canopy") or n:find("Wheel"))
	end)
	if model then
		model.Name = name
		local signPart = model:FindFirstChild("CartSign", true)
		if signPart then
			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.fromOffset(60, 60)
			bb.AlwaysOnTop = false
			bb.Adornee = signPart
			bb.Parent = signPart
			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.fromScale(1, 1)
			lbl.BackgroundTransparency = 1
			lbl.Text = emoji
			lbl.TextScaled = true
			lbl.Font = Enum.Font.FredokaOne
			lbl.Parent = bb
		end
		return
	end

	local body = plazaPart(parent, name .. "Body", Vector3.new(4.4, 2.2, 2.4), Vector3.new(rx, 1.9, rz), bodyColor)
	plazaPart(parent, name .. "Counter", Vector3.new(4.6, 0.3, 2.6), Vector3.new(rx, 3.1, rz), Color3.fromRGB(235, 232, 226))
	for _, oz in ipairs({ -1.1, 1.1 }) do
		local wheel = plazaPart(parent, name .. "Wheel", Vector3.new(0.5, 1.4, 1.4), Vector3.new(rx - 1.4, 0.5, rz + oz), Color3.fromRGB(40, 40, 44))
		wheel.Shape = Enum.PartType.Cylinder
		wheel.CanCollide = false
		local wheel2 = plazaPart(parent, name .. "Wheel", Vector3.new(0.5, 1.4, 1.4), Vector3.new(rx + 1.4, 0.5, rz + oz), Color3.fromRGB(40, 40, 44))
		wheel2.Shape = Enum.PartType.Cylinder
		wheel2.CanCollide = false
	end
	-- canopy + stripes on top
	local canopy = plazaPart(parent, name .. "Canopy", Vector3.new(5.2, 0.4, 3.2), Vector3.new(rx, 4.5, rz), canopyColor)
	canopy.CanCollide = false
	for i = -1, 1 do
		local stripe = plazaPart(parent, name .. "Stripe" .. (i + 2), Vector3.new(1.1, 0.42, 3.2), Vector3.new(rx + i * 1.7, 4.51, rz), Color3.fromRGB(245, 245, 240))
		stripe.CanCollide = false
	end
	-- two little posts holding the canopy up
	for _, ox in ipairs({ -2, 2 }) do
		local post = plazaPart(parent, name .. "Post", Vector3.new(0.25, 1.6, 0.25), Vector3.new(rx + ox, 3.7, rz), Color3.fromRGB(210, 205, 196))
		post.CanCollide = false
	end
	-- emoji sign board on the front
	local sign = plazaPart(parent, name .. "Sign", Vector3.new(1.6, 1.6, 0.2), Vector3.new(rx, 3.9, rz + 1.4), bodyColor)
	sign.CanCollide = false
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(60, 60)
	bb.AlwaysOnTop = false
	bb.Adornee = sign
	bb.Parent = sign
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Text = emoji
	lbl.TextScaled = true
	lbl.Font = Enum.Font.FredokaOne
	lbl.Parent = bb
end

-- A simple picnic table: top + two bench planks on angled legs.
local function buildPicnicTable(parent, name, rx, rz)
	-- Detailed Blender picnic table if synced (top + benches + A-frame legs).
	local model = placeProp("PicnicTable", parent, LOBBY_ORIGIN + Vector3.new(rx, FLOOR_TOP, rz), 2.5, 0, function(part)
		if part.Name:find("Leg") then
			part.Color, part.Material = Color3.fromRGB(130, 96, 60), Enum.Material.Wood
		else
			part.Color, part.Material = Color3.fromRGB(158, 116, 74), Enum.Material.WoodPlanks
		end
		part.CanCollide = true
	end)
	if model then
		model.Name = name
		return
	end

	local wood = Color3.fromRGB(158, 116, 74)
	plazaPart(parent, name .. "Top", Vector3.new(5, 0.3, 2.4), Vector3.new(rx, 2.2, rz), wood, Enum.Material.WoodPlanks)
	for _, oz in ipairs({ -1.6, 1.6 }) do
		plazaPart(parent, name .. "Seat", Vector3.new(5, 0.3, 0.9), Vector3.new(rx, 1.2, rz + oz), wood, Enum.Material.WoodPlanks).CanCollide = false
	end
	for _, ox in ipairs({ -2, 2 }) do
		plazaPart(parent, name .. "Leg", Vector3.new(0.4, 2.2, 3.4), Vector3.new(rx + ox, 1.1, rz), Color3.fromRGB(130, 96, 60)).CanCollide = false
	end
end

-- A covered market stall: counter, four posts, a striped roof and crates.
local function buildMarketStall(parent, name, rx, rz, canopyColor)
	-- Detailed Blender stall if synced (counter, posts, striped roof, produce).
	local model = placeProp("MarketStall", parent, LOBBY_ORIGIN + Vector3.new(rx, FLOOR_TOP, rz), 5.5, 0, function(part)
		local n = part.Name
		if n:find("CanopyA") then
			part.Color, part.Material = canopyColor, Enum.Material.SmoothPlastic
		elseif n:find("CanopyB") then
			part.Color, part.Material = Color3.fromRGB(245, 245, 240), Enum.Material.SmoothPlastic
		elseif n:find("Produce") then
			part.Color, part.Material = Color3.fromRGB(230, 120, 90), Enum.Material.SmoothPlastic
		else
			part.Color, part.Material = Color3.fromRGB(150, 116, 78), Enum.Material.WoodPlanks
		end
		part.CanCollide = not n:find("Canopy")
	end)
	if model then
		model.Name = name
		return
	end

	local wood = Color3.fromRGB(150, 116, 78)
	plazaPart(parent, name .. "Counter", Vector3.new(5, 1.6, 1.6), Vector3.new(rx, 1.8, rz - 1.4), wood, Enum.Material.WoodPlanks)
	for _, ox in ipairs({ -2.4, 2.4 }) do
		for _, oz in ipairs({ -2, 2 }) do
			plazaPart(parent, name .. "Post", Vector3.new(0.3, 5, 0.3), Vector3.new(rx + ox, 2.5, rz + oz), wood).CanCollide = false
		end
	end
	local roof = plazaPart(parent, name .. "Roof", Vector3.new(6, 0.4, 5), Vector3.new(rx, 5.2, rz), canopyColor)
	roof.CanCollide = false
	for i = -2, 2 do
		plazaPart(parent, name .. "RoofStripe" .. (i + 3), Vector3.new(1, 0.42, 5), Vector3.new(rx + i * 1.2, 5.21, rz), Color3.fromRGB(245, 245, 240)).CanCollide = false
	end
	local crateColors = { Color3.fromRGB(230, 120, 90), Color3.fromRGB(120, 200, 120), Color3.fromRGB(240, 200, 90) }
	for i = 1, 3 do
		local ball = plazaPart(parent, name .. "Produce" .. i, Vector3.new(0.9, 0.9, 0.9), Vector3.new(rx + (i - 2) * 1.2, 2.9, rz - 1.4), crateColors[i], Enum.Material.SmoothPlastic)
		ball.Shape = Enum.PartType.Ball
		ball.CanCollide = false
	end
end

-- A bunch of balloons on strings, tied to a little weight.
local function buildBalloons(parent, name, rx, rz)
	plazaPart(parent, name .. "Weight", Vector3.new(0.6, 0.6, 0.6), Vector3.new(rx, 0.3, rz), Color3.fromRGB(90, 70, 50)).CanCollide = false
	local colors = { Color3.fromRGB(230, 90, 90), Color3.fromRGB(90, 150, 230), Color3.fromRGB(240, 200, 90), Color3.fromRGB(150, 120, 220) }
	for i = 1, 4 do
		local ang = (i - 1) * (math.pi / 2)
		local bx, bz = rx + math.cos(ang) * 0.8, rz + math.sin(ang) * 0.8
		local string = plazaPart(parent, name .. "String" .. i, Vector3.new(0.08, 4.5, 0.08), Vector3.new((rx + bx) / 2, 2.6, (rz + bz) / 2), Color3.fromRGB(240, 240, 240))
		string.CanCollide = false
		local balloon = plazaPart(parent, name .. "Balloon" .. i, Vector3.new(1.4, 1.8, 1.4), Vector3.new(bx, 5.4, bz), colors[i], Enum.Material.SmoothPlastic)
		balloon.Shape = Enum.PartType.Ball
		balloon.CanCollide = false
	end
end

-- A rounded bush (a few green blobs clustered).
local function buildBush(parent, name, rx, rz)
	local green = Color3.fromRGB(74, 130, 82)
	for i, off in ipairs({ Vector3.new(0, 0, 0), Vector3.new(1, -0.3, 0.4), Vector3.new(-0.9, -0.3, 0.6), Vector3.new(0.2, -0.2, -0.9) }) do
		local blob = plazaPart(parent, name .. i, Vector3.new(2.2, 2, 2.2), Vector3.new(rx + off.X, 1 + off.Y, rz + off.Z), green:Lerp(Color3.fromRGB(96, 156, 100), (i - 1) / 4), Enum.Material.Grass)
		blob.Shape = Enum.PartType.Ball
		blob.CanCollide = false
	end
end

local function buildVIPLounge(lobbyFolder)
	local center = LOBBY_ORIGIN + Vector3.new(-34, 0, 6) -- open plaza spot; nudge in playtest if it overlaps
	local deckTop = FLOOR_TOP + 0.2 -- surface everything rests on

	-- palette (Neon reserved for accent trim only, per project rule)
	local SLATE = Color3.fromRGB(38, 30, 54)
	local GOLD = GOLD_COLOR
	local NEON_GOLD = Color3.fromRGB(255, 226, 150)
	local VELVET = Color3.fromRGB(108, 74, 150)
	local CUSHION = Color3.fromRGB(158, 116, 210)
	local RUG = Color3.fromRGB(120, 80, 175)
	local ROPE = Color3.fromRGB(158, 44, 74)
	local POT = Color3.fromRGB(120, 78, 60)
	local LEAF = Color3.fromRGB(70, 140, 86)

	-- helper: makePart at an offset from the lounge centre. Returns the part.
	local function P(name, size, off, color, mat)
		return makePart(name, size, center + off, color, mat, lobbyFolder)
	end

	-- ---- marble deck + gold trim ----
	P("LoungeDeck", Vector3.new(15, 0.4, 11), Vector3.new(0, FLOOR_TOP, 0), SLATE, Enum.Material.Marble)
	-- gold border frame (thin, sits on the deck edge — decorative, non-colliding)
	local bx, bz = 7.5, 5.5
	for _, b in ipairs({
		{ n = "N", s = Vector3.new(15, 0.35, 0.5), o = Vector3.new(0, deckTop + 0.15, -bz) },
		{ n = "S", s = Vector3.new(15, 0.35, 0.5), o = Vector3.new(0, deckTop + 0.15, bz) },
		{ n = "E", s = Vector3.new(0.5, 0.35, 11), o = Vector3.new(bx, deckTop + 0.15, 0) },
		{ n = "W", s = Vector3.new(0.5, 0.35, 11), o = Vector3.new(-bx, deckTop + 0.15, 0) },
	}) do
		P("LoungeTrim" .. b.n, b.s, b.o, GOLD, Enum.Material.Metal).CanCollide = false
	end
	-- glowing accent line inset just inside the trim (the "VIP glow")
	for _, b in ipairs({
		{ n = "N", s = Vector3.new(13.6, 0.12, 0.14), o = Vector3.new(0, deckTop + 0.18, -bz + 0.5) },
		{ n = "S", s = Vector3.new(13.6, 0.12, 0.14), o = Vector3.new(0, deckTop + 0.18, bz - 0.5) },
	}) do
		P("LoungeGlow" .. b.n, b.s, b.o, NEON_GOLD, Enum.Material.Neon).CanCollide = false
	end

	-- ---- plush rug with a diamond emblem ----
	local rug = P("LoungeRug", Vector3.new(9, 0.15, 6), Vector3.new(0, deckTop + 0.08, 0.5), RUG, Enum.Material.Fabric)
	rug.CanCollide = false
	local rugGui = Instance.new("SurfaceGui")
	rugGui.Face = Enum.NormalId.Top
	rugGui.Parent = rug
	local rugLbl = Instance.new("TextLabel")
	rugLbl.Size = UDim2.fromScale(1, 1)
	rugLbl.BackgroundTransparency = 1
	rugLbl.Text = "\240\159\146\142"
	rugLbl.TextColor3 = Color3.fromRGB(255, 235, 180)
	rugLbl.TextTransparency = 0.55
	rugLbl.Font = Enum.Font.FredokaOne
	rugLbl.TextScaled = true
	rugLbl.Parent = rugGui

	-- ---- back sofa (faces the plaza, +z) ----
	P("LoungeSofaBase", Vector3.new(8, 0.9, 2.2), Vector3.new(0, deckTop + 0.45, -3.3), VELVET, Enum.Material.Fabric)
	P("LoungeSofaSeat", Vector3.new(7.4, 0.35, 1.8), Vector3.new(0, deckTop + 1.05, -3.2), CUSHION, Enum.Material.Fabric).CanCollide = false
	P("LoungeSofaBack", Vector3.new(8, 1.7, 0.5), Vector3.new(0, deckTop + 0.9, -4.3), VELVET, Enum.Material.Fabric)
	P("LoungeSofaArmL", Vector3.new(0.6, 1.1, 2.2), Vector3.new(-3.9, deckTop + 0.55, -3.3), VELVET, Enum.Material.Fabric)
	P("LoungeSofaArmR", Vector3.new(0.6, 1.1, 2.2), Vector3.new(3.9, deckTop + 0.55, -3.3), VELVET, Enum.Material.Fabric)

	-- ---- two armchairs at the front corners, angled inward ----
	for _, c in ipairs({ { x = -5, yaw = -32 }, { x = 5, yaw = 32 } }) do
		local base = P("LoungeChairBase", Vector3.new(2.4, 0.9, 2.4), Vector3.new(c.x, deckTop + 0.45, 3.4), VELVET, Enum.Material.Fabric)
		base.CFrame = base.CFrame * CFrame.Angles(0, math.rad(c.yaw), 0)
		local seat = P("LoungeChairSeat", Vector3.new(2, 0.3, 2), Vector3.new(c.x, deckTop + 1.05, 3.4), CUSHION, Enum.Material.Fabric)
		seat.CFrame = seat.CFrame * CFrame.Angles(0, math.rad(c.yaw), 0)
		seat.CanCollide = false
		local back = P("LoungeChairBack", Vector3.new(2.4, 1.5, 0.5), center + Vector3.new(c.x, deckTop + 0.9, 3.4), VELVET, Enum.Material.Fabric)
		-- push the backrest to the outer edge along the chair's own facing
		back.CFrame = CFrame.new(center + Vector3.new(c.x, deckTop + 0.9, 3.4)) * CFrame.Angles(0, math.rad(c.yaw), 0) * CFrame.new(0, 0, 1.1)
		back.CanCollide = false
	end

	-- ---- glass coffee table + little gold trophy ----
	P("LoungeTableTop", Vector3.new(2.6, 0.2, 2.6), Vector3.new(0, deckTop + 1.0, 0.5), Color3.fromRGB(210, 235, 245), Enum.Material.Glass).CanCollide = false
	for _, lx in ipairs({ -1, 1 }) do
		for _, lz in ipairs({ -1, 1 }) do
			P("LoungeTableLeg", Vector3.new(0.18, 1.0, 0.18), Vector3.new(lx * 1.05, deckTop + 0.5, 0.5 + lz * 1.05), GOLD, Enum.Material.Metal).CanCollide = false
		end
	end
	P("LoungeTrophyBase", Vector3.new(0.5, 0.2, 0.5), Vector3.new(0, deckTop + 1.2, 0.5), GOLD, Enum.Material.Metal).CanCollide = false
	P("LoungeTrophyStem", Vector3.new(0.14, 0.4, 0.14), Vector3.new(0, deckTop + 1.45, 0.5), GOLD, Enum.Material.Metal).CanCollide = false
	local cup = P("LoungeTrophyCup", Vector3.new(0.7, 0.7, 0.7), Vector3.new(0, deckTop + 1.85, 0.5), GOLD, Enum.Material.Metal)
	cup.Shape = Enum.PartType.Ball
	cup.CanCollide = false

	-- ---- potted plants at the back corners ----
	for _, px in ipairs({ -6, 6 }) do
		P("LoungePot", Vector3.new(1.2, 1.1, 1.2), Vector3.new(px, deckTop + 0.55, -4.3), POT, Enum.Material.SmoothPlastic)
		local foliage = P("LoungeFoliage", Vector3.new(2.2, 2.2, 2.2), Vector3.new(px, deckTop + 1.9, -4.3), LEAF, Enum.Material.Grass)
		foliage.Shape = Enum.PartType.Ball
		foliage.CanCollide = false
	end

	-- ---- floor lamps at the front corners (soft warm glow, not blinding) ----
	for _, lx in ipairs({ -6.6, 6.6 }) do
		P("LoungeLampPole", Vector3.new(0.25, 6.5, 0.25), Vector3.new(lx, deckTop + 3.25, 4.6), GOLD, Enum.Material.Metal).CanCollide = false
		local globe = P("LoungeLampGlobe", Vector3.new(0.7, 0.7, 0.7), Vector3.new(lx, deckTop + 6.7, 4.6), NEON_GOLD, Enum.Material.Neon)
		globe.Shape = Enum.PartType.Ball
		globe.CanCollide = false
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 220, 150)
		light.Range = 9
		light.Brightness = 0.5
		light.Parent = globe
	end

	-- ---- velvet-rope entrance (signature VIP touch, decorative / walk-through) ----
	local ropePosts = { -6, -2.4, 2.4, 6 } -- centre gap = the entrance
	for i, rx in ipairs(ropePosts) do
		local post = P("LoungeStanchion" .. i, Vector3.new(0.32, 3, 0.32), Vector3.new(rx, deckTop + 1.5, 5.4), GOLD, Enum.Material.Metal)
		post.Shape = Enum.PartType.Cylinder
		post.CFrame = CFrame.new(center + Vector3.new(rx, deckTop + 1.5, 5.4)) * CFrame.Angles(0, 0, math.rad(90))
		post.CanCollide = false
		local cap = P("LoungeStanchionCap" .. i, Vector3.new(0.6, 0.6, 0.6), Vector3.new(rx, deckTop + 3.1, 5.4), NEON_GOLD, Enum.Material.Neon)
		cap.Shape = Enum.PartType.Ball
		cap.CanCollide = false
	end
	-- ropes span the outer two gaps, leaving the middle open to walk in
	for _, seg in ipairs({ { a = -6, b = -2.4 }, { a = 2.4, b = 6 } }) do
		local mid = (seg.a + seg.b) / 2
		local len = math.abs(seg.b - seg.a)
		local rope = P("LoungeRope", Vector3.new(len, 0.16, 0.16), Vector3.new(mid, deckTop + 2.7, 5.4), ROPE, Enum.Material.Fabric)
		rope.CanCollide = false
	end

	-- ---- backlit VIP+ sign with neon-gold trim ----
	P("LoungeSignPost", Vector3.new(0.4, 6, 0.4), Vector3.new(0, FLOOR_TOP + 3, -5.4), DARK_TRIM_COLOR, Enum.Material.Metal)
	local sign = P("LoungeSign", Vector3.new(7.5, 2.6, 0.3), Vector3.new(0, FLOOR_TOP + 6.2, -5.4), ACCENT_COLOR, Enum.Material.SmoothPlastic)
	sign.CanCollide = false
	-- solid gold frame around the board (a big neon rectangle blows out the scene)
	for _, f in ipairs({
		{ n = "T", s = Vector3.new(7.9, 0.22, 0.36), o = Vector3.new(0, FLOOR_TOP + 7.55, -5.4) },
		{ n = "B", s = Vector3.new(7.9, 0.22, 0.36), o = Vector3.new(0, FLOOR_TOP + 4.85, -5.4) },
		{ n = "L", s = Vector3.new(0.22, 2.9, 0.36), o = Vector3.new(-3.85, FLOOR_TOP + 6.2, -5.4) },
		{ n = "R", s = Vector3.new(0.22, 2.9, 0.36), o = Vector3.new(3.85, FLOOR_TOP + 6.2, -5.4) },
	}) do
		P("LoungeSignFrame" .. f.n, f.s, f.o, GOLD, Enum.Material.Metal).CanCollide = false
	end
	local signLight = Instance.new("PointLight")
	signLight.Color = Color3.fromRGB(180, 150, 255)
	signLight.Range = 10
	signLight.Brightness = 0.5
	signLight.Parent = sign
	-- text on BOTH faces so it reads from either side of the sign
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.Parent = sign
		local title = Instance.new("TextLabel")
		title.Size = UDim2.fromScale(1, 0.62)
		title.BackgroundTransparency = 1
		title.Text = "\240\159\146\142 VIP+ Lounge"
		title.TextColor3 = Color3.fromRGB(255, 255, 255)
		title.Font = Enum.Font.FredokaOne
		title.TextScaled = true
		title.Parent = sg
		local sub = Instance.new("TextLabel")
		sub.Position = UDim2.fromScale(0, 0.64)
		sub.Size = UDim2.fromScale(1, 0.32)
		sub.BackgroundTransparency = 1
		sub.Text = "Members earn cash while they relax"
		sub.TextColor3 = Color3.fromRGB(255, 226, 150)
		sub.Font = Enum.Font.GothamMedium
		sub.TextScaled = true
		sub.Parent = sg
	end

	-- invisible earning zone (UNCHANGED — server logic depends on this box)
	local zone = makePart("LoungeZone", Vector3.new(16, 10, 12), center + Vector3.new(0, FLOOR_TOP + 5, 0), Color3.fromRGB(120, 90, 235), Enum.Material.SmoothPlastic, lobbyFolder)
	zone.Transparency = 1
	zone.CanCollide = false
end

local function buildPlazaExtras(lobbyFolder)
	buildFoodCart(lobbyFolder, "IceCreamCart", -24, -8, Color3.fromRGB(120, 180, 210), Color3.fromRGB(235, 150, 180), "\240\159\141\166")
	buildFoodCart(lobbyFolder, "HotDogCart", 24, -8, Color3.fromRGB(210, 90, 80), Color3.fromRGB(220, 70, 70), "\240\159\140\173")
	buildPicnicTable(lobbyFolder, "Picnic1", -24, 8)
	buildPicnicTable(lobbyFolder, "Picnic2", 24, 8)
	buildMarketStall(lobbyFolder, "MarketStall", 30, 12, Color3.fromRGB(120, 190, 130))
	buildBalloons(lobbyFolder, "Balloons", -18, -12)
	buildBush(lobbyFolder, "PlazaBushA", -19, 4)
	buildBush(lobbyFolder, "PlazaBushB", 19, -4)
	buildBush(lobbyFolder, "PlazaBushC", 34, 6)
end

-- Pedestrian NPCs: some stroll straight routes on the sidewalks/plaza, and
-- a couple circle the roundabout. All get swinging-leg walk animation in
-- startLobbyLife.
local function buildPedestrians(lobbyFolder)
	activeNPCs = {}
	local roundabout = LOBBY_ORIGIN + ROUNDABOUT_CENTER_OFFSET

	local straightRoutes = {
		{ from = Vector3.new(-50, 0, ROAD_Z + 10.5), to = Vector3.new(40, 0, ROAD_Z + 10.5) },
		{ from = Vector3.new(40, 0, ROAD_Z - 10.5), to = Vector3.new(-50, 0, ROAD_Z - 10.5) },
		{ from = Vector3.new(-28, 0, 28), to = Vector3.new(28, 0, 28) },
		{ from = Vector3.new(CROSS_ROAD_X + 10.5, 0, -18), to = Vector3.new(CROSS_ROAD_X + 10.5, 0, 55) },
		{ from = Vector3.new(-26, 0, -26), to = Vector3.new(26, 0, -26) },
	}
	local index = 0
	local function addNPC(entry, startPos, pal)
		index += 1
		local model, legL, legR = buildNPC(lobbyFolder, "Pedestrian" .. index, startPos + Vector3.new(0, FLOOR_TOP, 0), pal.shirt, pal.pants, pal.skin)
		entry.model = model
		entry.legL = legL
		entry.legR = legR
		entry.walkPhase = index
		table.insert(activeNPCs, entry)
	end

	for i, route in ipairs(straightRoutes) do
		addNPC({
			kind = "straight",
			from = LOBBY_ORIGIN + route.from,
			to = LOBBY_ORIGIN + route.to,
			t = (i - 1) / #straightRoutes,
			dir = 1,
			speed = 0.03 + (i % 3) * 0.01,
		}, LOBBY_ORIGIN + route.from, NPC_PALETTE[((i - 1) % #NPC_PALETTE) + 1])
	end

	-- Two walkers circling the roundabout on the outer sidewalk (radius 22,
	-- outside the car ring).
	for i = 1, 2 do
		local angle = i * math.pi
		local startPos = roundabout + Vector3.new(math.cos(angle) * 22, 0, math.sin(angle) * 22)
		addNPC({
			kind = "orbit",
			center = roundabout,
			radius = 22,
			angle = angle,
			angSpeed = 0.22 * (i == 1 and 1 or -1),
		}, startPos, NPC_PALETTE[((i + 1) % #NPC_PALETTE) + 1])
	end
end

local function startLobbyLife()
	if lobbyLifeConnection then
		lobbyLifeConnection:Disconnect()
	end

	-- Swing an NPC's legs around their hips to sell the walking motion.
	local function animateLegs(npc, torsoCF)
		local swing = math.sin(npc.walkPhase) * 0.5
		if npc.legL then
			npc.legL.CFrame = torsoCF * CFrame.new(-0.4, -1.3, 0) * CFrame.Angles(swing, 0, 0) * CFrame.new(0, -1.3, 0)
		end
		if npc.legR then
			npc.legR.CFrame = torsoCF * CFrame.new(0.4, -1.3, 0) * CFrame.Angles(-swing, 0, 0) * CFrame.new(0, -1.3, 0)
		end
	end

	lobbyLifeConnection = RunService.Heartbeat:Connect(function(dt)
		for _, npc in ipairs(activeNPCs) do
			if npc.model and npc.model.PrimaryPart then
				npc.walkPhase += dt * 9
				local torsoCF
				if npc.kind == "orbit" then
					npc.angle += dt * npc.angSpeed
					local pos = npc.center + Vector3.new(math.cos(npc.angle) * npc.radius, FLOOR_TOP, math.sin(npc.angle) * npc.radius)
					local ahead = npc.center + Vector3.new(math.cos(npc.angle + 0.15) * npc.radius, FLOOR_TOP, math.sin(npc.angle + 0.15) * npc.radius)
					if npc.angSpeed < 0 then
						ahead = npc.center + Vector3.new(math.cos(npc.angle - 0.15) * npc.radius, FLOOR_TOP, math.sin(npc.angle - 0.15) * npc.radius)
					end
					local bob = math.sin(npc.walkPhase) * 0.12
					torsoCF = CFrame.new(pos + Vector3.new(0, 3.9 + bob, 0), Vector3.new(ahead.X, pos.Y + 3.9, ahead.Z))
				else
					npc.t += dt * npc.speed * npc.dir
					if npc.t >= 1 then
						npc.t = 1
						npc.dir = -1
					elseif npc.t <= 0 then
						npc.t = 0
						npc.dir = 1
					end
					local pos = npc.from:Lerp(npc.to, npc.t) + Vector3.new(0, FLOOR_TOP, 0)
					local bob = math.sin(npc.walkPhase) * 0.12
					local torsoPos = pos + Vector3.new(0, 3.9 + bob, 0)
					-- Face along the FIXED travel direction (not toward the
					-- endpoint) so facing stays stable near the ends -- looking
					-- toward the endpoint made pos ~= target there, which spun
					-- the NPC (the "backflip"). On reverse we just negate it.
					local travel = npc.to - npc.from
					travel = Vector3.new(travel.X, 0, travel.Z)
					if travel.Magnitude < 0.01 then
						travel = Vector3.new(0, 0, 1)
					end
					travel = travel.Unit * (npc.dir > 0 and 1 or -1)
					torsoCF = CFrame.new(torsoPos, torsoPos + travel)
				end
				npc.model:PivotTo(torsoCF)
				animateLegs(npc, torsoCF)
			end
		end

		-- Fish drift back and forth in the sea, facing where they swim.
		for _, fish in ipairs(activeFish) do
			if fish.model and fish.model.PrimaryPart then
				fish.t += dt * fish.speed * fish.dir
				if fish.t >= 1 then
					fish.t = 1
					fish.dir = -1
				elseif fish.t <= 0 then
					fish.t = 0
					fish.dir = 1
				end
				local pos = fish.from:Lerp(fish.to, fish.t)
				pos = pos + Vector3.new(0, math.sin(fish.t * 10) * 0.6, 0)
				local look = (fish.dir > 0) and fish.to or fish.from
				fish.model:PivotTo(CFrame.new(pos, Vector3.new(look.X, pos.Y, look.Z)))
			end
		end
	end)
end

-- A glowing holographic game controller that hovers above the plaza fountain,
-- projected up on a light beam with rising sparkles. Purely decorative eye
-- candy; startHologramSpin() slowly rotates it.
local function buildPlazaHologram(lobbyFolder)
	local fountainCenter = LOBBY_ORIGIN + Vector3.new(0, 0, -10)
	local P = fountainCenter + Vector3.new(0, FLOOR_TOP + 15, 0) -- controller hover centre
	local HOLO = Color3.fromRGB(110, 214, 255)
	local PURPLE = Color3.fromRGB(160, 120, 255)
	local GOLD = Color3.fromRGB(240, 205, 110)
	local GREEN = Color3.fromRGB(120, 230, 150)
	local RED = Color3.fromRGB(255, 110, 120)

	-- projection beam from the fountain spout up to the hologram
	local beam = Instance.new("Part")
	beam.Name = "HologramBeam"
	beam.Shape = Enum.PartType.Cylinder
	beam.Size = Vector3.new(9, 5.5, 5.5)
	beam.CFrame = CFrame.new(fountainCenter + Vector3.new(0, FLOOR_TOP + 11, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beam.Color = HOLO
	beam.Material = Enum.Material.Neon
	beam.Transparency = 0.88
	beam.Anchored = true
	beam.CanCollide = false
	beam.Parent = lobbyFolder
	local em = Instance.new("ParticleEmitter")
	em.Color = ColorSequence.new(HOLO)
	em.Rate = 24
	em.Lifetime = NumberRange.new(1.4, 2.4)
	em.Speed = NumberRange.new(3, 5)
	em.Size = NumberSequence.new(0.5)
	em.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	em.LightEmission = 1
	em.SpreadAngle = Vector2.new(10, 10)
	em.Acceleration = Vector3.new(0, 4, 0)
	em.Parent = beam

	-- Prefer the Blender controller mesh (nicer shape) painted as one translucent
	-- glowing cyan hologram. Falls back to the procedural controller below.
	local meshCtrl = StudioModels.get("Controller")
	if meshCtrl then
		meshCtrl.Name = "PlazaHologram"
		local sizeX
		if meshCtrl:IsA("Model") then
			local _, sz = meshCtrl:GetBoundingBox()
			sizeX = sz.X
		elseif meshCtrl:IsA("BasePart") then
			sizeX = meshCtrl.Size.X
		end
		local scale = (sizeX and sizeX > 0) and (9 / sizeX) or 1
		if meshCtrl:IsA("Model") then
			meshCtrl:ScaleTo(meshCtrl:GetScale() * scale)
		elseif meshCtrl:IsA("BasePart") then
			meshCtrl.Size = meshCtrl.Size * scale
		end
		local function paintHolo(p)
			p.Color = HOLO
			p.Material = Enum.Material.Neon
			p.Transparency = 0.4
			p.Anchored = true
			p.CanCollide = false
			p.CastShadow = false
		end
		if meshCtrl:IsA("BasePart") then
			paintHolo(meshCtrl)
		else
			for _, d in ipairs(meshCtrl:GetDescendants()) do
				if d:IsA("BasePart") then
					paintHolo(d)
				end
			end
			if not meshCtrl.PrimaryPart then
				meshCtrl.PrimaryPart = meshCtrl:FindFirstChildWhichIsA("BasePart")
			end
		end
		-- Tilt the face down toward players on the ground (spin preserves this).
		meshCtrl:PivotTo(CFrame.new(P) * CFrame.Angles(math.rad(-55), 0, 0))
		local mlight = Instance.new("PointLight")
		mlight.Color = HOLO
		mlight.Brightness = 1.3
		mlight.Range = 14
		mlight.Parent = meshCtrl:IsA("BasePart") and meshCtrl or meshCtrl.PrimaryPart
		meshCtrl.Parent = lobbyFolder
		plazaHologram = meshCtrl
		return
	end

	-- the floating controller: flat + wide with shoulder buttons and grips so it
	-- clearly reads as a controller (not a glowing bug), glass body + neon accents
	local EDGE = Color3.fromRGB(70, 150, 235)
	local model = Instance.new("Model")
	model.Name = "PlazaHologram"
	model.Parent = lobbyFolder
	local tilt = CFrame.Angles(math.rad(-14), 0, 0)
	local function hp(shape, size, pos, color, mat, tr, rot)
		local pt = Instance.new("Part")
		pt.Shape = shape
		pt.Size = size
		pt.Color = color
		pt.Material = mat
		pt.Transparency = tr or 0
		pt.Anchored = true
		pt.CanCollide = false
		pt.CFrame = CFrame.new(pos) * (rot or CFrame.new())
		pt.Parent = model
		return pt
	end
	local function L(x, dy, z)
		return P + Vector3.new(x, dy, z)
	end
	local G = Enum.Material.Glass
	local body = hp(Enum.PartType.Block, Vector3.new(7.2, 1.9, 3.2), L(0, 0, 0), HOLO, G, 0.28, tilt)
	hp(Enum.PartType.Cylinder, Vector3.new(3.2, 2.0, 2.0), L(-3.4, 0.1, 0), HOLO, G, 0.28, tilt * CFrame.Angles(0, 0, math.rad(90)))
	hp(Enum.PartType.Cylinder, Vector3.new(3.2, 2.0, 2.0), L(3.4, 0.1, 0), HOLO, G, 0.28, tilt * CFrame.Angles(0, 0, math.rad(90)))
	hp(Enum.PartType.Block, Vector3.new(1.5, 3.0, 1.7), L(-2.6, -1.7, 0.5), HOLO, G, 0.28, CFrame.Angles(math.rad(-14), 0, math.rad(26)))
	hp(Enum.PartType.Block, Vector3.new(1.5, 3.0, 1.7), L(2.6, -1.7, 0.5), HOLO, G, 0.28, CFrame.Angles(math.rad(-14), 0, math.rad(-26)))
	hp(Enum.PartType.Block, Vector3.new(6.4, 0.18, 0.18), L(0, 1.0, -1.5), EDGE, Enum.Material.Neon, 0, tilt) -- glow rim
	local fo = tilt * CFrame.new(0, 1.05, -1.55)
	local function ctrl(dx, dz, size, color, shape)
		local pos = (CFrame.new(L(0, 0, 0)) * fo * CFrame.new(dx, 0, dz)).Position
		hp(shape or Enum.PartType.Ball, size, pos, color, Enum.Material.Neon, 0)
	end
	ctrl(-2.1, 0, Vector3.new(1.4, 0.3, 0.5), PURPLE, Enum.PartType.Block) -- d-pad
	ctrl(-2.1, 0, Vector3.new(0.5, 0.3, 1.4), PURPLE, Enum.PartType.Block)
	ctrl(2.0, -0.7, Vector3.new(0.62, 0.5, 0.62), GOLD)
	ctrl(2.6, 0, Vector3.new(0.62, 0.5, 0.62), RED)
	ctrl(2.0, 0.7, Vector3.new(0.62, 0.5, 0.62), GREEN)
	ctrl(1.4, 0, Vector3.new(0.62, 0.5, 0.62), HOLO)
	ctrl(-0.7, 1.0, Vector3.new(0.8, 0.5, 0.8), PURPLE, Enum.PartType.Cylinder) -- sticks
	ctrl(0.4, 1.0, Vector3.new(0.8, 0.5, 0.8), PURPLE, Enum.PartType.Cylinder)
	local light = Instance.new("PointLight")
	light.Color = HOLO
	light.Brightness = 1.1
	light.Range = 13
	light.Parent = body

	model.PrimaryPart = body
	plazaHologram = model
end

-- Slowly spin the plaza hologram about the world Y axis, keeping its tilt.
local function startHologramSpin()
	if hologramSpinConnection then
		hologramSpinConnection:Disconnect()
	end
	if not plazaHologram or not plazaHologram.PrimaryPart then
		return
	end
	local rest = plazaHologram:GetPivot()
	local pos = rest.Position
	local tiltRot = rest.Rotation
	local angle = 0
	hologramSpinConnection = RunService.Heartbeat:Connect(function(dt)
		if not plazaHologram or not plazaHologram.Parent then
			return
		end
		angle += dt * 0.6 -- ~0.6 rad/s, a gentle spin
		plazaHologram:PivotTo(CFrame.new(pos) * CFrame.Angles(0, angle, 0) * tiltRot)
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

	-- (No separate lobby floor: the whole map's ground is the restyled grass
	-- baseplate, whose top sits exactly at FLOOR_TOP so nothing floats.)

	buildWelcomeSign(lobbyFolder)
	-- Walk-up Studio Kiosk (press E) is how players travel to their studio --
	-- the on-screen "To Studio" button was removed, so this is the way in, and
	-- it matches the welcome sign's "Head to the kiosk to visit your studio!".
	buildStudioKiosk(lobbyFolder)
	buildLandscaping(lobbyFolder)
	buildRoads(lobbyFolder)
	buildStreetlamps(lobbyFolder)
	buildStreetFurniture(lobbyFolder)
	buildParkedCars(lobbyFolder)
	buildRoundabout(lobbyFolder)
	buildRecreationArea(lobbyFolder)
	buildBeach(lobbyFolder)
	buildRockClusters(lobbyFolder)
	buildSkyline(lobbyFolder)
	buildNeighborhoodHouses(lobbyFolder)
	buildCrosswalks(lobbyFolder)
	buildFountain(lobbyFolder)
	buildPlazaHologram(lobbyFolder)
	buildParkDecor(lobbyFolder)
	buildPlayground(lobbyFolder)
	buildPlazaExtras(lobbyFolder)
	buildVIPLounge(lobbyFolder)
	buildMountains(lobbyFolder)
	buildRoTubePeaks(lobbyFolder)
	buildTunnels(lobbyFolder)
	buildBoundaryWalls(lobbyFolder)
	buildShops(lobbyFolder)
	buildPedestrians(lobbyFolder)

	activeCars = {}
	buildCars(lobbyFolder)
	startCarAnimation()
	startHologramSpin()
	startBasketballWatchdog()
	pcall(buildAtmosphere) -- never let a Lighting quirk abort the rest of build()
	startDayNightCycle()
	startLobbyLife()

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

-- Give a player a coloured CAP from a stored {r,g,b} outfit (Clothes shop).
-- (Body recolouring was removed -- players didn't want their character's own
-- colour changed; the welded cap is the visible "something" you get instead.)
local function applyOutfit(player, rgb)
	local char = player.Character
	if not char or not rgb then
		return
	end
	local color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
	local head = char:FindFirstChild("Head")
	if head then
		local old = char:FindFirstChild("ShopCap")
		if old then
			old:Destroy()
		end
		local cap = Instance.new("Model")
		cap.Name = "ShopCap"
		cap.Parent = char
		local function weldPart(name, size, offset, col)
			local p = Instance.new("Part")
			p.Name = name
			p.Size = size
			p.Color = col
			p.Material = Enum.Material.SmoothPlastic
			p.Anchored = false
			p.CanCollide = false
			p.Massless = true
			p.TopSurface = Enum.SurfaceType.Smooth
			p.BottomSurface = Enum.SurfaceType.Smooth
			p.CFrame = head.CFrame * offset
			p.Parent = cap
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = p
			weld.Part1 = head
			weld.Parent = p
			return p
		end
		weldPart("CapTop", Vector3.new(1.55, 0.7, 1.55), CFrame.new(0, 0.72, 0), color)
		weldPart("CapBrim", Vector3.new(1.55, 0.2, 0.95), CFrame.new(0, 0.48, -0.92), color)
	end
end

function Lobby.start()
	-- On-screen "To Studio" button: teleport the player to their own plot
	-- (replaces the old fountain kiosk prompt).
	Remotes.RequestGoToStudio.OnServerEvent:Connect(function(player)
		local plotIndex = PlotManager.getPlayerPlotIndex(player)
		local plotFolder = PlotManager.getPlotFolder(plotIndex)
		if not plotFolder or not player.Character then
			return
		end
		local spawnPoint = plotFolder:FindFirstChild("PlotSpawnPoint")
		if spawnPoint then
			player.Character:PivotTo(CFrame.new(spawnPoint.Position))
		end
	end)

	-- Re-apply a bought outfit whenever the player respawns.
	local function hookOutfit(plr)
		plr.CharacterAdded:Connect(function()
			task.wait(0.3)
			local data = PlayerData.get(plr)
			if data and data.outfitColor then
				applyOutfit(plr, data.outfitColor)
			end
		end)
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		hookOutfit(plr)
	end
	Players.PlayerAdded:Connect(hookOutfit)

	-- Shop: buy a specific item from a specific shop's catalog. The server is
	-- authoritative -- it looks the item up in the shared catalog by (shopKey,
	-- itemId) and applies its effect (a cash boost or a character recolour).
	Remotes.RequestBuyShopItem.OnServerEvent:Connect(function(player, shopKey, itemId)
		if typeof(shopKey) ~= "string" or typeof(itemId) ~= "string" then
			return
		end
		local item = GameData.findShopItem(shopKey, itemId)
		if not item then
			return
		end
		local data = PlayerData.get(player)
		if not data or data.cash < item.cost then
			if data then
				Remotes.PlayerStateUpdated:FireClient(player, data)
			end
			return
		end

		data.cash -= item.cost
		if item.kind == "boost" then
			-- Buying another while one runs adds its TIME on top; the multiplier
			-- takes the higher value (never the sum), via the shared rule.
			GameData.applyBoost(data, item.mult, item.dur, item.icon, item.name, workspace:GetServerTimeNow())
		elseif item.kind == "cosmetic" then
			local c = item.color
			data.outfitColor = { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
			data.outfitLabel = item.label or item.name
			applyOutfit(player, data.outfitColor)
		end
		Remotes.PlayerStateUpdated:FireClient(player, data)
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt.Name == "GoToStudioPrompt" then
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
		elseif prompt.Name == "ShootBasketballPrompt" then
			if not basketball or not player.Character then
				return
			end

			local root = player.Character:FindFirstChild("HumanoidRootPart")
			if not root then
				return
			end

			local nearestHoop = basketballHoopPositions[1]
			local nearestDist = nearestHoop and (root.Position - nearestHoop).Magnitude
			for _, hoopPosition in ipairs(basketballHoopPositions) do
				local dist = (root.Position - hoopPosition).Magnitude
				if not nearestDist or dist < nearestDist then
					nearestHoop = hoopPosition
					nearestDist = dist
				end
			end

			if nearestHoop then
				basketballShooterUserId = player.UserId
				shootBasketballToward(nearestHoop)
			end
		end
	end)
end

return Lobby

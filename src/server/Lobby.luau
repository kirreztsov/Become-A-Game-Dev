local ProximityPromptService = game:GetService("ProximityPromptService")
local PlotManager = require(script.Parent.PlotManager)

-- The shared arrival hub -- confirmed against RoTube Life 2's actual
-- structure ("the Park is where all players initially spawn... a
-- mailbox lets you select which Home to visit"). Everyone spawns here,
-- then a kiosk prompt sends each player to their own already-assigned
-- studio -- there's no home *choice* in this game (one studio per
-- player, upgraded in place), so one prompt is enough, no mailbox menu.
local Lobby = {}

local FLOOR_TOP = 1
local LOBBY_ORIGIN = Vector3.new(80, 0, -100)
local LOBBY_SIZE = 70

local ACCENT_COLOR = Color3.fromRGB(140, 92, 255)
local GOLD_COLOR = Color3.fromRGB(255, 209, 102)
local DARK_TRIM_COLOR = Color3.fromRGB(30, 22, 44)

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

	local labelAnchor = Instance.new("Part")
	labelAnchor.Name = "StudioKioskLabelAnchor"
	labelAnchor.Size = Vector3.new(0.1, 0.1, 0.1)
	labelAnchor.Position = LOBBY_ORIGIN + Vector3.new(0, FLOOR_TOP + 4.5, 0)
	labelAnchor.Transparency = 1
	labelAnchor.Anchored = true
	labelAnchor.CanCollide = false
	labelAnchor.Parent = lobbyFolder

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(200, 40)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 40
	billboard.Parent = labelAnchor

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = "\240\159\143\160 My Studio"
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.Parent = billboard
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

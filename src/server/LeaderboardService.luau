-- In-world leaderboards: physical boards near the beach showing a top-10
-- teaser for each global stat (Prestige, Subscribers, Cash, Games Released).
-- Reads from GlobalLeaderboardService's cache and auto-flips the displayed
-- period between "This Week" and "All-Time" every FLIP_SECONDS. Falls back to
-- a placeholder message when the cache has no data yet (e.g. in Studio, where
-- DataStore access is disabled, or before the first successful global read).

local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local GameData = require(game.ReplicatedStorage.Shared.GameData)
local GlobalLeaderboardService = require(script.Parent.GlobalLeaderboardService)

local LeaderboardService = {}

local REFRESH_SECONDS = 12
local TOP_N = 10
local ORIGIN = Vector3.new(15, 0, -40) -- world; a rocky outcrop on the beach
local BOARD_SPACING = 15
local FLOOR_TOP = 1
local FLIP_SECONDS = 10
local PLACEHOLDER = "\240\159\140\141 Global rankings appear in the live game"

-- Built once; holds the TextLabel that shows each board's rows, and the
-- header TextLabel so it can show which period (This Week / All-Time) is
-- currently on display.
local boardListLabels = {}
local boardTitleLabels = {}

local function part(name, size, position, color, material, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = position
	p.Anchored = true
	p.CanCollide = true
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

function LeaderboardService.build()
	local existing = workspace:FindFirstChild("Leaderboards")
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Leaderboards"
	folder.Parent = workspace

	-- A dedicated rocky outcrop on the beach for the boards to stand on (so
	-- they sit fully on rock, not half on sand/grass).
	part("LeaderboardRock", Vector3.new(66, 2, 16), Vector3.new(ORIGIN.X, FLOOR_TOP + 0.6, ORIGIN.Z), Color3.fromRGB(122, 116, 108), Enum.Material.Rock, folder)
	for _, off in ipairs({ Vector3.new(-34, 0, -5), Vector3.new(35, 0, 5), Vector3.new(-30, 0, 6), Vector3.new(31, 0, -6), Vector3.new(0, 0, 8) }) do
		local b = part("LeaderboardBoulder", Vector3.new(5.5, 5, 5.5), Vector3.new(ORIGIN.X + off.X, FLOOR_TOP + 2, ORIGIN.Z + off.Z), Color3.fromRGB(108, 102, 96), Enum.Material.Rock, folder)
		b.CFrame = CFrame.new(b.Position) * CFrame.Angles(0, math.rad((off.X + off.Z) % 90), 0)
	end

	local n = #GameData.LeaderboardStats
	for i, cat in ipairs(GameData.LeaderboardStats) do
		-- Auto-centre however many boards there are on the rock's midpoint.
		local x = ORIGIN.X + (i - (n + 1) / 2) * BOARD_SPACING
		local base = Vector3.new(x, 1, ORIGIN.Z)
		-- pedestal + board
		part("Board" .. i .. "Base", Vector3.new(14, 2, 2.5), base + Vector3.new(0, 1, 0), Color3.fromRGB(60, 54, 74), Enum.Material.Marble, folder)
		local board = part("Board" .. i, Vector3.new(13, 14, 0.6), base + Vector3.new(0, 9.5, 0), Color3.fromRGB(28, 24, 38), Enum.Material.SmoothPlastic, folder)

		-- header strip on top
		part("Board" .. i .. "Header", Vector3.new(13, 2, 0.7), base + Vector3.new(0, 15.5, 0), cat.accent, Enum.Material.SmoothPlastic, folder).CanCollide = false

		local sg = Instance.new("SurfaceGui")
		sg.Name = "Display"
		sg.Face = Enum.NormalId.Front -- -Z, toward the plaza
		sg.CanvasSize = Vector2.new(340, 380)
		sg.LightInfluence = 0
		sg.Parent = board

		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 10)
		pad.PaddingLeft = UDim.new(0, 12)
		pad.PaddingRight = UDim.new(0, 12)
		pad.Parent = sg

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, 0, 0, 44)
		title.BackgroundTransparency = 1
		title.Text = cat.title
		title.TextColor3 = cat.accent
		title.Font = Enum.Font.FredokaOne
		title.TextScaled = true
		title.Parent = sg
		boardTitleLabels[i] = title

		local list = Instance.new("TextLabel")
		list.Name = "List"
		list.Size = UDim2.new(1, 0, 1, -52)
		list.Position = UDim2.fromOffset(0, 50)
		list.BackgroundTransparency = 1
		list.TextXAlignment = Enum.TextXAlignment.Left
		list.TextYAlignment = Enum.TextYAlignment.Top
		list.TextColor3 = Color3.fromRGB(240, 238, 250)
		list.Font = Enum.Font.GothamMedium
		list.TextSize = 22
		list.Text = "Waiting for players..."
		list.Parent = sg

		boardListLabels[i] = list
	end
end

local function refresh()
	local period = (math.floor(os.time() / FLIP_SECONDS) % 2 == 0) and "week" or "all"
	local periodLabel = (period == "week") and "\240\159\151\147\239\184\143 This Week" or "\240\159\143\134 All-Time"
	for i, stat in ipairs(GameData.LeaderboardStats) do
		local titleLabel = boardTitleLabels[i]
		if titleLabel then
			titleLabel.Text = periodLabel .. " \226\128\148 " .. stat.title
		end
		local label = boardListLabels[i]
		if not label then continue end
		local rows = GlobalLeaderboardService.getRows(stat.key, period)
		if not rows then
			label.Text = PLACEHOLDER
		elseif #rows == 0 then
			label.Text = "Be the first on the board!"
		else
			local lines = {}
			for rank = 1, math.min(TOP_N, #rows) do
				local r = rows[rank]
				lines[#lines + 1] = ("%d. %s  \226\128\148  %s"):format(rank, r.name, stat.format(r.value))
			end
			label.Text = table.concat(lines, "\n")
		end
	end
end

-- Where the "Go to Leaderboards" button teleports you: standing on the rock,
-- facing the boards.
function LeaderboardService.getTeleportCFrame()
	return CFrame.new(Vector3.new(ORIGIN.X, FLOOR_TOP + 4, ORIGIN.Z - 10), Vector3.new(ORIGIN.X, FLOOR_TOP + 4, ORIGIN.Z))
end

function LeaderboardService.start()
	-- On-screen "Go to Leaderboards" button: teleport to the beach outcrop.
	Remotes.RequestGoToLeaderboards.OnServerEvent:Connect(function(player)
		if player.Character then
			player.Character:PivotTo(LeaderboardService.getTeleportCFrame())
		end
	end)

	task.spawn(function()
		while true do
			refresh()
			task.wait(REFRESH_SECONDS)
		end
	end)
end

return LeaderboardService

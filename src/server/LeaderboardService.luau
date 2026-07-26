-- In-world leaderboards: three tall boards near the plaza showing the top
-- players by Subscribers, Cash and Games Released. Ranks everyone currently in
-- the server from their live PlayerData and refreshes on a timer.
--
-- (Global cross-server ranking via OrderedDataStore is a future enhancement;
-- it can't run in Studio anyway since DataStore access is disabled there. This
-- version always works and is fully testable.)

local Players = game:GetService("Players")
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)

local LeaderboardService = {}

local REFRESH_SECONDS = 12
local TOP_N = 10
local ORIGIN = Vector3.new(15, 0, -40) -- world; a rocky outcrop on the beach
local BOARD_SPACING = 15
local FLOOR_TOP = 1

local function withCommas(n)
	local s = tostring(math.floor(n or 0))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local CATEGORIES = {
	{ key = "prestigeLevel", title = "\226\173\144 Top Prestige", accent = Color3.fromRGB(150, 92, 255), format = function(v) return "P" .. withCommas(v) end },
	{ key = "subscribers", title = "\240\159\143\134 Most Subscribers", accent = Color3.fromRGB(224, 72, 96), format = function(v) return withCommas(v) end },
	{ key = "cash", title = "\240\159\146\176 Richest", accent = Color3.fromRGB(255, 209, 102), format = function(v) return "$" .. withCommas(v) end },
	{ key = "gamesReleased", title = "\240\159\142\174 Most Games", accent = Color3.fromRGB(140, 200, 120), format = function(v) return withCommas(v) end },
}

-- Built once; holds the TextLabel that shows each board's rows.
local boardListLabels = {}

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

	local n = #CATEGORIES
	for i, cat in ipairs(CATEGORIES) do
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
	-- Gather live data for everyone in the server.
	local entries = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		local data = PlayerData.get(plr)
		if data then
			table.insert(entries, { name = plr.DisplayName, data = data })
		end
	end

	for i, cat in ipairs(CATEGORIES) do
		local sorted = table.clone(entries)
		table.sort(sorted, function(a, b)
			return (a.data[cat.key] or 0) > (b.data[cat.key] or 0)
		end)
		local lines = {}
		for rank = 1, math.min(TOP_N, #sorted) do
			local e = sorted[rank]
			lines[#lines + 1] = ("%d. %s  —  %s"):format(rank, e.name, cat.format(e.data[cat.key] or 0))
		end
		local label = boardListLabels[i]
		if label then
			label.Text = (#lines > 0) and table.concat(lines, "\n") or "Waiting for players..."
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

-- The "path connect" mini-game: a gridN x gridN grid of tiles with a green
-- start cell (left column) and a gold exit cell (right column). The player
-- taps tiles to extend a path from start, one orthogonally-adjacent step at a
-- time, trying to reach the exit before the timer runs out. Like
-- BlueprintMemory/TileDrop, this is a "sequence" variant: it owns no remotes
-- and no round logic, it just builds UI, runs its own input timer, and calls
-- the injected `report` callback once per round with how many path steps
-- (beyond the start tile) are on a valid contiguous chain, capped at
-- roundInfo.total. The framework controller supplies `report`, decides round
-- timing/targets (via params), and owns the server round (which independently
-- generates the same gridN/startCell/exitCell/total -- see
-- DevelopmentService.generateRoundInfo's PathConnect branch).
local PathConnect = { id = "PathConnect", station = "MapBuilding", inputKind = "sequence" }

local container
local hintLabel
local gridFrame
local gridLayout
local reportFn
local themeRef

local tileButtons = {} -- 1..gridN*gridN -> TextButton
local lastGridN = nil

-- Fixed pixel budget for the tile grid within the 420x300 station panel (see
-- UI.luau's makeStationPanel), matching BlueprintMemory's GRID_W/GRID_H
-- convention for this same panel size.
local GRID_W = 400
local GRID_H = 210
local CELL_PAD = 6
local MIN_CELL = 44

-- Round token: startRound captures a fresh token into activeToken; the tile
-- tap handlers and the timeout timer all compare against it so a stale round
-- (after hide() or a new startRound) can't keep firing into the new round.
local activeToken = nil
local gridN = 0
local startCell = nil
local exitCell = nil
local currentTotal = 0
local path = {} -- ordered list of cell indices, path[1] == startCell
local pathSet = {} -- cell index -> true, cells currently on the path
local correctCount = 0
local roundDone = false

-- Forward-declared: buildGrid's tile click handlers close over this before
-- it's assigned below (mirrors BlueprintMemory/TileDrop's finalize/token pattern).
local finalize

local function corner(inst, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
	return c
end

local function setTilesEnabled(enabled)
	for _, btn in ipairs(tileButtons) do
		btn.Active = enabled
	end
end

-- Row/col for a 1-based cell index, matching the server's convention
-- (row = floor((c-1)/gridN), col = (c-1) % gridN) so adjacency checks here
-- agree with how the server would judge the same grid.
local function rowColOf(cell, n)
	return math.floor((cell - 1) / n), (cell - 1) % n
end

local function areAdjacent(a, b, n)
	local rowA, colA = rowColOf(a, n)
	local rowB, colB = rowColOf(b, n)
	return (math.abs(rowA - rowB) + math.abs(colA - colB)) == 1
end

-- Repaints every tile from scratch: neutral, then start (green) and exit
-- (gold) markers, then any tiles currently on the path (accent).
local function repaintGrid()
	for _, btn in ipairs(tileButtons) do
		btn.BackgroundColor3 = themeRef.Neutral
	end
	for _, cell in ipairs(path) do
		if tileButtons[cell] then
			tileButtons[cell].BackgroundColor3 = themeRef.Accent
		end
	end
	if tileButtons[startCell] then
		tileButtons[startCell].BackgroundColor3 = themeRef.Success
	end
	if tileButtons[exitCell] then
		tileButtons[exitCell].BackgroundColor3 = themeRef.Gold
	end
end

-- (Re)builds the gridN x gridN tile buttons. Only called from startRound when
-- gridN differs from the last built grid, since most rounds reuse the same
-- difficulty's grid size.
local function buildGrid(n)
	for _, btn in ipairs(tileButtons) do
		btn:Destroy()
	end
	tileButtons = {}

	local cellW = (GRID_W - (n - 1) * CELL_PAD) / n
	local cellH = (GRID_H - (n - 1) * CELL_PAD) / n
	local cellPx = math.max(MIN_CELL, math.floor(math.min(cellW, cellH)))
	gridLayout.CellSize = UDim2.fromOffset(cellPx, cellPx)

	for i = 1, n * n do
		local btn = Instance.new("TextButton")
		btn.Name = "Tile_" .. i
		btn.LayoutOrder = i
		btn.BackgroundColor3 = themeRef.Neutral
		btn.Text = ""
		btn.AutoButtonColor = false
		btn.BorderSizePixel = 0
		btn.Active = false
		btn.Parent = gridFrame
		corner(btn, 8)
		local tileStroke = Instance.new("UIStroke")
		tileStroke.Color = themeRef.Line
		tileStroke.Thickness = 1
		tileStroke.Transparency = 0.3
		tileStroke.Parent = btn

		btn.MouseButton1Click:Connect(function()
			local token = activeToken
			if not token or roundDone or not btn.Active then
				return
			end
			-- Ignore revisits (already on the path) and non-adjacent taps.
			if pathSet[i] or not areAdjacent(i, path[#path], gridN) then
				return
			end
			table.insert(path, i)
			pathSet[i] = true
			if i == exitCell then
				correctCount = currentTotal
			else
				correctCount = math.min(#path - 1, currentTotal)
			end
			repaintGrid()
			hintLabel.Text = ("Progress: %d/%d"):format(correctCount, currentTotal)
			if i == exitCell then
				finalize(token)
			end
		end)

		tileButtons[i] = btn
	end

	lastGridN = n
end

-- Scores the round by how many path steps (beyond start) are on a valid
-- contiguous chain, capped at total -- reaching the exit always scores total.
-- Guarded so it only ever fires once per round, whether triggered by reaching
-- the exit or the input timer expiring.
finalize = function(token)
	if activeToken ~= token or roundDone then
		return
	end
	roundDone = true
	setTilesEnabled(false)
	reportFn(correctCount)
end

function PathConnect.init(parent, theme, report)
	reportFn = report
	themeRef = theme

	container = Instance.new("Frame")
	container.Name = "PathConnect"
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundTransparency = 1
	container.Visible = false
	container.Parent = parent

	hintLabel = Instance.new("TextLabel")
	hintLabel.Name = "Hint"
	hintLabel.Size = UDim2.new(1, -20, 0, 20)
	hintLabel.Position = UDim2.fromOffset(10, 6)
	hintLabel.BackgroundTransparency = 1
	hintLabel.Text = "CONNECT START TO EXIT!"
	hintLabel.Font = Enum.Font.FredokaOne
	hintLabel.TextSize = 16
	hintLabel.TextColor3 = theme.Text
	hintLabel.TextXAlignment = Enum.TextXAlignment.Left
	hintLabel.Parent = container

	-- Grid area: tappable square tiles, gridN x gridN, rebuilt in startRound
	-- when gridN changes. Cell size is computed from GRID_W/GRID_H so tiles
	-- stay >=44px (MIN_CELL) even as gridN grows across difficulties.
	gridFrame = Instance.new("Frame")
	gridFrame.Name = "Grid"
	gridFrame.Size = UDim2.new(1, -20, 0, GRID_H)
	gridFrame.Position = UDim2.fromOffset(10, 32)
	gridFrame.BackgroundTransparency = 1
	gridFrame.Parent = container

	gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellPadding = UDim2.fromOffset(CELL_PAD, CELL_PAD)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gridLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	gridLayout.Parent = gridFrame
end

function PathConnect.startRound(difficulty, params, roundInfo)
	gridN = (roundInfo and roundInfo.gridN) or 4
	startCell = (roundInfo and roundInfo.startCell) or 1
	exitCell = (roundInfo and roundInfo.exitCell) or (gridN * gridN)
	currentTotal = (roundInfo and roundInfo.total) or (gridN - 1)

	if gridN ~= lastGridN then
		buildGrid(gridN)
	end

	path = { startCell }
	pathSet = { [startCell] = true }
	correctCount = 0
	roundDone = false
	container.Visible = true

	local token = {}
	activeToken = token

	hintLabel.Text = ("Progress: 0/%d"):format(currentTotal)
	repaintGrid()
	setTilesEnabled(true)

	local timeSeconds = (params and params.timeSeconds) or 8
	task.delay(timeSeconds, function()
		finalize(token)
	end)
end

function PathConnect.hide()
	activeToken = nil
	roundDone = true
	setTilesEnabled(false)
	if container then
		container.Visible = false
	end
end

return PathConnect

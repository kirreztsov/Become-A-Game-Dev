-- The "blueprint memory" mini-game: a gridN x gridN grid of blueprint tiles.
-- A handful of tiles flash lit (the "pattern") for a peek window, then go
-- dark, and the player taps to reproduce which tiles were lit -- purely from
-- memory. Like KeyCombo, this is a "sequence" variant: it owns no remotes and
-- no round logic, it just builds UI, runs its own peek/input timers, and
-- calls the injected `report` callback once per round with how many distinct
-- pattern tiles were correctly tapped. The framework controller supplies
-- `report`, decides round timing/targets (via params), and owns the server
-- round (which independently generates the same gridN + pattern).
local BlueprintMemory = { id = "BlueprintMemory", station = "MapBuilding", inputKind = "sequence" }

local container
local hintLabel
local gridFrame
local gridLayout
local doneButton
local reportFn
local themeRef

local tileButtons = {} -- 1..gridN*gridN -> TextButton
local lastGridN = nil

-- Fixed pixel budget for the tile grid within the 420x300 station panel (see
-- UI.luau's makeStationPanel): matches the layout carved out in init below
-- (hint label + grid + Done button all stacked in the 300px-tall panel).
local GRID_W = 400
local GRID_H = 210
local CELL_PAD = 6
local MIN_CELL = 44

-- Round token: startRound captures a fresh token into activeToken; the peek
-- timer, the fallback finalize timer, and every tile/Done button callback
-- compare against it so a stale round (after hide() or a new startRound)
-- can't keep firing into the new round.
local activeToken = nil
local patternSet = {} -- tile index -> true, tiles that were lit this round
local countedSet = {} -- tile index -> true, pattern tiles already tapped correctly
local tapsMade = 0
local correctCount = 0
local currentTotal = 0
local roundDone = false

-- Forward-declared: buildGrid's tile click handlers close over this before
-- it's assigned below (mirrors KeyCombo's finalize/token pattern).
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

-- (Re)builds the gridN x gridN tile buttons. Only called from startRound when
-- gridN differs from the last built grid, since most rounds reuse the same
-- difficulty's grid size.
local function buildGrid(gridN)
	for _, btn in ipairs(tileButtons) do
		btn:Destroy()
	end
	tileButtons = {}

	local cellW = (GRID_W - (gridN - 1) * CELL_PAD) / gridN
	local cellH = (GRID_H - (gridN - 1) * CELL_PAD) / gridN
	local cellPx = math.max(MIN_CELL, math.floor(math.min(cellW, cellH)))
	gridLayout.CellSize = UDim2.fromOffset(cellPx, cellPx)

	for i = 1, gridN * gridN do
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
			tapsMade += 1
			if patternSet[i] and not countedSet[i] then
				countedSet[i] = true
				correctCount += 1
				btn.BackgroundColor3 = themeRef.Success
			else
				btn.BackgroundColor3 = themeRef.Danger
			end
			if tapsMade >= currentTotal then
				finalize(token)
			end
		end)

		tileButtons[i] = btn
	end

	lastGridN = gridN
end

-- Scores the round by distinct pattern tiles correctly tapped and reports it.
-- Guarded so it only ever fires once per round, whether triggered by the
-- final tap, the Done button, or the input fallback timer expiring.
finalize = function(token)
	if activeToken ~= token or roundDone then
		return
	end
	roundDone = true
	setTilesEnabled(false)
	if doneButton then
		doneButton.Active = false
	end
	reportFn(correctCount)
end

function BlueprintMemory.init(parent, theme, report)
	reportFn = report
	themeRef = theme

	container = Instance.new("Frame")
	container.Name = "BlueprintMemory"
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundTransparency = 1
	container.Visible = false
	container.Parent = parent

	hintLabel = Instance.new("TextLabel")
	hintLabel.Name = "Hint"
	hintLabel.Size = UDim2.new(1, -20, 0, 20)
	hintLabel.Position = UDim2.fromOffset(10, 6)
	hintLabel.BackgroundTransparency = 1
	hintLabel.Text = "MEMORIZE THE PATTERN!"
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

	doneButton = Instance.new("TextButton")
	doneButton.Name = "DoneButton"
	doneButton.Size = UDim2.new(1, -20, 0, 32)
	doneButton.Position = UDim2.new(0, 10, 1, -40)
	doneButton.BackgroundColor3 = theme.Accent
	doneButton.Text = "Done"
	doneButton.Font = Enum.Font.FredokaOne
	doneButton.TextSize = 16
	doneButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	doneButton.AutoButtonColor = false
	doneButton.BorderSizePixel = 0
	doneButton.Visible = false
	doneButton.Parent = container
	corner(doneButton, 10)

	doneButton.MouseButton1Click:Connect(function()
		local token = activeToken
		if not token or roundDone then
			return
		end
		finalize(token)
	end)
end

function BlueprintMemory.startRound(difficulty, params, roundInfo)
	local gridN = (roundInfo and roundInfo.gridN) or 3
	local pattern = (roundInfo and roundInfo.pattern) or {}
	currentTotal = (roundInfo and roundInfo.total) or #pattern

	if gridN ~= lastGridN then
		buildGrid(gridN)
	end

	patternSet = {}
	for _, idx in ipairs(pattern) do
		patternSet[idx] = true
	end
	countedSet = {}
	tapsMade = 0
	correctCount = 0
	roundDone = false
	container.Visible = true

	local token = {}
	activeToken = token

	-- Peek phase: light the pattern tiles, taps disabled.
	hintLabel.Text = "MEMORIZE THE PATTERN!"
	doneButton.Visible = false
	setTilesEnabled(false)
	for _, btn in ipairs(tileButtons) do
		btn.BackgroundColor3 = themeRef.Neutral
	end
	for idx in pairs(patternSet) do
		if tileButtons[idx] then
			tileButtons[idx].BackgroundColor3 = themeRef.Gold
		end
	end

	local peekSeconds = (params and params.peekSeconds) or 2
	task.delay(peekSeconds, function()
		if activeToken ~= token then
			return
		end
		for _, btn in ipairs(tileButtons) do
			btn.BackgroundColor3 = themeRef.Neutral
		end
		hintLabel.Text = "REPEAT THE PATTERN!"
		doneButton.Visible = true
		doneButton.Active = true
		setTilesEnabled(true)

		-- Fallback so a round can't hang forever if the player never makes
		-- #pattern taps nor presses Done. The server abandons waiting at
		-- peekSeconds + 12 (see DevelopmentService's generateRoundInfo maxWait
		-- for this variant), so finalize a little before that.
		task.delay(11, function()
			finalize(token)
		end)
	end)
end

function BlueprintMemory.hide()
	activeToken = nil
	roundDone = true
	setTilesEnabled(false)
	if doneButton then
		doneButton.Visible = false
	end
	if container then
		container.Visible = false
	end
end

return BlueprintMemory

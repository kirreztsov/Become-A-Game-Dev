-- The "bug hunt" mini-game: a gridN x gridN grid of identical "happy" tiles,
-- except one tile (the server-chosen correctIndex) is subtly glitched -- a
-- different glyph on a faintly different tint. The player taps the tile they
-- think is glitched. This is a "choice" variant: it owns no remotes and no
-- round logic -- it just builds UI and calls the injected `report` callback
-- once, on the first tap. The framework controller supplies `report`, decides
-- round content (via `roundInfo`), and owns the server round (which
-- independently picks the same correctIndex).
local BugHunt = { id = "BugHunt", station = "Testing", inputKind = "choice" }

local HAPPY_GLYPH = utf8.char(0x1F642) -- 🙂
local BUG_GLYPH = utf8.char(0x1F41B) -- 🐛

local container
local promptLabel
local gridFrame
local gridLayout
local reportFn
local themeRef
local answered = false

local tileButtons = {} -- 1..gridN*gridN -> TextButton
local lastGridN = nil
local correctIndex = nil

-- Fixed pixel budget for the tile grid within the 420x300 station panel (see
-- UI.luau's makeStationPanel): prompt label takes the top ~40px, the grid
-- gets the rest. Sized so cells stay >=44px even at gridN=5 (see
-- (GRID_H - 4*CELL_PAD)/5 = 45.2 -> floors to 45).
local GRID_W = 400
local GRID_H = 250
local CELL_PAD = 6
local MIN_CELL = 44

local function corner(inst, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
	return c
end

-- (Re)builds the gridN x gridN tile buttons. Only called from startRound when
-- gridN differs from the last built grid, since most rounds reuse the same
-- difficulty's grid size (mirrors BlueprintMemory's buildGrid).
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
		btn.Text = HAPPY_GLYPH
		btn.Font = Enum.Font.SourceSansBold
		btn.TextSize = math.floor(cellPx * 0.5)
		btn.TextColor3 = themeRef.Text
		btn.AutoButtonColor = false
		btn.BorderSizePixel = 0
		btn.Parent = gridFrame
		corner(btn, 8)

		local stroke = Instance.new("UIStroke")
		stroke.Color = themeRef.Line
		stroke.Thickness = 1
		stroke.Transparency = 0.3
		stroke.Parent = btn

		btn.MouseButton1Click:Connect(function()
			if answered then
				return
			end
			answered = true
			reportFn(i)
		end)

		tileButtons[i] = btn
	end

	lastGridN = gridN
end

function BugHunt.init(parent, theme, report)
	reportFn = report
	themeRef = theme

	container = Instance.new("Frame")
	container.Name = "BugHunt"
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundTransparency = 1
	container.Visible = false
	container.Parent = parent

	promptLabel = Instance.new("TextLabel")
	promptLabel.Name = "Prompt"
	promptLabel.Size = UDim2.new(1, -24, 0, 28)
	promptLabel.Position = UDim2.fromOffset(12, 8)
	promptLabel.BackgroundTransparency = 1
	promptLabel.Text = "Spot the bug!"
	promptLabel.Font = Enum.Font.FredokaOne
	promptLabel.TextSize = 16
	promptLabel.TextColor3 = theme.Text
	promptLabel.TextXAlignment = Enum.TextXAlignment.Left
	promptLabel.Parent = container

	-- Grid area: tappable square tiles, gridN x gridN, rebuilt in startRound
	-- when gridN changes. Cell size is computed from GRID_W/GRID_H so tiles
	-- stay >=44px (MIN_CELL) even as gridN grows across difficulties.
	gridFrame = Instance.new("Frame")
	gridFrame.Name = "Grid"
	gridFrame.Size = UDim2.new(1, -20, 0, GRID_H)
	gridFrame.Position = UDim2.fromOffset(10, 44)
	gridFrame.BackgroundTransparency = 1
	gridFrame.Parent = container

	gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellPadding = UDim2.fromOffset(CELL_PAD, CELL_PAD)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gridLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	gridLayout.Parent = gridFrame
end

function BugHunt.startRound(difficulty, params, roundInfo)
	answered = false
	correctIndex = roundInfo and roundInfo.correctIndex or 1

	local gridN = (roundInfo and roundInfo.gridN) or 3
	if gridN ~= lastGridN then
		buildGrid(gridN)
	end

	-- Reset every tile to "happy", then glitch the chosen one: a distinct
	-- glyph plus a faint tint shift, so a careful player can spot it (per
	-- design note: subtle is fine, invisible is unfair).
	for i, btn in ipairs(tileButtons) do
		if i == correctIndex then
			btn.Text = BUG_GLYPH
			btn.BackgroundColor3 = themeRef.Neutral:Lerp(themeRef.Danger, 0.35)
		else
			btn.Text = HAPPY_GLYPH
			btn.BackgroundColor3 = themeRef.Neutral
		end
	end

	container.Visible = true
end

function BugHunt.hide()
	if container then
		container.Visible = false
	end
end

return BugHunt

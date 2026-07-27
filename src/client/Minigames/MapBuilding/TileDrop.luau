-- The "tile drop" mini-game: pieces slide across a horizontal track one at a
-- time; the player taps DROP (or the piece itself) to release it -- a drop
-- counts as "good" if the piece is near the fixed slot (track centre) at the
-- moment it's released. Like BlueprintMemory, this is a "sequence" variant:
-- it owns no remotes and no round logic, it just builds UI, runs its own
-- per-piece movement loop, and calls the injected `report` callback once per
-- round with how many drops landed within tolerance. The framework
-- controller supplies `report`, decides round timing/targets (via params:
-- pieces, fallSeconds), and owns the server round -- position/tolerance
-- judging happens entirely client-side, the server only cares about the
-- final goodDrops/total count (see DevelopmentService.generateRoundInfo's
-- TileDrop branch, which just mirrors total=pieces for scoring).
local TileDrop = { id = "TileDrop", station = "MapBuilding", inputKind = "sequence" }

local container
local hintLabel
local scoreLabel
local track
local slotMarker
local piece
local dropButton
local reportFn
local themeRef

-- Fixed pixel budget for the track within the 420x300 station panel (see
-- UI.luau's makeStationPanel), matching BlueprintMemory's GRID_W/GRID_H
-- convention for this same panel size.
local TRACK_W = 400
local TRACK_H = 70
local PIECE_SIZE = 44 -- tap target, also the visual "piece" square
local TOLERANCE = 0.14 -- fraction of track width; within this of centre (0.5) = good

-- Round token: startRound captures a fresh token into activeToken; the
-- per-piece movement loop and the Drop/piece tap callbacks compare against
-- it so a stale round (after hide() or a new startRound) can't keep firing
-- into the new round.
local activeToken = nil
local totalPieces = 0
local fallSeconds = 2
local pieceIndex = 0
local goodDrops = 0
local roundDone = false
local pieceJudged = true -- true when no piece is currently "in flight"
local liveFrac = 0 -- current piece position (0..1 across the track), updated by the movement loop

-- Forward-declared: the movement loop, the tap handler and the drop button
-- all need to call these before they're assigned below (mirrors
-- BlueprintMemory's finalize/token pattern).
local judgeDrop
local runPiece
local finalizeRound

local function corner(inst, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
	return c
end

local function setControlsEnabled(enabled)
	dropButton.Active = enabled
	dropButton.BackgroundColor3 = enabled and themeRef.Accent or themeRef.Neutral
	piece.Active = enabled
end

-- Judges the piece currently in flight at position `frac` (0 = left edge,
-- 1 = right edge; the slot sits at the centre, 0.5), then advances to the
-- next piece or finalizes the round if this was the last one. Guarded so a
-- piece can only be judged once, whether triggered by a tap or by the
-- movement loop reaching the end of the track untapped.
judgeDrop = function(token, frac)
	if activeToken ~= token or roundDone or pieceJudged then
		return
	end
	pieceJudged = true
	setControlsEnabled(false)

	local dist = math.abs(frac - 0.5)
	if dist <= TOLERANCE then
		goodDrops += 1
		piece.BackgroundColor3 = themeRef.Success
	else
		piece.BackgroundColor3 = themeRef.Danger
	end
	scoreLabel.Text = ("Good drops: %d/%d"):format(goodDrops, totalPieces)

	if pieceIndex >= totalPieces then
		task.delay(0.3, function()
			finalizeRound(token)
		end)
	else
		task.delay(0.35, function()
			if activeToken == token then
				runPiece(token)
			end
		end)
	end
end

-- Starts the next piece: resets it to the left edge and slides it across the
-- track over `fallSeconds`. If it reaches the far edge without being tapped,
-- that counts as a (very) bad drop -- the loop judges it itself so a round
-- can never hang waiting on an AFK player.
runPiece = function(token)
	if activeToken ~= token then
		return
	end
	pieceIndex += 1
	pieceJudged = false
	liveFrac = 0
	hintLabel.Text = ("Piece %d/%d -- tap DROP over the slot!"):format(pieceIndex, totalPieces)
	piece.BackgroundColor3 = themeRef.Gold
	piece.Position = UDim2.fromOffset(0, (TRACK_H - PIECE_SIZE) / 2)
	setControlsEnabled(true)

	local startClock = os.clock()
	task.spawn(function()
		while activeToken == token and not pieceJudged do
			local elapsed = os.clock() - startClock
			local frac = math.clamp(elapsed / fallSeconds, 0, 1)
			liveFrac = frac
			piece.Position = UDim2.fromOffset(frac * (TRACK_W - PIECE_SIZE), (TRACK_H - PIECE_SIZE) / 2)
			if frac >= 1 then
				judgeDrop(token, frac)
				break
			end
			task.wait(0.03)
		end
	end)
end

-- Scores the round done and reports it. Guarded so it only ever fires once
-- per round.
finalizeRound = function(token)
	if activeToken ~= token or roundDone then
		return
	end
	roundDone = true
	setControlsEnabled(false)
	reportFn(goodDrops)
end

local function onDropTapped()
	local token = activeToken
	if not token or roundDone or pieceJudged then
		return
	end
	judgeDrop(token, liveFrac)
end

function TileDrop.init(parent, theme, report)
	reportFn = report
	themeRef = theme

	container = Instance.new("Frame")
	container.Name = "TileDrop"
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundTransparency = 1
	container.Visible = false
	container.Parent = parent

	hintLabel = Instance.new("TextLabel")
	hintLabel.Name = "Hint"
	hintLabel.Size = UDim2.new(1, -20, 0, 20)
	hintLabel.Position = UDim2.fromOffset(10, 6)
	hintLabel.BackgroundTransparency = 1
	hintLabel.Text = "GET READY!"
	hintLabel.Font = Enum.Font.FredokaOne
	hintLabel.TextSize = 16
	hintLabel.TextColor3 = theme.Text
	hintLabel.TextXAlignment = Enum.TextXAlignment.Left
	hintLabel.Parent = container

	scoreLabel = Instance.new("TextLabel")
	scoreLabel.Name = "Score"
	scoreLabel.Size = UDim2.new(1, -20, 0, 16)
	scoreLabel.Position = UDim2.fromOffset(10, 26)
	scoreLabel.BackgroundTransparency = 1
	scoreLabel.Text = ""
	scoreLabel.Font = Enum.Font.GothamMedium
	scoreLabel.TextSize = 13
	scoreLabel.TextColor3 = theme.TextMuted or theme.Text
	scoreLabel.TextXAlignment = Enum.TextXAlignment.Left
	scoreLabel.Parent = container

	-- Track: the horizontal path the piece slides along, with a highlighted
	-- "slot" band at its centre marking the good-drop zone.
	track = Instance.new("Frame")
	track.Name = "Track"
	track.Size = UDim2.fromOffset(TRACK_W, TRACK_H)
	track.Position = UDim2.fromOffset(10, 52)
	track.BackgroundColor3 = theme.Neutral
	track.BorderSizePixel = 0
	track.Parent = container
	corner(track, 10)
	local trackStroke = Instance.new("UIStroke")
	trackStroke.Color = theme.Line
	trackStroke.Thickness = 1
	trackStroke.Transparency = 0.3
	trackStroke.Parent = track

	local slotWidth = TOLERANCE * 2 * TRACK_W
	slotMarker = Instance.new("Frame")
	slotMarker.Name = "Slot"
	slotMarker.Size = UDim2.new(0, slotWidth, 1, 0)
	slotMarker.Position = UDim2.new(0.5, -slotWidth / 2, 0, 0)
	slotMarker.BackgroundColor3 = theme.Accent
	slotMarker.BackgroundTransparency = 0.75
	slotMarker.BorderSizePixel = 0
	slotMarker.ZIndex = 1
	slotMarker.Parent = track
	corner(slotMarker, 8)

	piece = Instance.new("TextButton")
	piece.Name = "Piece"
	piece.Size = UDim2.fromOffset(PIECE_SIZE, PIECE_SIZE)
	piece.Position = UDim2.fromOffset(0, (TRACK_H - PIECE_SIZE) / 2)
	piece.BackgroundColor3 = theme.Gold
	piece.Text = ""
	piece.AutoButtonColor = false
	piece.BorderSizePixel = 0
	piece.Active = false
	piece.ZIndex = 2
	piece.Parent = track
	corner(piece, 8)
	local pieceStroke = Instance.new("UIStroke")
	pieceStroke.Color = Color3.fromRGB(255, 255, 255)
	pieceStroke.Thickness = 1.5
	pieceStroke.Transparency = 0.5
	pieceStroke.Parent = piece
	piece.MouseButton1Click:Connect(onDropTapped)

	dropButton = Instance.new("TextButton")
	dropButton.Name = "DropButton"
	dropButton.Size = UDim2.new(1, -20, 0, 52)
	dropButton.Position = UDim2.fromOffset(10, 140)
	dropButton.BackgroundColor3 = theme.Neutral
	dropButton.Text = "DROP"
	dropButton.Font = Enum.Font.FredokaOne
	dropButton.TextSize = 20
	dropButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	dropButton.AutoButtonColor = false
	dropButton.BorderSizePixel = 0
	dropButton.Active = false
	dropButton.Parent = container
	corner(dropButton, 12)
	dropButton.MouseButton1Click:Connect(onDropTapped)
end

function TileDrop.startRound(difficulty, params, roundInfo)
	totalPieces = (roundInfo and (roundInfo.total or roundInfo.pieces)) or (params and params.pieces) or 1
	fallSeconds = (roundInfo and roundInfo.fallSeconds) or (params and params.fallSeconds) or 2
	pieceIndex = 0
	goodDrops = 0
	roundDone = false
	pieceJudged = true -- nothing in flight until runPiece starts the first one
	container.Visible = true

	local token = {}
	activeToken = token

	scoreLabel.Text = ("Good drops: 0/%d"):format(totalPieces)
	setControlsEnabled(false)

	runPiece(token)
end

function TileDrop.hide()
	activeToken = nil
	roundDone = true
	pieceJudged = true
	setControlsEnabled(false)
	if container then
		container.Visible = false
	end
end

return TileDrop

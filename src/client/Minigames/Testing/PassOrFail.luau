-- The "pass or fail" mini-game: a rapid-fire QA triage. One feature/bug
-- statement is shown at a time; the player taps SHIP (ships fine) or CUT
-- (should be cut) before it auto-advances after `flashSeconds`. This is a
-- "sequence" variant: it owns no remotes and no round logic -- it just
-- builds UI, runs its own per-item advance timer, and calls the injected
-- `report` callback once per round with how many items were judged
-- correctly. The framework controller supplies `report`, decides round
-- timing/content (via params/roundInfo), and owns the server round (which
-- independently generates the same items + truth array).
local PassOrFail = { id = "PassOrFail", station = "Testing", inputKind = "sequence" }

local container
local hintLabel
local progressLabel
local featureLabel
local shipButton
local cutButton
local reportFn

-- Round token: startRound captures a fresh token into activeToken; the
-- per-item advance timer (task.delay) and the button callbacks compare
-- against it so a stale round (after hide() or a new startRound) can't keep
-- firing into the new round. Mirrors KeyCombo's activeToken pattern.
local activeToken = nil
local items = {}
local truth = {}
local total = 0
local flashSeconds = 1.5
local answers = {} -- index -> true/false (ship/cut), nil if never answered
local currentIndex = 0
local roundDone = false

local function corner(inst, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
	return c
end

-- Scores the round item-by-item (an unanswered item never matches truth,
-- since answers[i] is nil) and reports it. Guarded so it only ever fires
-- once per round, whether triggered by the last item's advance or by a tap
-- on the final item.
local function finalize(token)
	if activeToken ~= token or roundDone then
		return
	end
	roundDone = true
	local correct = 0
	for i = 1, total do
		if answers[i] ~= nil and answers[i] == truth[i] then
			correct += 1
		end
	end
	reportFn(correct)
end

local function showItem(token, index)
	if activeToken ~= token or roundDone then
		return
	end
	currentIndex = index
	featureLabel.Text = items[index] or ""
	progressLabel.Text = string.format("%d / %d", index, total)

	task.delay(flashSeconds, function()
		if activeToken ~= token or roundDone then
			return
		end
		-- If a tap already advanced past this item (currentIndex changed),
		-- this stale timer must not advance a second time.
		if currentIndex ~= index then
			return
		end
		if index >= total then
			finalize(token)
		else
			showItem(token, index + 1)
		end
	end)
end

local function answerCurrent(shipIt)
	local token = activeToken
	if not token or roundDone then
		return
	end
	local index = currentIndex
	if index < 1 or index > total then
		return
	end
	answers[index] = shipIt
	if index >= total then
		finalize(token)
	else
		showItem(token, index + 1)
	end
end

function PassOrFail.init(parent, theme, report)
	reportFn = report

	container = Instance.new("Frame")
	container.Name = "PassOrFail"
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundTransparency = 1
	container.Visible = false
	container.Parent = parent

	hintLabel = Instance.new("TextLabel")
	hintLabel.Name = "Hint"
	hintLabel.Size = UDim2.new(1, -24, 0, 22)
	hintLabel.Position = UDim2.fromOffset(12, 8)
	hintLabel.BackgroundTransparency = 1
	hintLabel.Text = "SHIP IT OR CUT IT?"
	hintLabel.Font = Enum.Font.FredokaOne
	hintLabel.TextSize = 16
	hintLabel.TextColor3 = theme.Text
	hintLabel.TextXAlignment = Enum.TextXAlignment.Left
	hintLabel.Parent = container

	progressLabel = Instance.new("TextLabel")
	progressLabel.Name = "Progress"
	progressLabel.Size = UDim2.new(1, -24, 0, 18)
	progressLabel.Position = UDim2.fromOffset(12, 8)
	progressLabel.BackgroundTransparency = 1
	progressLabel.Text = ""
	progressLabel.Font = Enum.Font.GothamMedium
	progressLabel.TextSize = 13
	progressLabel.TextColor3 = theme.TextMuted
	progressLabel.TextXAlignment = Enum.TextXAlignment.Right
	progressLabel.Parent = container

	-- Big feature/bug statement, centered, wraps for longer QA statements.
	featureLabel = Instance.new("TextLabel")
	featureLabel.Name = "Feature"
	featureLabel.Size = UDim2.new(1, -24, 0, 130)
	featureLabel.Position = UDim2.fromOffset(12, 40)
	featureLabel.BackgroundColor3 = theme.PanelLight or theme.Neutral
	featureLabel.BorderSizePixel = 0
	featureLabel.Text = ""
	featureLabel.Font = Enum.Font.GothamBold
	featureLabel.TextSize = 22
	featureLabel.TextWrapped = true
	featureLabel.TextColor3 = theme.Text
	featureLabel.TextXAlignment = Enum.TextXAlignment.Center
	featureLabel.TextYAlignment = Enum.TextYAlignment.Center
	featureLabel.Parent = container
	corner(featureLabel, 12)
	local featureStroke = Instance.new("UIStroke")
	featureStroke.Color = theme.Line or theme.Accent
	featureStroke.Thickness = 1
	featureStroke.Transparency = 0.3
	featureStroke.Parent = featureLabel

	-- Two big tap-only buttons, each well over the 44px minimum, filling the
	-- row width so they're easy to hit on mobile.
	shipButton = Instance.new("TextButton")
	shipButton.Name = "Ship"
	shipButton.Size = UDim2.new(0.5, -18, 0, 70)
	shipButton.Position = UDim2.new(0, 12, 0, 180)
	shipButton.BackgroundColor3 = theme.Success
	shipButton.Text = "\u{2705} SHIP"
	shipButton.Font = Enum.Font.FredokaOne
	shipButton.TextSize = 24
	shipButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	shipButton.AutoButtonColor = false
	shipButton.BorderSizePixel = 0
	shipButton.Parent = container
	corner(shipButton, 14)

	cutButton = Instance.new("TextButton")
	cutButton.Name = "Cut"
	cutButton.Size = UDim2.new(0.5, -18, 0, 70)
	cutButton.Position = UDim2.new(0.5, 6, 0, 180)
	cutButton.BackgroundColor3 = theme.Danger
	cutButton.Text = "\u{274C} CUT"
	cutButton.Font = Enum.Font.FredokaOne
	cutButton.TextSize = 24
	cutButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	cutButton.AutoButtonColor = false
	cutButton.BorderSizePixel = 0
	cutButton.Parent = container
	corner(cutButton, 14)

	shipButton.MouseButton1Click:Connect(function()
		answerCurrent(true)
	end)
	cutButton.MouseButton1Click:Connect(function()
		answerCurrent(false)
	end)
end

function PassOrFail.startRound(difficulty, params, roundInfo)
	items = (roundInfo and roundInfo.items) or {}
	truth = (roundInfo and roundInfo.truth) or {}
	total = (roundInfo and roundInfo.total) or #items
	flashSeconds = (roundInfo and roundInfo.flashSeconds) or (params and params.flashSeconds) or 1.5
	answers = {}
	currentIndex = 0
	roundDone = false
	container.Visible = true

	local token = {}
	activeToken = token

	if total > 0 then
		showItem(token, 1)
	else
		finalize(token)
	end
end

function PassOrFail.hide()
	activeToken = nil
	roundDone = true
	if container then
		container.Visible = false
	end
end

return PassOrFail

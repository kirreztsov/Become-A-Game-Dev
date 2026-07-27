-- The "bug squash" mini-game: a mash variant where 🐛 bugs pop up at random
-- spots inside the panel and the player taps them before they scurry off.
-- Like CodeSprint, this module owns no remotes and no round logic -- it just
-- builds UI, runs its own spawn loop, and calls the injected `report`
-- callback on every squash. The framework controller supplies `report`,
-- decides round timing/targets (via params), and owns the server round.
local BugSquash = { id = "BugSquash", station = "Coding", inputKind = "mash" }

local container
local panel
local reportFn
local currentTheme

-- Round token: startRound captures a fresh token into activeToken; the spawn
-- loop and any pending bug-button callbacks compare against it so a stale
-- round (after hide() or a new startRound) can't keep spawning or scoring.
local activeToken = nil
local bugs = {} -- live TextButton instances, so clear()/hide() can wipe them

local PANEL_PAD = 16
local BUG_SIZE = 48
local BUG_LIFETIME = 1.5

local BG = Color3.fromRGB(24, 26, 33)
local BAR_BG = Color3.fromRGB(38, 41, 52)
local TXT = Color3.fromRGB(210, 216, 230)

local function corner(inst, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
	return c
end

local function clearBugs()
	for _, bug in ipairs(bugs) do
		if bug.Parent then
			bug:Destroy()
		end
	end
	bugs = {}
end

local function spawnBug(token, theme)
	if activeToken ~= token or not panel then
		return
	end

	local absSize = panel.AbsoluteSize
	local maxX = math.max(absSize.X - PANEL_PAD * 2 - BUG_SIZE, 0)
	local maxY = math.max(absSize.Y - PANEL_PAD * 2 - BUG_SIZE, 0)
	local x = PANEL_PAD + math.random() * maxX
	local y = PANEL_PAD + math.random() * maxY

	local bug = Instance.new("TextButton")
	bug.Name = "Bug"
	bug.Size = UDim2.fromOffset(BUG_SIZE, BUG_SIZE)
	bug.Position = UDim2.fromOffset(x, y)
	bug.BackgroundColor3 = BAR_BG
	bug.Text = "\240\159\144\155" -- bug emoji
	bug.Font = Enum.Font.SourceSansBold
	bug.TextSize = 28
	bug.AutoButtonColor = false
	bug.BorderSizePixel = 0
	bug.ZIndex = 3
	bug.Parent = panel
	corner(bug, BUG_SIZE / 2)
	local stroke = Instance.new("UIStroke")
	stroke.Color = theme.Accent
	stroke.Thickness = 1.5
	stroke.Transparency = 0.35
	stroke.Parent = bug

	table.insert(bugs, bug)

	local function remove()
		for i, b in ipairs(bugs) do
			if b == bug then
				table.remove(bugs, i)
				break
			end
		end
		if bug.Parent then
			bug:Destroy()
		end
	end

	bug.MouseButton1Click:Connect(function()
		if activeToken ~= token or not bug.Parent then
			return
		end
		remove()
		reportFn()
	end)

	task.delay(BUG_LIFETIME, function()
		if activeToken == token and bug.Parent then
			remove()
		end
	end)
end

function BugSquash.init(parent, theme, report)
	reportFn = report
	currentTheme = theme

	container = Instance.new("Frame")
	container.Name = "BugSquash"
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundTransparency = 1
	container.Visible = false
	container.Parent = parent

	-- Panel fills the whole station panel, styled like a little IDE surface
	-- so bugs read as "in the code" rather than floating on nothing.
	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = BG
	panel.BorderSizePixel = 0
	panel.ClipsDescendants = true
	panel.Parent = container
	corner(panel, 16)
	local edgeStroke = Instance.new("UIStroke")
	edgeStroke.Color = theme.Accent
	edgeStroke.Thickness = 1.5
	edgeStroke.Transparency = 0.35
	edgeStroke.Parent = panel

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.Size = UDim2.new(1, -20, 0, 24)
	hint.Position = UDim2.fromOffset(10, 8)
	hint.BackgroundTransparency = 1
	hint.Text = "SQUASH THE BUGS!"
	hint.Font = Enum.Font.FredokaOne
	hint.TextSize = 18
	hint.TextColor3 = TXT
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Parent = panel
end

function BugSquash.startRound(difficulty, params, roundInfo)
	clearBugs()
	container.Visible = true

	local token = {}
	activeToken = token

	local theme = currentTheme
	local windowSeconds = (params and params.windowSeconds) or 4
	local spawnInterval = (params and params.spawnInterval) or 0.5

	task.spawn(function()
		local elapsed = 0
		while activeToken == token and elapsed < windowSeconds do
			spawnBug(token, theme)
			task.wait(spawnInterval)
			elapsed += spawnInterval
		end
	end)
end

function BugSquash.hide()
	activeToken = nil
	clearBugs()
	if container then
		container.Visible = false
	end
end

return BugSquash

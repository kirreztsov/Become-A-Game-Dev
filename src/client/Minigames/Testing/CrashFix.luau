-- The "crash fix" mini-game: a mash variant where small red "⚠ CRASH" popup
-- cards spawn at random spots inside the panel and the player taps them to
-- dismiss them, like closing crash dialogs before they pile up. Structurally
-- identical to BugSquash (Coding) -- it owns no remotes and no round logic,
-- just UI + its own spawn loop, calling the injected `report` callback on
-- every dismiss. The framework controller supplies `report`, decides round
-- timing/targets (via params), and owns the server round.
local CrashFix = { id = "CrashFix", station = "Testing", inputKind = "mash" }

local container
local panel
local reportFn
local currentTheme

-- Round token: startRound captures a fresh token into activeToken; the spawn
-- loop and any pending crash-card callbacks compare against it so a stale
-- round (after hide() or a new startRound) can't keep spawning or scoring.
-- A lingering (uncaught) crash card that's tapped after the round ends must
-- NOT call reportFn() -- this token check is exactly what guards that.
local activeToken = nil
local crashes = {} -- live TextButton instances, so clear()/hide() can wipe them

local PANEL_PAD = 16
local CARD_W = 128
local CARD_H = 52

local BG = Color3.fromRGB(24, 26, 33)
local TXT = Color3.fromRGB(210, 216, 230)

local function corner(inst, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
	return c
end

local function clearCrashes()
	for _, card in ipairs(crashes) do
		if card.Parent then
			card:Destroy()
		end
	end
	crashes = {}
end

local function spawnCrash(token, theme)
	if activeToken ~= token or not panel then
		return
	end

	local absSize = panel.AbsoluteSize
	local maxX = math.max(absSize.X - PANEL_PAD * 2 - CARD_W, 0)
	local maxY = math.max(absSize.Y - PANEL_PAD * 2 - CARD_H, 0)
	local x = PANEL_PAD + math.random() * maxX
	local y = PANEL_PAD + math.random() * maxY

	local card = Instance.new("TextButton")
	card.Name = "Crash"
	card.Size = UDim2.fromOffset(CARD_W, CARD_H)
	card.Position = UDim2.fromOffset(x, y)
	card.BackgroundColor3 = theme.Danger
	card.Text = "\u{26A0} CRASH   \u{2715}"
	card.Font = Enum.Font.FredokaOne
	card.TextSize = 16
	card.TextColor3 = Color3.fromRGB(255, 255, 255)
	card.AutoButtonColor = false
	card.BorderSizePixel = 0
	card.ZIndex = 3
	card.Parent = panel
	corner(card, 10)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Thickness = 1.5
	stroke.Transparency = 0.5
	stroke.Parent = card

	table.insert(crashes, card)

	local function remove()
		for i, c in ipairs(crashes) do
			if c == card then
				table.remove(crashes, i)
				break
			end
		end
		if card.Parent then
			card:Destroy()
		end
	end

	card.MouseButton1Click:Connect(function()
		if activeToken ~= token or not card.Parent then
			return
		end
		remove()
		reportFn()
	end)
end

function CrashFix.init(parent, theme, report)
	reportFn = report
	currentTheme = theme

	container = Instance.new("Frame")
	container.Name = "CrashFix"
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundTransparency = 1
	container.Visible = false
	container.Parent = parent

	-- Panel fills the whole station panel, styled like a little crash-log
	-- surface so crash cards read as "in the app" rather than floating free.
	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = BG
	panel.BorderSizePixel = 0
	panel.ClipsDescendants = true
	panel.Parent = container
	corner(panel, 16)
	local edgeStroke = Instance.new("UIStroke")
	edgeStroke.Color = theme.Danger
	edgeStroke.Thickness = 1.5
	edgeStroke.Transparency = 0.35
	edgeStroke.Parent = panel

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.Size = UDim2.new(1, -20, 0, 24)
	hint.Position = UDim2.fromOffset(10, 8)
	hint.BackgroundTransparency = 1
	hint.Text = "DISMISS THE CRASHES!"
	hint.Font = Enum.Font.FredokaOne
	hint.TextSize = 18
	hint.TextColor3 = TXT
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Parent = panel
end

function CrashFix.startRound(difficulty, params, roundInfo)
	clearCrashes()
	container.Visible = true

	local token = {}
	activeToken = token

	local theme = currentTheme
	local windowSeconds = (params and params.windowSeconds) or 5
	local spawnInterval = (params and params.spawnInterval) or 0.6

	task.spawn(function()
		local elapsed = 0
		while activeToken == token and elapsed < windowSeconds do
			spawnCrash(token, theme)
			task.wait(spawnInterval)
			elapsed += spawnInterval
		end
	end)
end

function CrashFix.hide()
	activeToken = nil
	clearCrashes()
	if container then
		container.Visible = false
	end
end

return CrashFix

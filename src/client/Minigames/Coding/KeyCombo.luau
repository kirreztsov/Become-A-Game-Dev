-- The "key combo" mini-game: a sequence variant where the player is shown a
-- short combo of glyphs (arrows/braces/etc), the combo disappears, then a
-- keypad of the 8 possible glyphs appears and the player taps them back in
-- order from memory. Like CodeSprint/BugSquash, this module owns no remotes
-- and no round logic -- it just builds UI, runs its own peek/input timers,
-- and calls the injected `report` callback once per round with how many
-- taps landed in the right position. The framework controller supplies
-- `report`, decides round timing/targets (via params), and owns the server
-- round (which independently generates the same glyph sequence).
local KeyCombo = { id = "KeyCombo", station = "Coding", inputKind = "sequence" }

local container
local panel
local hintLabel
local promptRow
local keypad
local glyphButtons = {} -- glyph string -> TextButton
local reportFn

-- Round token: startRound captures a fresh token into activeToken; the peek
-- and input timers (task.delay) and the keypad button callbacks compare
-- against it so a stale round (after hide() or a new startRound) can't keep
-- firing into the new round.
local activeToken = nil
local currentKeys = {}
local entered = {}
local roundDone = false

-- Must match the glyph set the server's generateRoundInfo("KeyCombo", ...)
-- branch draws from -- the client keypad and server-authoritative sequence
-- have to agree on the same alphabet.
local GLYPHS = { "↑", "↓", "←", "→", "{", "}", ";", "(" }

local BG = Color3.fromRGB(24, 26, 33)
local BAR_BG = Color3.fromRGB(38, 41, 52)
local KEY_BG = Color3.fromRGB(48, 52, 66)
local TXT = Color3.fromRGB(210, 216, 230)

local function corner(inst, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
	return c
end

local function setKeypadEnabled(enabled)
	for _, btn in pairs(glyphButtons) do
		btn.Active = enabled
		btn.BackgroundColor3 = enabled and KEY_BG or BAR_BG
		btn.TextTransparency = enabled and 0 or 0.55
	end
end

local function clearPromptRow()
	for _, child in ipairs(promptRow:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
end

-- Scores the round position-wise (tap i counts only if it matches keys[i])
-- and reports it. Guarded so it only ever fires once per round, whether
-- triggered by the last keypad tap or by the input timer expiring.
local function finalize(token)
	if activeToken ~= token or roundDone then
		return
	end
	roundDone = true
	setKeypadEnabled(false)
	local correct = 0
	for i, k in ipairs(currentKeys) do
		if entered[i] == k then
			correct += 1
		end
	end
	reportFn(correct)
end

function KeyCombo.init(parent, theme, report)
	reportFn = report

	container = Instance.new("Frame")
	container.Name = "KeyCombo"
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundTransparency = 1
	container.Visible = false
	container.Parent = parent

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = BG
	panel.BorderSizePixel = 0
	panel.Parent = container
	corner(panel, 16)
	local edgeStroke = Instance.new("UIStroke")
	edgeStroke.Color = theme.Accent
	edgeStroke.Thickness = 1.5
	edgeStroke.Transparency = 0.35
	edgeStroke.Parent = panel

	hintLabel = Instance.new("TextLabel")
	hintLabel.Name = "Hint"
	hintLabel.Size = UDim2.new(1, -20, 0, 24)
	hintLabel.Position = UDim2.fromOffset(10, 8)
	hintLabel.BackgroundTransparency = 1
	hintLabel.Text = "WATCH THE COMBO!"
	hintLabel.Font = Enum.Font.FredokaOne
	hintLabel.TextSize = 18
	hintLabel.TextColor3 = TXT
	hintLabel.TextXAlignment = Enum.TextXAlignment.Left
	hintLabel.Parent = panel

	-- Prompt row: shows the sequence big, only during the "watch" phase.
	promptRow = Instance.new("Frame")
	promptRow.Name = "PromptRow"
	promptRow.Size = UDim2.new(1, -20, 0, 56)
	promptRow.Position = UDim2.fromOffset(10, 40)
	promptRow.BackgroundColor3 = BAR_BG
	promptRow.BorderSizePixel = 0
	promptRow.Parent = panel
	corner(promptRow, 10)
	local promptLayout = Instance.new("UIListLayout")
	promptLayout.FillDirection = Enum.FillDirection.Horizontal
	promptLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	promptLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	promptLayout.Padding = UDim.new(0, 6)
	promptLayout.Parent = promptRow

	-- Keypad: grid of the 8 glyph buttons, each >=44px, tap-only (no
	-- physical keyboard input is read anywhere in this module).
	keypad = Instance.new("Frame")
	keypad.Name = "Keypad"
	keypad.Size = UDim2.new(1, -20, 1, -106)
	keypad.Position = UDim2.fromOffset(10, 100)
	keypad.BackgroundTransparency = 1
	keypad.Parent = panel
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.25, -8, 0.5, -8)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = keypad

	for i, g in ipairs(GLYPHS) do
		local btn = Instance.new("TextButton")
		btn.Name = "Key_" .. i
		btn.LayoutOrder = i
		btn.BackgroundColor3 = KEY_BG
		btn.Text = g
		btn.Font = Enum.Font.Code
		btn.TextSize = 28
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.AutoButtonColor = false
		btn.BorderSizePixel = 0
		btn.Parent = keypad
		corner(btn, 10)
		local keyStroke = Instance.new("UIStroke")
		keyStroke.Color = theme.Accent
		keyStroke.Thickness = 1
		keyStroke.Transparency = 0.5
		keyStroke.Parent = btn

		btn.MouseButton1Click:Connect(function()
			local token = activeToken
			if not token or roundDone or not btn.Active then
				return
			end
			table.insert(entered, g)
			if #entered >= #currentKeys then
				finalize(token)
			end
		end)

		glyphButtons[g] = btn
	end
end

function KeyCombo.startRound(difficulty, params, roundInfo)
	currentKeys = (roundInfo and roundInfo.keys) or {}
	entered = {}
	roundDone = false
	container.Visible = true

	local token = {}
	activeToken = token

	clearPromptRow()
	for i, k in ipairs(currentKeys) do
		local lbl = Instance.new("TextLabel")
		lbl.Name = "Glyph_" .. i
		lbl.LayoutOrder = i
		lbl.Size = UDim2.fromOffset(36, 36)
		lbl.BackgroundTransparency = 1
		lbl.Text = k
		lbl.Font = Enum.Font.Code
		lbl.TextSize = 26
		lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
		lbl.Parent = promptRow
	end

	promptRow.Visible = true
	hintLabel.Text = "WATCH THE COMBO!"
	setKeypadEnabled(false)

	local peekSeconds = (params and params.peekSeconds) or 2
	local inputSeconds = (params and params.inputSeconds) or 5

	task.delay(peekSeconds, function()
		if activeToken ~= token then
			return
		end
		promptRow.Visible = false
		hintLabel.Text = "REPEAT THE COMBO!"
		setKeypadEnabled(true)

		task.delay(inputSeconds, function()
			finalize(token)
		end)
	end)
end

function KeyCombo.hide()
	activeToken = nil
	roundDone = true
	entered = {}
	setKeypadEnabled(false)
	if promptRow then
		promptRow.Visible = false
	end
	if container then
		container.Visible = false
	end
end

return KeyCombo

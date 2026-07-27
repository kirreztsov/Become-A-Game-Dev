local Remotes = require(game.ReplicatedStorage.Shared.Remotes)

-- The "coding" mini-game screen, styled as a little code editor that fills the
-- whole station panel: a dark IDE with a title bar (traffic-light dots +
-- filename + a live line count), syntax-coloured code, and a big WRITE CODE
-- key along the bottom. Tapping the key still just fires ReportTap (the server
-- owns the round) -- only the presentation changed.
local CodingGame = {}

local container
local counterLabel
local tapButton
local tapCount = 0
local roundActive = false

local EDITOR_BG = Color3.fromRGB(24, 26, 33)
local BAR_BG = Color3.fromRGB(38, 41, 52)
local GUTTER = Color3.fromRGB(120, 128, 148)
local KW = Color3.fromRGB(198, 134, 192) -- keyword (purple)
local FN = Color3.fromRGB(97, 175, 239) -- function (blue)
local STR = Color3.fromRGB(152, 195, 121) -- string (green)
local TXT = Color3.fromRGB(210, 216, 230) -- plain code

-- Fake source lines (indent, {color, text} spans) for editor flavor.
local CODE = {
	{ 0, { { KW, "local" }, { TXT, " game = " }, { TXT, "{}" } } },
	{ 0, { { KW, "function" }, { FN, " game.start" }, { TXT, "()" } } },
	{ 1, { { FN, "spawnPlayers" }, { TXT, "()" } } },
	{ 1, { { FN, "loadMap" }, { TXT, "(" }, { STR, "\"lobby\"" }, { TXT, ")" } } },
	{ 1, { { KW, "return" }, { STR, " \"shipped!\"" } } },
	{ 0, { { KW, "end" } } },
}

local function corner(inst, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
	return c
end

function CodingGame.init(parent, theme)
	container = Instance.new("Frame")
	container.Name = "CodingGame"
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundTransparency = 1
	container.Visible = false
	container.Parent = parent

	-- Editor panel fills the whole station panel.
	local editor = Instance.new("Frame")
	editor.Name = "Editor"
	editor.Size = UDim2.fromScale(1, 1)
	editor.BackgroundColor3 = EDITOR_BG
	editor.BorderSizePixel = 0
	editor.Parent = container
	corner(editor, 16)
	local stroke = Instance.new("UIStroke")
	stroke.Color = theme.Accent
	stroke.Thickness = 1.5
	stroke.Transparency = 0.35
	stroke.Parent = editor

	-- Title bar with traffic-light dots + filename + live line count.
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, 0, 0, 26)
	bar.BackgroundColor3 = BAR_BG
	bar.BorderSizePixel = 0
	bar.Parent = editor
	corner(bar, 16)
	local barFix = Instance.new("Frame") -- square off the bottom corners
	barFix.Size = UDim2.new(1, 0, 0, 13)
	barFix.Position = UDim2.new(0, 0, 1, -13)
	barFix.BackgroundColor3 = BAR_BG
	barFix.BorderSizePixel = 0
	barFix.Parent = bar
	for i, col in ipairs({ Color3.fromRGB(237, 106, 94), Color3.fromRGB(245, 191, 79), Color3.fromRGB(98, 197, 84) }) do
		local dot = Instance.new("Frame")
		dot.Size = UDim2.fromOffset(9, 9)
		dot.Position = UDim2.fromOffset(10 + (i - 1) * 15, 9)
		dot.BackgroundColor3 = col
		dot.BorderSizePixel = 0
		dot.ZIndex = 2
		dot.Parent = bar
		corner(dot, 5)
	end
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 1, 0)
	title.BackgroundTransparency = 1
	title.Text = "main.lua"
	title.Font = Enum.Font.Code
	title.TextSize = 13
	title.TextColor3 = GUTTER
	title.Parent = bar

	-- Live line count, right-aligned in the title bar.
	counterLabel = Instance.new("TextLabel")
	counterLabel.Size = UDim2.new(0, 96, 1, 0)
	counterLabel.Position = UDim2.new(1, -104, 0, 0)
	counterLabel.BackgroundTransparency = 1
	counterLabel.Text = "0 lines"
	counterLabel.Font = Enum.Font.Code
	counterLabel.TextSize = 13
	counterLabel.TextXAlignment = Enum.TextXAlignment.Right
	counterLabel.TextColor3 = STR
	counterLabel.Parent = bar

	-- Code lines.
	local code = Instance.new("Frame")
	code.Size = UDim2.new(1, -20, 1, -78)
	code.Position = UDim2.fromOffset(10, 32)
	code.BackgroundTransparency = 1
	code.Parent = editor
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 1)
	layout.Parent = code

	for i, line in ipairs(CODE) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 16)
		row.BackgroundTransparency = 1
		row.LayoutOrder = i
		row.Parent = code
		local num = Instance.new("TextLabel")
		num.Size = UDim2.fromOffset(18, 16)
		num.BackgroundTransparency = 1
		num.Text = tostring(i)
		num.Font = Enum.Font.Code
		num.TextSize = 12
		num.TextXAlignment = Enum.TextXAlignment.Right
		num.TextColor3 = GUTTER
		num.Parent = row
		local x = 26 + line[1] * 16
		for _, span in ipairs(line[2]) do
			local t = Instance.new("TextLabel")
			t.AutomaticSize = Enum.AutomaticSize.X
			t.Size = UDim2.new(0, 0, 0, 16)
			t.Position = UDim2.fromOffset(x, 0)
			t.BackgroundTransparency = 1
			t.Text = span[2]
			t.Font = Enum.Font.Code
			t.TextSize = 13
			t.TextXAlignment = Enum.TextXAlignment.Left
			t.TextColor3 = span[1]
			t.Parent = row
			x += #span[2] * 7
		end
	end

	-- The WRITE CODE key: a footer bar along the bottom of the editor.
	tapButton = Instance.new("TextButton")
	tapButton.Name = "TapButton"
	tapButton.AnchorPoint = Vector2.new(0.5, 1)
	tapButton.Position = UDim2.new(0.5, 0, 1, -8)
	tapButton.Size = UDim2.new(1, -20, 0, 34)
	tapButton.BackgroundColor3 = theme.Accent
	tapButton.Text = "\226\140\168\239\184\143  WRITE CODE"
	tapButton.Font = Enum.Font.FredokaOne
	tapButton.TextSize = 18
	tapButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	tapButton.AutoButtonColor = false
	tapButton.BorderSizePixel = 0
	tapButton.Parent = editor
	corner(tapButton, 10)
	local btnStroke = Instance.new("UIStroke")
	btnStroke.Color = Color3.fromRGB(255, 255, 255)
	btnStroke.Thickness = 1.5
	btnStroke.Transparency = 0.7
	btnStroke.Parent = tapButton

	tapButton.MouseButton1Click:Connect(function()
		if not roundActive then
			return
		end
		tapCount += 1
		counterLabel.Text = tapCount == 1 and "1 line" or ("%d lines"):format(tapCount)
		-- Quick press feedback (manual, TweenService is unreliable here).
		tapButton.Size = UDim2.new(1, -28, 0, 31)
		task.delay(0.06, function()
			if tapButton and tapButton.Parent then
				tapButton.Size = UDim2.new(1, -20, 0, 34)
			end
		end)
		Remotes.ReportTap:FireServer()
	end)
end

function CodingGame.startRound()
	tapCount = 0
	roundActive = true
	if counterLabel then
		counterLabel.Text = "0 lines"
	end
	container.Visible = true
end

function CodingGame.hide()
	roundActive = false
	if container then
		container.Visible = false
	end
end

return CodingGame

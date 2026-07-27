-- The "coding" mini-game screen where three code lines are shown and only
-- one of them actually compiles/runs -- the player taps the one they think
-- is correct. This is a "variant" implementation: it owns no remotes and no
-- round logic -- it just builds UI and calls the injected `report` callback
-- on every tap. The framework controller supplies `report`, decides round
-- content (via `roundInfo`), and owns the server round.
local CompileCheck = { id = "CompileCheck", station = "Coding", inputKind = "choice" }

local LINE_COUNT = 3

local container
local promptLabel
local lineButtons = {}
local reportFn
local answered = false

local function corner(inst, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
	return c
end

function CompileCheck.init(parent, theme, report)
	reportFn = report

	container = Instance.new("Frame")
	container.Name = "CompileCheck"
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundTransparency = 1
	container.Visible = false
	container.Parent = parent

	promptLabel = Instance.new("TextLabel")
	promptLabel.Size = UDim2.new(1, -24, 0, 32)
	promptLabel.Position = UDim2.fromOffset(12, 8)
	promptLabel.BackgroundTransparency = 1
	promptLabel.Text = "Which line runs?"
	promptLabel.Font = Enum.Font.GothamMedium
	promptLabel.TextSize = 16
	promptLabel.TextWrapped = true
	promptLabel.TextColor3 = theme.Text
	promptLabel.Parent = container

	for i = 1, LINE_COUNT do
		local button = Instance.new("TextButton")
		button.Name = ("Line%d"):format(i)
		button.Size = UDim2.new(1, -24, 0, 44)
		button.Position = UDim2.fromOffset(12, 48 + (i - 1) * 52)
		button.BackgroundColor3 = theme.Neutral
		button.Text = ""
		button.Font = Enum.Font.Code
		button.TextSize = 15
		button.TextWrapped = true
		button.TextColor3 = theme.Text
		button.AutoButtonColor = false
		button.BorderSizePixel = 0
		button.Parent = container

		corner(button, 10)
		local stroke = Instance.new("UIStroke")
		stroke.Color = theme.Accent
		stroke.Thickness = 1
		stroke.Transparency = 0.55
		stroke.Parent = button

		button.MouseButton1Click:Connect(function()
			if answered then
				return
			end
			answered = true
			reportFn(i)
		end)

		lineButtons[i] = button
	end
end

function CompileCheck.startRound(difficulty, params, roundInfo)
	answered = false

	local lines = roundInfo.lines or {}
	for i, button in ipairs(lineButtons) do
		button.Text = lines[i] or ""
	end

	container.Visible = true
end

function CompileCheck.hide()
	if container then
		container.Visible = false
	end
end

return CompileCheck

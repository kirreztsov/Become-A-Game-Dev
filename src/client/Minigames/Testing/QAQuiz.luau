-- The "testing" mini-game screen: a prompt label plus up to 4 option
-- buttons. This is a "variant" implementation: it owns no remotes and no
-- round logic -- it just builds UI and calls the injected `report` callback
-- on every tap. The framework controller supplies `report`, decides round
-- content (via `roundInfo`), and owns the server round.
local QAQuiz = { id = "QAQuiz", station = "Testing", inputKind = "choice" }

local MAX_OPTIONS = 4

local container
local promptLabel
local optionButtons = {}
local reportFn
local answered = false

function QAQuiz.init(parent, theme, report)
	reportFn = report

	container = Instance.new("Frame")
	container.Name = "QAQuiz"
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundTransparency = 1
	container.Visible = false
	container.Parent = parent

	promptLabel = Instance.new("TextLabel")
	promptLabel.Size = UDim2.new(1, -24, 0, 60)
	promptLabel.Position = UDim2.fromOffset(12, 8)
	promptLabel.BackgroundTransparency = 1
	promptLabel.Text = ""
	promptLabel.Font = Enum.Font.GothamMedium
	promptLabel.TextSize = 15
	promptLabel.TextWrapped = true
	promptLabel.TextColor3 = theme.Text
	promptLabel.Parent = container

	for i = 1, MAX_OPTIONS do
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(1, -24, 0, 36)
		button.Position = UDim2.fromOffset(12, 70 + (i - 1) * 44)
		button.BackgroundColor3 = theme.Neutral
		button.Text = ""
		button.Font = Enum.Font.GothamMedium
		button.TextSize = 14
		button.TextWrapped = true
		button.TextColor3 = theme.Text
		button.AutoButtonColor = false
		button.BorderSizePixel = 0
		button.Visible = false
		button.Parent = container

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = button

		button.MouseButton1Click:Connect(function()
			if answered then
				return
			end
			answered = true
			reportFn(i)
		end)

		optionButtons[i] = button
	end
end

function QAQuiz.startRound(difficulty, params, roundInfo)
	answered = false
	promptLabel.Text = roundInfo.prompt or ""

	local options = roundInfo.options or {}
	for i, button in ipairs(optionButtons) do
		local text = options[i]
		if text then
			button.Text = text
			button.Visible = true
		else
			button.Text = ""
			button.Visible = false
		end
	end

	container.Visible = true
end

function QAQuiz.hide()
	if container then
		container.Visible = false
	end
end

return QAQuiz

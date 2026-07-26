-- Custom loading screen: shown before the game finishes loading, with the
-- game title and credits, then fades out. Manual fade (TweenService is
-- unreliable in this project).
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

ReplicatedFirst:RemoveDefaultLoadingScreen()

local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 1000
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.fromRGB(22, 19, 38)
bg.BorderSizePixel = 0
bg.Parent = gui
local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new(Color3.fromRGB(34, 28, 60), Color3.fromRGB(14, 12, 24))
grad.Rotation = 90
grad.Parent = bg

local function label(text, color, sizeY, posScaleY, textSize, font)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, -80, 0, sizeY)
	l.Position = UDim2.new(0.5, 0, posScaleY, 0)
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = color
	l.Font = font or Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	l.TextStrokeTransparency = 0.6
	l.Parent = bg
	-- Cap the scaled text so big screens don't make it absurdly large.
	local tc = Instance.new("UITextSizeConstraint")
	tc.MaxTextSize = textSize
	tc.Parent = l
	return l
end

local title = label("\240\159\142\174 Become a Game Developer", Color3.fromRGB(255, 255, 255), 88, 0.30, 54)
local made = label("Game made by: Krikis2003", Color3.fromRGB(255, 209, 102), 64, 0.50, 44)
local tested = label("Game tested by: JrRh0t", Color3.fromRGB(180, 150, 255), 54, 0.61, 34)
local loading = label("Loading\226\128\166", Color3.fromRGB(160, 156, 180), 34, 0.80, 22)

-- Animated "Loading..." dots + a minimum display window while the game loads.
local loadingActive = true
task.spawn(function()
	local dots = { "Loading", "Loading.", "Loading..", "Loading..." }
	local i = 0
	while loadingActive do
		i = (i % #dots) + 1
		loading.Text = dots[i]
		task.wait(0.35)
	end
end)

if not game:IsLoaded() then
	game.Loaded:Wait()
end
task.wait(5) -- keep the credits up ~5s even on fast loads
loadingActive = false

-- Manual fade-out.
for step = 1, 22 do
	local a = step / 22
	bg.BackgroundTransparency = a
	grad.Color = ColorSequence.new(Color3.fromRGB(34, 28, 60), Color3.fromRGB(14, 12, 24))
	for _, l in ipairs({ title, made, tested, loading }) do
		l.TextTransparency = a
		l.TextStrokeTransparency = 0.6 + 0.4 * a
	end
	task.wait(0.025)
end
gui:Destroy()

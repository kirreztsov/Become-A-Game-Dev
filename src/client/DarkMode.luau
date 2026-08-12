-- Dark mode toggle: re-skins the white/light UI to a dark palette while keeping
-- the same layout and accent colours (gold coin, purple buttons, red/green).
-- It works by swapping the exact light-theme surface + text colours for dark
-- equivalents wherever they appear, so every panel flips together. Accent
-- colours aren't in the maps, so they're left untouched.
local Players = game:GetService("Players")
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)

local DarkMode = {}

local function C(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local function key(c)
	return ("%d,%d,%d"):format(math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255))
end

-- {light, dark} pairs. Surfaces = panel/card/border/idle-button backgrounds.
local SURFACE_PAIRS = {
	{ C(255, 255, 255), C(32, 30, 50) },
	{ C(248, 249, 252), C(42, 40, 62) },
	{ C(238, 240, 247), C(26, 25, 44) },
	{ C(233, 236, 243), C(52, 50, 74) },
	{ C(219, 223, 233), C(64, 62, 88) },
	{ C(214, 218, 230), C(72, 70, 96) },
}
local TEXT_PAIRS = {
	{ C(30, 33, 48), C(238, 238, 250) },
	{ C(120, 126, 142), C(172, 170, 200) },
}

local surfDark, surfLight, txtDark, txtLight = {}, {}, {}, {}
for _, p in ipairs(SURFACE_PAIRS) do
	surfDark[key(p[1])] = p[2]
	surfLight[key(p[2])] = p[1]
end
for _, p in ipairs(TEXT_PAIRS) do
	txtDark[key(p[1])] = p[2]
	txtLight[key(p[2])] = p[1]
end

local function remapGradient(grad, sMap)
	local changed, new = false, {}
	for _, kp in ipairs(grad.Color.Keypoints) do
		local d = sMap[key(kp.Value)]
		if d then
			new[#new + 1] = ColorSequenceKeypoint.new(kp.Time, d)
			changed = true
		else
			new[#new + 1] = kp
		end
	end
	if changed then
		grad.Color = ColorSequence.new(new)
	end
end

local function applyTo(inst, dark)
	local sMap = dark and surfDark or surfLight
	local tMap = dark and txtDark or txtLight
	if inst:IsA("GuiObject") then
		local d = sMap[key(inst.BackgroundColor3)]
		if d then
			inst.BackgroundColor3 = d
		end
	end
	if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
		local d = tMap[key(inst.TextColor3)]
		if d then
			inst.TextColor3 = d
		end
	end
	if inst:IsA("UIStroke") then
		local d = sMap[key(inst.Color)]
		if d then
			inst.Color = d
		end
	end
	if inst:IsA("UIGradient") then
		remapGradient(inst, sMap)
	end
end

local isDark = false

function DarkMode.init(player, playerState)
	local pg = player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "DarkModeGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 30
	gui.Parent = pg

	local btn = Instance.new("TextButton")
	btn.Name = "DarkModeToggle"
	btn.Size = UDim2.fromOffset(46, 46)
	-- Top RIGHT: the left column is the main button stack, and it grew tall
	-- enough (6 buttons) to collide with toggles parked at the top-left.
	btn.AnchorPoint = Vector2.new(1, 0)
	btn.Position = UDim2.new(1, -16, 0, 16)
	btn.BackgroundColor3 = Color3.fromRGB(120, 90, 235)
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Font = Enum.Font.FredokaOne
	btn.TextSize = 22
	btn.Text = "\240\159\140\153" -- 🌙
	btn.AutoButtonColor = true
	btn.Parent = gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = btn

	local function applyAll(dark)
		for _, inst in ipairs(pg:GetDescendants()) do
			applyTo(inst, dark)
		end
	end

	local function setDark(on, persist)
		isDark = on
		applyAll(on)
		btn.Text = on and "\226\152\128\239\184\143" or "\240\159\140\153" -- ☀️ / 🌙
		if persist then
			if playerState then
				playerState.darkMode = on
			end
			Remotes.SetDarkMode:FireServer(on)
		end
	end

	btn.MouseButton1Click:Connect(function()
		setDark(not isDark, true)
	end)

	-- Keep newly-created UI (panels built on first open, cards, etc.) in sync
	-- while dark mode is on.
	pg.DescendantAdded:Connect(function(inst)
		if isDark then
			task.defer(applyTo, inst, true)
		end
	end)

	-- Load the saved preference: apply dark once, from the first state we get.
	local loaded = false
	Remotes.PlayerStateUpdated.OnClientEvent:Connect(function(data)
		if not loaded then
			loaded = true
			if data.darkMode then
				setDark(true, false)
			end
		end
	end)
	-- Pull our state now that the listener is live (the join push may have
	-- arrived before this script loaded).
	Remotes.RequestInitialState:FireServer()
end

return DarkMode

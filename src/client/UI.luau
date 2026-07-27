local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local GameData = require(game.ReplicatedStorage.Shared.GameData)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)

local UI = {}

local selectedGenre = nil
local selectedTopic = nil
local playerState = {
	cash = 0,
	gamesReleased = 0,
	houseTier = 0,
	pcTier = 0,
	boostUntil = 0,
	boostMult = 1,
	boostIcon = nil,
	boostLabel = nil,
	subscribers = 0,
	roomsOwned = { Arcade = false, Merch = false },
	prestigeLevel = 0,
	workers = {
		Coding = { hired = false, level = 0 },
		MapBuilding = { hired = false, level = 0 },
		Testing = { hired = false, level = 0 },
	},
}

-- Light "clean card" theme (M6): white/near-white surfaces, dark text, a purple
-- accent + gold highlight. Matches the money HUD's white-card look. Panels read
-- these tokens so flipping the palette here reskins most of the UI at once.
local Theme = {
	Panel = Color3.fromRGB(255, 255, 255),
	PanelLight = Color3.fromRGB(248, 249, 252),
	Neutral = Color3.fromRGB(233, 236, 243),
	NeutralHover = Color3.fromRGB(219, 223, 233),
	Accent = Color3.fromRGB(140, 92, 255),
	AccentDeep = Color3.fromRGB(108, 66, 214),
	Gold = Color3.fromRGB(240, 176, 60),
	Success = Color3.fromRGB(38, 168, 110),
	Danger = Color3.fromRGB(222, 78, 98),
	Text = Color3.fromRGB(30, 33, 48),
	TextMuted = Color3.fromRGB(120, 126, 142),
	Line = Color3.fromRGB(214, 218, 230),
}

UI.Theme = Theme

local function addCorner(instance, radius)
	instance.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
	return corner
end

local function addStroke(instance, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency or 0
	stroke.Parent = instance
	return stroke
end

local function addGradient(instance, colorA, colorB, rotation)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(colorA, colorB)
	gradient.Rotation = rotation or 90
	gradient.Parent = instance
	return gradient
end

local function addHoverFeedback(button, baseColor, hoverColor)
	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = hoverColor }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = baseColor }):Play()
	end)
end

local function makeButton(parent, layoutOrder, text, size, textSize)
	local button = Instance.new("TextButton")
	button.Name = text
	button.Text = text
	button.Size = size
	button.LayoutOrder = layoutOrder
	button.BackgroundColor3 = Theme.Neutral
	button.TextColor3 = Theme.Text
	button.Font = Enum.Font.FredokaOne
	button.TextSize = textSize or 18
	button.TextWrapped = true
	button.AutoButtonColor = false
	button.Parent = parent
	addCorner(button, 10)
	addStroke(button, Color3.fromRGB(255, 255, 255), 1, 0.85)
	return button
end

UI.addCorner = addCorner
UI.addStroke = addStroke
UI.addGradient = addGradient
UI.addHoverFeedback = addHoverFeedback
UI.makeButton = makeButton

-- ---- Juice (M6 polish) ----------------------------------------------------
-- Manual easing (TweenService is unreliable in this project). Each animation
-- uses a generation counter so a new one cleanly cancels the last.

-- Springy hover-grow + press-shrink on any button. Applied game-wide so every
-- button feels alive. Safe to call twice (guarded by an attribute).
local function addButtonJuice(btn)
	if btn:GetAttribute("_juiced") then
		return
	end
	btn:SetAttribute("_juiced", true)
	local scale = btn:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = btn
	local gen = 0
	local hovering = false
	local function animateTo(target)
		gen += 1
		local myGen = gen
		local start = scale.Scale
		task.spawn(function()
			for i = 1, 6 do
				if myGen ~= gen or not btn.Parent then
					return
				end
				scale.Scale = start + (target - start) * (i / 6)
				task.wait(0.012)
			end
			if myGen == gen then
				scale.Scale = target
			end
		end)
	end
	btn.MouseEnter:Connect(function()
		hovering = true
		animateTo(1.06)
	end)
	btn.MouseLeave:Connect(function()
		hovering = false
		animateTo(1)
	end)
	btn.MouseButton1Down:Connect(function()
		animateTo(0.93)
	end)
	btn.MouseButton1Up:Connect(function()
		animateTo(hovering and 1.06 or 1)
	end)
end

-- Give every current + future button in a GUI tree the juice above.
local function juiceAllButtons(root)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("TextButton") or d:IsA("ImageButton") then
			addButtonJuice(d)
		end
	end
	root.DescendantAdded:Connect(function(d)
		if d:IsA("TextButton") or d:IsA("ImageButton") then
			addButtonJuice(d)
		end
	end)
end

-- Pop a frame in with a little overshoot when it appears (0.9 -> 1.04 -> 1).
local function popIn(frame)
	local scale = frame:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = frame
	scale.Scale = 0.9
	task.spawn(function()
		local keys = { 0.9, 0.97, 1.02, 1.04, 1.02, 1.0 }
		for _, s in ipairs(keys) do
			if not frame.Parent then
				return
			end
			scale.Scale = s
			task.wait(0.025)
		end
		scale.Scale = 1
	end)
end

-- A soft drop shadow behind a card/panel for depth (a dark rounded frame
-- nudged down-right, sitting just under the panel in its own ZIndex).
local function addShadow(panel, radius, offset)
	local shadow = Instance.new("Frame")
	shadow.Name = "DropShadow"
	shadow.AnchorPoint = panel.AnchorPoint
	shadow.Position = panel.Position + UDim2.fromOffset(0, offset or 5)
	shadow.Size = panel.Size
	shadow.BackgroundColor3 = Color3.fromRGB(20, 22, 34)
	shadow.BackgroundTransparency = 0.72
	shadow.BorderSizePixel = 0
	shadow.ZIndex = panel.ZIndex - 1
	shadow.Parent = panel.Parent
	addCorner(shadow, radius or 16)
	return shadow
end

UI.addButtonJuice = addButtonJuice
UI.popIn = popIn
UI.addShadow = addShadow

-- (Old multi-page "Welcome, Game Dev!" first-time guide removed -- the dynamic
-- onboarding tutorial is being rebuilt as roadmap milestone M2.)

local function makeStationPanel(screenGui, name)
	local panel = Instance.new("Frame")
	panel.Name = name .. "Panel"
	panel.Size = UDim2.fromOffset(420, 300)
	-- Centred so it reads as the open "app window" on the computer desktop.
	-- (No raised ZIndex: the panel is already above the desktop via its
	-- ScreenGui's DisplayOrder, and raising it here hid its own contents.)
	panel.Position = UDim2.fromScale(0.5, 0.54)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.BackgroundColor3 = Theme.Panel
	panel.Visible = false
	panel.Parent = screenGui
	addCorner(panel, 16)
	addStroke(panel, Theme.Line, 1.5, 0)
	addGradient(panel, Theme.PanelLight, Theme.Panel, 90)
	-- Depth + a springy pop-in each time the panel opens.
	local shadow = addShadow(panel, 16, 7)
	shadow.Visible = false
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		shadow.Visible = panel.Visible
		if panel.Visible then
			popIn(panel)
		end
	end)
	return panel
end

function UI.init()
	local player = Players.LocalPlayer
	local MinigameHost = require(script.Parent.Minigames.MinigameHost)
	local WorkersPanel = require(script.Parent.WorkersPanel)
	local HousePanel = require(script.Parent.HousePanel)
	local PCPanel = require(script.Parent.PCPanel)
	local ShopPanel = require(script.Parent.ShopPanel)
	local DecorPanel = require(script.Parent.DecorPanel)
	local DailyRewardPanel = require(script.Parent.DailyRewardPanel)
	local PrestigePanel = require(script.Parent.PrestigePanel)
	local WorkerHub = require(script.Parent.WorkerHub)
	local TutorialGuide = require(script.Parent.TutorialGuide)
	local StorePanel = require(script.Parent.StorePanel)
	local VIPChat = require(script.Parent.VIPChat)
	local Fx = require(script.Parent.Fx)
	local DarkMode = require(script.Parent.DarkMode)
	local MobileScale = require(script.Parent.MobileScale)

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "GameDevTycoonUI"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = player:WaitForChild("PlayerGui")

	-- True while the player is seated at a station: the whole ambient HUD hides
	-- so only the "computer" (desktop + the minigame app window) is on screen.
	local seatedHudHidden = false

	-- ---- Money HUD: a gold "wallet" card ----------------------------------
	-- A coin emblem + a CASH eyebrow + a comma-grouped amount, with a soft
	-- drop shadow, a top sheen, and (on a gain) a spinning coin + a shine
	-- sweep. Kept named "CashPill" so the pop + boost-pill layout still work.
	local CASH_W, CASH_H = 220, 58
	local AMBER_DARK = Color3.fromRGB(150, 100, 30)
	local AMBER_TEXT = Color3.fromRGB(74, 46, 10)

	local cashShadow = Instance.new("Frame")
	cashShadow.Name = "CashShadow"
	cashShadow.Size = UDim2.fromOffset(CASH_W, CASH_H)
	cashShadow.AnchorPoint = Vector2.new(1, 1)
	cashShadow.Position = UDim2.new(1, -15, 1, -15)
	cashShadow.BackgroundColor3 = Color3.fromRGB(18, 12, 4)
	cashShadow.BackgroundTransparency = 0.55
	cashShadow.ZIndex = 1
	cashShadow.Parent = screenGui
	addCorner(cashShadow, 18)

	local cashPill = Instance.new("Frame")
	cashPill.Name = "CashPill"
	cashPill.Size = UDim2.fromOffset(CASH_W, CASH_H)
	cashPill.AnchorPoint = Vector2.new(1, 1)
	cashPill.Position = UDim2.new(1, -20, 1, -20)
	cashPill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	cashPill.ClipsDescendants = true
	cashPill.ZIndex = 2
	cashPill.Parent = screenGui
	addCorner(cashPill, 20)
	addGradient(cashPill, Color3.fromRGB(255, 255, 255), Color3.fromRGB(238, 240, 247), 90)
	addStroke(cashPill, Color3.fromRGB(214, 218, 230), 1.5, 0)
	local cashScale = Instance.new("UIScale")
	cashScale.Parent = cashPill

	local sheen = Instance.new("Frame")
	sheen.Name = "Sheen"
	sheen.Size = UDim2.new(1, -16, 0, 12)
	sheen.Position = UDim2.fromOffset(8, 4)
	sheen.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	sheen.BackgroundTransparency = 0.68
	sheen.ZIndex = 3
	sheen.Parent = cashPill
	addCorner(sheen, 8)

	-- shine bar that sweeps across on a gain (clipped to the card)
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.Size = UDim2.fromOffset(26, 120)
	shine.Position = UDim2.fromOffset(-50, -30)
	shine.Rotation = 18
	shine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	shine.BackgroundTransparency = 0.62
	shine.Visible = false
	shine.ZIndex = 5
	shine.Parent = cashPill

	local coin = Instance.new("Frame")
	coin.Name = "Coin"
	coin.Size = UDim2.fromOffset(40, 40)
	coin.Position = UDim2.fromOffset(9, 9)
	coin.BackgroundColor3 = Color3.fromRGB(255, 214, 110)
	coin.ZIndex = 3
	coin.Parent = cashPill
	addCorner(coin, 20)
	addGradient(coin, Color3.fromRGB(255, 236, 172), Color3.fromRGB(230, 165, 60), 90)
	addStroke(coin, AMBER_DARK, 1.5, 0)
	local coinScale = Instance.new("UIScale")
	coinScale.Parent = coin
	local coinText = Instance.new("TextLabel")
	coinText.Size = UDim2.fromScale(1, 1)
	coinText.BackgroundTransparency = 1
	coinText.Text = "$"
	coinText.Font = Enum.Font.FredokaOne
	coinText.TextScaled = true
	coinText.TextColor3 = Color3.fromRGB(120, 78, 20)
	coinText.ZIndex = 4
	coinText.Parent = coin
	local coinPad = Instance.new("UIPadding")
	coinPad.PaddingTop = UDim.new(0, 6)
	coinPad.PaddingBottom = UDim.new(0, 6)
	coinPad.PaddingLeft = UDim.new(0, 10)
	coinPad.PaddingRight = UDim.new(0, 10)
	coinPad.Parent = coinText

	local eyebrow = Instance.new("TextLabel")
	eyebrow.Name = "Eyebrow"
	eyebrow.Text = "CASH"
	eyebrow.Size = UDim2.fromOffset(140, 14)
	eyebrow.Position = UDim2.fromOffset(59, 9)
	eyebrow.BackgroundTransparency = 1
	eyebrow.Font = Enum.Font.GothamBold
	eyebrow.TextSize = 11
	eyebrow.TextColor3 = Color3.fromRGB(120, 126, 142)
	eyebrow.TextXAlignment = Enum.TextXAlignment.Left
	eyebrow.ZIndex = 3
	eyebrow.Parent = cashPill

	local cashLabel = Instance.new("TextLabel")
	cashLabel.Name = "CashLabel"
	cashLabel.Text = "$0"
	cashLabel.Size = UDim2.fromOffset(152, 28)
	cashLabel.Position = UDim2.fromOffset(59, 22)
	cashLabel.BackgroundTransparency = 1
	cashLabel.Font = Enum.Font.FredokaOne
	cashLabel.TextSize = 26
	cashLabel.TextColor3 = Color3.fromRGB(30, 33, 48)
	cashLabel.TextXAlignment = Enum.TextXAlignment.Left
	cashLabel.ZIndex = 3
	cashLabel.Parent = cashPill

	-- $12,345 style grouping for readability.
	local function withCommas(n)
		local s = tostring(math.floor(n + 0.5))
		local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
		return (formatted:gsub("^,", ""))
	end

	-- Drives the count-up animation; the label text follows this value.
	local cashCounter = Instance.new("NumberValue")
	cashCounter.Value = 0
	cashCounter.Parent = screenGui
	cashCounter.Changed:Connect(function(value)
		cashLabel.Text = "$" .. withCommas(value)
	end)

	-- Count-up animation done by hand (setting .Value in a loop) rather than
	-- via TweenService: tweening a NumberValue's .Value does not animate
	-- reliably, which had left the cash label frozen on its first value.
	local cashAnimToken = 0
	local function animateCashTo(target)
		cashAnimToken += 1
		local myToken = cashAnimToken
		local startValue = cashCounter.Value
		task.spawn(function()
			local steps = 16
			for i = 1, steps do
				if cashAnimToken ~= myToken then
					return
				end
				cashCounter.Value = startValue + (target - startValue) * (i / steps)
				task.wait(0.03)
			end
			if cashAnimToken == myToken then
				cashCounter.Value = target
			end
		end)
	end

	-- Manual property animation. TweenService proved unreliable in this
	-- project (see the cash count-up + the NumberValue note), so the money
	-- card's juice is driven by hand: run `steps` frames, call stepFn(alpha),
	-- then doneFn. A per-target token could guard overlaps, but these are all
	-- short and self-terminating so we keep it simple.
	local function animate(steps, stepFn, doneFn)
		task.spawn(function()
			for i = 1, steps do
				stepFn(i / steps)
				task.wait(0.02)
			end
			if doneFn then
				doneFn()
			end
		end)
	end

	-- Gain feedback: the card springs, the coin spins + pops, and a shine bar
	-- sweeps across. Spend feedback: just the spring (no spin/shine).
	local function playCashPop(isGain)
		animate(6, function(a)
			cashScale.Scale = 1 + 0.08 * a
		end, function()
			animate(8, function(a)
				cashScale.Scale = 1.08 - 0.08 * a
			end, function()
				cashScale.Scale = 1
			end)
		end)
		if isGain then
			animate(18, function(a)
				coin.Rotation = a * 360
			end, function()
				coin.Rotation = 0
			end)
			animate(8, function(a)
				coinScale.Scale = 1.25 - 0.25 * a
			end, function()
				coinScale.Scale = 1
			end)
			shine.Position = UDim2.fromOffset(-50, -30)
			shine.Visible = true
			animate(16, function(a)
				shine.Position = UDim2.fromOffset(-50 + (CASH_W + 90) * a, -30)
			end, function()
				shine.Visible = false
			end)
		end
	end

	-- ---- Subscriber card (matches the money card, in channel red) ----------
	local SUBS_W, SUBS_H = CASH_W, 50
	-- Bottom-right stack: cash sits in the corner, subs above it, boost above
	-- subs. subsY / boostY are distances UP from the bottom edge.
	local subsY = 20 + CASH_H + 10
	local SUBS_TEXT = Color3.fromRGB(90, 20, 20)

	local subsShadow = Instance.new("Frame")
	subsShadow.Name = "SubsShadow"
	subsShadow.Size = UDim2.fromOffset(SUBS_W, SUBS_H)
	subsShadow.AnchorPoint = Vector2.new(1, 1)
	subsShadow.Position = UDim2.new(1, -15, 1, -(subsY - 5))
	subsShadow.BackgroundColor3 = Color3.fromRGB(20, 6, 6)
	subsShadow.BackgroundTransparency = 0.55
	subsShadow.ZIndex = 1
	subsShadow.Parent = screenGui
	addCorner(subsShadow, 18)

	local subsPill = Instance.new("Frame")
	subsPill.Name = "SubsPill"
	subsPill.Size = UDim2.fromOffset(SUBS_W, SUBS_H)
	subsPill.AnchorPoint = Vector2.new(1, 1)
	subsPill.Position = UDim2.new(1, -20, 1, -subsY)
	subsPill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	subsPill.ClipsDescendants = true
	subsPill.ZIndex = 2
	subsPill.Parent = screenGui
	addCorner(subsPill, 20)
	addGradient(subsPill, Color3.fromRGB(255, 255, 255), Color3.fromRGB(238, 240, 247), 90)
	addStroke(subsPill, Color3.fromRGB(214, 218, 230), 1.5, 0)
	local subsScale = Instance.new("UIScale")
	subsScale.Parent = subsPill

	local subsSheen = Instance.new("Frame")
	subsSheen.Size = UDim2.new(1, -16, 0, 10)
	subsSheen.Position = UDim2.fromOffset(8, 4)
	subsSheen.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	subsSheen.BackgroundTransparency = 0.78
	subsSheen.ZIndex = 3
	subsSheen.Parent = subsPill
	addCorner(subsSheen, 6)

	local subsEmblem = Instance.new("Frame")
	subsEmblem.Size = UDim2.fromOffset(36, 36)
	subsEmblem.Position = UDim2.fromOffset(9, 7)
	subsEmblem.BackgroundColor3 = Color3.fromRGB(224, 74, 68)
	subsEmblem.ZIndex = 3
	subsEmblem.Parent = subsPill
	addCorner(subsEmblem, 18)
	addStroke(subsEmblem, Color3.fromRGB(150, 44, 40), 1.5, 0)
	local subsPlay = Instance.new("TextLabel")
	subsPlay.Size = UDim2.fromScale(1, 1)
	subsPlay.BackgroundTransparency = 1
	subsPlay.Text = "\226\150\182" -- ▶
	subsPlay.TextColor3 = Color3.fromRGB(255, 255, 255)
	subsPlay.Font = Enum.Font.FredokaOne
	subsPlay.TextScaled = true
	subsPlay.ZIndex = 4
	subsPlay.Parent = subsEmblem
	local subsPlayPad = Instance.new("UIPadding")
	subsPlayPad.PaddingTop = UDim.new(0, 8)
	subsPlayPad.PaddingBottom = UDim.new(0, 8)
	subsPlayPad.PaddingLeft = UDim.new(0, 9)
	subsPlayPad.PaddingRight = UDim.new(0, 7)
	subsPlayPad.Parent = subsPlay

	local subsEyebrow = Instance.new("TextLabel")
	subsEyebrow.Size = UDim2.fromOffset(140, 12)
	subsEyebrow.Position = UDim2.fromOffset(55, 8)
	subsEyebrow.BackgroundTransparency = 1
	subsEyebrow.TextXAlignment = Enum.TextXAlignment.Left
	subsEyebrow.TextColor3 = Color3.fromRGB(120, 126, 142)
	subsEyebrow.Font = Enum.Font.GothamBold
	subsEyebrow.TextSize = 10
	subsEyebrow.Text = "SUBSCRIBERS"
	subsEyebrow.ZIndex = 3
	subsEyebrow.Parent = subsPill

	local subsLabel = Instance.new("TextLabel")
	subsLabel.Name = "SubsLabel"
	subsLabel.Size = UDim2.fromOffset(160, 24)
	subsLabel.Position = UDim2.fromOffset(55, 20)
	subsLabel.BackgroundTransparency = 1
	subsLabel.TextXAlignment = Enum.TextXAlignment.Left
	subsLabel.TextColor3 = Color3.fromRGB(30, 33, 48)
	subsLabel.Font = Enum.Font.FredokaOne
	subsLabel.TextSize = 22
	subsLabel.Text = "0"
	subsLabel.ZIndex = 3
	subsLabel.Parent = subsPill

	local subsCounter = Instance.new("NumberValue")
	subsCounter.Value = 0
	subsCounter.Parent = screenGui
	subsCounter.Changed:Connect(function(value)
		subsLabel.Text = withCommas(value)
	end)
	local subsAnimToken = 0
	local function animateSubsTo(target)
		subsAnimToken += 1
		local myToken = subsAnimToken
		local startValue = subsCounter.Value
		task.spawn(function()
			for i = 1, 16 do
				if subsAnimToken ~= myToken then
					return
				end
				subsCounter.Value = startValue + (target - startValue) * (i / 16)
				task.wait(0.03)
			end
			if subsAnimToken == myToken then
				subsCounter.Value = target
			end
		end)
	end

	-- "+N subs" floater + a little card pop when subscribers are gained.
	local function showSubsGained(amount)
		animate(6, function(a)
			subsScale.Scale = 1 + 0.07 * a
		end, function()
			animate(8, function(a)
				subsScale.Scale = 1.07 - 0.07 * a
			end, function()
				subsScale.Scale = 1
			end)
		end)
		local f = Instance.new("TextLabel")
		f.Name = "SubsGainFloat"
		f.Text = ("+%s \226\150\182"):format(withCommas(amount))
		f.Size = UDim2.fromOffset(150, 26)
		f.AnchorPoint = Vector2.new(0, 0.5)
		f.Position = UDim2.new(0.5, SUBS_W / 2 + 12, 0, subsY + 24)
		f.BackgroundTransparency = 1
		f.TextColor3 = Color3.fromRGB(255, 150, 145)
		f.Font = Enum.Font.FredokaOne
		f.TextSize = 22
		f.TextXAlignment = Enum.TextXAlignment.Left
		f.TextStrokeColor3 = Color3.fromRGB(30, 10, 10)
		f.TextStrokeTransparency = 0.4
		f.ZIndex = 6
		f.Parent = screenGui
		animate(26, function(a)
			f.Position = UDim2.new(0.5, SUBS_W / 2 + 12, 0, subsY + 24 - 42 * a)
			f.TextTransparency = a
			f.TextStrokeTransparency = 0.4 + 0.6 * a
		end, function()
			f:Destroy()
		end)
	end

	-- Big centred celebration when a Play Button milestone is reached.
	local function showMilestoneCelebration(index)
		local m = GameData.SubMilestones[index]
		if not m then
			return
		end
		local banner = Instance.new("Frame")
		banner.Size = UDim2.fromOffset(460, 120)
		banner.AnchorPoint = Vector2.new(0.5, 0.5)
		banner.Position = UDim2.fromScale(0.5, 0.4)
		banner.BackgroundColor3 = Theme.Panel
		banner.BackgroundTransparency = 0.05
		banner.ZIndex = 20
		banner.Parent = screenGui
		addCorner(banner, 20)
		addStroke(banner, m.color, 3, 0)
		local bScale = Instance.new("UIScale")
		bScale.Scale = 0.5
		bScale.Parent = banner
		-- Award plate with a wrench + a Roblox-style tilted square.
		local plate = Instance.new("Frame")
		plate.Size = UDim2.fromOffset(84, 84)
		plate.Position = UDim2.fromOffset(20, 18)
		plate.BackgroundColor3 = m.color
		plate.BorderSizePixel = 0
		plate.ZIndex = 21
		plate.Parent = banner
		addCorner(plate, 14)
		local wrench = Instance.new("TextLabel")
		wrench.Size = UDim2.fromScale(0.5, 1)
		wrench.Position = UDim2.fromScale(0.02, 0)
		wrench.BackgroundTransparency = 1
		wrench.Text = "\240\159\148\167" -- 🔧
		wrench.Font = Enum.Font.FredokaOne
		wrench.TextScaled = true
		wrench.ZIndex = 22
		wrench.Parent = plate
		local rbx = Instance.new("Frame")
		rbx.Size = UDim2.fromScale(0.34, 0.5)
		rbx.Position = UDim2.fromScale(0.54, 0.25)
		rbx.Rotation = 12
		rbx.BackgroundColor3 = Color3.fromRGB(28, 24, 36)
		rbx.BorderSizePixel = 0
		rbx.ZIndex = 22
		rbx.Parent = plate
		addCorner(rbx, 8)
		local hole = Instance.new("Frame")
		hole.Size = UDim2.fromScale(0.4, 0.4)
		hole.Position = UDim2.fromScale(0.3, 0.3)
		hole.BackgroundColor3 = m.color
		hole.BorderSizePixel = 0
		hole.ZIndex = 23
		hole.Parent = rbx
		addCorner(hole, 4)
		local t1 = Instance.new("TextLabel")
		t1.Size = UDim2.new(1, -120, 0, 40)
		t1.Position = UDim2.fromOffset(110, 24)
		t1.BackgroundTransparency = 1
		t1.TextXAlignment = Enum.TextXAlignment.Left
		t1.TextColor3 = m.color
		t1.Font = Enum.Font.FredokaOne
		t1.TextSize = 28
		t1.Text = m.label .. "!"
		t1.ZIndex = 21
		t1.Parent = banner
		local t2 = Instance.new("TextLabel")
		t2.Size = UDim2.new(1, -120, 0, 26)
		t2.Position = UDim2.fromOffset(110, 66)
		t2.BackgroundTransparency = 1
		t2.TextXAlignment = Enum.TextXAlignment.Left
		t2.TextColor3 = Theme.Text
		t2.Font = Enum.Font.GothamMedium
		t2.TextSize = 16
		t2.Text = ("%s subscribers \194\183 +$%s bonus!"):format(withCommas(m.subs), withCommas(m.cash))
		t2.ZIndex = 21
		t2.Parent = banner
		animate(8, function(a)
			bScale.Scale = 0.5 + 0.5 * a
		end, function()
			bScale.Scale = 1
			task.delay(2.4, function()
				animate(14, function(a)
					banner.BackgroundTransparency = 0.05 + 0.95 * a
					for _, d in ipairs(banner:GetDescendants()) do
						if d:IsA("TextLabel") then
							d.TextTransparency = a
						end
					end
				end, function()
					banner:Destroy()
				end)
			end)
		end)
	end

	-- Boost timer HUD: a card matching the money card's look (shadow, sheen,
	-- circular icon emblem, comma of the same corner/stroke styling) but in the
	-- purple accent, centred directly under the subscriber card. Shows the
	-- boost's icon, multiplier, a live countdown and a draining bar.
	local BOOST_W, BOOST_H = CASH_W, 50
	local boostY = subsY + SUBS_H + 10

	local boostShadow = Instance.new("Frame")
	boostShadow.Name = "BoostShadow"
	boostShadow.Size = UDim2.fromOffset(BOOST_W, BOOST_H)
	boostShadow.AnchorPoint = Vector2.new(1, 1)
	boostShadow.Position = UDim2.new(1, -15, 1, -(boostY - 5))
	boostShadow.BackgroundColor3 = Color3.fromRGB(10, 6, 20)
	boostShadow.BackgroundTransparency = 0.55
	boostShadow.Visible = false
	boostShadow.ZIndex = 1
	boostShadow.Parent = screenGui
	addCorner(boostShadow, 18)

	local boostPill = Instance.new("Frame")
	boostPill.Name = "BoostPill"
	boostPill.Size = UDim2.fromOffset(BOOST_W, BOOST_H)
	boostPill.AnchorPoint = Vector2.new(1, 1)
	boostPill.Position = UDim2.new(1, -20, 1, -boostY)
	boostPill.BackgroundColor3 = Theme.Panel
	boostPill.Visible = false
	boostPill.ClipsDescendants = true
	boostPill.ZIndex = 2
	boostPill.Parent = screenGui
	addCorner(boostPill, 20)
	addGradient(boostPill, Color3.fromRGB(255, 255, 255), Color3.fromRGB(238, 240, 247), 90)
	addStroke(boostPill, Theme.Line, 1.5, 0)
	-- keep the shadow shown/hidden together with the pill
	boostPill:GetPropertyChangedSignal("Visible"):Connect(function()
		boostShadow.Visible = boostPill.Visible
	end)

	local boostSheen = Instance.new("Frame")
	boostSheen.Size = UDim2.new(1, -16, 0, 10)
	boostSheen.Position = UDim2.fromOffset(8, 4)
	boostSheen.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	boostSheen.BackgroundTransparency = 0.82
	boostSheen.ZIndex = 3
	boostSheen.Parent = boostPill
	addCorner(boostSheen, 6)

	local boostIconHolder = Instance.new("Frame")
	boostIconHolder.Size = UDim2.fromOffset(36, 36)
	boostIconHolder.Position = UDim2.fromOffset(9, 7)
	boostIconHolder.BackgroundColor3 = Theme.Accent
	boostIconHolder.ZIndex = 3
	boostIconHolder.Parent = boostPill
	addCorner(boostIconHolder, 18)
	addGradient(boostIconHolder, Color3.fromRGB(168, 128, 255), Theme.AccentDeep, 90)
	addStroke(boostIconHolder, Color3.fromRGB(70, 44, 140), 1.5, 0)
	local boostIcon = Instance.new("TextLabel")
	boostIcon.Size = UDim2.fromScale(1, 1)
	boostIcon.BackgroundTransparency = 1
	boostIcon.Text = "\226\154\161"
	boostIcon.TextScaled = true
	boostIcon.Font = Enum.Font.FredokaOne
	boostIcon.ZIndex = 4
	boostIcon.Parent = boostIconHolder
	local boostIconPad = Instance.new("UIPadding")
	boostIconPad.PaddingTop = UDim.new(0, 5)
	boostIconPad.PaddingBottom = UDim.new(0, 5)
	boostIconPad.PaddingLeft = UDim.new(0, 5)
	boostIconPad.PaddingRight = UDim.new(0, 5)
	boostIconPad.Parent = boostIcon

	local boostEyebrow = Instance.new("TextLabel")
	boostEyebrow.Size = UDim2.fromOffset(120, 12)
	boostEyebrow.Position = UDim2.fromOffset(55, 7)
	boostEyebrow.BackgroundTransparency = 1
	boostEyebrow.TextXAlignment = Enum.TextXAlignment.Left
	boostEyebrow.TextColor3 = Color3.fromRGB(120, 126, 142)
	boostEyebrow.Font = Enum.Font.GothamBold
	boostEyebrow.TextSize = 10
	boostEyebrow.Text = "BOOST"
	boostEyebrow.ZIndex = 3
	boostEyebrow.Parent = boostPill

	local boostTitle = Instance.new("TextLabel")
	boostTitle.Size = UDim2.fromOffset(110, 20)
	boostTitle.Position = UDim2.fromOffset(55, 18)
	boostTitle.BackgroundTransparency = 1
	boostTitle.TextXAlignment = Enum.TextXAlignment.Left
	boostTitle.TextColor3 = Color3.fromRGB(30, 33, 48)
	boostTitle.Font = Enum.Font.FredokaOne
	boostTitle.TextSize = 18
	boostTitle.Text = "2x CASH"
	boostTitle.ZIndex = 3
	boostTitle.Parent = boostPill

	local boostTime = Instance.new("TextLabel")
	boostTime.Size = UDim2.fromOffset(56, 22)
	boostTime.Position = UDim2.fromOffset(BOOST_W - 66, 8)
	boostTime.BackgroundTransparency = 1
	boostTime.TextXAlignment = Enum.TextXAlignment.Right
	boostTime.TextColor3 = Theme.AccentDeep
	boostTime.Font = Enum.Font.FredokaOne
	boostTime.TextSize = 18
	boostTime.Text = "0:00"
	boostTime.ZIndex = 3
	boostTime.Parent = boostPill

	local boostBarBg = Instance.new("Frame")
	boostBarBg.Size = UDim2.new(1, -66, 0, 6)
	boostBarBg.Position = UDim2.fromOffset(55, 38)
	boostBarBg.BackgroundColor3 = Color3.fromRGB(224, 227, 236)
	boostBarBg.ZIndex = 3
	boostBarBg.Parent = boostPill
	addCorner(boostBarBg, 3)
	local boostBarFill = Instance.new("Frame")
	boostBarFill.Size = UDim2.fromScale(1, 1)
	boostBarFill.BackgroundColor3 = Color3.fromRGB(168, 128, 255)
	boostBarFill.ZIndex = 4
	boostBarFill.Parent = boostBarBg
	addCorner(boostBarFill, 3)

	-- Total duration of the currently-shown boost, captured when it starts so
	-- the drain bar has something to scale against.
	local boostTotal, boostTrackedUntil = 0, 0
	local function refreshBoostHud()
		if seatedHudHidden then
			boostPill.Visible = false
			return
		end
		local now = Workspace:GetServerTimeNow()
		local remaining = playerState.boostUntil - now
		if remaining <= 0 then
			boostPill.Visible = false
			return
		end
		if playerState.boostUntil ~= boostTrackedUntil then
			boostTrackedUntil = playerState.boostUntil
			boostTotal = math.max(1, remaining)
		end
		boostPill.Visible = true
		boostIcon.Text = playerState.boostIcon or "\226\154\161"
		local mult = playerState.boostMult or 2
		boostTitle.Text = ("%gx CASH"):format(mult)
		local mins = math.floor(remaining / 60)
		local secs = math.floor(remaining % 60)
		boostTime.Text = ("%d:%02d"):format(mins, secs)
		boostBarFill.Size = UDim2.fromScale(math.clamp(remaining / boostTotal, 0, 1), 1)
	end
	task.spawn(function()
		while true do
			refreshBoostHud()
			task.wait(0.25)
		end
	end)

	-- (Old static Goals checklist removed -- the dynamic onboarding tutorial is
	-- being rebuilt as roadmap milestone M2.)

	-- Navigation buttons: "To Studio" (top) + "Go to Leaderboards" (right).
	local toStudioBtn = Instance.new("TextButton")
	toStudioBtn.Name = "ToStudioButton"
	toStudioBtn.Size = UDim2.fromOffset(170, 38)
	toStudioBtn.AnchorPoint = Vector2.new(0.5, 0)
	toStudioBtn.Position = UDim2.new(0.5, 0, 0, 12)
	toStudioBtn.BackgroundColor3 = Theme.Accent
	toStudioBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	toStudioBtn.Font = Enum.Font.FredokaOne
	toStudioBtn.TextSize = 18
	toStudioBtn.Text = "\240\159\143\160 To Studio"
	toStudioBtn.AutoButtonColor = true
	toStudioBtn.Parent = screenGui
	addCorner(toStudioBtn, 12)
	addStroke(toStudioBtn, Color3.fromRGB(255, 255, 255), 1, 0.7)
	toStudioBtn.MouseButton1Click:Connect(function()
		Remotes.RequestGoToStudio:FireServer()
	end)

	local leaderboardBtn = Instance.new("TextButton")
	leaderboardBtn.Name = "GoToLeaderboardsButton"
	leaderboardBtn.Size = UDim2.fromOffset(186, 48)
	leaderboardBtn.AnchorPoint = Vector2.new(1, 0.5)
	leaderboardBtn.Position = UDim2.new(1, -16, 0.5, 0)
	leaderboardBtn.BackgroundColor3 = Theme.Gold
	leaderboardBtn.TextColor3 = Color3.fromRGB(60, 40, 10)
	leaderboardBtn.Font = Enum.Font.FredokaOne
	leaderboardBtn.TextSize = 17
	leaderboardBtn.Text = "\240\159\143\134 Go to Leaderboards"
	leaderboardBtn.AutoButtonColor = true
	leaderboardBtn.Parent = screenGui
	addCorner(leaderboardBtn, 12)
	addStroke(leaderboardBtn, Color3.fromRGB(255, 255, 255), 1, 0.6)
	leaderboardBtn.MouseButton1Click:Connect(function()
		Remotes.RequestGoToLeaderboards:FireServer()
	end)

	-- A "+$X" pops up next to the cash pill and floats up while fading
	-- out -- the classic tycoon-game "cha-ching" feedback for any cash
	-- gain (basketball scores, game releases, etc. all funnel through
	-- PlayerStateUpdated, so this one spot covers all of them).
	-- Floating delta rises just above the bottom-right cash card.
	local floatBaseY = -(20 + CASH_H + 6)
	local function showFloatingCashDelta(delta)
		local isGain = delta > 0
		local floatLabel = Instance.new("TextLabel")
		floatLabel.Name = "CashDeltaFloat"
		floatLabel.Text = ("%s$%s"):format(isGain and "+" or "-", withCommas(math.abs(delta)))
		floatLabel.Size = UDim2.fromOffset(160, 30)
		floatLabel.Position = UDim2.new(1, -24, 1, floatBaseY)
		floatLabel.AnchorPoint = Vector2.new(1, 1)
		floatLabel.BackgroundTransparency = 1
		floatLabel.TextColor3 = isGain and Theme.Success or Theme.Danger
		floatLabel.Font = Enum.Font.FredokaOne
		floatLabel.TextSize = 24
		floatLabel.TextXAlignment = Enum.TextXAlignment.Right
		floatLabel.TextStrokeColor3 = Color3.fromRGB(20, 16, 30)
		floatLabel.TextStrokeTransparency = 0.4
		floatLabel.ZIndex = 6
		floatLabel.Parent = screenGui
		-- pop-in, then float up + fade (manual; TweenService is unreliable here)
		local sc = Instance.new("UIScale")
		sc.Scale = 0.6
		sc.Parent = floatLabel
		animate(6, function(a)
			sc.Scale = 0.6 + 0.4 * a
		end, function()
			sc.Scale = 1
		end)
		animate(28, function(a)
			floatLabel.Position = UDim2.new(1, -24, 1, floatBaseY - 50 * a)
			floatLabel.TextTransparency = a
			floatLabel.TextStrokeTransparency = 0.4 + 0.6 * a
		end, function()
			floatLabel:Destroy()
		end)
	end

	-- Small transient status toast (feedback wherever you are, not gated by seating)
	local statusToast = Instance.new("TextLabel")
	statusToast.Name = "StatusToast"
	statusToast.Size = UDim2.fromOffset(360, 30)
	statusToast.Position = UDim2.fromOffset(20, 150)
	statusToast.BackgroundTransparency = 1
	statusToast.TextColor3 = Theme.TextMuted
	statusToast.Font = Enum.Font.GothamMedium
	statusToast.TextSize = 15
	statusToast.TextXAlignment = Enum.TextXAlignment.Left
	statusToast.TextWrapped = true
	statusToast.Text = ""
	statusToast.Parent = screenGui

	-- New Project panel (seat-gated: only visible while sitting at NewProjectSeat)
	local newProjectPanel = makeStationPanel(screenGui, "NewProject")

	local newProjectPadding = Instance.new("UIPadding")
	newProjectPadding.PaddingTop = UDim.new(0, 12)
	newProjectPadding.PaddingBottom = UDim.new(0, 12)
	newProjectPadding.PaddingLeft = UDim.new(0, 12)
	newProjectPadding.PaddingRight = UDim.new(0, 12)
	newProjectPadding.Parent = newProjectPanel

	local newProjectLayout = Instance.new("UIListLayout")
	newProjectLayout.Padding = UDim.new(0, 8)
	newProjectLayout.SortOrder = Enum.SortOrder.LayoutOrder
	newProjectLayout.Parent = newProjectPanel

	local genreLabel = Instance.new("TextLabel")
	genreLabel.Text = "GENRE"
	genreLabel.Size = UDim2.new(1, 0, 0, 16)
	genreLabel.LayoutOrder = 1
	genreLabel.BackgroundTransparency = 1
	genreLabel.TextColor3 = Theme.TextMuted
	genreLabel.Font = Enum.Font.GothamBold
	genreLabel.TextSize = 12
	genreLabel.TextXAlignment = Enum.TextXAlignment.Left
	genreLabel.Parent = newProjectPanel

	local genreRow = Instance.new("Frame")
	genreRow.Size = UDim2.new(1, 0, 0, 34)
	genreRow.LayoutOrder = 2
	genreRow.BackgroundTransparency = 1
	genreRow.Parent = newProjectPanel

	local genreRowLayout = Instance.new("UIListLayout")
	genreRowLayout.FillDirection = Enum.FillDirection.Horizontal
	genreRowLayout.Padding = UDim.new(0, 6)
	genreRowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	genreRowLayout.Parent = genreRow

	local GENRE_ICONS = { Racing = "\240\159\143\129", Horror = "\240\159\145\187", Adventure = "\240\159\151\186", Simulator = "\240\159\149\185" }
	local genreButtons = {}
	for i, genre in ipairs(GameData.Genres) do
		local button = makeButton(genreRow, i, genre, UDim2.new(0.25, -5, 1, 0), 13)
		button.Text = (GENRE_ICONS[genre] or "") .. " " .. genre
		genreButtons[genre] = button
		button.MouseButton1Click:Connect(function()
			selectedGenre = genre
			for name, btn in pairs(genreButtons) do
				local sel = name == genre
				btn.BackgroundColor3 = sel and Theme.Accent or Theme.Neutral
				btn.TextColor3 = sel and Color3.fromRGB(255, 255, 255) or Theme.Text
			end
		end)
	end

	local topicLabel = Instance.new("TextLabel")
	topicLabel.Text = "TOPIC"
	topicLabel.Size = UDim2.new(1, 0, 0, 16)
	topicLabel.LayoutOrder = 3
	topicLabel.BackgroundTransparency = 1
	topicLabel.TextColor3 = Theme.TextMuted
	topicLabel.Font = Enum.Font.GothamBold
	topicLabel.TextSize = 12
	topicLabel.TextXAlignment = Enum.TextXAlignment.Left
	topicLabel.Parent = newProjectPanel

	local topicRow = Instance.new("Frame")
	topicRow.Size = UDim2.new(1, 0, 0, 34)
	topicRow.LayoutOrder = 4
	topicRow.BackgroundTransparency = 1
	topicRow.Parent = newProjectPanel

	local topicRowLayout = Instance.new("UIListLayout")
	topicRowLayout.FillDirection = Enum.FillDirection.Horizontal
	topicRowLayout.Padding = UDim.new(0, 6)
	topicRowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	topicRowLayout.Parent = topicRow

	local TOPIC_ICONS = { Space = "\240\159\154\128", Zombies = "\240\159\167\159", Sports = "\226\154\189", Fantasy = "\240\159\144\137" }
	local topicButtons = {}
	for i, topic in ipairs(GameData.Topics) do
		local button = makeButton(topicRow, i, topic, UDim2.new(0.25, -5, 1, 0), 13)
		button.Text = (TOPIC_ICONS[topic] or "") .. " " .. topic
		topicButtons[topic] = button
		button.MouseButton1Click:Connect(function()
			selectedTopic = topic
			for name, btn in pairs(topicButtons) do
				local sel = name == topic
				btn.BackgroundColor3 = sel and Theme.Accent or Theme.Neutral
				btn.TextColor3 = sel and Color3.fromRGB(255, 255, 255) or Theme.Text
			end
		end)
	end

	local startButton = makeButton(newProjectPanel, 5, "\240\159\154\128 Start Developing", UDim2.new(1, 0, 0, 40), 18)
	startButton.BackgroundColor3 = Theme.Accent
	startButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	addGradient(startButton, Color3.fromRGB(163, 110, 255), Color3.fromRGB(120, 74, 220), 90)
	addHoverFeedback(startButton, Theme.Accent, Theme.AccentDeep)

	-- Mini-game panels (each seat-gated to its matching computer)
	local codingPanel = makeStationPanel(screenGui, "Coding")
	local mapBuildingPanel = makeStationPanel(screenGui, "MapBuilding")
	local testingPanel = makeStationPanel(screenGui, "Testing")

	local hosts = {
		Coding = MinigameHost.new("Coding", codingPanel, Theme),
		MapBuilding = MinigameHost.new("MapBuilding", mapBuildingPanel, Theme),
		Testing = MinigameHost.new("Testing", testingPanel, Theme),
	}

	local function hideAllMiniGames()
		for _, h in pairs(hosts) do
			h:hide()
		end
	end

	hideAllMiniGames()

	-- Seat tracking: show the matching panel only while physically seated at that computer
	local STATION_NAMES = { "NewProject", "Coding", "MapBuilding", "Testing" }
	local STATION_PANELS = {
		NewProject = newProjectPanel,
		Coding = codingPanel,
		MapBuilding = mapBuildingPanel,
		Testing = testingPanel,
	}

	-- Each station type can now have several seats (one set per floor), so we
	-- track a LIST of seats per station and the player is "at" a station if
	-- they occupy any of its seats -- this is what makes the upper floors'
	-- stations work for developing games, not just the ground floor.
	local seatsByStation = {}
	for _, name in ipairs(STATION_NAMES) do
		seatsByStation[name] = {}
	end
	local seatedStation = nil

	-- Big center-top "what to do next" banner + a 3D arrow floating over the
	-- computer you need to use, so a new player is never guessing.
	local currentPhase = nil

	local instructionBanner = Instance.new("TextLabel")
	instructionBanner.Name = "InstructionBanner"
	instructionBanner.Size = UDim2.fromOffset(600, 66)
	instructionBanner.Position = UDim2.new(0.5, 0, 0, 22)
	instructionBanner.AnchorPoint = Vector2.new(0.5, 0)
	instructionBanner.BackgroundColor3 = Theme.Panel
	instructionBanner.BackgroundTransparency = 0.05
	instructionBanner.TextColor3 = Theme.Gold
	instructionBanner.Font = Enum.Font.FredokaOne
	instructionBanner.TextSize = 30
	instructionBanner.TextWrapped = true
	instructionBanner.Visible = false
	instructionBanner.ZIndex = 20
	instructionBanner.Parent = screenGui
	addCorner(instructionBanner, 16)
	addStroke(instructionBanner, Theme.Accent, 2, 0.25)
	addGradient(instructionBanner, Theme.PanelLight, Theme.Panel, 90)

	local guideArrow = Instance.new("BillboardGui")
	guideArrow.Name = "GuideArrow"
	guideArrow.Size = UDim2.fromOffset(150, 170)
	guideArrow.StudsOffsetWorldSpace = Vector3.new(0, 6.5, 0)
	guideArrow.AlwaysOnTop = true
	guideArrow.Enabled = false
	guideArrow.Parent = screenGui
	local arrowSymbol = Instance.new("TextLabel")
	arrowSymbol.Size = UDim2.new(1, 0, 0.66, 0)
	arrowSymbol.BackgroundTransparency = 1
	arrowSymbol.Text = "\226\150\188" -- big down triangle
	arrowSymbol.Font = Enum.Font.FredokaOne
	arrowSymbol.TextScaled = true
	arrowSymbol.TextColor3 = Theme.Gold
	arrowSymbol.TextStrokeTransparency = 0.3
	arrowSymbol.Parent = guideArrow
	local arrowCaption = Instance.new("TextLabel")
	arrowCaption.Size = UDim2.new(1, 0, 0.34, 0)
	arrowCaption.Position = UDim2.fromScale(0, 0.66)
	arrowCaption.BackgroundTransparency = 1
	arrowCaption.Text = "SIT HERE"
	arrowCaption.Font = Enum.Font.FredokaOne
	arrowCaption.TextScaled = true
	arrowCaption.TextColor3 = Color3.fromRGB(255, 255, 255)
	arrowCaption.TextStrokeTransparency = 0.3
	arrowCaption.Parent = guideArrow

	local function nearestSeat(station)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local best, bestDist
		for _, seat in ipairs(seatsByStation[station] or {}) do
			if seat.Parent then
				local dist = root and (seat.Position - root.Position).Magnitude or 0
				if not bestDist or dist < bestDist then
					best, bestDist = seat, dist
				end
			end
		end
		return best
	end

	local function hideInstruction()
		instructionBanner.Visible = false
		guideArrow.Enabled = false
	end

	local function showGoToStation(station, labelText)
		instructionBanner.Text = labelText
		instructionBanner.Visible = true
		local seat = nearestSeat(station)
		if seat then
			guideArrow.Adornee = seat
			guideArrow.Enabled = true
		else
			guideArrow.Enabled = false
		end
	end

	-- "Computer" desktop shown while seated at a station: a Windows-style blue
	-- wallpaper + a big center app tile matching the current activity, plus a
	-- taskbar of all the apps. Its own ScreenGui at a lower DisplayOrder so it
	-- sits BEHIND the mini-game panels (which read as the open "app windows").
	local APP_META = {
		NewProject = { icon = "\226\156\168", name = "New Project", color = Color3.fromRGB(90, 110, 170) },
		Coding = { icon = "\240\159\148\167", name = "Code Editor", color = Color3.fromRGB(60, 120, 90) },
		MapBuilding = { icon = "\240\159\167\177", name = "Map Builder", color = Color3.fromRGB(150, 100, 60) },
		Testing = { icon = "\240\159\144\158", name = "Bug Tester", color = Color3.fromRGB(150, 70, 90) },
	}

	local desktopGui = Instance.new("ScreenGui")
	desktopGui.Name = "ComputerDesktopGui"
	desktopGui.ResetOnSpawn = false
	desktopGui.DisplayOrder = -1
	desktopGui.IgnoreGuiInset = true
	desktopGui.Enabled = false
	desktopGui.Parent = player:WaitForChild("PlayerGui")

	local wallpaper = Instance.new("Frame")
	wallpaper.Size = UDim2.fromScale(1, 1)
	wallpaper.BackgroundColor3 = Color3.fromRGB(30, 110, 210)
	wallpaper.BorderSizePixel = 0
	wallpaper.Parent = desktopGui
	local wg = Instance.new("UIGradient")
	wg.Color = ColorSequence.new(Color3.fromRGB(86, 172, 250), Color3.fromRGB(12, 70, 172))
	wg.Rotation = 32
	wg.Parent = wallpaper

	-- A soft diagonal "light ray" sweeping from the logo, Win10-style.
	local ray = Instance.new("Frame")
	ray.Size = UDim2.fromScale(1.4, 0.5)
	ray.Position = UDim2.fromScale(0.62, 0.22)
	ray.AnchorPoint = Vector2.new(0.5, 0.5)
	ray.Rotation = 18
	ray.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	ray.BorderSizePixel = 0
	ray.ZIndex = 1
	ray.Parent = wallpaper
	local rayGrad = Instance.new("UIGradient")
	rayGrad.Rotation = 90
	rayGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.82),
		NumberSequenceKeypoint.new(1, 1),
	})
	rayGrad.Parent = ray

	-- Glowing Windows-style 4-pane logo, upper-right.
	local logo = Instance.new("Frame")
	logo.Size = UDim2.fromOffset(140, 140)
	logo.Position = UDim2.fromScale(0.72, 0.2)
	logo.AnchorPoint = Vector2.new(0.5, 0.5)
	logo.BackgroundTransparency = 1
	logo.Rotation = -8
	logo.ZIndex = 2
	logo.Parent = wallpaper
	for r = 0, 1 do
		for c = 0, 1 do
			local pane = Instance.new("Frame")
			pane.Size = UDim2.fromOffset(62, 62)
			pane.Position = UDim2.fromOffset(c * 78, r * 78)
			pane.BackgroundColor3 = Color3.fromRGB(180, 222, 255)
			pane.BackgroundTransparency = 0.1
			pane.BorderSizePixel = 0
			pane.ZIndex = 2
			pane.Parent = logo
			addCorner(pane, 8)
		end
	end

	-- The "app window": chrome (shadow + rounded body + coloured title bar with
	-- an icon, the app name and traffic-light buttons) framing the mini-game.
	local winShadow = Instance.new("Frame")
	winShadow.Size = UDim2.fromOffset(452, 312)
	winShadow.Position = UDim2.new(0.5, 6, 0.54, 8)
	winShadow.AnchorPoint = Vector2.new(0.5, 0.5)
	winShadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	winShadow.BackgroundTransparency = 0.55
	winShadow.ZIndex = 3
	winShadow.Parent = wallpaper
	addCorner(winShadow, 16)

	local window = Instance.new("Frame")
	window.Name = "AppWindow"
	window.Size = UDim2.fromOffset(448, 308)
	window.Position = UDim2.fromScale(0.5, 0.54)
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.BackgroundColor3 = Color3.fromRGB(238, 240, 245)
	window.ZIndex = 3
	window.Parent = wallpaper
	addCorner(window, 14)

	local titleBar = Instance.new("Frame")
	titleBar.Size = UDim2.new(1, 0, 0, 40)
	titleBar.BackgroundColor3 = Color3.fromRGB(60, 90, 150)
	titleBar.BorderSizePixel = 0
	titleBar.ZIndex = 4
	titleBar.Parent = window
	addCorner(titleBar, 14)
	-- square off the bottom of the title bar
	local tbFill = Instance.new("Frame")
	tbFill.Size = UDim2.new(1, 0, 0, 14)
	tbFill.Position = UDim2.new(0, 0, 1, -14)
	tbFill.BackgroundColor3 = Color3.fromRGB(60, 90, 150)
	tbFill.BorderSizePixel = 0
	tbFill.ZIndex = 4
	tbFill.Parent = titleBar

	local appIcon = Instance.new("TextLabel")
	appIcon.Size = UDim2.fromOffset(28, 28)
	appIcon.Position = UDim2.fromOffset(10, 6)
	appIcon.BackgroundTransparency = 1
	appIcon.Text = "\240\159\148\167"
	appIcon.TextScaled = true
	appIcon.Font = Enum.Font.FredokaOne
	appIcon.ZIndex = 5
	appIcon.Parent = titleBar
	local appName = Instance.new("TextLabel")
	appName.Size = UDim2.new(1, -160, 1, 0)
	appName.Position = UDim2.fromOffset(44, 0)
	appName.BackgroundTransparency = 1
	appName.TextXAlignment = Enum.TextXAlignment.Left
	appName.Text = "Code Editor"
	appName.TextColor3 = Color3.fromRGB(255, 255, 255)
	appName.Font = Enum.Font.FredokaOne
	appName.TextSize = 18
	appName.ZIndex = 5
	appName.Parent = titleBar
	for i, col in ipairs({ Color3.fromRGB(255, 95, 86), Color3.fromRGB(255, 189, 46), Color3.fromRGB(39, 201, 63) }) do
		local dot = Instance.new("Frame")
		dot.Size = UDim2.fromOffset(14, 14)
		dot.AnchorPoint = Vector2.new(1, 0.5)
		dot.Position = UDim2.new(1, -10 - (3 - i) * 22, 0.5, 0)
		dot.BackgroundColor3 = col
		dot.BorderSizePixel = 0
		dot.ZIndex = 5
		dot.Parent = titleBar
		addCorner(dot, 7)
	end

	-- Taskbar: a full-width translucent bar with a Start orb, the app icons,
	-- and a live clock -- like a real OS.
	local taskbar = Instance.new("Frame")
	taskbar.Size = UDim2.new(1, 0, 0, 48)
	taskbar.Position = UDim2.new(0, 0, 1, 0)
	taskbar.AnchorPoint = Vector2.new(0, 1)
	taskbar.BackgroundColor3 = Color3.fromRGB(16, 30, 56)
	taskbar.BackgroundTransparency = 0.12
	taskbar.BorderSizePixel = 0
	taskbar.ZIndex = 6
	taskbar.Parent = wallpaper

	local startOrb = Instance.new("TextLabel")
	startOrb.Size = UDim2.fromOffset(34, 34)
	startOrb.Position = UDim2.fromOffset(12, 7)
	startOrb.BackgroundColor3 = Color3.fromRGB(60, 150, 240)
	startOrb.Text = "\226\138\158" -- ⊞
	startOrb.TextColor3 = Color3.fromRGB(255, 255, 255)
	startOrb.Font = Enum.Font.FredokaOne
	startOrb.TextSize = 22
	startOrb.ZIndex = 7
	startOrb.Parent = taskbar
	addCorner(startOrb, 8)

	local iconRow = Instance.new("Frame")
	iconRow.Size = UDim2.fromOffset(56 * #STATION_NAMES, 40)
	iconRow.Position = UDim2.fromScale(0.5, 0.5)
	iconRow.AnchorPoint = Vector2.new(0.5, 0.5)
	iconRow.BackgroundTransparency = 1
	iconRow.ZIndex = 7
	iconRow.Parent = taskbar
	local tbLayout = Instance.new("UIListLayout")
	tbLayout.FillDirection = Enum.FillDirection.Horizontal
	tbLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tbLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	tbLayout.Padding = UDim.new(0, 10)
	tbLayout.Parent = iconRow
	local taskbarIcons = {}
	for _, name in ipairs(STATION_NAMES) do
		local meta = APP_META[name]
		local holder = Instance.new("Frame")
		holder.Size = UDim2.fromOffset(40, 40)
		holder.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		holder.BackgroundTransparency = 0.7
		holder.ZIndex = 7
		holder.Parent = iconRow
		addCorner(holder, 9)
		-- a little "running app" underline
		local underline = Instance.new("Frame")
		underline.Name = "Underline"
		underline.Size = UDim2.fromOffset(20, 3)
		underline.Position = UDim2.new(0.5, 0, 1, 3)
		underline.AnchorPoint = Vector2.new(0.5, 0)
		underline.BackgroundColor3 = Color3.fromRGB(90, 190, 255)
		underline.BorderSizePixel = 0
		underline.Visible = false
		underline.ZIndex = 7
		underline.Parent = holder
		addCorner(underline, 2)
		local ic = Instance.new("TextLabel")
		ic.Size = UDim2.fromScale(1, 1)
		ic.BackgroundTransparency = 1
		ic.Text = (meta and meta.icon) or "?"
		ic.TextScaled = true
		ic.Font = Enum.Font.FredokaOne
		ic.ZIndex = 8
		ic.Parent = holder
		taskbarIcons[name] = holder
	end

	local clock = Instance.new("TextLabel")
	clock.Size = UDim2.fromOffset(70, 40)
	clock.Position = UDim2.new(1, -12, 0.5, 0)
	clock.AnchorPoint = Vector2.new(1, 0.5)
	clock.BackgroundTransparency = 1
	clock.TextColor3 = Color3.fromRGB(235, 240, 250)
	clock.Font = Enum.Font.GothamMedium
	clock.TextSize = 16
	clock.Text = "12:00"
	clock.ZIndex = 7
	clock.Parent = taskbar
	task.spawn(function()
		while true do
			clock.Text = os.date("%H:%M")
			task.wait(20)
		end
	end)

	local function setDesktop(station)
		if not station then
			desktopGui.Enabled = false
			return
		end
		local meta = APP_META[station]
		if meta then
			appIcon.Text = meta.icon
			appName.Text = meta.name
			if meta.color then
				titleBar.BackgroundColor3 = meta.color
				tbFill.BackgroundColor3 = meta.color
			end
		end
		for name, holder in pairs(taskbarIcons) do
			holder.BackgroundTransparency = (name == station) and 0.05 or 0.7
			local underline = holder:FindFirstChild("Underline")
			if underline then
				underline.Visible = (name == station)
			end
		end
		desktopGui.Enabled = true
	end

	-- Hide/show the whole ambient HUD (everything except the computer + the
	-- minigame) so sitting down feels like you're just at the computer.
	local function setHudHidden(hidden)
		seatedHudHidden = hidden
		local show = not hidden
		cashPill.Visible = show
		cashShadow.Visible = show
		subsPill.Visible = show
		subsShadow.Visible = show
		toStudioBtn.Visible = show
		leaderboardBtn.Visible = show
		if statusToast then
			statusToast.Visible = show
		end
		if hidden then
			boostPill.Visible = false
			boostShadow.Visible = false
		else
			refreshBoostHud()
		end
		local prestigeGui = player.PlayerGui:FindFirstChild("PrestigeGui")
		if prestigeGui then
			prestigeGui.Enabled = show
		end
		-- Also close the rebirth progress modal when the HUD hides (e.g. seated).
		if hidden then
			local rebirthGui = player.PlayerGui:FindFirstChild("RebirthProgressGui")
			if rebirthGui then
				rebirthGui.Enabled = false
			end
		end
	end

	local function refreshStationVisibility()
		for _, name in ipairs(STATION_NAMES) do
			STATION_PANELS[name].Visible = (seatedStation == name)
		end
		setDesktop(seatedStation)
		setHudHidden(seatedStation ~= nil)
	end

	local function isPlayerInSeat(seat)
		local character = player.Character
		return seat.Parent ~= nil and character ~= nil and seat.Occupant ~= nil and seat.Occupant.Parent == character
	end

	local seatedStationListeners = {}

	local function updateSeatedStation()
		local newStation = nil
		for _, name in ipairs(STATION_NAMES) do
			for _, seat in ipairs(seatsByStation[name]) do
				if isPlayerInSeat(seat) then
					newStation = name
					break
				end
			end
			if newStation then
				break
			end
		end
		seatedStation = newStation
		for _, cb in ipairs(seatedStationListeners) do
			task.spawn(cb, seatedStation)
		end
		refreshStationVisibility()
		-- Once the player reaches the station they were directed to, drop the
		-- banner + arrow (the mini-game panel takes over).
		if currentPhase and seatedStation == currentPhase then
			hideInstruction()
		end
	end

	-- Maps a seat's name (ground "CodingSeat" or upper "F2_CodingSeat") to its
	-- station type by suffix.
	local function stationForSeatName(seatName)
		for _, name in ipairs(STATION_NAMES) do
			local suffix = name .. "Seat"
			if seatName == suffix or seatName:sub(-#suffix) == suffix then
				return name
			end
		end
		return nil
	end

	local function trackSeat(inst)
		if not inst:IsA("Seat") then
			return
		end
		local station = stationForSeatName(inst.Name)
		if not station then
			return
		end
		for _, existing in ipairs(seatsByStation[station]) do
			if existing == inst then
				return
			end
		end
		table.insert(seatsByStation[station], inst)
		inst:GetPropertyChangedSignal("Occupant"):Connect(updateSeatedStation)
	end

	-- Find this player's own plot (assigned server-side on join) rather than
	-- a single shared lobby -- everything below is relative to that plot.
	local plotIndex = player:GetAttribute("PlotIndex")
	if not plotIndex then
		local gotAttribute = false
		local connection
		connection = player:GetAttributeChangedSignal("PlotIndex"):Connect(function()
			gotAttribute = true
		end)

		local waited = 0
		while not gotAttribute and waited < 10 do
			task.wait(0.2)
			waited += 0.2
		end

		connection:Disconnect()
		plotIndex = player:GetAttribute("PlotIndex")
	end

	if not plotIndex then
		warn("No plot was assigned -- the server may be full (max 4 players).")
		return
	end

	local plotFolder = workspace:WaitForChild("Plots"):WaitForChild("Plot" .. plotIndex)

	-- Start onboarding BEFORE the (possibly slow) seat wait below, so its
	-- listeners connect and it can appear promptly instead of after the stall.
	TutorialGuide.init(player, Theme, playerState, {
		toStudioButton = toStudioBtn,
		onSeatedStationChanged = function(cb)
			table.insert(seatedStationListeners, cb)
		end,
		getPlotFolder = function()
			return plotFolder
		end,
	})

	-- Ensure the ground floor is populated before scanning.
	plotFolder:WaitForChild("NewProjectSeat")

	-- Track every station seat currently in the plot, and any added later when
	-- floors are built on upgrade.
	for _, inst in ipairs(plotFolder:GetDescendants()) do
		trackSeat(inst)
	end
	-- Remembered so a trend board on a floor built later (on upgrade) shows
	-- the current trend right away instead of sitting on "Loading...".
	local latestTrendText = nil

	plotFolder.DescendantAdded:Connect(function(inst)
		trackSeat(inst)
		if inst:IsA("Seat") then
			updateSeatedStation()
		end
		if inst.Name == "TrendsText" and inst:IsA("TextLabel") and latestTrendText then
			inst.Text = latestTrendText
		end
	end)

	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		updateSeatedStation()
	end)

	updateSeatedStation()

	-- Physical wall signs showing the Trends Board (one per floor -- every
	-- board in the house shows the same current trend). Update them all.
	local function updateTrendsSigns(text)
		latestTrendText = text
		for _, inst in ipairs(plotFolder:GetDescendants()) do
			if inst.Name == "TrendsText" and inst:IsA("TextLabel") then
				inst.Text = text
			end
		end
	end

	local PHASE_DISPLAY_NAMES = {
		Coding = "Coding",
		MapBuilding = "Map Building",
		Testing = "Testing",
	}

	-- Watchdog resets on every sign of progress (phase/round events) instead of
	-- using one fixed deadline for the whole cycle -- a player can now spend up
	-- to ~30s walking to a station between phases, so a single fixed timeout
	-- sized for the old always-on-screen UI would misfire on ordinary play.
	local WATCHDOG_SECONDS = 60
	local developing = false
	local developSequence = 0

	local function armWatchdog()
		developSequence += 1
		local mySequence = developSequence
		task.delay(WATCHDOG_SECONDS, function()
			if developing and mySequence == developSequence then
				developing = false
				hideAllMiniGames()
				currentPhase = nil
				hideInstruction()
				statusToast.Text = "Something went wrong -- try again."
				statusToast.TextColor3 = Theme.Danger
			end
		end)
	end

	Remotes.PhaseStarted.OnClientEvent:Connect(function(phase, isAutomated)
		hideAllMiniGames()
		armWatchdog()
		currentPhase = phase
		if isAutomated then
			statusToast.Text = ("\240\159\164\150 Your %s worker is working..."):format(PHASE_DISPLAY_NAMES[phase])
			statusToast.TextColor3 = Theme.TextMuted
			instructionBanner.Text = ("\240\159\164\150 Your %s worker is on it..."):format(PHASE_DISPLAY_NAMES[phase])
			instructionBanner.Visible = true
			guideArrow.Enabled = false
		else
			statusToast.Text = ("Go sit at the %s computer!"):format(PHASE_DISPLAY_NAMES[phase])
			statusToast.TextColor3 = Theme.Gold
			showGoToStation(phase, ("\226\158\161\239\184\143 Go to the %s computer!"):format(string.upper(PHASE_DISPLAY_NAMES[phase])))
		end
	end)

	Remotes.RoundStarted.OnClientEvent:Connect(function(station, roundIndex, info)
		armWatchdog()
		statusToast.Text = ("%s \226\128\148 round %d/%d"):format(PHASE_DISPLAY_NAMES[station], roundIndex, GameData.RoundsPerPhase)
		statusToast.TextColor3 = Theme.TextMuted
		local host = hosts[station]
		if host then
			host:show(info.variantId, info.difficulty, info.params, info.roundInfo)
		end
	end)

	Remotes.RoundComplete.OnClientEvent:Connect(function(phase, roundIndex, score)
		armWatchdog()
		statusToast.Text = ("Round %d: %d%%"):format(roundIndex, math.floor(score * 100 + 0.5))
		statusToast.TextColor3 = Theme.TextMuted
	end)

	Remotes.PhaseComplete.OnClientEvent:Connect(function(phase, score)
		hideAllMiniGames()
		armWatchdog()
		currentPhase = nil
		hideInstruction()
		statusToast.Text = ("%s complete: %d%%"):format(PHASE_DISPLAY_NAMES[phase], math.floor(score * 100 + 0.5))
	end)

	startButton.MouseButton1Click:Connect(function()
		if developing then
			return
		end

		if not selectedGenre or not selectedTopic then
			statusToast.Text = "Pick a Genre and a Topic first!"
			statusToast.TextColor3 = Theme.Danger
			return
		end

		developing = true
		statusToast.Text = "Starting..."
		statusToast.TextColor3 = Theme.TextMuted
		Remotes.RequestStartDevelopment:FireServer(selectedGenre, selectedTopic)
		armWatchdog()
	end)

	Remotes.DevelopmentComplete.OnClientEvent:Connect(function(cash, wasCopy, hitBonus)
		developing = false
		hideAllMiniGames()
		currentPhase = nil
		hideInstruction()

		if wasCopy then
			statusToast.Text = "That was a copy! Earned $0."
			statusToast.TextColor3 = Theme.Danger
		elseif hitBonus then
			statusToast.Text = ("\240\159\148\165 TRENDY HIT! Earned $%d!"):format(cash)
			statusToast.TextColor3 = Theme.Success
			Fx.celebrate("\240\159\148\165 TRENDY HIT!", Theme.Success)
		else
			statusToast.Text = ("Released! Earned $%d."):format(cash)
			statusToast.TextColor3 = Theme.Gold
		end
	end)

	local hasReceivedInitialState = false

	Remotes.PlayerStateUpdated.OnClientEvent:Connect(function(data)
		local cashDelta = data.cash - playerState.cash

		playerState.cash = data.cash
		playerState.gamesReleased = data.gamesReleased
		playerState.houseTier = data.houseTier
		playerState.pcTier = data.pcTier
		playerState.boostUntil = data.boostUntil or 0
		playerState.boostMult = data.boostMult or 1
		playerState.boostIcon = data.boostIcon
		playerState.boostLabel = data.boostLabel
		playerState.outfitLabel = data.outfitLabel
		playerState.subscribers = data.subscribers or 0
		playerState.subMilestone = data.subMilestone or 0
		playerState.roomsOwned = data.roomsOwned or playerState.roomsOwned
		playerState.prestigeLevel = data.prestigeLevel or 0
		playerState.workers = data.workers
		refreshBoostHud()

		if not hasReceivedInitialState then
			-- The very first update is just hydrating the HUD with
			-- whatever was loaded/saved, not a cash gain -- snap straight
			-- to it instead of animating a "+$X" for the starting balance.
			hasReceivedInitialState = true
			cashCounter.Value = data.cash
			subsCounter.Value = data.subscribers or 0
			return
		end

		animateCashTo(data.cash)
		animateSubsTo(data.subscribers or 0)

		if cashDelta ~= 0 then
			playCashPop(cashDelta > 0)
			showFloatingCashDelta(cashDelta)
			if cashDelta > 0 then
				local c = coin.AbsolutePosition + coin.AbsoluteSize / 2
				Fx.coinBurst(c.X, c.Y)
			end
		end
	end)

	Remotes.SubscribersGained.OnClientEvent:Connect(function(amount, milestoneReached)
		if amount and amount > 0 then
			showSubsGained(amount)
		end
		if milestoneReached and milestoneReached > 0 then
			showMilestoneCelebration(milestoneReached)
			Fx.confetti(44)
		end
	end)

	Remotes.TrendsUpdated.OnClientEvent:Connect(function(trend1, trend2)
		updateTrendsSigns(("%s + %s\n%s + %s"):format(
			trend1.genre, trend1.topic, trend2.genre, trend2.topic
		))
	end)

	WorkersPanel.init(player, Theme, playerState)
	HousePanel.init(player, Theme, playerState)
	PCPanel.init(player, Theme, playerState)
	ShopPanel.init(player, Theme, playerState)
	DecorPanel.init(player, Theme, playerState)
	DailyRewardPanel.init(player, Theme)
	PrestigePanel.init(player, Theme, playerState)
	WorkerHub.init(player, Theme)
	StorePanel.init(player, Theme, playerState)
	VIPChat.setup()

	-- M6 polish: give every button in every panel a springy hover/press feel.
	juiceAllButtons(player:WaitForChild("PlayerGui"))
	DarkMode.init(player, playerState)

	-- M5 mobile: auto-fit every menu/HUD to the screen size (no-op on desktop).
	MobileScale.init(player)
end

return UI

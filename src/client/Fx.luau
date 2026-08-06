-- Shared celebration / particle effects (M6 juice). Manual animation only
-- (TweenService is unreliable in this project). Everything draws on a top
-- overlay ScreenGui; plain Frames don't catch clicks, so it never blocks input.
local Players = game:GetService("Players")

local Fx = {}

local CONFETTI_COLORS = {
	Color3.fromRGB(255, 99, 132),
	Color3.fromRGB(255, 205, 86),
	Color3.fromRGB(75, 220, 150),
	Color3.fromRGB(90, 160, 255),
	Color3.fromRGB(180, 120, 255),
	Color3.fromRGB(255, 140, 90),
}

local function layer()
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = pg:FindFirstChild("FxGui")
	if not gui then
		gui = Instance.new("ScreenGui")
		gui.Name = "FxGui"
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 60
		gui.IgnoreGuiInset = true
		gui.Parent = pg
	end
	return gui
end

-- A burst of confetti that rains down from the upper third and fades.
function Fx.confetti(count)
	local gui = layer()
	count = count or 32
	local pieces = {}
	for i = 1, count do
		local p = Instance.new("Frame")
		p.Size = UDim2.fromOffset(math.random(7, 13), math.random(9, 16))
		p.Position = UDim2.new(0.5 + math.random(-28, 28) / 100, 0, 0.30, 0)
		p.BackgroundColor3 = CONFETTI_COLORS[math.random(1, #CONFETTI_COLORS)]
		p.BorderSizePixel = 0
		p.Rotation = math.random(0, 360)
		p.ZIndex = 5
		p.Parent = gui
		pieces[i] = { f = p, vx = math.random(-6, 6), vy = math.random(-16, -4), vr = math.random(-18, 18) }
	end
	task.spawn(function()
		for step = 1, 72 do
			for _, pc in ipairs(pieces) do
				pc.vy += 0.55
				pc.f.Position = pc.f.Position + UDim2.fromOffset(pc.vx, pc.vy)
				pc.f.Rotation += pc.vr
				pc.f.BackgroundTransparency = math.max(0, (step - 40) / 32)
			end
			task.wait(0.02)
		end
		for _, pc in ipairs(pieces) do
			pc.f:Destroy()
		end
	end)
end

-- A big centred banner that pops in with overshoot, holds, then fades up + out.
-- Confetti fires with it.
function Fx.celebrate(text, color)
	local gui = layer()
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromOffset(620, 92)
	lbl.AnchorPoint = Vector2.new(0.5, 0.5)
	lbl.Position = UDim2.fromScale(0.5, 0.33)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = color or Color3.fromRGB(255, 209, 102)
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextScaled = true
	lbl.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
	lbl.TextStrokeTransparency = 0.35
	lbl.ZIndex = 6
	lbl.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = lbl
	Fx.confetti(36)
	task.spawn(function()
		for _, s in ipairs({ 0.2, 0.7, 1.16, 1.06, 1.0 }) do
			scale.Scale = s
			task.wait(0.03)
		end
		task.wait(0.9)
		for i = 1, 12 do
			lbl.TextTransparency = i / 12
			lbl.TextStrokeTransparency = 0.35 + 0.65 * (i / 12)
			scale.Scale = 1 + i / 22
			task.wait(0.025)
		end
		lbl:Destroy()
	end)
end

-- A few gold coins that pop out from a screen point, arc up, then fall + fade.
function Fx.coinBurst(centerX, centerY, n)
	local gui = layer()
	n = n or 7
	local coins = {}
	for i = 1, n do
		local c = Instance.new("Frame")
		c.Size = UDim2.fromOffset(15, 15)
		c.AnchorPoint = Vector2.new(0.5, 0.5)
		c.Position = UDim2.fromOffset(centerX, centerY)
		c.BackgroundColor3 = Color3.fromRGB(247, 196, 92)
		c.BorderSizePixel = 0
		c.ZIndex = 5
		local uic = Instance.new("UICorner")
		uic.CornerRadius = UDim.new(1, 0)
		uic.Parent = c
		local st = Instance.new("UIStroke")
		st.Color = Color3.fromRGB(150, 100, 30)
		st.Thickness = 1.5
		st.Parent = c
		c.Parent = gui
		coins[i] = { f = c, vx = math.random(-45, 45) / 10, vy = math.random(-60, -30) / 10 }
	end
	task.spawn(function()
		for step = 1, 34 do
			for _, cc in ipairs(coins) do
				cc.vy += 0.4
				cc.f.Position = cc.f.Position + UDim2.fromOffset(cc.vx, cc.vy)
				cc.f.BackgroundTransparency = math.max(0, (step - 18) / 16)
			end
			task.wait(0.02)
		end
		for _, cc in ipairs(coins) do
			cc.f:Destroy()
		end
	end)
end

-- Pop a GUI element in with a springy overshoot (open animation for menus).
-- Manual UIScale tween (TweenService is unreliable in this project). Safe to
-- call every time a panel opens; reuses/!resets a single UIScale child.
function Fx.popIn(guiObject)
	if not guiObject then
		return
	end
	local scale = guiObject:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Parent = guiObject
	end
	-- Animate a MULTIPLIER of whatever scale is already set and restore it, so
	-- we don't stomp MobileScale's per-panel UIScale (which shrinks panels on
	-- phones). Ending at `target`, not a hardcoded 1.0, keeps mobile correct.
	local target = scale.Scale
	if target <= 0 then target = 1 end
	task.spawn(function()
		for _, m in ipairs({ 0.6, 0.86, 1.06, 0.98, 1.0 }) do
			scale.Scale = target * m
			task.wait(0.025)
		end
		scale.Scale = target
	end)
end

-- A satisfying reward pop for buying an upgrade / hiring: a coin burst from
-- screen centre plus a little confetti. Optional banner text.
function Fx.rewardBurst(text, color)
	local cam = workspace.CurrentCamera
	local cx = cam and cam.ViewportSize.X / 2 or 400
	local cy = cam and cam.ViewportSize.Y / 2 or 300
	Fx.coinBurst(cx, cy, 9)
	Fx.confetti(18)
	if text then
		Fx.celebrate(text, color)
	end
end

return Fx

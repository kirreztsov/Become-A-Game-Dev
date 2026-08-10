-- 2D "install the part" minigame (a ScreenGui overlay). Shows the open PC case
-- with the currently-installed (or a basic stock) part sitting in its slot. Each
-- round: drag the old part OUT to the recycle bin, then drag the NEW part INTO
-- the glowing white slot. Real part models render inside 2D ViewportFrame tiles.
-- Everything is animated (slide-out, slide-in, snap bounce, pulsing slot). The
-- round cannot fail; the server applies the upgrade only on completion.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local PCVisuals = require(game.ReplicatedStorage.Shared.PCVisuals)
local GameData = require(game.ReplicatedStorage.Shared.GameData)

local PCInstallGame = {}
local active = false

local WHITE = Color3.fromRGB(255, 255, 255)
local PANEL = Color3.fromRGB(24, 26, 33)
local TILE_BG = Color3.fromRGB(34, 37, 47)
local TILE_SIZE = 128

function PCInstallGame.isActive()
	return active
end

local function partName(partId)
	local p = GameData.getPCPart(partId)
	return (p and (p.name or p.label)) or partId
end

-- Build the real 3D model for a part at a visual tier (nil-safe).
local function buildModel(partId, tier)
	local asset = PCVisuals.TIERED[partId]
	if not asset then
		return nil
	end
	local byWidth = PCVisuals.DISPLAY[partId] and PCVisuals.DISPLAY[partId].byWidth
	return PCVisuals.buildTierDisplay(asset, tier, Vector3.new(0, 0, 0), 4, 0, PCVisuals.PAINT[partId], byWidth)
end

-- A draggable tile that shows the real part inside a ViewportFrame.
local function makeTile(partId, tier, parent)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(TILE_SIZE, TILE_SIZE)
	frame.BackgroundColor3 = TILE_BG
	frame.BackgroundTransparency = 0.1
	frame.ZIndex = 6
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(120, 210, 255)
	stroke.Thickness = 2
	stroke.Parent = frame

	local vp = Instance.new("ViewportFrame")
	vp.Size = UDim2.fromScale(1, 1)
	vp.BackgroundTransparency = 1
	vp.ZIndex = 6
	vp.Parent = frame

	local model = buildModel(partId, tier)
	if model then
		model.Parent = vp
		local cam = Instance.new("Camera")
		cam.Parent = vp
		vp.CurrentCamera = cam
		local cf, size = model:GetBoundingBox()
		local dist = size.Magnitude * 0.9 + 2
		cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(dist * 0.45, dist * 0.35, dist), cf.Position)
		-- gentle turntable so the part reads as 3D
		local spin = RunService.RenderStepped:Connect(function(dt)
			if model and model.Parent then
				model:PivotTo(model:GetPivot() * CFrame.Angles(0, dt * 0.7, 0))
			end
		end)
		frame.Destroying:Connect(function()
			spin:Disconnect()
		end)
	end

	frame.Parent = parent
	return frame
end

-- Tile center in screen space (matches AbsolutePosition space of siblings).
local function centerOf(gui)
	return gui.AbsolutePosition + gui.AbsoluteSize / 2
end

local function pointInside(point, gui)
	local tl = gui.AbsolutePosition
	local br = tl + gui.AbsoluteSize
	return point.X >= tl.X and point.X <= br.X and point.Y >= tl.Y and point.Y <= br.Y
end

-- Drag `tile` until released. Returns true if the pointer was over `target` at
-- release. Yields until release or cancel.
local function dragTile(tile, target, shouldCancel)
	local dragging = false
	local released = false
	local overTarget = false
	local last

	local beginConn = tile.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			last = input.Position
			tile.ZIndex = 20
		end
	end)
	local moveConn = UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
			local delta = input.Position - last
			last = input.Position
			tile.Position = UDim2.new(
				tile.Position.X.Scale,
				tile.Position.X.Offset + delta.X,
				tile.Position.Y.Scale,
				tile.Position.Y.Offset + delta.Y
			)
		end
	end)
	local upConn = UserInputService.InputEnded:Connect(function(input)
		if not dragging then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			overTarget = target ~= nil and pointInside(centerOf(tile), target)
			released = true
		end
	end)

	while not released and not shouldCancel() do
		RunService.Heartbeat:Wait()
	end
	beginConn:Disconnect()
	moveConn:Disconnect()
	upConn:Disconnect()
	tile.ZIndex = 6
	return overTarget
end

local function tween(obj, time, props)
	local t = TweenService:Create(obj, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

-- Move a tile to a target GuiObject's center over `time` seconds.
local function tweenToCenter(tile, targetGui, time)
	local c = centerOf(targetGui)
	local parentPos = tile.Parent.AbsolutePosition
	tween(tile, time, { Position = UDim2.fromOffset(c.X - parentPos.X - TILE_SIZE / 2, c.Y - parentPos.Y - TILE_SIZE / 2) }).Completed:Wait()
end

-- One round. Returns true if installed, false if cancelled.
local function runRound(root, partId, oldTier, newTier, shouldCancel)
	-- ----- the PC case (the "box") -----
	local case = Instance.new("Frame")
	case.Name = "Case"
	case.AnchorPoint = Vector2.new(0.5, 0.5)
	case.Position = UDim2.new(0.5, -60, 0.5, 0)
	case.Size = UDim2.fromOffset(360, 440)
	case.BackgroundColor3 = PANEL
	case.BackgroundTransparency = 0.05
	case.ZIndex = 3
	case.Parent = root
	local caseCorner = Instance.new("UICorner")
	caseCorner.CornerRadius = UDim.new(0, 18)
	caseCorner.Parent = case
	local caseStroke = Instance.new("UIStroke")
	caseStroke.Color = Color3.fromRGB(70, 74, 88)
	caseStroke.Thickness = 3
	caseStroke.Parent = case
	local caseLabel = Instance.new("TextLabel")
	caseLabel.BackgroundTransparency = 1
	caseLabel.Size = UDim2.new(1, 0, 0, 34)
	caseLabel.Position = UDim2.fromOffset(0, 8)
	caseLabel.Text = "PC CASE"
	caseLabel.TextColor3 = Color3.fromRGB(150, 160, 180)
	caseLabel.Font = Enum.Font.GothamBold
	caseLabel.TextSize = 16
	caseLabel.ZIndex = 4
	caseLabel.Parent = case

	-- ----- the glowing white (neon) target slot inside the case -----
	local slot = Instance.new("Frame")
	slot.Name = "Slot"
	slot.AnchorPoint = Vector2.new(0.5, 0.5)
	slot.Position = UDim2.new(0.5, 0, 0.5, 0)
	slot.Size = UDim2.fromOffset(TILE_SIZE + 18, TILE_SIZE + 18)
	slot.BackgroundColor3 = WHITE
	slot.BackgroundTransparency = 0.7
	slot.ZIndex = 4
	slot.Parent = case
	local slotCorner = Instance.new("UICorner")
	slotCorner.CornerRadius = UDim.new(0, 16)
	slotCorner.Parent = slot
	local slotStroke = Instance.new("UIStroke")
	slotStroke.Color = WHITE
	slotStroke.Thickness = 4
	slotStroke.Parent = slot
	-- neon pulse
	local pulse = TweenService:Create(
		slotStroke,
		TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Thickness = 9 }
	)
	pulse:Play()
	local pulse2 = TweenService:Create(
		slot,
		TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ BackgroundTransparency = 0.45 }
	)
	pulse2:Play()

	-- ----- recycle bin (drop the old part here) -----
	local bin = Instance.new("Frame")
	bin.Name = "Bin"
	bin.AnchorPoint = Vector2.new(0.5, 0.5)
	bin.Position = UDim2.new(0.5, 320, 0.5, -40)
	bin.Size = UDim2.fromOffset(150, 150)
	bin.BackgroundColor3 = Color3.fromRGB(40, 30, 30)
	bin.BackgroundTransparency = 0.2
	bin.ZIndex = 3
	bin.Parent = root
	local binCorner = Instance.new("UICorner")
	binCorner.CornerRadius = UDim.new(0, 16)
	binCorner.Parent = bin
	local binStroke = Instance.new("UIStroke")
	binStroke.Color = Color3.fromRGB(235, 120, 90)
	binStroke.Thickness = 3
	binStroke.Parent = bin
	local binLabel = Instance.new("TextLabel")
	binLabel.BackgroundTransparency = 1
	binLabel.Size = UDim2.fromScale(1, 1)
	binLabel.Text = "Old part"
	binLabel.TextColor3 = Color3.fromRGB(235, 150, 130)
	binLabel.Font = Enum.Font.GothamBold
	binLabel.TextSize = 18
	binLabel.ZIndex = 4
	binLabel.Parent = bin

	-- Prompt label
	local prompt = Instance.new("TextLabel")
	prompt.BackgroundTransparency = 1
	prompt.Size = UDim2.new(1, 0, 0, 40)
	prompt.Position = UDim2.new(0, 0, 0, 70)
	prompt.TextColor3 = WHITE
	prompt.Font = Enum.Font.GothamBold
	prompt.TextSize = 24
	prompt.ZIndex = 8
	prompt.Parent = root

	-- ----- Step 1: remove the OLD part (basic stock if none owned) -----
	-- oldTier is nil at level 0; show a basic (tier-1) stock part to pull out so
	-- the case is never empty and there is always something to remove first.
	local removeTier = oldTier or 1
	local isStock = oldTier == nil
	prompt.Text = isStock and ("Take out the basic " .. partName(partId)) or ("Take out the old " .. partName(partId))

	local oldTile = makeTile(partId, removeTier, root)
	oldTile.Position = UDim2.fromOffset(
		case.AbsolutePosition.X + case.AbsoluteSize.X / 2 - TILE_SIZE / 2,
		case.AbsolutePosition.Y + case.AbsoluteSize.Y / 2 - TILE_SIZE / 2
	)
	if isStock then
		oldTile.BackgroundColor3 = Color3.fromRGB(46, 46, 52) -- greyed "stock"
	end

	while true do
		local droppedInBin = dragTile(oldTile, bin, shouldCancel)
		if shouldCancel() then
			return false
		end
		if droppedInBin then
			-- animate into the bin: shrink + fade
			tween(oldTile, 0.25, { Size = UDim2.fromOffset(20, 20), Rotation = 40 })
			for _, d in ipairs(oldTile:GetDescendants()) do
				if d:IsA("GuiObject") then
					tween(d, 0.25, { BackgroundTransparency = 1 })
				end
			end
			task.wait(0.26)
			oldTile:Destroy()
			break
		else
			tweenToCenter(oldTile, slot, 0.18) -- snap back to the slot, try again
		end
	end

	-- ----- Step 2: install the NEW part -----
	prompt.Text = "Slide the new " .. partName(partId) .. " into the glowing slot"
	local newTile = makeTile(partId, newTier, root)
	local trayX = case.AbsolutePosition.X + case.AbsoluteSize.X / 2 - TILE_SIZE / 2
	local trayY = root.AbsoluteSize.Y - TILE_SIZE - 60
	-- start below the screen and slide up onto the tray
	newTile.Position = UDim2.fromOffset(trayX, root.AbsoluteSize.Y + TILE_SIZE)
	tween(newTile, 0.35, { Position = UDim2.fromOffset(trayX, trayY) })
	task.wait(0.36)

	while true do
		local droppedInSlot = dragTile(newTile, slot, shouldCancel)
		if shouldCancel() then
			return false
		end
		if droppedInSlot then
			pulse:Cancel()
			pulse2:Cancel()
			tweenToCenter(newTile, slot, 0.16)
			-- snap bounce + slot flash
			tween(slot, 0.15, { BackgroundTransparency = 0.15, Size = UDim2.fromOffset(TILE_SIZE + 30, TILE_SIZE + 30) })
			tween(newTile, 0.12, { Size = UDim2.fromOffset(TILE_SIZE + 14, TILE_SIZE + 14) }).Completed:Wait()
			tween(newTile, 0.1, { Size = UDim2.fromOffset(TILE_SIZE, TILE_SIZE) })
			prompt.Text = "Installed!"
			task.wait(0.5)
			return true
		else
			tween(newTile, 0.18, { Position = UDim2.fromOffset(trayX, trayY) })
		end
	end
end

function PCInstallGame.run(partId, oldTier, newTier)
	if active then
		return
	end
	if not PCVisuals.TIERED[partId] then
		Remotes.PCInstallCancel:FireServer(partId)
		return
	end
	active = true

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	-- hide the HUD
	local hidden = {}
	for _, g in ipairs(playerGui:GetChildren()) do
		if g:IsA("ScreenGui") and g.Enabled then
			g.Enabled = false
			hidden[#hidden + 1] = g
		end
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "PCInstallUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.Parent = playerGui

	local backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
	backdrop.BackgroundTransparency = 0.25
	backdrop.ZIndex = 1
	backdrop.Parent = gui

	local root = Instance.new("Frame")
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.ZIndex = 2
	root.Parent = gui

	local cancelBtn = Instance.new("TextButton")
	cancelBtn.Size = UDim2.fromOffset(120, 44)
	cancelBtn.Position = UDim2.new(0, 20, 1, -64)
	cancelBtn.Text = "Cancel"
	cancelBtn.TextScaled = true
	cancelBtn.BackgroundColor3 = Color3.fromRGB(60, 62, 72)
	cancelBtn.TextColor3 = WHITE
	cancelBtn.ZIndex = 30
	cancelBtn.Parent = gui
	local cancelCorner = Instance.new("UICorner")
	cancelCorner.CornerRadius = UDim.new(0, 10)
	cancelCorner.Parent = cancelBtn
	local cancelled = false
	cancelBtn.Activated:Connect(function()
		cancelled = true
	end)

	local function cleanup()
		gui:Destroy()
		for _, g in ipairs(hidden) do
			g.Enabled = true
		end
		active = false
	end

	task.spawn(function()
		local okRun, done = pcall(runRound, root, partId, oldTier, newTier, function()
			return cancelled
		end)
		cleanup()
		if okRun and done and not cancelled then
			Remotes.PCInstallComplete:FireServer(partId)
		else
			Remotes.PCInstallCancel:FireServer(partId)
		end
	end)
end

return PCInstallGame

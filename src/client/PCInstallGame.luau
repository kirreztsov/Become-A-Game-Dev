-- Local 3D "install the part" minigame. Not replicated: everything is built on
-- the client, framed with a scriptable camera, and torn down when the round
-- ends. Drag the old part out (if any), then drag the new part into its glowing
-- slot; drop within the snap radius and it eases home. Cannot fail.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local PCInstall = require(game.ReplicatedStorage.Shared.PCInstall)
local PCVisuals = require(game.ReplicatedStorage.Shared.PCVisuals)

local PCInstallGame = {}
local active = false

function PCInstallGame.isActive()
	return active
end

local function highlight(model, color)
	local h = Instance.new("Highlight")
	h.FillColor = color
	h.OutlineColor = color
	h.FillTransparency = 0.6
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Parent = model
	return h
end

-- A glowing target marker at a world CFrame.
local function makeSlotMarker(cf, size, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.Transparency = 0.5
	p.Size = Vector3.new(size, 0.1, size)
	p.CFrame = cf
	p.Color = Color3.fromRGB(90, 220, 255)
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

-- Build a tier model, anchored non-colliding, pivoted to a world CFrame.
local function buildPart(partId, tier, worldCF)
	local asset = PCVisuals.TIERED[partId]
	local size = (PCInstall.Layout[partId] and PCInstall.Layout[partId].size) or 2.0
	local byWidth = PCVisuals.DISPLAY[partId] and PCVisuals.DISPLAY[partId].byWidth
	local model = PCVisuals.buildTierDisplay(asset, tier, worldCF.Position, size, 0, PCVisuals.PAINT[partId], byWidth)
	if model then
		model:PivotTo(worldCF)
	end
	return model
end

-- Drag `model` on a horizontal plane at height planeY until the mouse/touch is
-- released, then return the drop position. Yields.
local function dragUntilRelease(model, planeY, camera)
	local dropPos
	local released = false

	local function screenToPlane(x, y)
		local ray = camera:ViewportPointToRay(x, y)
		local dy = ray.Direction.Y
		if math.abs(dy) < 1e-4 then
			return model:GetPivot().Position
		end
		local tparam = (planeY - ray.Origin.Y) / dy
		return ray.Origin + ray.Direction * tparam
	end

	local moveConn = UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
			local pos = screenToPlane(input.Position.X, input.Position.Y)
			model:PivotTo(CFrame.new(pos.X, planeY, pos.Z))
			dropPos = pos
		end
	end)
	local upConn = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dropPos = screenToPlane(input.Position.X, input.Position.Y)
			released = true
		end
	end)

	while not released do
		RunService.Heartbeat:Wait()
	end
	moveConn:Disconnect()
	upConn:Disconnect()
	return dropPos or model:GetPivot().Position
end

-- Ease a model to a target CFrame over a few frames.
local function easeTo(model, cf)
	local start = model:GetPivot()
	local steps = 12
	for i = 1, steps do
		model:PivotTo(start:Lerp(cf, i / steps))
		RunService.Heartbeat:Wait()
	end
end

-- Run a single-part round. Returns true if installed.
local function runRound(scene, camera, partId, oldTier, newTier)
	local slotWorld = PCInstall.worldSlot(partId)
	local trayWorld = PCInstall.worldTray(partId)
	local snap = PCInstall.Layout[partId].snap
	local planeY = slotWorld.Position.Y

	local marker = makeSlotMarker(slotWorld, snap * 1.4, scene)

	-- 1. Remove the old part, if any.
	if oldTier then
		local oldModel = buildPart(partId, oldTier, slotWorld)
		if oldModel then
			oldModel.Parent = scene
			highlight(oldModel, Color3.fromRGB(255, 170, 60))
			dragUntilRelease(oldModel, planeY, camera)
			for _, d in ipairs(oldModel:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Transparency = 0.5
				end
			end
			task.wait(0.15)
			oldModel:Destroy()
		end
	end

	-- 2. Insert the new part: drag from the tray until it snaps into the slot.
	local newModel = buildPart(partId, newTier, trayWorld)
	if not newModel then
		return true -- nothing to build (defensive); treat as done
	end
	newModel.Parent = scene
	highlight(newModel, Color3.fromRGB(90, 220, 255))

	while true do
		local drop = dragUntilRelease(newModel, planeY, camera)
		if PCInstall.isWithinSnap(drop, slotWorld.Position, snap) then
			easeTo(newModel, slotWorld)
			marker.Transparency = 1
			task.wait(0.3)
			return true
		else
			easeTo(newModel, trayWorld) -- eases back, try again
		end
	end
end

function PCInstallGame.run(partId, oldTier, newTier)
	if active then
		return
	end
	if not PCInstall.Layout[partId] then
		Remotes.PCInstallCancel:FireServer(partId)
		return
	end
	active = true

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local camera = workspace.CurrentCamera

	-- hide HUD
	local hidden = {}
	for _, g in ipairs(playerGui:GetChildren()) do
		if g:IsA("ScreenGui") and g.Enabled then
			g.Enabled = false
			hidden[#hidden + 1] = g
		end
	end
	local prevCamType = camera.CameraType
	local prevCamCF = camera.CFrame
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = PCInstall.worldCamera(partId)

	local scene = Instance.new("Folder")
	scene.Name = "PCInstallScene"
	scene.Parent = workspace

	-- Cancel button
	local ui = Instance.new("ScreenGui")
	ui.Name = "PCInstallUI"
	ui.ResetOnSpawn = false
	ui.Parent = playerGui
	local cancelBtn = Instance.new("TextButton")
	cancelBtn.Size = UDim2.fromOffset(120, 44)
	cancelBtn.Position = UDim2.new(0, 20, 1, -64)
	cancelBtn.Text = "Cancel"
	cancelBtn.TextScaled = true
	cancelBtn.BackgroundColor3 = Color3.fromRGB(60, 62, 72)
	cancelBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	cancelBtn.Parent = ui
	local cancelled = false
	cancelBtn.Activated:Connect(function()
		cancelled = true
	end)

	local function cleanup()
		scene:Destroy()
		ui:Destroy()
		camera.CameraType = prevCamType
		camera.CFrame = prevCamCF
		for _, g in ipairs(hidden) do
			g.Enabled = true
		end
		active = false
	end

	task.spawn(function()
		local done = runRound(scene, camera, partId, oldTier, newTier)
		cleanup()
		if cancelled or not done then
			Remotes.PCInstallCancel:FireServer(partId)
		else
			Remotes.PCInstallComplete:FireServer(partId)
		end
	end)
end

return PCInstallGame

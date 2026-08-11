-- 3D "install the part" minigame, played AT the workbench. When it starts the
-- camera moves to the bench, your character is placed at the bench facing it, a
-- real open PC tower sits on the bench with a glowing white NEON slot inside,
-- plus a parts tray and a recycle bin. Drag the old (or basic stock) part out to
-- the bin, then drag the new part into the slot; parts animate as they move.
-- Cannot fail. The server applies the upgrade only when the round completes.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local PCInstall = require(game.ReplicatedStorage.Shared.PCInstall)
local PCVisuals = require(game.ReplicatedStorage.Shared.PCVisuals)
local GameData = require(game.ReplicatedStorage.Shared.GameData)

local PCInstallGame = {}
local active = false

local WHITE = Color3.fromRGB(255, 255, 255)

function PCInstallGame.isActive()
	return active
end

local function partName(partId)
	local p = GameData.getPCPart(partId)
	return (p and (p.name or p.label)) or partId
end

local function newPart(name, size, cf, color, material, parent, scene)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Parent = parent or scene
	return p
end

-- Build a simple open PC tower (back + bottom + top + left + a motherboard),
-- front and right left open so the interior + slot are visible. Returns the
-- interior slot's world CFrame.
local function buildCase(benchCF, scene)
	local model = Instance.new("Model")
	model.Name = "InstallCase"
	model.Parent = scene
	local caseColor = Color3.fromRGB(30, 32, 40)
	-- interior origin: sits on the bench top, pushed slightly back
	local o = benchCF * CFrame.new(0, 1.7, -0.2)
	newPart("CaseBack", Vector3.new(3.2, 3.4, 0.2), o * CFrame.new(0, 0, -1.3), caseColor, Enum.Material.SmoothPlastic, model)
	newPart("CaseBottom", Vector3.new(3.2, 0.2, 2.6), o * CFrame.new(0, -1.7, 0), caseColor, Enum.Material.SmoothPlastic, model)
	newPart("CaseTop", Vector3.new(3.2, 0.2, 2.6), o * CFrame.new(0, 1.7, 0), caseColor, Enum.Material.SmoothPlastic, model)
	newPart("CaseLeft", Vector3.new(0.2, 3.4, 2.6), o * CFrame.new(-1.5, 0, 0), caseColor, Enum.Material.SmoothPlastic, model)
	newPart("CaseBoard", Vector3.new(2.6, 3.0, 0.15), o * CFrame.new(0, 0, -1.1), Color3.fromRGB(28, 66, 48), Enum.Material.SmoothPlastic, model)
	-- glowing white NEON slot marker on the motherboard
	local slot = newPart("Slot", Vector3.new(1.7, 1.7, 0.12), o * CFrame.new(0, 0, -0.95), WHITE, Enum.Material.Neon, model)
	slot.Transparency = 0.35
	return model, slot.CFrame, o
end

-- A pad (tray / bin) on the bench.
local function buildPad(name, cf, color, scene)
	local pad = newPart(name, Vector3.new(2.2, 0.15, 2.2), cf, color, Enum.Material.SmoothPlastic, scene)
	pad.Transparency = 0.2
	local sel = Instance.new("SelectionBox")
	sel.Adornee = pad
	sel.Color3 = color
	sel.LineThickness = 0.05
	sel.Parent = pad
	return pad
end

local function buildPartModel(partId, tier, worldCF)
	local asset = PCVisuals.TIERED[partId]
	if not asset then
		return nil
	end
	local byWidth = PCVisuals.DISPLAY[partId] and PCVisuals.DISPLAY[partId].byWidth
	local m = PCVisuals.buildTierDisplay(asset, tier, worldCF.Position, 1.9, 0, PCVisuals.PAINT[partId], byWidth)
	if m then
		m:PivotTo(worldCF)
	end
	return m
end

-- Drag a model on the horizontal plane at planeY. Press-and-hold to grab;
-- ignores UI-handled inputs; returns the drop position. Cancel-aware.
local function dragModel(model, planeY, camera, shouldCancel)
	local dropPos = model:GetPivot().Position
	local dragging = false
	local released = false

	local function toPlane(x, y)
		local ray = camera:ViewportPointToRay(x, y)
		local dy = ray.Direction.Y
		if math.abs(dy) < 1e-4 then
			return model:GetPivot().Position
		end
		local t = (planeY - ray.Origin.Y) / dy
		return ray.Origin + ray.Direction * t
	end

	local beginConn = UserInputService.InputBegan:Connect(function(input, gp)
		if gp then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dropPos = toPlane(input.Position.X, input.Position.Y)
			model:PivotTo(CFrame.new(dropPos.X, planeY, dropPos.Z))
		end
	end)
	local moveConn = UserInputService.InputChanged:Connect(function(input, gp)
		if not dragging or gp then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
			dropPos = toPlane(input.Position.X, input.Position.Y)
			model:PivotTo(CFrame.new(dropPos.X, planeY, dropPos.Z))
		end
	end)
	local upConn = UserInputService.InputEnded:Connect(function(input)
		if not dragging then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dropPos = toPlane(input.Position.X, input.Position.Y)
			released = true
		end
	end)

	while not released and not shouldCancel() do
		RunService.Heartbeat:Wait()
	end
	beginConn:Disconnect()
	moveConn:Disconnect()
	upConn:Disconnect()
	return dropPos
end

-- Slide a model to a target CFrame over a few frames; cancel-aware.
local function slideTo(model, targetCF, shouldCancel)
	local start = model:GetPivot()
	for i = 1, 12 do
		if shouldCancel and shouldCancel() then
			return
		end
		model:PivotTo(start:Lerp(targetCF, i / 12))
		RunService.Heartbeat:Wait()
	end
	model:PivotTo(targetCF)
end

local function near(a, b, r)
	return (a - b).Magnitude <= r
end

-- One round. Returns true if installed, false if cancelled.
local function runRound(scene, benchCF, camera, prompt, partId, oldTier, newTier, shouldCancel)
	local _, slotCF = buildCase(benchCF, scene)
	local trayCF = benchCF * CFrame.new(-2.6, 0.25, 1.6)
	local binCF = benchCF * CFrame.new(2.6, 0.25, 1.6)
	buildPad("Tray", trayCF, Color3.fromRGB(90, 200, 255), scene)
	local binPad = buildPad("Bin", binCF, Color3.fromRGB(235, 120, 90), scene)
	local planeY = slotCF.Position.Y

	-- Step 1: remove the old (or basic stock) part sitting in the slot.
	local removeTier = oldTier or 1
	local isStock = oldTier == nil
	prompt.Text = isStock and ("Pull the basic " .. partName(partId) .. " out to the red pad")
		or ("Pull the old " .. partName(partId) .. " out to the red pad")
	local oldModel = buildPartModel(partId, removeTier, slotCF)
	if oldModel then
		oldModel.Parent = scene
		while true do
			local drop = dragModel(oldModel, planeY, camera, shouldCancel)
			if shouldCancel() then
				return false
			end
			if near(drop, binCF.Position, 2.0) then
				slideTo(oldModel, binCF * CFrame.new(0, 0.6, 0), shouldCancel)
				for _, p in ipairs(oldModel:GetDescendants()) do
					if p:IsA("BasePart") then
						p.Transparency = 0.6
					end
				end
				binPad.Color = Color3.fromRGB(120, 220, 130)
				task.wait(0.2)
				oldModel:Destroy()
				break
			else
				slideTo(oldModel, slotCF, shouldCancel) -- snap back, try again
			end
		end
	end

	-- Step 2: install the new part from the tray into the slot.
	prompt.Text = "Now slide the new " .. partName(partId) .. " into the glowing slot"
	local newModel = buildPartModel(partId, newTier, trayCF * CFrame.new(0, 0.8, 0))
	if not newModel then
		return true
	end
	newModel.Parent = scene
	while true do
		local drop = dragModel(newModel, planeY, camera, shouldCancel)
		if shouldCancel() then
			return false
		end
		if near(drop, slotCF.Position, 2.0) then
			slideTo(newModel, slotCF, shouldCancel)
			prompt.Text = "Installed!"
			task.wait(0.5)
			return true
		else
			slideTo(newModel, trayCF * CFrame.new(0, 0.8, 0), shouldCancel)
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
	local camera = workspace.CurrentCamera
	local benchCF = PCInstall.BenchCFrame

	-- hide the HUD
	local hidden = {}
	for _, g in ipairs(playerGui:GetChildren()) do
		if g:IsA("ScreenGui") and g.Enabled then
			g.Enabled = false
			hidden[#hidden + 1] = g
		end
	end

	-- move the character to the bench (keep their Y so they don't fall), face it
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local savedCF, savedAnchor
	if hrp then
		savedCF = hrp.CFrame
		savedAnchor = hrp.Anchored
		local standPos = (benchCF * CFrame.new(0, 0, 3.2)).Position
		hrp.CFrame = CFrame.lookAt(Vector3.new(standPos.X, savedCF.Position.Y, standPos.Z), benchCF.Position)
		hrp.Anchored = true
	end

	local prevCamType = camera.CameraType
	local prevCamCF = camera.CFrame
	camera.CameraType = Enum.CameraType.Scriptable
	-- frame the bench + the character from front-right, slightly above
	camera.CFrame = CFrame.lookAt((benchCF * CFrame.new(4.5, 3.2, 5.5)).Position, (benchCF * CFrame.new(0, 1.3, 0)).Position)

	local scene = Instance.new("Folder")
	scene.Name = "PCInstallScene"
	scene.Parent = workspace

	-- prompt + cancel UI
	local ui = Instance.new("ScreenGui")
	ui.Name = "PCInstallUI"
	ui.ResetOnSpawn = false
	ui.IgnoreGuiInset = true
	ui.DisplayOrder = 50
	ui.Parent = playerGui
	local prompt = Instance.new("TextLabel")
	prompt.BackgroundColor3 = Color3.fromRGB(15, 17, 24)
	prompt.BackgroundTransparency = 0.25
	prompt.Size = UDim2.new(1, -80, 0, 56)
	prompt.Position = UDim2.new(0, 40, 0, 40)
	prompt.TextColor3 = WHITE
	prompt.Font = Enum.Font.GothamBold
	prompt.TextSize = 26
	prompt.Text = ""
	prompt.Parent = ui
	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0, 12)
	pc.Parent = prompt
	local cancelBtn = Instance.new("TextButton")
	cancelBtn.Size = UDim2.fromOffset(120, 44)
	cancelBtn.Position = UDim2.new(0, 20, 1, -64)
	cancelBtn.Text = "Cancel"
	cancelBtn.TextScaled = true
	cancelBtn.BackgroundColor3 = Color3.fromRGB(60, 62, 72)
	cancelBtn.TextColor3 = WHITE
	cancelBtn.Parent = ui
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, 10)
	cc.Parent = cancelBtn
	local cancelled = false
	cancelBtn.Activated:Connect(function()
		cancelled = true
	end)

	local function cleanup()
		scene:Destroy()
		ui:Destroy()
		camera.CameraType = prevCamType
		camera.CFrame = prevCamCF
		if hrp then
			hrp.Anchored = savedAnchor
			hrp.CFrame = savedCF
		end
		for _, g in ipairs(hidden) do
			g.Enabled = true
		end
		active = false
	end

	task.spawn(function()
		local okRun, done = pcall(runRound, scene, benchCF, camera, prompt, partId, oldTier, newTier, function()
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

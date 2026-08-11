-- 3D "install the part" minigame at the workbench. Click-to-install: click the
-- part in the case and it flies from the slot to your character's hand and into
-- the recycle bin; then click the new part on the tray and it flies through your
-- hand into the glowing white NEON slot. Your character reaches as it happens.
-- Cannot fail. The server applies the upgrade only when the round completes.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

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

local function newPart(name, size, cf, color, material, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Parent = parent
	return p
end

local function buildCase(benchCF, scene)
	local model = Instance.new("Model")
	model.Name = "InstallCase"
	model.Parent = scene
	local caseColor = Color3.fromRGB(38, 40, 50)
	local o = benchCF * CFrame.new(0, 1.7, -0.2)
	-- shell (front + right stay open so you can reach in and see the slot)
	newPart("CaseBack", Vector3.new(3.3, 3.5, 0.2), o * CFrame.new(0, 0, -1.3), caseColor, Enum.Material.Metal, model)
	newPart("CaseBottom", Vector3.new(3.5, 0.25, 2.8), o * CFrame.new(0, -1.78, 0), caseColor, Enum.Material.Metal, model)
	newPart("CaseTop", Vector3.new(3.5, 0.25, 2.8), o * CFrame.new(0, 1.78, 0), caseColor, Enum.Material.Metal, model)
	newPart("CaseLeft", Vector3.new(0.2, 3.5, 2.8), o * CFrame.new(-1.55, 0, 0), caseColor, Enum.Material.Metal, model)
	-- tinted glass right side panel
	local glass = newPart("CaseGlass", Vector3.new(0.12, 3.2, 2.5), o * CFrame.new(1.55, 0, 0.1), Color3.fromRGB(150, 205, 235), Enum.Material.Glass, model)
	glass.Transparency = 0.55
	glass.Reflectance = 0.15
	-- motherboard + chip detail
	newPart("CaseBoard", Vector3.new(2.7, 3.1, 0.15), o * CFrame.new(0, 0, -1.1), Color3.fromRGB(22, 58, 42), Enum.Material.SmoothPlastic, model)
	for i = -1, 1 do
		newPart("Chip" .. i, Vector3.new(0.5, 0.5, 0.08), o * CFrame.new(i * 0.85, -1.05, -1.0), Color3.fromRGB(18, 20, 26), Enum.Material.SmoothPlastic, model)
	end
	-- RGB accent bar (SmoothPlastic -- Neon blooms to white in this game's lighting)
	newPart("CaseRGB", Vector3.new(3.0, 0.16, 0.16), o * CFrame.new(0, 1.6, 1.25), Color3.fromRGB(120, 220, 255), Enum.Material.SmoothPlastic, model)
	-- glowing white NEON slot (white neon reads as a bright glow, as requested)
	local slot = newPart("Slot", Vector3.new(1.7, 1.7, 0.12), o * CFrame.new(0, 0.25, -0.95), WHITE, Enum.Material.Neon, model)
	slot.Transparency = 0.3
	local slotLight = Instance.new("PointLight")
	slotLight.Color = WHITE
	slotLight.Brightness = 3
	slotLight.Range = 11
	slotLight.Parent = slot
	TweenService:Create(slot, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.65 }):Play()
	-- warm interior fill light so the parts read clearly (fixes the dark look)
	local anchor = newPart("CaseLightAnchor", Vector3.new(0.2, 0.2, 0.2), o * CFrame.new(0, 0.4, 0.6), caseColor, Enum.Material.SmoothPlastic, model)
	anchor.Transparency = 1
	local fill = Instance.new("PointLight")
	fill.Color = Color3.fromRGB(255, 248, 235)
	fill.Brightness = 2.6
	fill.Range = 13
	fill.Parent = anchor
	return model, slot.CFrame
end

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

-- Make every part of the model clickable; resolves when clicked (or cancelled).
local function waitForClick(model, shouldCancel)
	local clicked = false
	local conns = {}
	local glow = Instance.new("Highlight")
	glow.FillColor = Color3.fromRGB(120, 220, 255)
	glow.FillTransparency = 0.5
	glow.OutlineColor = WHITE
	glow.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	glow.Parent = model
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			local cd = Instance.new("ClickDetector")
			cd.MaxActivationDistance = 1000
			cd.CursorIcon = "rbxasset://textures/GunCursor.png"
			cd.Parent = p
			conns[#conns + 1] = cd.MouseClick:Connect(function()
				clicked = true
			end)
		end
	end
	while not clicked and not shouldCancel() do
		RunService.Heartbeat:Wait()
	end
	for _, c in ipairs(conns) do
		c:Disconnect()
	end
	if glow then
		glow:Destroy()
	end
	return clicked and not shouldCancel()
end

-- Slide a model smoothly through a list of world CFrames.
local function flyThrough(model, cfs, shouldCancel)
	for _, target in ipairs(cfs) do
		local start = model:GetPivot()
		for i = 1, 14 do
			if shouldCancel and shouldCancel() then
				return
			end
			model:PivotTo(start:Lerp(target, i / 14))
			RunService.Heartbeat:Wait()
		end
		model:PivotTo(target)
	end
end

-- Make the character reach toward the case by PLAYING a real animation through
-- the Animator (priority Action, so it layers over the idle instead of fighting
-- it -- fighting was the earlier "drugged" look). Uses a Roblox-owned public
-- animation, so nothing needs uploading. Returns a stop() function.
local REACH_ANIM_ID = "rbxassetid://507770453" -- Roblox "Point": arm extends forward
local function playReach(char)
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not animator then
		return function() end
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = REACH_ANIM_ID
	local ok, track = pcall(function()
		return animator:LoadAnimation(anim)
	end)
	if not ok or not track then
		return function() end
	end
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = true
	track:Play(0.15)
	return function()
		track:Stop(0.25)
		task.delay(0.4, function()
			anim:Destroy()
		end)
	end
end

-- One round. Returns true if installed, false if cancelled.
local function runRound(scene, benchCF, prompt, char, partId, oldTier, newTier, shouldCancel)
	local _, slotCF = buildCase(benchCF, scene)
	local trayCF = benchCF * CFrame.new(-2.6, 0.9, 1.6)
	local binCF = benchCF * CFrame.new(2.6, 0.9, 1.6)
	buildPad("Tray", benchCF * CFrame.new(-2.6, 0.25, 1.6), Color3.fromRGB(90, 200, 255), scene)
	local binPad = buildPad("Bin", benchCF * CFrame.new(2.6, 0.25, 1.6), Color3.fromRGB(235, 120, 90), scene)
	local handCF = benchCF * CFrame.new(0, 0.6, 2.4) -- roughly where the character's hands are

	-- Step 1: click the old (or basic stock) part to pull it out.
	local removeTier = oldTier or 1
	local isStock = oldTier == nil
	prompt.Text = isStock and ("CLICK the basic " .. partName(partId) .. " to take it out")
		or ("CLICK the old " .. partName(partId) .. " to take it out")
	local oldModel = buildPartModel(partId, removeTier, slotCF)
	if oldModel then
		oldModel.Parent = scene
		if not waitForClick(oldModel, shouldCancel) then
			return false
		end
		local stopReach = playReach(char)
		flyThrough(oldModel, { handCF, binCF }, shouldCancel)
		stopReach()
		for _, p in ipairs(oldModel:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Transparency = 0.6
			end
		end
		binPad.Color = Color3.fromRGB(120, 220, 130)
		task.wait(0.2)
		oldModel:Destroy()
	end
	if shouldCancel() then
		return false
	end

	-- Step 2: click the new part to install it into the glowing slot.
	prompt.Text = "CLICK the new " .. partName(partId) .. " to install it"
	local newModel = buildPartModel(partId, newTier, trayCF)
	if not newModel then
		return true
	end
	newModel.Parent = scene
	if not waitForClick(newModel, shouldCancel) then
		return false
	end
	local stopReach2 = playReach(char)
	flyThrough(newModel, { handCF, slotCF }, shouldCancel)
	stopReach2()
	prompt.Text = "Installed!"
	task.wait(0.6)
	return true
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

	local hidden = {}
	for _, g in ipairs(playerGui:GetChildren()) do
		if g:IsA("ScreenGui") and g.Enabled then
			g.Enabled = false
			hidden[#hidden + 1] = g
		end
	end

	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local savedCF, savedAnchor, standCF
	if hrp then
		savedCF = hrp.CFrame
		savedAnchor = hrp.Anchored
		local standPos = (benchCF * CFrame.new(0, 0, 3.2)).Position
		standCF = CFrame.lookAt(Vector3.new(standPos.X, savedCF.Position.Y, standPos.Z), benchCF.Position)
		hrp.CFrame = standCF
		hrp.Anchored = true
	end

	local prevType, prevCF = camera.CameraType, camera.CFrame
	camera.CameraType = Enum.CameraType.Scriptable
	-- FIRST PERSON: sit at the character's eyes looking into the open case, so
	-- you see your own arm reach in. standCF's -Z faces the case.
	local eyeCF = (standCF or benchCF * CFrame.new(0, 0, 3.2)) * CFrame.new(0, 1.5, -0.6)
	camera.CFrame = CFrame.lookAt(eyeCF.Position, (benchCF * CFrame.new(0, 1.6, -0.2)).Position)

	local scene = Instance.new("Folder")
	scene.Name = "PCInstallScene"
	scene.Parent = workspace

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
		camera.CameraType = prevType
		camera.CFrame = prevCF
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
		local ok, done = pcall(runRound, scene, benchCF, prompt, char, partId, oldTier, newTier, function()
			return cancelled
		end)
		cleanup()
		if ok and done and not cancelled then
			Remotes.PCInstallComplete:FireServer(partId)
		else
			Remotes.PCInstallCancel:FireServer(partId)
		end
	end)
end

return PCInstallGame

-- 3D "install the part" minigame at the workbench. Click-to-install: click the
-- part in the case and it flies from the slot to your character's hand and into
-- the recycle bin; then click the new part on the tray and it flies through your
-- hand into the glowing white NEON slot. Your character reaches as it happens.
-- Cannot fail. The server applies the upgrade only when the round completes.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local Sound = require(script.Parent.Sound)
local PCInstall = require(game.ReplicatedStorage.Shared.PCInstall)
local PCVisuals = require(game.ReplicatedStorage.Shared.PCVisuals)
local GameData = require(game.ReplicatedStorage.Shared.GameData)

local PCInstallGame = {}
local active = false
local WHITE = Color3.fromRGB(255, 255, 255)

-- Where each part sits inside the case, as a LOCAL offset from the case interior
-- origin `o`. The Z (depth) differs per part, so the camera/hand goes deeper for
-- some parts than others.
local SLOT_OFFSETS = {
	-- INSIDE the tower, spread out like a real motherboard (viewed from the open
	-- side). These meshes pivot at their BASE, so Y is the base height. Tuned so
	-- each part sits in its own zone -- no overlaps, nothing poking through walls.
	CPU = CFrame.new(-0.7, 0.25, -0.7), -- socket, upper-left against the board
	Cooling = CFrame.new(-0.7, -0.1, 0.3), -- cooler, in front of the CPU
	RAM = CFrame.new(0.5, 0.2, -0.7), -- sticks, upper-right against the board
	GPU = CFrame.new(0.1, -1.15, -0.15), -- long card, lower-center
	Storage = CFrame.new(1.0, -1.2, -0.55), -- drive, bottom-right by the glass
	-- Monitor + RGB are NOT installed inside the tower: they have their own actions
	-- (Monitor -> mounts on a stand in front; RGB -> swaps the whole tower). See runRound.
}

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

local function buildCase(benchCF, scene, currentPartId)
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
	local slotOff = SLOT_OFFSETS[currentPartId] or CFrame.new(0, 0.25, -0.95)
	local slotCF = o * slotOff -- destination for the part; no visible marker (click-to-install, no dragging)
	-- warm interior fill light so the parts read clearly (fixes the dark look)
	local anchor = newPart("CaseLightAnchor", Vector3.new(0.2, 0.2, 0.2), o * CFrame.new(0, 0.4, 0.6), caseColor, Enum.Material.SmoothPlastic, model)
	anchor.Transparency = 1
	local fill = Instance.new("PointLight")
	fill.Color = Color3.fromRGB(255, 248, 235)
	fill.Brightness = 0.7
	fill.Range = 9
	fill.Parent = anchor
	-- shell/glass must NOT block clicks -- otherwise the glass panel eats the click
	-- meant for the part behind it (you had to aim off the part to click it).
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanQuery = false
		end
	end
	return model, slotCF, o
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

local function buildPartModel(partId, tier, worldCF, size)
	local asset = PCVisuals.TIERED[partId]
	if not asset then
		return nil
	end
	local byWidth = PCVisuals.DISPLAY[partId] and PCVisuals.DISPLAY[partId].byWidth
	local m = PCVisuals.buildTierDisplay(asset, tier, worldCF.Position, size or 1.9, 0, PCVisuals.PAINT[partId], byWidth)
	if m then
		m:PivotTo(worldCF)
	end
	return m
end

-- Make every part of the model clickable; resolves when clicked (or cancelled).
local function waitForClick(model, shouldCancel)
	local clicked = false
	local glow = Instance.new("Highlight")
	glow.FillColor = Color3.fromRGB(120, 220, 255)
	glow.FillTransparency = 0.5
	glow.OutlineColor = WHITE
	glow.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	glow.Parent = model
	-- invisible click target sized to the part itself. Parented OUTSIDE the model
	-- so the Highlight above traces only the real mesh (not a big box). A small
	-- margin keeps tiny parts (RAM/Storage) easy to click.
	local cf, size = model:GetBoundingBox()
	local hit = Instance.new("Part")
	hit.Anchored = true
	hit.CanCollide = false
	hit.Transparency = 1
	hit.Size = size + Vector3.new(0.2, 0.2, 0.2)
	hit.CFrame = cf
	hit.Parent = model.Parent
	local cd = Instance.new("ClickDetector")
	cd.MaxActivationDistance = 1000
	cd.Parent = hit
	local conn = cd.MouseClick:Connect(function()
		clicked = true
		Sound.play("Click")
	end)
	while not clicked and not shouldCancel() do
		RunService.Heartbeat:Wait()
	end
	conn:Disconnect()
	hit:Destroy()
	if glow then
		glow:Destroy()
	end
	return clicked and not shouldCancel()
end

-- Smoothly tween the scriptable camera to a target CFrame.
local function tweenCam(camera, targetCF, time)
	TweenService:Create(camera, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = targetCF }):Play()
end

-- Slide a model smoothly through a list of world CFrames. If `camera` is given,
-- the camera follows the moving part (a little behind + above) for a cinematic.
local FLY_STEPS = 40 -- higher = slower, smoother movement
local function flyThrough(model, cfs, shouldCancel, camera, camOffset)
	for _, target in ipairs(cfs) do
		local start = model:GetPivot()
		for i = 1, FLY_STEPS do
			if shouldCancel and shouldCancel() then
				return
			end
			model:PivotTo(start:Lerp(target, i / FLY_STEPS))
			if camera and camOffset then
				local p = model:GetPivot().Position
				-- follow from the FRONT (aisle side), easing smoothly (no jerk)
				camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(p + camOffset, p), 0.15)
			end
			RunService.Heartbeat:Wait()
		end
		model:PivotTo(target)
	end
end

-- Press a part down into its slot with a small overshoot + settle ("click in").
local function pressIn(model, slotCF, shouldCancel)
	local overshoot = slotCF * CFrame.new(0, -0.14, 0)
	local a = model:GetPivot()
	for i = 1, 9 do -- push down (a touch past the slot)
		if shouldCancel and shouldCancel() then
			return
		end
		model:PivotTo(a:Lerp(overshoot, i / 9))
		RunService.Heartbeat:Wait()
	end
	for i = 1, 7 do -- settle back up into place
		if shouldCancel and shouldCancel() then
			return
		end
		model:PivotTo(overshoot:Lerp(slotCF, i / 7))
		RunService.Heartbeat:Wait()
	end
	model:PivotTo(slotCF)
end

-- A spark burst at a world CFrame (satisfying "it clicked in" payoff).
local function seatBurst(cf, scene)
	local fx = newPart("FX", Vector3.new(0.4, 0.4, 0.4), cf, WHITE, Enum.Material.Neon, scene)
	fx.Transparency = 1
	local att = Instance.new("Attachment")
	att.Parent = fx
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Rate = 0
	pe.Lifetime = NumberRange.new(0.4, 0.7)
	pe.Speed = NumberRange.new(7, 12)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Color = ColorSequence.new(WHITE)
	pe.Size = NumberSequence.new(0.6)
	pe.Parent = att
	pe:Emit(40)
	task.delay(1.2, function()
		fx:Destroy()
	end)
end

-- Make the character reach toward the case by PLAYING a real animation through
-- the Animator (priority Action, so it layers over the idle instead of fighting
-- it -- fighting was the earlier "drugged" look). Uses a Roblox-owned public
-- animation, so nothing needs uploading. Returns a stop() function.
-- A chunky screwdriver that descends onto the just-seated part at the slot and
-- twists it in (a couple of turns with a little dip), then lifts away. This is
-- the camera's focal point, so it's always visible -- no hand-rig guesswork.
-- `topLocalY` is how far above the slot base the part's top sits.
local function driveScrew(slotCF, topLocalY, scene, shouldCancel)
	local tipPos = slotCF.Position + Vector3.new(0, topLocalY, 0)
	local model = Instance.new("Model")
	model.Name = "ScrewIn"
	model.Parent = scene
	-- built pointing DOWN (-Y): tip at tipPos, handle above it
	newPart("SDHandle", Vector3.new(0.26, 0.7, 0.26), CFrame.new(tipPos + Vector3.new(0, 0.95, 0)), Color3.fromRGB(225, 70, 70), Enum.Material.SmoothPlastic, model)
	newPart("SDShaft", Vector3.new(0.1, 0.62, 0.1), CFrame.new(tipPos + Vector3.new(0, 0.46, 0)), Color3.fromRGB(190, 195, 205), Enum.Material.Metal, model)
	newPart("SDTip", Vector3.new(0.15, 0.16, 0.15), CFrame.new(tipPos + Vector3.new(0, 0.09, 0)), Color3.fromRGB(150, 155, 165), Enum.Material.Metal, model)
	local startCF = model:GetPivot()
	local downCF = startCF * CFrame.new(0, -0.22, 0) -- press down as it turns
	local turns = 26
	for i = 1, turns do
		if shouldCancel and shouldCancel() then
			break
		end
		if i == 1 or i % 9 == 0 then
			Sound.play("MinigameTap") -- ratchet taps as it screws in
		end
		local a = i / turns
		model:PivotTo(startCF:Lerp(downCF, math.sin(a * math.pi)) * CFrame.Angles(0, a * math.pi * 4, 0)) -- 2 turns + dip
		RunService.Heartbeat:Wait()
	end
	-- lift away
	local up = startCF * CFrame.new(0, 1.5, 0)
	for i = 1, 10 do
		if shouldCancel and shouldCancel() then
			break
		end
		model:PivotTo(model:GetPivot():Lerp(up, i / 10))
		RunService.Heartbeat:Wait()
	end
	model:Destroy()
end

local REACH_ANIM_ID = "rbxassetid://507770453" -- Roblox "Point": arm extends forward
local function playReach(char)
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")

	-- Body lean: the anchored character leans forward + dips slightly toward the
	-- bench so the reach reads as effort, then eases back on stop. Runs regardless
	-- of whether the emote track loads.
	local restCF = hrp and hrp.CFrame
	local leanConn
	if hrp and restCF then
		local target = restCF * CFrame.new(0, -0.12, -0.5) * CFrame.Angles(math.rad(-10), 0, 0)
		local t = 0
		leanConn = RunService.Heartbeat:Connect(function(dt)
			t = math.min(1, t + dt * 4)
			hrp.CFrame = restCF:Lerp(target, t)
		end)
	end

	local anim, track
	if animator then
		anim = Instance.new("Animation")
		anim.AnimationId = REACH_ANIM_ID
		local ok, loaded = pcall(function()
			return animator:LoadAnimation(anim)
		end)
		if ok and loaded then
			track = loaded
			track.Priority = Enum.AnimationPriority.Action
			track.Looped = true
			track:Play(0.15)
		end
	end

	return function()
		if leanConn then
			leanConn:Disconnect()
		end
		if hrp and restCF then
			-- ease back to the resting pose
			local from = hrp.CFrame
			task.spawn(function()
				for i = 1, 10 do
					hrp.CFrame = from:Lerp(restCF, i / 10)
					RunService.Heartbeat:Wait()
				end
				hrp.CFrame = restCF
			end)
		end
		if track then
			track:Stop(0.25)
		end
		if anim then
			task.delay(0.4, function()
				anim:Destroy()
			end)
		end
	end
end

-- Display size per part: internal parts stay small so they fit inside the tower
-- (no poking through the walls); Monitor + Case sit outside, so they can be big.
local function partSize(id)
	if id == "RGB" then
		return 3.0 -- the whole tower, swapped as one piece
	end
	if id == "Monitor" then
		return 2.4 -- mounts on its own stand out front
	end
	if id == "RAM" or id == "Storage" then
		return 0.9
	end
	if id == "Cooling" then
		return 1.05
	end
	return 1.25
end

-- One round. Returns true if installed, false if cancelled.
-- Three flavors of install: internal parts seat INSIDE the tower; the Monitor
-- mounts on its own stand out front; the RGB case SWAPS the whole tower.
local function runRound(scene, benchCF, camera, prompt, char, partId, oldTier, newTier, ownedParts, shouldCancel)
	local overviewCF = CFrame.lookAt((benchCF * CFrame.new(6.5, 2.7, 3.8)).Position, (benchCF * CFrame.new(0, 1.2, -0.1)).Position)
	-- follow-camera offset on the FRONT (aisle) side, a bit up and back toward the player
	local camOff = (benchCF * CFrame.new(0, 2, 6)).Position - benchCF.Position

	local mode = (partId == "RGB" and "tower") or (partId == "Monitor" and "monitor") or "internal"
	local o = benchCF * CFrame.new(0, 1.7, -0.2) -- tower interior origin (matches buildCase)
	local slotCF

	if mode == "tower" then
		-- Swapping the WHOLE tower: no small shell -- the tower mesh IS the case.
		-- These meshes pivot at their BASE, so seat the base on the bench (Y ~= bench top).
		slotCF = benchCF * CFrame.new(0, 0.02, -0.2)
		local anchor = newPart("SceneLight", Vector3.new(0.2, 0.2, 0.2), o * CFrame.new(0, 0.4, 1.4), WHITE, Enum.Material.SmoothPlastic, scene)
		anchor.Transparency = 1
		local fill = Instance.new("PointLight")
		fill.Color = Color3.fromRGB(255, 248, 235)
		fill.Brightness = 0.8
		fill.Range = 13
		fill.Parent = anchor
	else
		local _, innerSlot = buildCase(benchCF, scene, partId)
		-- Monitor stands on the bench NEXT TO the tower (to its left), on its own
		-- base (pivot at base -> Y ~= bench top), facing the player; internal parts
		-- seat inside the tower at innerSlot.
		slotCF = (mode == "monitor") and (benchCF * CFrame.new(-2.9, 0.02, 0.2) * CFrame.Angles(0, math.rad(180), 0)) or innerSlot
		-- Fill EVERY other internal slot so the tower always looks like a full PC:
		-- show your upgraded part if you own one, else a basic (tier 1) part. The
		-- slot being installed is skipped (its own basic part is shown to remove).
		if ownedParts then
			for id in pairs(SLOT_OFFSETS) do
				if id ~= partId and PCVisuals.TIERED[id] then
					local level = ownedParts[id] or 0
					local tier = (level > 0) and PCVisuals.getVisualTier(level) or 1
					local decor = buildPartModel(id, tier, o * SLOT_OFFSETS[id], partSize(id))
					if decor then
						-- decor must not block clicks meant for the part being installed
						for _, p in ipairs(decor:GetDescendants()) do
							if p:IsA("BasePart") then
								p.CanQuery = false
							end
						end
						decor.Parent = scene
					end
				end
			end
		end
	end

	local trayCF = benchCF * CFrame.new(-2.6, 0.9, 1.6)
	local binCF = benchCF * CFrame.new(2.6, 0.9, 1.6)
	buildPad("Tray", benchCF * CFrame.new(-2.6, 0.25, 1.6), Color3.fromRGB(90, 200, 255), scene)
	local binPad = buildPad("Bin", benchCF * CFrame.new(2.6, 0.25, 1.6), Color3.fromRGB(235, 120, 90), scene)

	-- Human-readable noun for the prompts.
	local noun = (mode == "tower" and "case") or (mode == "monitor" and "monitor") or partName(partId)

	-- Step 1: click the old (or basic stock) piece to take it out / off.
	local removeTier = oldTier or 1
	local isStock = oldTier == nil
	local verb = (mode == "tower") and "unplug" or (mode == "monitor") and "take off" or "take out"
	prompt.Text = (isStock and "CLICK the basic " or "CLICK the old ") .. noun .. " to " .. verb
	local oldModel = buildPartModel(partId, removeTier, slotCF, partSize(partId))
	if oldModel then
		oldModel.Parent = scene
		if not waitForClick(oldModel, shouldCancel) then
			return false
		end
		local stopReach = playReach(char)
		flyThrough(oldModel, { benchCF * CFrame.new(0, 1.8, 1.0), binCF }, shouldCancel, camera, camOff) -- camera follows the part out
		stopReach()
		tweenCam(camera, overviewCF, 0.5) -- zoom back to 3rd person
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

	-- Step 2: click the new piece to install it.
	prompt.Text = "CLICK the new " .. noun .. " to install it"
	local newModel = buildPartModel(partId, newTier, trayCF, partSize(partId))
	if not newModel then
		return true
	end
	newModel.Parent = scene
	if not waitForClick(newModel, shouldCancel) then
		return false
	end
	local stopReach2 = playReach(char)
	-- internal parts drop straight down into the slot; the monitor/tower arc in from the front
	local approach = (mode == "internal") and (slotCF * CFrame.new(0, 0.55, 0)) or (slotCF * CFrame.new(0, 1.1, 0.5))
	flyThrough(newModel, { benchCF * CFrame.new(0, 2.0, 1.2), approach }, shouldCancel, camera, camOff)
	pressIn(newModel, slotCF, shouldCancel) -- push it down into place with a settle
	driveScrew(slotCF, math.min(partSize(partId), 1.4), scene, shouldCancel) -- screw it in (the payoff moment)
	stopReach2()
	seatBurst(slotCF, scene) -- spark burst payoff
	Sound.play("Correct") -- satisfying "seated" ding
	tweenCam(camera, overviewCF, 0.6) -- zoom back to 3rd person
	prompt.Text = "Installed!"
	Sound.play("Shipped") -- success chime
	task.wait(0.5)
	return true
end

function PCInstallGame.run(partId, oldTier, newTier, ownedParts)
	if active then
		return
	end
	if not PCVisuals.TIERED[partId] then
		Remotes.PCInstallCancel:FireServer(partId)
		return
	end
	active = true
	Sound.play("PanelOpen") -- the bench opens

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
		local standPos = (benchCF * CFrame.new(0, 0, 2.6)).Position
		local eye = Vector3.new(standPos.X, savedCF.Position.Y, standPos.Z)
		-- look at the bench at the SAME height, so the character stays upright (no tilt)
		standCF = CFrame.lookAt(eye, Vector3.new(benchCF.Position.X, savedCF.Position.Y, benchCF.Position.Z))
		hrp.CFrame = standCF
		hrp.Anchored = true
	end

	local prevType, prevCF = camera.CameraType, camera.CFrame
	camera.CameraType = Enum.CameraType.Scriptable
	-- pulled-back 3rd-person so the case, pads and character are all in frame and
	-- nothing clips into the camera
	camera.CFrame = CFrame.lookAt((benchCF * CFrame.new(6.5, 2.7, 3.8)).Position, (benchCF * CFrame.new(0, 1.2, -0.1)).Position)

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
		local ok, done = pcall(runRound, scene, benchCF, camera, prompt, char, partId, oldTier, newTier, ownedParts, function()
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

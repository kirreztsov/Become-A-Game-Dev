-- Shared helpers for the tiered PC-part display models. A part's 0..5 gameplay
-- level maps to one of THREE visual "looks" (basic / RGB / elite). Tiered assets
-- (e.g. PCGpu) pack all three as parts named T1_* / T2_* / T3_*; these helpers
-- pick and build the one look matching a player's level. Used by both the shop
-- counter (client, per-player) and the studio rig (server).
local PCVisuals = {}

-- 6 gameplay tiers -> 3 visual looks.
function PCVisuals.getVisualTier(level)
	level = level or 0
	if level <= 1 then
		return 1
	elseif level <= 3 then
		return 2
	end
	return 3
end

-- Which assets are tiered (packed with T1_/T2_/T3_ parts), by PC-part id.
PCVisuals.TIERED = {
	GPU = "PCGpu",
	Monitor = "PCMonitor",
	RGB = "PCTower",
	CPU = "PCCpu",
	RAM = "PCRam",
	Storage = "PCStorage",
	Cooling = "PCCooling",
}

-- Per-category display sizing on the shop counter (matches Lobby PC_SHELF_MODELS).
-- `size` is a target height, unless `byWidth` (the ultrawide monitor).
PCVisuals.DISPLAY = {
	GPU = { size = 2.6 },
	Monitor = { size = 3.0, byWidth = true },
	RGB = { size = 3.0 },
	CPU = { size = 2.0 },
	RAM = { size = 2.6 },
	Storage = { size = 2.2 },
	Cooling = { size = 2.6 },
}

-- Paint a GPU mesh part by its role name (shared so the counter and rig match).
function PCVisuals.paintGpu(p)
	local n = p.Name
	if n:find("Ring") then -- glowing RGB fan ring
		p.Color, p.Material = Color3.fromRGB(90, 220, 255), Enum.Material.SmoothPlastic
	elseif n:find("Accent") then
		p.Color, p.Material = Color3.fromRGB(90, 220, 255), Enum.Material.SmoothPlastic
	elseif n:find("Bracket") then
		p.Color, p.Material = Color3.fromRGB(150, 155, 165), Enum.Material.Metal
	elseif n:find("Fan") then
		p.Color, p.Material = Color3.fromRGB(46, 49, 58), Enum.Material.SmoothPlastic
	elseif n:find("Backplate") then
		p.Color, p.Material = Color3.fromRGB(22, 22, 28), Enum.Material.SmoothPlastic
	else -- Shroud
		p.Color, p.Material = Color3.fromRGB(74, 78, 90), Enum.Material.Metal
	end
end

-- Paint a Monitor mesh part by role. Screen segments (Screen<n>) get a vibrant
-- blue->purple wallpaper gradient; a lone Screen (basic tier) is solid blue.
function PCVisuals.paintMonitor(p)
	local n = p.Name
	local sidx = n:match("Screen(%d+)")
	if sidx then
		local h = 0.58 + 0.28 * ((tonumber(sidx) - 1) / 10)
		p.Color, p.Material = Color3.fromHSV(h, 0.68, 1), Enum.Material.SmoothPlastic
	elseif n:find("Screen") then
		p.Color, p.Material = Color3.fromRGB(70, 130, 225), Enum.Material.SmoothPlastic
	elseif n:find("Accent") then
		p.Color, p.Material = Color3.fromRGB(235, 95, 220), Enum.Material.SmoothPlastic
	elseif n:find("Neck") then
		p.Color, p.Material = Color3.fromRGB(40, 42, 50), Enum.Material.SmoothPlastic
	elseif n:find("Base") then
		p.Color, p.Material = Color3.fromRGB(34, 36, 44), Enum.Material.SmoothPlastic
	else -- Bezel
		p.Color, p.Material = Color3.fromRGB(26, 28, 34), Enum.Material.SmoothPlastic
	end
end

-- Paint a Tower (RGB case) mesh part by role.
local TOWER_FAN_COLORS = { Color3.fromRGB(90, 220, 255), Color3.fromRGB(235, 95, 220), Color3.fromRGB(120, 240, 150) }
function PCVisuals.paintTower(p)
	local n = p.Name
	local ringIdx = n:match("Ring(%d)")
	if ringIdx then
		p.Color, p.Material = TOWER_FAN_COLORS[tonumber(ringIdx)] or TOWER_FAN_COLORS[1], Enum.Material.SmoothPlastic
	elseif n:find("Fan") then
		p.Color, p.Material = Color3.fromRGB(40, 42, 50), Enum.Material.SmoothPlastic
	elseif n:find("Glass") then
		p.Color, p.Material, p.Transparency, p.Reflectance = Color3.fromRGB(170, 205, 235), Enum.Material.Glass, 0.5, 0.1
	elseif n:find("Cooler") then
		p.Color, p.Material = Color3.fromRGB(120, 125, 140), Enum.Material.Metal
	elseif n:find("InnerBoard") then
		p.Color, p.Material = Color3.fromRGB(30, 70, 55), Enum.Material.SmoothPlastic
	elseif n:find("Accent") then
		p.Color, p.Material = Color3.fromRGB(90, 220, 255), Enum.Material.SmoothPlastic
	elseif n:find("Front") then
		p.Color, p.Material = Color3.fromRGB(22, 24, 30), Enum.Material.SmoothPlastic
	elseif n:find("Feet") then
		p.Color, p.Material = Color3.fromRGB(20, 20, 24), Enum.Material.SmoothPlastic
	else -- Case
		p.Color, p.Material = Color3.fromRGB(30, 32, 40), Enum.Material.SmoothPlastic
	end
end

-- Paint a CPU mesh part by role.
function PCVisuals.paintCpu(p)
	local n = p.Name
	if n:find("IHS") then
		p.Color, p.Material = Color3.fromRGB(182, 187, 197), Enum.Material.Metal -- heatspreader
	elseif n:find("Accent") then
		p.Color, p.Material = Color3.fromRGB(90, 220, 255), Enum.Material.SmoothPlastic
	elseif n:find("Fins") then
		p.Color, p.Material = Color3.fromRGB(150, 155, 165), Enum.Material.Metal
	elseif n:find("Stand") then
		p.Color, p.Material = Color3.fromRGB(40, 42, 50), Enum.Material.SmoothPlastic
	else -- Chip substrate
		p.Color, p.Material = Color3.fromRGB(34, 36, 44), Enum.Material.SmoothPlastic
	end
end

-- Paint a RAM mesh part by role.
function PCVisuals.paintRam(p)
	local n = p.Name
	if n:find("Contacts") then
		p.Color, p.Material = Color3.fromRGB(218, 180, 90), Enum.Material.Metal -- gold pins
	elseif n:find("Accent") then
		p.Color, p.Material = Color3.fromRGB(90, 220, 255), Enum.Material.SmoothPlastic -- RGB bar
	elseif n:find("Spreader") then
		p.Color, p.Material = Color3.fromRGB(38, 40, 48), Enum.Material.Metal
	elseif n:find("Chip") then
		p.Color, p.Material = Color3.fromRGB(24, 26, 32), Enum.Material.SmoothPlastic
	else -- PCB
		p.Color, p.Material = Color3.fromRGB(26, 74, 48), Enum.Material.SmoothPlastic
	end
end

-- Paint a Storage mesh part by role.
function PCVisuals.paintStorage(p)
	local n = p.Name
	if n:find("Label") then
		p.Color, p.Material = Color3.fromRGB(226, 228, 233), Enum.Material.SmoothPlastic -- sticker
	elseif n:find("Accent") then
		p.Color, p.Material = Color3.fromRGB(90, 220, 255), Enum.Material.SmoothPlastic
	elseif n:find("Fins") then
		p.Color, p.Material = Color3.fromRGB(60, 63, 72), Enum.Material.Metal
	elseif n:find("Stand") then
		p.Color, p.Material = Color3.fromRGB(40, 42, 50), Enum.Material.SmoothPlastic
	else -- Body (metal drive shell)
		p.Color, p.Material = Color3.fromRGB(150, 155, 165), Enum.Material.Metal
	end
end

-- Paint a Cooling mesh part by role.
function PCVisuals.paintCooling(p)
	local n = p.Name
	if n:find("Ring") or n:find("Accent") then
		p.Color, p.Material = Color3.fromRGB(90, 220, 255), Enum.Material.SmoothPlastic -- cool blue RGB
	elseif n:find("Fan") then
		p.Color, p.Material = Color3.fromRGB(46, 49, 58), Enum.Material.SmoothPlastic
	else -- Fins (heatsink)
		p.Color, p.Material = Color3.fromRGB(170, 175, 185), Enum.Material.Metal
	end
end

PCVisuals.PAINT = {
	GPU = PCVisuals.paintGpu,
	Monitor = PCVisuals.paintMonitor,
	RGB = PCVisuals.paintTower,
	CPU = PCVisuals.paintCpu,
	RAM = PCVisuals.paintRam,
	Storage = PCVisuals.paintStorage,
	Cooling = PCVisuals.paintCooling,
}

local function assetTemplate(assetName)
	local assets = game:GetService("ReplicatedStorage"):FindFirstChild("Assets")
	local studio = assets and assets:FindFirstChild("studio")
	return studio and studio:FindFirstChild(assetName)
end

-- Clone `assetName` and keep ONLY tier T<tier>_ parts (deleting the other
-- tiers). Cloning the WHOLE model first preserves its upright orientation --
-- rebuilding from individual parts loses it (the model ends up lying down).
-- Returns the model, or nil if the asset/tier isn't present.
function PCVisuals.cloneTier(assetName, tier)
	local tmpl = assetTemplate(assetName)
	if not tmpl then
		return nil
	end
	local model = tmpl:Clone()
	local prefix = "T" .. tier .. "_"
	local kept = false
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Name:match("^T%d+_") then
			if d.Name:sub(1, #prefix) == prefix then
				kept = true
			else
				d:Destroy()
			end
		end
	end
	if not kept then
		model:Destroy()
		return nil
	end
	-- NOTE: do NOT set PrimaryPart here. GetBoundingBox/ScaleTo/PivotTo use the
	-- model's own pivot orientation (from import); overriding PrimaryPart re-aligns
	-- the bounding axes and makes the model scale/lie down wrong.
	return model
end

-- Build a display of `assetName` at visual `tier`: cloned, scaled so it stands
-- `targetHeight` studs tall, base seated at `basePos`, spun to `yaw`, painted by
-- `paintFn`, anchored. Returns the Model (caller parents it) or nil.
function PCVisuals.buildTierDisplay(assetName, tier, basePos, targetSize, yaw, paintFn, byWidth)
	local model = PCVisuals.cloneTier(assetName, tier)
	if not model then
		return nil
	end
	local _, size = model:GetBoundingBox()
	-- scale to a target HEIGHT (bounding Y), or WIDTH (bounding X) if byWidth
	local dim = byWidth and size.X or size.Y
	if dim > 0 then
		model:ScaleTo(targetSize / dim)
	end
	model:PivotTo(CFrame.new(basePos) * CFrame.Angles(0, yaw or 0, 0))
	local cf, sz = model:GetBoundingBox()
	local delta = basePos.Y - (cf.Position.Y - sz.Y / 2)
	model:PivotTo(model:GetPivot() + Vector3.new(0, delta, 0))
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			paintFn(p)
			p.Anchored = true
			p.CanCollide = false
		end
	end
	return model
end

return PCVisuals

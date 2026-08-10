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

PCVisuals.PAINT = {
	GPU = PCVisuals.paintGpu,
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
function PCVisuals.buildTierDisplay(assetName, tier, basePos, targetHeight, yaw, paintFn)
	local model = PCVisuals.cloneTier(assetName, tier)
	if not model then
		return nil
	end
	local _, size = model:GetBoundingBox()
	if size.Y > 0 then
		model:ScaleTo(targetHeight / size.Y)
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

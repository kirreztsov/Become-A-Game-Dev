-- Clones studio building meshes from ReplicatedStorage/Assets/studio and places
-- them in the world. Returns nil when an asset is missing so callers can fall
-- back to the procedural Parts build -- the game must never break mid-migration.
--
-- Imported FBX meshes come in at an arbitrary scale (often ~100x too big), so
-- `place` can scale a Model to a known target width using its bounding box,
-- which makes placement correct regardless of the import scale.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StudioModels = {}

-- Rojo names the subfolder after the on-disk directory: assets/studio -> "studio".
local FOLDER_NAME = "studio"

local function assetsFolder()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	return assets and assets:FindFirstChild(FOLDER_NAME) or nil
end

-- Is a given model asset present and synced?
function StudioModels.has(name)
	local folder = assetsFolder()
	return folder ~= nil and folder:FindFirstChild(name) ~= nil
end

-- A fresh clone of the asset, or nil if it isn't present.
function StudioModels.get(name)
	local folder = assetsFolder()
	local template = folder and folder:FindFirstChild(name)
	if not template then
		return nil
	end
	return template:Clone()
end

-- Clone + place an asset. `opts` (all optional):
--   name        -> rename the clone
--   targetWidth -> uniformly scale a Model so its bounding-box X == targetWidth
--                  (corrects the FBX import scale; keeps proportions)
-- Returns the clone, or nil if the asset is missing (caller uses its fallback).
function StudioModels.place(name, parent, cframe, opts)
	opts = opts or {}
	local clone = StudioModels.get(name)
	if not clone then
		return nil
	end
	if opts.name then
		clone.Name = opts.name
	end
	if opts.targetWidth and clone:IsA("Model") then
		local _, size = clone:GetBoundingBox()
		if size.X > 0 then
			clone:ScaleTo(clone:GetScale() * (opts.targetWidth / size.X))
		end
	end
	if clone:IsA("Model") then
		clone:PivotTo(cframe)
	elseif clone:IsA("BasePart") then
		clone.CFrame = cframe
	end
	clone.Parent = parent
	return clone
end

-- Place a Blender "Tree" asset (trunk + foliage), scaled to `targetWidth` studs
-- wide, coloured by piece name. Returns the tree Model, or nil if no asset
-- (caller builds the procedural tree instead).
local TREE_TRUNK = Color3.fromRGB(90, 60, 40)
local TREE_LEAVES = Color3.fromRGB(58, 122, 74)

-- Slightly shift a colour's brightness so instances vary (factor ~0.85..1.15).
local function tinted(color, factor)
	return Color3.new(
		math.clamp(color.R * factor, 0, 1),
		math.clamp(color.G * factor, 0, 1),
		math.clamp(color.B * factor, 0, 1)
	)
end

function StudioModels.placeTree(parent, cframe, targetWidth, nameOverride)
	-- Per-tree variety: random size, facing, and leaf shade so no two match.
	local w = targetWidth * (0.82 + math.random() * 0.5)
	local cf = cframe * CFrame.Angles(0, math.random() * 2 * math.pi, 0)
	local leaves = tinted(TREE_LEAVES, 0.85 + math.random() * 0.3)
	local tree = StudioModels.place("Tree", parent, cf, {
		name = nameOverride or "Tree",
		targetWidth = w,
	})
	if tree then
		for _, part in ipairs(tree:GetDescendants()) do
			if part:IsA("BasePart") then
				if part.Name:sub(1, 5) == "Trunk" or part.Name:sub(1, 6) == "Branch" then
					part.Color, part.Material = TREE_TRUNK, Enum.Material.Wood
					part.CanCollide = (part.Name:sub(1, 5) == "Trunk")
				else
					part.Color, part.Material = leaves, Enum.Material.Grass
					part.CanCollide = false
				end
				part.Anchored = true
			end
		end
	end
	return tree
end

-- Place any asset scaled to `targetWidth` studs wide, running `paint(part)` on
-- each BasePart (caller sets Color/Material/CanCollide). Anchors everything.
-- Returns the Model, or nil if the asset is missing (caller uses its fallback).
StudioModels.tinted = tinted

-- Like place + paint, but with per-instance variety: `scaleJitter` (e.g. 0.25)
-- randomises the width ±that fraction, and every instance gets a random facing.
function StudioModels.placeColored(assetName, parent, cframe, targetWidth, paint, nameOverride, scaleJitter, yaw)
	local w = targetWidth
	if scaleJitter then
		w = w * (1 + (math.random() * 2 - 1) * scaleJitter)
	end
	local spin = yaw ~= nil and yaw or (math.random() * 2 * math.pi)
	local cf = cframe * CFrame.Angles(0, spin, 0)
	local model = StudioModels.place(assetName, parent, cf, {
		name = nameOverride or assetName,
		targetWidth = w,
	})
	if model then
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				paint(part)
				part.Anchored = true
			end
		end
	end
	return model
end

-- Place ONE random variant child of an asset (its children are the variants),
-- scaled to `targetWidth` wide, base sitting on `worldPos.Y`, random spin, then
-- painted. Great for scattering rocks/props so no two match. nil if no asset.
function StudioModels.placeRandomVariant(assetName, parent, worldPos, targetWidth, paint, nameOverride, scaleJitter)
	local folder = assetsFolder()
	local asset = folder and folder:FindFirstChild(assetName)
	if not asset then
		return nil
	end
	local variants = {}
	for _, ch in ipairs(asset:GetChildren()) do
		if ch:IsA("BasePart") then
			variants[#variants + 1] = ch
		end
	end
	if #variants == 0 then
		return nil
	end
	local clone = variants[math.random(#variants)]:Clone()
	local w = targetWidth
	if scaleJitter then
		w = w * (1 + (math.random() * 2 - 1) * scaleJitter)
	end
	if clone.Size.X > 0 then
		clone.Size = clone.Size * (w / clone.Size.X)
	end
	clone.CFrame = CFrame.new(worldPos + Vector3.new(0, clone.Size.Y / 2, 0))
		* CFrame.Angles(0, math.random() * 2 * math.pi, 0)
	if nameOverride then
		clone.Name = nameOverride
	end
	paint(clone)
	clone.Anchored = true
	clone.Parent = parent
	return clone
end

-- Place a random skyline tower STRETCHED to an exact box `size` (Vector3), base
-- on `basePos.Y`. The asset's parts are named V<n>_Body / V<n>_Trim / V<n>_Win;
-- a random variant <n> is chosen and coloured: body=`bodyColor`,
-- trim(pillars/bands/frames/cap)=`trimColor`, windows glow `winColor` -- the
-- RoTube-Life-2 look.
function StudioModels.placeTower(assetName, parent, basePos, size, bodyColor, trimColor, winColor, nameOverride)
	local folder = assetsFolder()
	local asset = folder and folder:FindFirstChild(assetName)
	if not asset then
		return nil
	end
	local nums = {}
	for _, ch in ipairs(asset:GetChildren()) do
		local v = ch.Name:match("^V(%d+)_")
		if v then
			nums[tonumber(v)] = true
		end
	end
	local list = {}
	for k in pairs(nums) do
		list[#list + 1] = k
	end
	if #list == 0 then
		return nil
	end
	local pick = list[math.random(#list)]
	local center = basePos + Vector3.new(0, size.Y / 2, 0)

	-- Gather this variant's parts and derive a SINGLE scale from the body, then
	-- apply the same scale to body/trim/windows so they stay aligned (setting each
	-- part's Size directly stretches them by different factors -> scattered windows).
	local parts, bodySize, bodyPos = {}, nil, nil
	for _, ch in ipairs(asset:GetChildren()) do
		if ch:IsA("BasePart") and ch.Name:match("^V" .. pick .. "_") then
			parts[#parts + 1] = ch
			if ch.Name:find("Body") then
				bodySize, bodyPos = ch.Size, ch.Position
			end
		end
	end
	if not bodySize or #parts == 0 then
		return nil
	end
	local scaleVec = Vector3.new(size.X / bodySize.X, size.Y / bodySize.Y, size.Z / bodySize.Z)

	local group = Instance.new("Model")
	group.Name = nameOverride or assetName
	for _, ch in ipairs(parts) do
		do
			-- Keep each part's offset from the body (scaled) -- the trim's centre
			-- sits higher than the body (antennas/cap), so all-same-CFrame drifts.
			local off = ch.Position - bodyPos
			local scaledOff = Vector3.new(off.X * scaleVec.X, off.Y * scaleVec.Y, off.Z * scaleVec.Z)
			local clone = ch:Clone()
			clone.Size = ch.Size * scaleVec
			clone.CFrame = CFrame.new(center + scaledOff)
			clone.Anchored = true
			clone.CanCollide = true
			if clone.Name:find("Win") then
				-- Warm "lit" windows, but SmoothPlastic (Neon blooms to white here).
				clone.Color, clone.Material = winColor, Enum.Material.SmoothPlastic
			elseif clone.Name:find("Trim") then
				clone.Color, clone.Material = trimColor, Enum.Material.SmoothPlastic
			else
				clone.Color, clone.Material = bodyColor, Enum.Material.SmoothPlastic
			end
			clone.Parent = group
		end
	end
	group.Parent = parent
	return group
end

return StudioModels

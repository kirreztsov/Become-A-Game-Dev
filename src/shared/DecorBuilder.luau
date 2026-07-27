-- Shared builder for studio decorations. Both the server (the real, solid
-- decoration) and the client (the translucent placement "ghost") build from
-- this one module, so what you see while placing is exactly what you get.
--
-- Every item is built at the world ORIGIN with its base sitting on Y = 0;
-- callers position it with `model:PivotTo(cframe)` afterwards.

local DecorBuilder = {}

local function newPart(model, name, size, offset, color, material, opts)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = CFrame.new(offset)
	p.Anchored = true
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if opts and opts.ghost then
		p.Color = opts.tint or Color3.fromRGB(120, 235, 140)
		p.Transparency = 0.5
		p.CanCollide = false
	else
		p.Color = color
		p.CanCollide = opts and opts.solid ~= false
	end
	p.Parent = model
	return p
end

-- kind builders: each receives (model, item, opts, part) and adds its parts.
local builders = {}

function builders.plant(model, item, opts, part)
	part("Pot", Vector3.new(1.8, 1.6, 1.8), Vector3.new(0, 0.8, 0), Color3.fromRGB(150, 96, 66), Enum.Material.WoodPlanks)
	local f1 = part("Foliage1", Vector3.new(2.8, 2.8, 2.8), Vector3.new(0, 2.9, 0), item.color, Enum.Material.Grass)
	f1.Shape = Enum.PartType.Ball
	local f2 = part("Foliage2", Vector3.new(2, 2, 2), Vector3.new(0.3, 4.1, -0.2), item.color, Enum.Material.Grass)
	f2.Shape = Enum.PartType.Ball
end

function builders.rug(model, item, opts, part)
	local w, d = item.footprint.X, item.footprint.Y
	part("Rug", Vector3.new(w, 0.12, d), Vector3.new(0, 0.07, 0), item.color, Enum.Material.Fabric).CanCollide = false
	part("RugInner", Vector3.new(w - 1.6, 0.14, d - 1.6), Vector3.new(0, 0.08, 0), Color3.fromRGB(245, 240, 232), Enum.Material.Fabric).CanCollide = false
end

function builders.couch(model, item, opts, part)
	local dark = item.color:Lerp(Color3.fromRGB(0, 0, 0), 0.2)
	part("Base", Vector3.new(7, 1.3, 3), Vector3.new(0, 0.95, 0), item.color, Enum.Material.Fabric)
	part("Back", Vector3.new(7, 2.2, 0.8), Vector3.new(0, 2.4, 1.1), dark, Enum.Material.Fabric)
	for _, sx in ipairs({ -3.1, 3.1 }) do
		part("Arm", Vector3.new(0.8, 1.9, 3), Vector3.new(sx, 1.6, 0), dark, Enum.Material.Fabric)
	end
	for _, sx in ipairs({ -1.6, 1.6 }) do
		part("Cushion", Vector3.new(3, 0.5, 2.6), Vector3.new(sx, 1.85, -0.1), item.color:Lerp(Color3.fromRGB(255, 255, 255), 0.12), Enum.Material.Fabric).CanCollide = false
	end
end

function builders.arcade(model, item, opts, part)
	part("Cabinet", Vector3.new(2.8, 7, 2.4), Vector3.new(0, 3.5, 0), item.color, Enum.Material.SmoothPlastic)
	part("Screen", Vector3.new(2.1, 1.7, 0.2), Vector3.new(0, 4.9, -1.25), Color3.fromRGB(40, 60, 120), Enum.Material.Neon).CanCollide = false
	part("Panel", Vector3.new(2.6, 0.4, 1.1), Vector3.new(0, 3.3, -1.2), Color3.fromRGB(30, 30, 40), Enum.Material.SmoothPlastic).CanCollide = false
	part("Marquee", Vector3.new(2.8, 0.9, 0.5), Vector3.new(0, 6.9, -1), item.color:Lerp(Color3.fromRGB(255, 255, 255), 0.3), Enum.Material.SmoothPlastic).CanCollide = false
end

function builders.shelf(model, item, opts, part)
	local wood = item.color
	part("Back", Vector3.new(5, 6, 0.4), Vector3.new(0, 3, 0.9), wood, Enum.Material.WoodPlanks)
	for _, sx in ipairs({ -2.3, 2.3 }) do
		part("Side", Vector3.new(0.4, 6, 2), Vector3.new(sx, 3, 0), wood, Enum.Material.WoodPlanks)
	end
	local bookColors = { Color3.fromRGB(220, 90, 80), Color3.fromRGB(90, 150, 220), Color3.fromRGB(120, 200, 120), Color3.fromRGB(240, 200, 90) }
	for s = 1, 3 do
		local y = 1.4 + (s - 1) * 1.9
		part("Shelf" .. s, Vector3.new(5, 0.3, 2), Vector3.new(0, y, 0), wood:Lerp(Color3.fromRGB(255, 255, 255), 0.1), Enum.Material.WoodPlanks)
		for b = 1, 4 do
			part("Book" .. s .. b, Vector3.new(0.5, 1.3, 1.4), Vector3.new(-1.8 + b * 0.7, y + 0.9, -0.1), bookColors[((s + b) % #bookColors) + 1], Enum.Material.SmoothPlastic).CanCollide = false
		end
	end
end

function builders.lamp(model, item, opts, part)
	part("Base", Vector3.new(1.4, 0.35, 1.4), Vector3.new(0, 0.18, 0), Color3.fromRGB(60, 60, 66), Enum.Material.Metal)
	part("Pole", Vector3.new(0.25, 5, 0.25), Vector3.new(0, 2.7, 0), Color3.fromRGB(90, 90, 96), Enum.Material.Metal).CanCollide = false
	part("Shade", Vector3.new(2, 1.3, 2), Vector3.new(0, 5.6, 0), item.color, Enum.Material.SmoothPlastic).CanCollide = false
end

function builders.trophy(model, item, opts, part)
	part("Pedestal", Vector3.new(1.8, 1.4, 1.8), Vector3.new(0, 0.7, 0), Color3.fromRGB(60, 55, 70), Enum.Material.Marble)
	part("Stem", Vector3.new(0.5, 0.8, 0.5), Vector3.new(0, 1.7, 0), item.color, Enum.Material.Metal).CanCollide = false
	local cup = part("Cup", Vector3.new(1.6, 1.6, 1.6), Vector3.new(0, 2.7, 0), item.color, Enum.Material.Metal)
	cup.Shape = Enum.PartType.Ball
	cup.CanCollide = false
	for _, sx in ipairs({ -1, 1 }) do
		part("Handle", Vector3.new(0.3, 1, 0.3), Vector3.new(sx, 2.7, 0), item.color, Enum.Material.Metal).CanCollide = false
	end
end

function builders.tv(model, item, opts, part)
	part("Stand", Vector3.new(6, 1.4, 1.8), Vector3.new(0, 0.7, 0), Color3.fromRGB(150, 110, 70), Enum.Material.WoodPlanks)
	part("Bezel", Vector3.new(5, 3, 0.4), Vector3.new(0, 3.6, 0), Color3.fromRGB(30, 32, 38), Enum.Material.SmoothPlastic).CanCollide = false
	part("Screen", Vector3.new(4.4, 2.4, 0.1), Vector3.new(0, 3.6, -0.22), Color3.fromRGB(70, 120, 200), Enum.Material.Neon).CanCollide = false
end

function DecorBuilder.build(item, opts)
	opts = opts or {}
	local model = Instance.new("Model")
	model.Name = "Decor_" .. item.id
	local function part(name, size, offset, color, material)
		return newPart(model, name, size, offset, color, material, opts)
	end
	local builder = builders[item.id] or builders.plant
	builder(model, item, opts, part)
	model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart")
	return model
end

return DecorBuilder

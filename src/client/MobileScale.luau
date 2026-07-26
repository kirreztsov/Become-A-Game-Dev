-- Auto-fit UI scaler (M5). Shrinks the menus so they fit small / phone screens,
-- full-size on desktop. Works by giving each top-level panel a UIScale driven by
-- the viewport size, and recomputing when the screen changes (e.g. rotation).
--
-- Note: a UIScale must live on a GuiObject, not on the ScreenGui itself, so we
-- scale each ScreenGui's top-level children. Children that already own a UIScale
-- (the money/subs cards, the springy buttons, pop-in panels) are skipped so we
-- never fight those animations -- they're small/corner elements that already fit;
-- the big centred panels (which have no UIScale) are what actually overflow, and
-- those get scaled.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local MobileScale = {}

local REF_W, REF_H = 1000, 650 -- the layout is designed around roughly this size
local MIN_SCALE = 0.55

-- Full-screen effect / overlay guis that must NOT be scaled.
local BLOCKLIST = { FxGui = true, LoadingScreen = true }

function MobileScale.init(player)
	local pg = player:WaitForChild("PlayerGui")
	local managed = {} -- UIScale instances we drive

	local function currentScale()
		local cam = Workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
		if vp.X < 2 or vp.Y < 2 then
			return 1 -- viewport not ready (or headless) -- don't shrink to nothing
		end
		return math.clamp(math.min(vp.X / REF_W, vp.Y / REF_H), MIN_SCALE, 1)
	end

	local function applyAll()
		local s = currentScale()
		for scale in pairs(managed) do
			if scale.Parent then
				scale.Scale = s
			end
		end
	end

	-- A full-screen (both axes fill the screen) object is a dim backdrop / overlay
	-- wrapper -- scaling it would shrink the dim off the screen edges. Keep those
	-- full-screen and scale the real content nested inside them instead.
	local function fillsScreen(obj)
		local sz = obj.Size
		return sz.X.Scale >= 0.99
			and sz.Y.Scale >= 0.99
			and math.abs(sz.X.Offset) <= 4
			and math.abs(sz.Y.Offset) <= 4
	end

	-- Give one panel object a scaler, unless it already has a UIScale. For
	-- full-screen wrappers, recurse to the content inside instead.
	local function scaleObject(obj)
		if not obj:IsA("GuiObject") then
			return
		end
		if obj:FindFirstChildOfClass("UIScale") then
			return -- leave objects that animate their own scale alone
		end
		if fillsScreen(obj) then
			for _, child in ipairs(obj:GetChildren()) do
				scaleObject(child)
			end
			obj.ChildAdded:Connect(function(child)
				task.defer(scaleObject, child)
			end)
			return
		end
		local s = Instance.new("UIScale")
		s.Scale = currentScale()
		s.Parent = obj
		managed[s] = true
	end

	local function manageGui(gui)
		if not gui:IsA("ScreenGui") or BLOCKLIST[gui.Name] then
			return
		end
		for _, child in ipairs(gui:GetChildren()) do
			scaleObject(child)
		end
		gui.ChildAdded:Connect(function(child)
			task.defer(scaleObject, child)
		end)
	end

	for _, gui in ipairs(pg:GetChildren()) do
		manageGui(gui)
	end
	pg.ChildAdded:Connect(function(gui)
		task.defer(manageGui, gui)
	end)

	-- Re-fit whenever the viewport changes (rotation, window resize).
	local function hookCamera()
		local cam = Workspace.CurrentCamera
		if cam then
			cam:GetPropertyChangedSignal("ViewportSize"):Connect(applyAll)
		end
	end
	hookCamera()
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		hookCamera()
		applyAll()
	end)
end

return MobileScale

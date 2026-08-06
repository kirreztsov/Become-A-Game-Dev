local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local GameData = require(game.ReplicatedStorage.Shared.GameData)

local HomePanel = {}
local H = GameData.Home

local plr, gui, listFrame, selMenu, ghost
local selectedId, curYaw, myItems
local placing = false
local movingIndex = nil    -- when moving an existing item, its index in myItems
local menuIndex, menuEntry -- the placed item the action menu targets

local function inHome()
	local ch = plr and plr.Character
	local root = ch and ch:FindFirstChild("HumanoidRootPart")
	return root ~= nil and math.abs(root.Position.Y - H.skyY) < 200
end

-- The room corner (-X,-Z, floor Y) for the room the player is standing in --
-- must match HomeService.buildRoom: center = (0, skyY, index*spacing).
local function roomCorner()
	local ch = plr and plr.Character
	local root = ch and ch:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local index = math.floor(root.Position.Z / H.spacing + 0.5)
	return Vector3.new(-H.roomW / 2, H.skyY, index * H.spacing - H.roomD / 2)
end

local function hideMenu()
	if selMenu then selMenu.Visible = false end
	menuIndex, menuEntry = nil, nil
end

local function clearGhost()
	if ghost then ghost:Destroy(); ghost = nil end
	placing = false
	selectedId = nil
	movingIndex = nil
end

-- Enter placement mode for a new item (fromIndex nil) or to move an existing
-- one (fromIndex = its index in myItems, yaw = its current yaw).
local function startPlacing(id, yaw, fromIndex)
	clearGhost()
	hideMenu()
	selectedId, curYaw, movingIndex, placing = id, yaw or 0, fromIndex, true
	local it = GameData.getHomeItem(id)
	ghost = Instance.new("Part")
	ghost.Anchored = true; ghost.CanCollide = false; ghost.Transparency = 0.5
	ghost.Color = Color3.fromRGB(120, 220, 140)
	-- Size from NATIVE cells; the CFrame rotation handles yaw (same as the
	-- server's buildItem) -- sizing from the swapped footprint would double it.
	ghost.Size = Vector3.new(it.cells[1] * H.cell - 0.4, 1, it.cells[2] * H.cell - 0.4)
	ghost.Parent = workspace
end

local function pointerRay()
	local cam = workspace.CurrentCamera
	local mp = UserInputService:GetMouseLocation()
	return cam:ViewportPointToRay(mp.X, mp.Y)
end

-- Snap the ghost to the grid cell under the pointer; colour green/red.
local function updateGhost()
	if not placing or not ghost then return end
	if not inHome() then clearGhost(); return end
	local corner = roomCorner()
	if not corner then return end
	local ray = pointerRay()
	local rc = RaycastParams.new()
	rc.FilterType = Enum.RaycastFilterType.Exclude
	rc.FilterDescendantsInstances = { ghost, plr.Character }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 3000, rc)
	if not hit then return end
	local w, d = GameData.homeFootprint(selectedId, curYaw)
	local gx = math.clamp(math.floor((hit.Position.X - corner.X) / H.cell), 0, H.cols - w)
	local gz = math.clamp(math.floor((hit.Position.Z - corner.Z) / H.cell), 0, H.rows - d)
	-- (ghost.Size is set from native cells in startPlacing; rotation is via CFrame)
	local wc = GameData.homeCellToWorld(corner.X, corner.Z, H.skyY + 0.6, gx, gz, w, d)
	ghost.CFrame = CFrame.new(wc) * CFrame.Angles(0, math.rad(curYaw), 0)
	local free = not GameData.homeOverlaps(myItems or {}, gx, gz, w, d, movingIndex)
	ghost.Color = free and Color3.fromRGB(120, 220, 140) or Color3.fromRGB(230, 90, 90)
	ghost:SetAttribute("gx", gx); ghost:SetAttribute("gz", gz)
end

local function confirmPlace()
	if not placing or not ghost then return end
	local gx, gz = ghost:GetAttribute("gx"), ghost:GetAttribute("gz")
	if gx and gz then
		if movingIndex then
			Remotes.RequestMoveHomeItem:FireServer(movingIndex, gx, gz, curYaw)
		else
			Remotes.RequestPlaceHomeItem:FireServer(selectedId, gx, gz, curYaw)
		end
	end
	clearGhost()
end

-- Find the placed item under the pointer -> (index, entry) in myItems, matched
-- by the grid cell attributes HomeService stamps on each placed model.
local function pickPlaced()
	local ray = pointerRay()
	local rc = RaycastParams.new()
	rc.FilterType = Enum.RaycastFilterType.Exclude
	rc.FilterDescendantsInstances = { plr.Character }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 3000, rc)
	if not hit then return nil end
	local inst = hit.Instance
	while inst and inst.Name ~= "HomeItem" do inst = inst.Parent end
	if not inst then return nil end
	local gx, gz = inst:GetAttribute("gx"), inst:GetAttribute("gz")
	if gx == nil then return nil end
	for i, e in ipairs(myItems or {}) do
		if e.gx == gx and e.gz == gz then return i, e end
	end
	return nil
end

local function addCard(item)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 40)
	b.BackgroundColor3 = Color3.fromRGB(238, 238, 246)
	b.Text = "  " .. item.icon .. "  " .. item.name
	b.TextXAlignment = Enum.TextXAlignment.Left
	b.TextColor3 = Color3.fromRGB(30, 33, 48)
	b.Font = Enum.Font.GothamMedium; b.TextSize = 16
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = b
	b.MouseButton1Click:Connect(function() startPlacing(item.id, 0, nil) end)
	b.Parent = listFrame
end

function HomePanel.init(player)
	plr = player
	myItems = {}
	local pg = player:WaitForChild("PlayerGui")
	gui = Instance.new("ScreenGui")
	gui.Name = "HomePanelGui"; gui.ResetOnSpawn = false; gui.DisplayOrder = 45; gui.Enabled = false
	gui.Parent = pg

	-- "Furniture" button lives on its OWN always-enabled ScreenGui so it shows
	-- in the Home even while the furniture panel (gui) is closed.
	local btnGui = Instance.new("ScreenGui")
	btnGui.Name = "HomeButtonGui"; btnGui.ResetOnSpawn = false; btnGui.DisplayOrder = 44
	btnGui.Parent = pg
	local openBtn = Instance.new("TextButton")
	openBtn.Name = "FurnitureButton"
	openBtn.Size = UDim2.fromOffset(150, 44)
	openBtn.Position = UDim2.new(0, 16, 1, -60)
	openBtn.AnchorPoint = Vector2.new(0, 1)
	openBtn.BackgroundColor3 = Color3.fromRGB(140, 92, 235)
	openBtn.TextColor3 = Color3.new(1, 1, 1)
	openBtn.Font = Enum.Font.FredokaOne; openBtn.TextSize = 18
	openBtn.Text = "\240\159\170\145 Furniture"
	openBtn.Visible = false
	local oc = Instance.new("UICorner"); oc.CornerRadius = UDim.new(0, 10); oc.Parent = openBtn
	openBtn.Parent = btnGui
	openBtn.MouseButton1Click:Connect(function() gui.Enabled = not gui.Enabled end)

	-- Panel: catalog list + Leave button.
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0, 0.5); panel.Position = UDim2.new(0, 16, 0.5, 0)
	panel.Size = UDim2.fromOffset(240, 420); panel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	panel.Parent = gui
	local pc = Instance.new("UICorner"); pc.CornerRadius = UDim.new(0, 14); pc.Parent = panel
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 40); title.Position = UDim2.fromOffset(12, 8)
	title.BackgroundTransparency = 1; title.Text = "\240\159\170\145 Furniture"
	title.TextColor3 = Color3.fromRGB(30, 33, 48); title.Font = Enum.Font.FredokaOne
	title.TextSize = 22; title.TextXAlignment = Enum.TextXAlignment.Left; title.Parent = panel

	listFrame = Instance.new("ScrollingFrame")
	listFrame.Position = UDim2.fromOffset(12, 52); listFrame.Size = UDim2.new(1, -24, 1, -110)
	listFrame.BackgroundTransparency = 1; listFrame.ScrollBarThickness = 6
	listFrame.CanvasSize = UDim2.new(); listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listFrame.Parent = panel
	local ll = Instance.new("UIListLayout"); ll.Padding = UDim.new(0, 6); ll.Parent = listFrame
	for _, item in ipairs(GameData.HomeCatalog) do addCard(item) end

	local leaveBtn = Instance.new("TextButton")
	leaveBtn.Size = UDim2.new(1, -24, 0, 40); leaveBtn.Position = UDim2.new(0, 12, 1, -48)
	leaveBtn.BackgroundColor3 = Color3.fromRGB(230, 90, 90); leaveBtn.TextColor3 = Color3.new(1, 1, 1)
	leaveBtn.Font = Enum.Font.FredokaOne; leaveBtn.TextSize = 18; leaveBtn.Text = "\240\159\154\170 Leave Home"
	local lc = Instance.new("UICorner"); lc.CornerRadius = UDim.new(0, 10); lc.Parent = leaveBtn
	leaveBtn.Parent = panel
	leaveBtn.MouseButton1Click:Connect(function()
		Remotes.RequestLeaveHome:FireServer(); gui.Enabled = false; clearGhost(); hideMenu()
	end)

	-- Action menu for a tapped placed item: Move / Delete / Cancel.
	selMenu = Instance.new("Frame")
	selMenu.AnchorPoint = Vector2.new(0.5, 1); selMenu.Position = UDim2.new(0.5, 0, 1, -80)
	selMenu.Size = UDim2.fromOffset(300, 52); selMenu.BackgroundColor3 = Color3.fromRGB(30, 33, 48)
	selMenu.Visible = false; selMenu.Parent = btnGui
	local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0, 10); sc.Parent = selMenu
	local sl = Instance.new("UIListLayout")
	sl.FillDirection = Enum.FillDirection.Horizontal; sl.Padding = UDim.new(0, 6)
	sl.HorizontalAlignment = Enum.HorizontalAlignment.Center; sl.VerticalAlignment = Enum.VerticalAlignment.Center
	sl.Parent = selMenu
	local function menuBtn(text, color, onClick)
		local b = Instance.new("TextButton")
		b.Size = UDim2.fromOffset(90, 40); b.BackgroundColor3 = color; b.TextColor3 = Color3.new(1, 1, 1)
		b.Font = Enum.Font.FredokaOne; b.TextSize = 16; b.Text = text
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = b
		b.MouseButton1Click:Connect(onClick); b.Parent = selMenu
		return b
	end
	menuBtn("Move", Color3.fromRGB(140, 92, 235), function()
		if menuEntry then startPlacing(menuEntry.id, menuEntry.yaw or 0, menuIndex) end
	end)
	menuBtn("Delete", Color3.fromRGB(230, 90, 90), function()
		if menuIndex then Remotes.RequestRemoveHomeItem:FireServer(menuIndex) end
		hideMenu()
	end)
	menuBtn("Cancel", Color3.fromRGB(90, 94, 110), function() hideMenu() end)

	-- Server pushes the current item list on entry + after every change.
	Remotes.HomeStateUpdated.OnClientEvent:Connect(function(items)
		myItems = items or {}
		if selMenu.Visible then hideMenu() end -- indices may have shifted
	end)

	-- Show the Furniture button only in the Home; tidy up on leaving.
	RunService.RenderStepped:Connect(function()
		local here = inHome()
		openBtn.Visible = here
		if not here then
			if gui.Enabled then gui.Enabled = false end
			if placing then clearGhost() end
			if selMenu.Visible then hideMenu() end
			return
		end
		updateGhost()
	end)

	-- Place while placing; otherwise tap a placed item to open its menu. Rotate with R.
	UserInputService.InputBegan:Connect(function(input, gp)
		if gp or not inHome() then return end
		local clicked = input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		if placing then
			if clicked then
				confirmPlace()
			elseif input.KeyCode == Enum.KeyCode.R then
				curYaw = (curYaw + 90) % 360
			end
		elseif clicked then
			local idx, entry = pickPlaced()
			if idx then
				menuIndex, menuEntry = idx, entry
				selMenu.Visible = true
			else
				hideMenu()
			end
		end
	end)
end

return HomePanel

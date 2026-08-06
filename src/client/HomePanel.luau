local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local GameData = require(game.ReplicatedStorage.Shared.GameData)

local HomePanel = {}
local H = GameData.Home

local plr, gui, listFrame, ghost, selectedId, curYaw, myItems
local placing = false

local function inHome()
	local ch = plr.Character
	local root = ch and ch:FindFirstChild("HumanoidRootPart")
	return root ~= nil and math.abs(root.Position.Y - H.skyY) < 200
end

-- The room corner for THIS player = derived from their plot index is server-side;
-- the client finds it from the room floor it is standing on.
local function roomCorner()
	local ch = plr.Character
	local root = ch and ch:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	-- room center Z ~ round(root.Z / spacing)*spacing; corner = center - (roomW/2, 0, roomD/2)
	local index = math.floor(root.Position.Z / H.spacing + 0.5)
	local centerZ = index * H.spacing
	return Vector3.new(-H.roomW / 2, H.skyY, centerZ - H.roomD / 2)
end

local function clearGhost()
	if ghost then ghost:Destroy(); ghost = nil end
	placing = false
	selectedId = nil
end

local function makeGhost(id)
	clearGhost()
	selectedId = id; curYaw = 0; placing = true
	local w, d = GameData.homeFootprint(id, curYaw)
	ghost = Instance.new("Part")
	ghost.Anchored = true; ghost.CanCollide = false; ghost.Transparency = 0.5
	ghost.Color = Color3.fromRGB(120, 220, 140)
	ghost.Size = Vector3.new(w * H.cell - 0.4, 1, d * H.cell - 0.4)
	ghost.Parent = workspace
end

-- Snap the ghost to the grid cell under the mouse/touch, colour green/red.
local function updateGhost()
	if not placing or not ghost then return end
	local corner = roomCorner()
	if not corner then return end
	local cam = workspace.CurrentCamera
	local pos = UserInputService:GetMouseLocation()
	local ray = cam:ViewportPointToRay(pos.X, pos.Y)
	local rc = RaycastParams.new()
	rc.FilterType = Enum.RaycastFilterType.Exclude
	rc.FilterDescendantsInstances = { ghost, plr.Character }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 2000, rc)
	if not hit then return end
	local w, d = GameData.homeFootprint(selectedId, curYaw)
	local gx = math.floor((hit.Position.X - corner.X) / H.cell)
	local gz = math.floor((hit.Position.Z - corner.Z) / H.cell)
	gx = math.clamp(gx, 0, H.cols - w)
	gz = math.clamp(gz, 0, H.rows - d)
	ghost.Size = Vector3.new(w * H.cell - 0.4, 1, d * H.cell - 0.4)
	local wc = GameData.homeCellToWorld(corner.X, corner.Z, H.skyY + 0.6, gx, gz, w, d)
	ghost.CFrame = CFrame.new(wc) * CFrame.Angles(0, math.rad(curYaw), 0)
	local free = not GameData.homeOverlaps(myItems or {}, gx, gz, w, d, nil)
	ghost.Color = free and Color3.fromRGB(120, 220, 140) or Color3.fromRGB(230, 90, 90)
	ghost:SetAttribute("gx", gx); ghost:SetAttribute("gz", gz)
end

local function confirmPlace()
	if not placing or not ghost then return end
	local gx, gz = ghost:GetAttribute("gx"), ghost:GetAttribute("gz")
	if gx and gz then
		Remotes.RequestPlaceHomeItem:FireServer(selectedId, gx, gz, curYaw)
	end
	clearGhost()
end

local function addCard(item)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 40)
	b.BackgroundColor3 = Color3.fromRGB(238, 238, 246)
	b.Text = "  " .. item.icon .. "  " .. item.name
	b.TextXAlignment = Enum.TextXAlignment.Left
	b.TextColor3 = Color3.fromRGB(30, 33, 48)
	b.Font = Enum.Font.GothamMedium; b.TextSize = 16
	b.LayoutOrder = 1
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = b
	b.MouseButton1Click:Connect(function() makeGhost(item.id) end)
	b.Parent = listFrame
end

function HomePanel.toggle()
	if not gui then return end
	gui.Enabled = not gui.Enabled
end

function HomePanel.init(player)
	plr = player
	myItems = {}
	local pg = player:WaitForChild("PlayerGui")
	gui = Instance.new("ScreenGui")
	gui.Name = "HomePanelGui"; gui.ResetOnSpawn = false; gui.DisplayOrder = 45; gui.Enabled = false
	gui.Parent = pg

	-- A "Furniture" button, only visible while inside the Home.
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
	openBtn.Parent = pg:FindFirstChild("HomePanelGui")
	openBtn.MouseButton1Click:Connect(function() gui.Enabled = not gui.Enabled end)

	-- Panel with the catalog list + a Leave button.
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0, 0.5); panel.Position = UDim2.new(0, 16, 0.5, 0)
	panel.Size = UDim2.fromOffset(240, 420); panel.BackgroundColor3 = Color3.fromRGB(255,255,255)
	panel.Parent = gui
	local pc = Instance.new("UICorner"); pc.CornerRadius = UDim.new(0, 14); pc.Parent = panel
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 40); title.Position = UDim2.fromOffset(12, 8)
	title.BackgroundTransparency = 1; title.Text = "\240\159\170\145 Furniture"
	title.TextColor3 = Color3.fromRGB(30,33,48); title.Font = Enum.Font.FredokaOne
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
	leaveBtn.BackgroundColor3 = Color3.fromRGB(230, 90, 90); leaveBtn.TextColor3 = Color3.new(1,1,1)
	leaveBtn.Font = Enum.Font.FredokaOne; leaveBtn.TextSize = 18; leaveBtn.Text = "\240\159\154\170 Leave Home"
	local lc = Instance.new("UICorner"); lc.CornerRadius = UDim.new(0, 10); lc.Parent = leaveBtn
	leaveBtn.Parent = panel
	leaveBtn.MouseButton1Click:Connect(function()
		Remotes.RequestLeaveHome:FireServer(); gui.Enabled = false; clearGhost()
	end)

	-- Track my placed items (for the ghost's red/green overlap check).
	Remotes.HomeStateUpdated.OnClientEvent:Connect(function(items) myItems = items end)

	-- Show/hide the Furniture button based on being inside the Home.
	RunService.RenderStepped:Connect(function()
		local here = inHome()
		openBtn.Visible = here
		if not here and gui.Enabled then gui.Enabled = false; clearGhost() end
		updateGhost()
	end)

	-- Place on click/tap; rotate with R.
	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if placing and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			confirmPlace()
		elseif placing and input.KeyCode == Enum.KeyCode.R then
			curYaw = (curYaw + 90) % 360
		end
	end)
end

return HomePanel

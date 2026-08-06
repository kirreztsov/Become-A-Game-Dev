-- Private per-player Home rooms (Round 1). One hidden room per plot index, high
-- in the sky. A white pad at each studio entrance teleports the owner in; a
-- Leave pad returns them. Furniture placement is server-authoritative and saved
-- to PlayerData.homeItems.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local GameData = require(game.ReplicatedStorage.Shared.GameData)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local PlotManager = require(script.Parent.PlotManager)
local StudioModels = require(script.Parent.StudioModels)

local HomeService = {}

local H = GameData.Home
local NEUTRAL_WALL = Color3.fromRGB(214, 210, 202)
local NEUTRAL_FLOOR = Color3.fromRGB(176, 170, 160)
local ACCENT = Color3.fromRGB(140, 92, 255)

local homesFolder
local roomCorner = {}  -- [index] = Vector3 of the room's -X,-Z floor corner
local roomSpawn = {}   -- [index] = CFrame to drop the player at
local recentlyLeft = {} -- [userId] = os.clock() when they last left, to stop the
                        -- Home pad from instantly re-triggering as they land.

local function markLeft(player)
	recentlyLeft[player.UserId] = os.clock()
end
local function leftRecently(player)
	local t = recentlyLeft[player.UserId]
	return t ~= nil and (os.clock() - t) < 2
end

local function part(name, size, pos, color, mat, parent)
	local p = Instance.new("Part")
	p.Name, p.Size, p.Position = name, size, pos
	p.Anchored, p.CanCollide = true, true
	p.Color, p.Material = color, mat or Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

-- Build the empty room shell for a plot index. Returns the room folder.
local function buildRoom(index)
	local center = Vector3.new(0, H.skyY, index * H.spacing)
	local floorTop = center.Y
	local folder = Instance.new("Folder")
	folder.Name = "Home" .. index
	folder.Parent = homesFolder

	local w, d, wh = H.roomW, H.roomD, H.wallH
	part("Floor", Vector3.new(w, 1, d), center + Vector3.new(0, -0.5, 0), NEUTRAL_FLOOR, Enum.Material.WoodPlanks, folder)
	part("Ceiling", Vector3.new(w, 1, d), center + Vector3.new(0, wh + 0.5, 0), NEUTRAL_WALL, Enum.Material.SmoothPlastic, folder)
	part("WallN", Vector3.new(w, wh, 1), center + Vector3.new(0, wh / 2, -d / 2), NEUTRAL_WALL, nil, folder)
	part("WallS", Vector3.new(w, wh, 1), center + Vector3.new(0, wh / 2, d / 2), NEUTRAL_WALL, nil, folder)
	part("WallW", Vector3.new(1, wh, d), center + Vector3.new(-w / 2, wh / 2, 0), NEUTRAL_WALL, nil, folder)
	local wallE = part("WallE", Vector3.new(1, wh, d), center + Vector3.new(w / 2, wh / 2, 0), NEUTRAL_WALL, nil, folder)
	-- a window strip on the east wall (glass, cosmetic)
	local win = part("Window", Vector3.new(1.2, wh * 0.5, d * 0.6), center + Vector3.new(w / 2, wh * 0.55, 0), Color3.fromRGB(150, 195, 215), Enum.Material.Glass, folder)
	win.Transparency = 0.5

	-- Leave pad near the -Z,-X corner.
	local leave = part("LeavePad", Vector3.new(6, 0.4, 6), center + Vector3.new(-w / 2 + 5, 0.2, -d / 2 + 5), ACCENT, Enum.Material.Neon, folder)
	leave.CanCollide = false
	local lg = Instance.new("SurfaceGui"); lg.Face = Enum.NormalId.Top; lg.Parent = leave
	local ll = Instance.new("TextLabel"); ll.Size = UDim2.fromScale(1,1); ll.BackgroundTransparency = 1
	ll.Text = "\240\159\154\170 Leave"; ll.TextColor3 = Color3.new(1,1,1); ll.Font = Enum.Font.FredokaOne; ll.TextScaled = true; ll.Parent = lg

	-- furniture goes in its own subfolder we can clear + rebuild.
	local furn = Instance.new("Folder"); furn.Name = "Furniture"; furn.Parent = folder

	roomCorner[index] = center + Vector3.new(-w / 2, 0, -d / 2)  -- floor corner, y = floorTop
	roomCorner[index] = Vector3.new(roomCorner[index].X, floorTop, roomCorner[index].Z)
	roomSpawn[index] = CFrame.new(center + Vector3.new(0, 4, d / 2 - 6), center + Vector3.new(0, 4, 0))

	-- Leave pad -> teleport back to studio entrance.
	leave.Touched:Connect(function(hit)
		local plr = Players:GetPlayerFromCharacter(hit.Parent)
		if plr and PlotManager.getPlayerPlotIndex(plr) == index then
			local cf = PlotManager.getStudioEntranceCFrame(index)
			if cf and plr.Character then markLeft(plr); plr.Character:PivotTo(cf) end
		end
	end)
	return folder
end

-- Build one item's model at its grid cell (Blender asset or procedural).
local function buildItem(furn, index, entry)
	local it = GameData.getHomeItem(entry.id)
	if not it then return end
	-- Swapped footprint (w,d) is for positioning + the reserved grid cells.
	local w, d = GameData.homeFootprint(entry.id, entry.yaw)
	-- Geometry is sized from the item's NATIVE cells; the yaw rotation in `cf`
	-- re-projects it into the swapped world footprint. (Sizing from the swapped
	-- pair AND rotating would double-apply the swap -> wrong size on 90/270.)
	local nativeX = it.cells[1] * H.cell
	local nativeZ = it.cells[2] * H.cell
	local corner = roomCorner[index]
	local pos = GameData.homeCellToWorld(corner.X, corner.Z, corner.Y, entry.gx, entry.gz, w, d)
	local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(entry.yaw or 0), 0)
	local model
	if it.asset and StudioModels.has(it.asset) then
		model = StudioModels.place(it.asset, furn, cf, { name = "HomeItem", targetWidth = nativeX - 0.5 })
		if model then
			for _, p in ipairs(model:GetDescendants()) do
				if p:IsA("BasePart") then p.Anchored = true end
			end
		end
	else
		-- procedural fallback: a simple block at the item's native size, rotated by cf.
		local m = Instance.new("Model"); m.Name = "HomeItem"; m.Parent = furn
		local body = part("Body", Vector3.new(nativeX - 0.6, 2.5, nativeZ - 0.6), pos, Color3.fromRGB(150, 150, 165), nil, m)
		body.CFrame = cf * CFrame.new(0, 1.25, 0)
		model = m
	end
	if model then
		model:SetAttribute("gx", entry.gx); model:SetAttribute("gz", entry.gz)
	end
	return model
end

function HomeService.rebuildHome(player)
	local index = PlotManager.getPlayerPlotIndex(player)
	if not index then return end
	local folder = homesFolder:FindFirstChild("Home" .. index)
	if not folder then return end
	local furn = folder:FindFirstChild("Furniture")
	if not furn then return end
	furn:ClearAllChildren()
	local data = PlayerData.get(player)
	if not data then return end
	for _, entry in ipairs(data.homeItems) do
		pcall(buildItem, furn, index, entry)
	end
end

local function enter(player)
	local index = PlotManager.getPlayerPlotIndex(player)
	if not index or not roomSpawn[index] then return end
	HomeService.rebuildHome(player)
	if player.Character then player.Character:PivotTo(roomSpawn[index]) end
	-- Seed the client with the current layout so its ghost overlap-check is
	-- correct for returning players (before they make any change).
	local data = PlayerData.get(player)
	if data then Remotes.HomeStateUpdated:FireClient(player, data.homeItems) end
end

function HomeService.build()
	homesFolder = Workspace:FindFirstChild("Homes")
	if homesFolder then homesFolder:Destroy() end
	homesFolder = Instance.new("Folder"); homesFolder.Name = "Homes"; homesFolder.Parent = Workspace
	for index = 1, 4 do
		buildRoom(index)
		-- Home portal standing UPRIGHT in the studio doorway for this plot.
		local origin = PlotManager.getPlotOrigin(index)
		if origin then
			-- A vertical glowing pane filling the doorway opening (front wall is at
			-- origin.z + 29; the door is ~4 wide x 6 tall). Sat just in front of the
			-- glass door so it reads clearly even with the studio interior visible
			-- behind it. Walk into it to enter your room. The leave-landing spot is
			-- ~5 studs in front (origin + (0,4,23)); the 2s leftRecently debounce is
			-- the backstop against an instant re-trigger.
			local portalPos = origin + Vector3.new(0, 4, 28.4)
			local pad = part("HomePad" .. index, Vector3.new(3.6, 6, 0.4), portalPos, ACCENT, Enum.Material.Neon, Workspace)
			pad.CanCollide = false
			pad.Transparency = 0.35
			-- Label on BOTH faces so it reads walking in and looking back out.
			for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
				local sg = Instance.new("SurfaceGui"); sg.Face = face; sg.Parent = pad
				local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.fromScale(1, 1); lbl.BackgroundTransparency = 1
				lbl.Text = "\240\159\143\160\nMy Home"; lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
				lbl.Font = Enum.Font.FredokaOne; lbl.TextScaled = true; lbl.Parent = sg
			end
			pad:SetAttribute("plotIndex", index)
			pad.Touched:Connect(function(hit)
				local plr = Players:GetPlayerFromCharacter(hit.Parent)
				if plr and not leftRecently(plr) and PlotManager.getPlayerPlotIndex(plr) == index then
					enter(plr)
				end
			end)
		end
	end
end

function HomeService.start()
	Remotes.RequestEnterHome.OnServerEvent:Connect(function(player) enter(player) end)
	Remotes.RequestLeaveHome.OnServerEvent:Connect(function(player)
		local index = PlotManager.getPlayerPlotIndex(player)
		local cf = index and PlotManager.getStudioEntranceCFrame(index)
		if cf and player.Character then markLeft(player); player.Character:PivotTo(cf) end
	end)

	Remotes.RequestPlaceHomeItem.OnServerEvent:Connect(function(player, id, gx, gz, yaw)
		local index = PlotManager.getPlayerPlotIndex(player)
		local data = PlayerData.get(player)
		if not index or not data then return end
		if not GameData.getHomeItem(id) then return end
		gx, gz, yaw = math.floor(tonumber(gx) or -1), math.floor(tonumber(gz) or -1), tonumber(yaw) or 0
		if yaw ~= 0 and yaw ~= 90 and yaw ~= 180 and yaw ~= 270 then return end
		local w, d = GameData.homeFootprint(id, yaw)
		if not GameData.homeInBounds(gx, gz, w, d) then return end
		if GameData.homeOverlaps(data.homeItems, gx, gz, w, d, nil) then return end
		table.insert(data.homeItems, { id = id, gx = gx, gz = gz, yaw = yaw })
		HomeService.rebuildHome(player)
		Remotes.HomeStateUpdated:FireClient(player, data.homeItems)
	end)

	Remotes.RequestMoveHomeItem.OnServerEvent:Connect(function(player, i, gx, gz, yaw)
		local index = PlotManager.getPlayerPlotIndex(player)
		local data = PlayerData.get(player)
		if not index or not data then return end
		i = math.floor(tonumber(i) or -1)
		local entry = data.homeItems[i]
		if not entry then return end
		gx, gz, yaw = math.floor(tonumber(gx) or -1), math.floor(tonumber(gz) or -1), tonumber(yaw) or 0
		if yaw ~= 0 and yaw ~= 90 and yaw ~= 180 and yaw ~= 270 then return end
		local w, d = GameData.homeFootprint(entry.id, yaw)
		if not GameData.homeInBounds(gx, gz, w, d) then return end
		if GameData.homeOverlaps(data.homeItems, gx, gz, w, d, i) then return end
		entry.gx, entry.gz, entry.yaw = gx, gz, yaw
		HomeService.rebuildHome(player)
		Remotes.HomeStateUpdated:FireClient(player, data.homeItems)
	end)

	Remotes.RequestRemoveHomeItem.OnServerEvent:Connect(function(player, i)
		local data = PlayerData.get(player)
		if not data then return end
		i = math.floor(tonumber(i) or -1)
		if not data.homeItems[i] then return end
		table.remove(data.homeItems, i)
		HomeService.rebuildHome(player)
		Remotes.HomeStateUpdated:FireClient(player, data.homeItems)
	end)
end

return HomeService

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
local roomDims = {}    -- [index] = the dims table the room was last built at

-- Debounce for the studio door's Touched entry trigger, keyed by UserId. The
-- Leave pad drops a player OUTSIDE the studio door (getStudioEntranceCFrame,
-- z=23 vs the door at z~29), so there's no natural re-trigger loop, but this
-- guards against any stray double-fire from the Touched event.
local recentDoorEntry = {}
local DOOR_ENTRY_DEBOUNCE = 1.5

local function part(name, size, pos, color, mat, parent)
	local p = Instance.new("Part")
	p.Name, p.Size, p.Position = name, size, pos
	p.Anchored, p.CanCollide = true, true
	p.Color, p.Material = color, mat or Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

-- Build the empty room shell for a plot index. Returns the room folder. The
-- folder INSTANCE is created once and reused on every later call -- only its
-- children are cleared + rebuilt -- so external references to it (the
-- client's captured homeFolder, its WaitForChild/DescendantAdded hooks)
-- survive every rebuild instead of pointing at a dead, destroyed folder.
local function buildRoom(index, tier)
	local center = Vector3.new(0, H.skyY, index * H.spacing)
	local floorTop = center.Y
	local folder = homesFolder:FindFirstChild("Home" .. index)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Home" .. index
		folder.Parent = homesFolder
	end
	folder:ClearAllChildren()

	local dims = GameData.homeDims(tier)
	local w, d, wh = dims.roomW, dims.roomD, H.wallH
	part("Floor", Vector3.new(w, 1, d), center + Vector3.new(0, -0.5, 0), NEUTRAL_FLOOR, Enum.Material.WoodPlanks, folder)
	part("Ceiling", Vector3.new(w, 1, d), center + Vector3.new(0, wh + 0.5, 0), NEUTRAL_WALL, Enum.Material.SmoothPlastic, folder)
	part("WallN", Vector3.new(w, wh, 1), center + Vector3.new(0, wh / 2, -d / 2), NEUTRAL_WALL, nil, folder)
	part("WallS", Vector3.new(w, wh, 1), center + Vector3.new(0, wh / 2, d / 2), NEUTRAL_WALL, nil, folder)
	part("WallW", Vector3.new(1, wh, d), center + Vector3.new(-w / 2, wh / 2, 0), NEUTRAL_WALL, nil, folder)
	local wallE = part("WallE", Vector3.new(1, wh, d), center + Vector3.new(w / 2, wh / 2, 0), NEUTRAL_WALL, nil, folder)
	-- a window strip on the east wall (glass, cosmetic)
	local win = part("Window", Vector3.new(1.2, wh * 0.5, d * 0.6), center + Vector3.new(w / 2, wh * 0.55, 0), Color3.fromRGB(150, 195, 215), Enum.Material.Glass, folder)
	win.Transparency = 0.5

	-- ---- ambiance: warm interior lighting + accent glow, so the enclosed sky
	-- room reads bright, cosy + polished instead of a flat grey box ----
	-- Glowing accent strip down the ceiling centre (Neon = accent purple only,
	-- per the project rule); Bloom makes it pop.
	local strip = part("CeilingStrip", Vector3.new(w * 0.55, 0.3, 1.4), center + Vector3.new(0, wh - 0.15, 0), ACCENT, Enum.Material.Neon, folder)
	strip.CanCollide = false
	local stripLight = Instance.new("PointLight"); stripLight.Color = ACCENT; stripLight.Brightness = 0.5; stripLight.Range = 16; stripLight.Parent = strip
	-- Warm ceiling fill: subtle invisible PointLight sources on plain light
	-- panels (NOT Neon -- that material is reserved for the accent colour). The
	-- room is already ambient-lit, so these just add gentle warmth.
	for i, dx in ipairs({ -w / 4, w / 4 }) do
		local fixture = part("LightFixture" .. i, Vector3.new(5, 0.4, 5), center + Vector3.new(dx, wh - 0.15, 0), Color3.fromRGB(245, 240, 230), Enum.Material.SmoothPlastic, folder)
		fixture.CanCollide = false
		local pl = Instance.new("PointLight"); pl.Color = Color3.fromRGB(255, 240, 214); pl.Brightness = 0.8; pl.Range = 20; pl.Parent = fixture
	end
	-- Accent baseboard around the floor edge for a finished, framed look.
	local bh, bt = 0.9, 0.4
	local function baseboard(name, size, pos)
		local p = part(name, size, pos, ACCENT, Enum.Material.SmoothPlastic, folder); p.CanCollide = false
	end
	baseboard("BaseN", Vector3.new(w, bh, bt), center + Vector3.new(0, bh / 2, -d / 2 + 0.6))
	baseboard("BaseS", Vector3.new(w, bh, bt), center + Vector3.new(0, bh / 2, d / 2 - 0.6))
	baseboard("BaseW", Vector3.new(bt, bh, d), center + Vector3.new(-w / 2 + 0.6, bh / 2, 0))
	baseboard("BaseE", Vector3.new(bt, bh, d), center + Vector3.new(w / 2 - 0.6, bh / 2, 0))

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
	roomDims[index] = dims

	-- Leave pad -> teleport back to studio entrance.
	leave.Touched:Connect(function(hit)
		local plr = Players:GetPlayerFromCharacter(hit.Parent)
		if plr and PlotManager.getPlayerPlotIndex(plr) == index then
			local cf = PlotManager.getStudioEntranceCFrame(index)
			if cf and plr.Character then plr.Character:PivotTo(cf) end
		end
	end)
	return folder
end

-- Build one item's model at its grid cell (Blender asset or procedural).
local function buildItem(furn, index, entry, pcTier)
	local it = GameData.getHomeItem(entry.id)
	if not it then return end
	-- Swapped footprint (w,d) is for positioning + the reserved grid cells.
	local w, d = GameData.homeFootprint(entry.id, entry.yaw)
	-- Placeable work stations ("equipment") build as FUNCTIONAL stations (real
	-- seat + prompts) via PlotManager, not a decorative mesh.
	if it.station then
		local corner = roomCorner[index]
		local pos = GameData.homeCellToWorld(corner.X, corner.Z, corner.Y, entry.gx, entry.gz, w, d)
		return PlotManager.buildHomeStation(furn, pos, it.station, entry.yaw or 0, pcTier or 0)
	end
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

-- FULL rebuild: tears down and rebuilds the entire room shell (walls,
-- stations, trends board, workers desk, worker NPCs) plus furniture. Only
-- for cases that actually need the shell to change size/contents -- entering
-- the room (and, later, join/upgrade). Furniture-only changes should call
-- HomeService.refreshFurniture instead, or every placement causes a
-- full-room flicker.
function HomeService.rebuildHome(player)
	local index = PlotManager.getPlayerPlotIndex(player)
	if not index then return end
	local data = PlayerData.get(player)
	if not data then return end
	local tier = data.houseTier or 0

	-- Rebuild the shell at the player's current tier size, then the interior.
	-- buildRoom reuses the existing Home<i> folder instance in place (Fix A),
	-- it does NOT destroy + recreate it -- so external references (the
	-- client's captured homeFolder / DescendantAdded seat-tracking) survive.
	local folder = buildRoom(index, tier)
	PlotManager.populateHomeInterior(folder, PlotManager.getHomeBackWallPoint(index, tier), tier, data.pcTier or 0)
	PlotManager.refreshWorkerNPCs(player)
	-- Show/hide the Arcade + Merch fixtures (buy button vs. earning state) to
	-- match what this player has already bought (Task 5: they live in the Home
	-- room now, so this must re-apply on every rebuild, same as worker NPCs).
	PlotManager.applyRoomOwnership(player)

	local furn = folder:FindFirstChild("Furniture")
	if furn then
		for _, entry in ipairs(data.homeItems) do
			pcall(buildItem, furn, index, entry, (data.pcParts and data.pcParts.Monitor) or 0)
		end
	end
end

-- Furniture-only refresh: clears + rebuilds just the `Furniture` subfolder of
-- the player's ALREADY-BUILT room. Does not touch the shell/stations/trends/
-- workers, so placing/moving/removing an item doesn't flicker the whole room.
-- No-ops safely if the room or its Furniture subfolder doesn't exist yet.
function HomeService.refreshFurniture(player)
	local index = PlotManager.getPlayerPlotIndex(player)
	if not index then return end
	local data = PlayerData.get(player)
	if not data then return end

	local folder = homesFolder:FindFirstChild("Home" .. index)
	if not folder then return end
	local furn = folder:FindFirstChild("Furniture")
	if not furn then return end

	furn:ClearAllChildren()
	for _, entry in ipairs(data.homeItems) do
		pcall(buildItem, furn, index, entry, (data.pcParts and data.pcParts.Monitor) or 0)
	end
	-- Worker NPCs sit at the (player-placed) station seats, so re-sync them
	-- when furniture changes -- a station may have just been placed/moved/removed.
	PlotManager.refreshWorkerNPCs(player)
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
	-- Entering your Home is a HUD button ("My Home", client UI.luau) that fires
	-- RequestEnterHome. The studio is now an empty shell (Task 4/6), so its
	-- front door ALSO enters the room -- walking in feels natural since there's
	-- nothing else inside.
	for index = 1, 4 do
		local folder = buildRoom(index)
		-- Populate the interior at tier 0 immediately at server start (not just
		-- on player join/rebuild) so the stations already exist -- the client's
		-- homeFolder:WaitForChild("NewProjectSeat") resolves promptly instead of
		-- stalling until the owning player's join-time rebuildHome runs.
		PlotManager.populateHomeInterior(folder, PlotManager.getHomeBackWallPoint(index, 0), 0, 0)

		-- Own our OWN persistent door-entry trigger, parented to homesFolder (NOT
		-- inside Home<index>, which gets ClearAllChildren()'d on every rebuild,
		-- and NOT inside the StudioBuilding, which PlotManager destroys + rebuilds
		-- on join/prestige/skin-change). homesFolder itself is only ever
		-- (re)created here at boot, so this trigger -- and the Touched wiring
		-- below -- lives for the whole server session.
		local cf = PlotManager.getStudioEntranceCFrame(index)
		if cf then
			local pos = cf.Position + cf.LookVector * 5
			local trigger = part("HomeDoorTrigger" .. index, Vector3.new(8, 8, 3), pos, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, homesFolder)
			trigger.CanCollide = false
			trigger.CanQuery = false
			trigger.Transparency = 1
			trigger.Touched:Connect(function(hit)
				local plr = Players:GetPlayerFromCharacter(hit.Parent)
				if plr and PlotManager.getPlayerPlotIndex(plr) == index then
					local now = os.clock()
					if (recentDoorEntry[plr.UserId] or 0) + DOOR_ENTRY_DEBOUNCE > now then
						return
					end
					recentDoorEntry[plr.UserId] = now
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
		if cf and player.Character then player.Character:PivotTo(cf) end
	end)

	Remotes.RequestPlaceHomeItem.OnServerEvent:Connect(function(player, id, gx, gz, yaw)
		local index = PlotManager.getPlayerPlotIndex(player)
		local data = PlayerData.get(player)
		if not index or not data then return end
		if not GameData.getHomeItem(id) then return end
		gx, gz, yaw = math.floor(tonumber(gx) or -1), math.floor(tonumber(gz) or -1), tonumber(yaw) or 0
		if yaw ~= 0 and yaw ~= 90 and yaw ~= 180 and yaw ~= 270 then return end
		local w, d = GameData.homeFootprint(id, yaw)
		if not GameData.homeInBounds(gx, gz, w, d, GameData.homeDims(data.houseTier or 0)) then return end
		if GameData.homeOverlaps(data.homeItems, gx, gz, w, d, nil) then return end
		table.insert(data.homeItems, { id = id, gx = gx, gz = gz, yaw = yaw })
		HomeService.refreshFurniture(player)
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
		if not GameData.homeInBounds(gx, gz, w, d, GameData.homeDims(data.houseTier or 0)) then return end
		if GameData.homeOverlaps(data.homeItems, gx, gz, w, d, i) then return end
		entry.gx, entry.gz, entry.yaw = gx, gz, yaw
		HomeService.refreshFurniture(player)
		Remotes.HomeStateUpdated:FireClient(player, data.homeItems)
	end)

	Remotes.RequestRemoveHomeItem.OnServerEvent:Connect(function(player, i)
		local data = PlayerData.get(player)
		if not data then return end
		i = math.floor(tonumber(i) or -1)
		if not data.homeItems[i] then return end
		table.remove(data.homeItems, i)
		HomeService.refreshFurniture(player)
		Remotes.HomeStateUpdated:FireClient(player, data.homeItems)
	end)
end

return HomeService

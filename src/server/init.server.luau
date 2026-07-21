local Players = game:GetService("Players")
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.PlayerData)
local TrendsService = require(script.TrendsService)
local DevelopmentService = require(script.DevelopmentService)
local WorkerService = require(script.WorkerService)
local HouseService = require(script.HouseService)
local PCService = require(script.PCService)
local PlotManager = require(script.PlotManager)
local Lobby = require(script.Lobby)

PlotManager.build()
Lobby.build()
TrendsService.start()
DevelopmentService.start()
WorkerService.start()
HouseService.start()
PCService.start()
Lobby.start()

local AUTOSAVE_INTERVAL_SECONDS = 120

-- Every spawn (first join and every respawn) lands in the shared Lobby,
-- not directly at the player's own studio -- matches RoTube Life 2's
-- actual flow (spawn in the shared Park, then travel to your home from
-- there via a prompt) instead of teleporting straight to gameplay.
local function teleportToLobby(character)
	local spawnPoint = Lobby.getSpawnPoint()
	if not spawnPoint then
		return
	end

	local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 5)
	if not humanoidRootPart then
		return
	end

	character:PivotTo(CFrame.new(spawnPoint.Position))
end

local function onPlayerJoined(player)
	-- Assign a plot synchronously (no yields before this point) so the
	-- PlotIndex attribute is always already set by the time the player
	-- uses the "Go to My Studio" kiosk prompt.
	PlotManager.assignPlot(player)

	local data = PlayerData.load(player)
	PlotManager.rebuildHouseForPlayer(player, data.houseTier)
	PlotManager.rebuildPCForPlayer(player, data.pcTier)

	Remotes.PlayerStateUpdated:FireClient(player, data)
	TrendsService.sendCurrentTo(player)

	player.CharacterAdded:Connect(function(character)
		teleportToLobby(character)
	end)

	if player.Character then
		teleportToLobby(player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerJoined)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerJoined, player)
end

Players.PlayerRemoving:Connect(function(player)
	DevelopmentService.cleanupPlayer(player)
	PlayerData.save(player)
	PlayerData.remove(player)
	PlotManager.releasePlot(player)
end)

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_INTERVAL_SECONDS)
		for _, player in ipairs(Players:GetPlayers()) do
			PlayerData.save(player)
		end
	end
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		PlayerData.save(player)
	end
end)

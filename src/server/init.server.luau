local Players = game:GetService("Players")
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.PlayerData)
local TrendsService = require(script.TrendsService)
local DevelopmentService = require(script.DevelopmentService)
local WorkerService = require(script.WorkerService)
local HouseService = require(script.HouseService)
local PCService = require(script.PCService)
local PlotManager = require(script.PlotManager)

PlotManager.build()
TrendsService.start()
DevelopmentService.start()
WorkerService.start()
HouseService.start()
PCService.start()

local AUTOSAVE_INTERVAL_SECONDS = 120

local function teleportToPlot(player, character)
	local plotIndex = player:GetAttribute("PlotIndex")
	if not plotIndex then
		return
	end

	local plotFolder = PlotManager.getPlotFolder(plotIndex)
	if not plotFolder then
		return
	end

	local spawnPoint = plotFolder:FindFirstChild("PlotSpawnPoint")
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
	-- PlotIndex attribute is always already set by the time a character
	-- could possibly spawn and trigger a teleport below.
	PlotManager.assignPlot(player)

	local data = PlayerData.load(player)
	PlotManager.rebuildHouseForPlayer(player, data.houseTier)
	PlotManager.rebuildPCForPlayer(player, data.pcTier)

	Remotes.PlayerStateUpdated:FireClient(player, data)
	TrendsService.sendCurrentTo(player)

	player.CharacterAdded:Connect(function(character)
		teleportToPlot(player, character)
	end)

	if player.Character then
		teleportToPlot(player, player.Character)
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

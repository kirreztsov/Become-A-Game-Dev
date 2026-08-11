local Players = game:GetService("Players")
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local GameData = require(game.ReplicatedStorage.Shared.GameData)
local PlayerData = require(script.PlayerData)
local TrendsService = require(script.TrendsService)
local DevelopmentService = require(script.DevelopmentService)
local WorkerService = require(script.WorkerService)
local HouseService = require(script.HouseService)
local PCService = require(script.PCService)
local PlotManager = require(script.PlotManager)
local DailyRewardService = require(script.DailyRewardService)
local LeaderboardService = require(script.LeaderboardService)
local WorkerCaseService = require(script.WorkerCaseService)
local MonetizationService = require(script.MonetizationService)
local LoungeService = require(script.LoungeService)
local TutorialService = require(script.TutorialService)
local GlobalLeaderboardService = require(script.GlobalLeaderboardService)
local HomeService = require(script.HomeService)
local QuestService = require(script.QuestService)
local Lobby = require(script.Lobby)

PlotManager.build()
Lobby.build()
LeaderboardService.build()
HomeService.build()
TrendsService.start()
DevelopmentService.start()
WorkerService.start()
HouseService.start()
PCService.start()
PlotManager.start()
DailyRewardService.start()
GlobalLeaderboardService.start()
HomeService.start()
QuestService.start()
LeaderboardService.start()
WorkerCaseService.start()
MonetizationService.start()
LoungeService.start()
TutorialService.start()
Lobby.start()

-- Serve the client Leaderboards panel: answer a stat+period request from the
-- GlobalLeaderboardService cache (no new DataStore reads per request).
do
	local validStat = {}
	for _, s in ipairs(GameData.LeaderboardStats) do
		validStat[s.key] = true
	end
	Remotes.RequestLeaderboardData.OnServerEvent:Connect(function(player, stat, period)
		if not validStat[stat] then return end
		if period ~= "week" and period ~= "all" then return end
		local rows = GlobalLeaderboardService.getRows(stat, period) -- may be nil (Studio/unavailable)
		local standing = GlobalLeaderboardService.getSelfStanding(player, stat, period)
		local safeRows
		if rows then
			safeRows = {}
			for _, r in ipairs(rows) do
				safeRows[#safeRows + 1] = { name = r.name, value = r.value, userId = r.userId }
			end
		end
		Remotes.LeaderboardData:FireClient(player, stat, period, safeRows, standing)
	end)
end

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
	PlotManager.rebuildHouseForPlayer(player, data.houseTier, data.pcTier)
	PlotManager.rebuildDecorForPlayer(player, data.decorations)
	PlotManager.rebuildPlayButtons(player, data.subMilestone)
	-- Populate the player's private Home room (stations, Trends, PC, workers
	-- desk + NPCs) at their saved tier. This also covers what the removed
	-- PlotManager.rebuildPCForPlayer/refreshWorkerNPCs join-time calls used to
	-- do -- those targeted the studio, which no longer has stations/PC/workers
	-- (they all moved into the room in this task).
	HomeService.rebuildHome(player)

	Remotes.PlayerStateUpdated:FireClient(player, data)
	TrendsService.sendCurrentTo(player)
	DailyRewardService.checkForPlayer(player)

	player.CharacterAdded:Connect(function(character)
		teleportToLobby(character)
	end)

	if player.Character then
		teleportToLobby(player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerJoined)

-- Clients pull their state once their listeners are connected -- the initial
-- push at join can be missed while a client is still loading its UI.
Remotes.RequestInitialState.OnServerEvent:Connect(function(player)
	local data = PlayerData.get(player)
	if data then
		Remotes.PlayerStateUpdated:FireClient(player, data)
	end
end)

-- Remember the player's dark-mode UI preference.
Remotes.SetDarkMode.OnServerEvent:Connect(function(player, on)
	local data = PlayerData.get(player)
	if data then
		data.darkMode = on and true or false
	end
end)

-- Remember the player's sound mute preference.
Remotes.SetSoundMuted.OnServerEvent:Connect(function(player, on)
	local data = PlayerData.get(player)
	if data then
		data.soundMuted = on and true or false
	end
end)

-- Change the player's studio exterior skin (validates ownership of the
-- matching Robux pass unless reverting to "Default").
Remotes.RequestSetSkin.OnServerEvent:Connect(function(player, skinKey)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	if skinKey ~= "Default" then
		if not GameData.StudioSkins[skinKey] then
			return -- unknown skin
		end
		local passKey = "Skin" .. tostring(skinKey) -- "Gold" -> "SkinGold"
		if not (data.passes and data.passes[passKey]) then
			return -- must own the skin pass
		end
	end
	data.activeSkin = skinKey
	PlotManager.applySkin(player, skinKey)
	Remotes.PlayerStateUpdated:FireClient(player, data)
end)

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

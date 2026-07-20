local Players = game:GetService("Players")
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.PlayerData)
local TrendsService = require(script.TrendsService)
local DevelopmentService = require(script.DevelopmentService)
local UpgradeService = require(script.UpgradeService)

TrendsService.start()
DevelopmentService.start()
UpgradeService.start()

local AUTOSAVE_INTERVAL_SECONDS = 120

Players.PlayerAdded:Connect(function(player)
	local data = PlayerData.load(player)
	Remotes.PlayerStateUpdated:FireClient(player, data)
	TrendsService.sendCurrentTo(player)
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerData.save(player)
	PlayerData.remove(player)
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

local GameData = require(game.ReplicatedStorage.Shared.GameData)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local PlotManager = require(script.Parent.PlotManager)

local HouseService = {}

function HouseService.start()
	Remotes.RequestUpgradeHouse.OnServerEvent:Connect(function(player)
		local data = PlayerData.get(player)
		if not data then
			return
		end

		if data.houseTier >= GameData.HouseTierCount - 1 then
			Remotes.HouseActionResult:FireClient(player, false)
			return
		end

		local cost = GameData.getHouseUpgradeCost(data.houseTier)
		if data.cash < cost then
			Remotes.HouseActionResult:FireClient(player, false)
			return
		end

		data.cash -= cost
		data.houseTier += 1

		PlotManager.rebuildHouseForPlayer(player, data.houseTier, data.pcTier)

		Remotes.HouseActionResult:FireClient(player, true)
		Remotes.PlayerStateUpdated:FireClient(player, data)
	end)
end

return HouseService

local GameData = require(game.ReplicatedStorage.Shared.GameData)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)

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

		-- The room-size upgrade now grows the private Home room (stations +
		-- Trends + PC + workers desk all live there), not the studio -- the
		-- studio is just an empty shell. Local require avoids a load-order
		-- cycle with PlotManager/HomeService at boot.
		local HomeService = require(script.Parent.HomeService)
		HomeService.rebuildHome(player)

		Remotes.HouseActionResult:FireClient(player, true)
		Remotes.PlayerStateUpdated:FireClient(player, data)
	end)
end

return HouseService

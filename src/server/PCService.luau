local GameData = require(game.ReplicatedStorage.Shared.GameData)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local PlotManager = require(script.Parent.PlotManager)

local PCService = {}

function PCService.start()
	Remotes.RequestUpgradePC.OnServerEvent:Connect(function(player)
		local data = PlayerData.get(player)
		if not data then
			return
		end

		if data.pcTier >= GameData.PCTierCount - 1 then
			Remotes.PCActionResult:FireClient(player, false)
			return
		end

		local cost = GameData.getPCUpgradeCost(data.pcTier, data.houseTier)
		if data.cash < cost then
			Remotes.PCActionResult:FireClient(player, false)
			return
		end

		data.cash -= cost
		data.pcTier += 1

		PlotManager.rebuildPCForPlayer(player, data.pcTier)

		Remotes.PCActionResult:FireClient(player, true)
		Remotes.PlayerStateUpdated:FireClient(player, data)
	end)
end

return PCService

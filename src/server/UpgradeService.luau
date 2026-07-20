local GameData = require(game.ReplicatedStorage.Shared.GameData)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)

local UpgradeService = {}

local UPGRADE_HANDLERS = {
	DevSpeed = {
		getLevel = function(data) return data.devSpeedLevel end,
		getCost = GameData.getDevSpeedCost,
		applyLevel = function(data) data.devSpeedLevel += 1 end,
	},
	QualityBoost = {
		getLevel = function(data) return data.qualityBoostLevel end,
		getCost = GameData.getQualityBoostCost,
		applyLevel = function(data) data.qualityBoostLevel += 1 end,
	},
}

function UpgradeService.start()
	Remotes.RequestBuyUpgrade.OnServerEvent:Connect(function(player, upgradeType)
		local handler = UPGRADE_HANDLERS[upgradeType]
		if not handler then
			return
		end

		local data = PlayerData.get(player)
		if not data then
			return
		end

		local cost = handler.getCost(handler.getLevel(data))

		if data.cash < cost then
			Remotes.UpgradeResult:FireClient(player, upgradeType, false)
			return
		end

		data.cash -= cost
		handler.applyLevel(data)

		Remotes.UpgradeResult:FireClient(player, upgradeType, true)
		Remotes.PlayerStateUpdated:FireClient(player, data)
	end)
end

return UpgradeService

-- Server side of the rebirth perk tree. Players earn Prestige Points on rebirth
-- (awarded in PlotManager) and spend them here. Buying is server-authoritative:
-- PerkData.applyBuy re-checks the player can afford it and isn't maxed, deducts
-- the points, and bumps the level; we then save and push the new state.
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local PerkData = require(game.ReplicatedStorage.Shared.PerkData)
local PlayerData = require(script.Parent.PlayerData)

local PerkService = {}

function PerkService.start()
	Remotes.RequestBuyPerk.OnServerEvent:Connect(function(player, perkId)
		if type(perkId) ~= "string" then
			return
		end
		local data = PlayerData.get(player)
		if not data then
			return
		end
		if PerkData.applyBuy(data, perkId) then
			PlayerData.save(player)
			Remotes.PlayerStateUpdated:FireClient(player, data)
		end
	end)
end

return PerkService

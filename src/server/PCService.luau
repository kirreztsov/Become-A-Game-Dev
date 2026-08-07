local GameData = require(game.ReplicatedStorage.Shared.GameData)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)

local PCService = {}

function PCService.start()
	-- PC Parts Shop: upgrade one component a level at a time (replaces the old
	-- single pcTier upgrade). Money parts scale cash/game, follower parts scale
	-- subscribers/release -- see GameData.getPCParts*Multiplier.
	Remotes.RequestUpgradePart.OnServerEvent:Connect(function(player, partId)
		local data = PlayerData.get(player)
		if not data then
			return
		end
		local part = GameData.getPCPart(partId)
		if not part then
			Remotes.PCActionResult:FireClient(player, false)
			return
		end

		data.pcParts = data.pcParts or {}
		local level = data.pcParts[partId] or 0
		if level >= GameData.getPCPartMaxLevel(partId) then
			Remotes.PCActionResult:FireClient(player, false)
			return
		end

		local cost = GameData.getPCPartUpgradeCost(partId, level)
		if not cost or data.cash < cost then
			Remotes.PCActionResult:FireClient(player, false)
			return
		end

		data.cash -= cost
		data.pcParts[partId] = level + 1

		-- Only the Monitor changes the on-screen computer visual, so only that
		-- needs a room rebuild. Local require avoids a boot load-order cycle.
		if partId == "Monitor" then
			local HomeService = require(script.Parent.HomeService)
			HomeService.rebuildHome(player)
		end

		Remotes.PCActionResult:FireClient(player, true)
		Remotes.PlayerStateUpdated:FireClient(player, data)
	end)
end

return PCService

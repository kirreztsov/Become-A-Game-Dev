require(script.UI).init()

local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local PCInstallGame = require(script.PCInstallGame)

Remotes.PCInstallStart.OnClientEvent:Connect(function(partId, oldTier, newTier, ownedParts)
	if PCInstallGame.isActive() then
		return
	end
	PCInstallGame.run(partId, oldTier, newTier, ownedParts)
end)

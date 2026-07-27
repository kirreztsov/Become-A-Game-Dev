-- Persists the onboarding tutorial's "done" flag. The client drives the whole
-- tutorial; the server just records that the player finished (or skipped) it so
-- it never auto-starts again.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)

local TutorialService = {}

function TutorialService.start()
	Remotes.SetTutorialDone.OnServerEvent:Connect(function(player)
		local data = PlayerData.get(player)
		if data then
			data.tutorialDone = true
		end
	end)
end

return TutorialService

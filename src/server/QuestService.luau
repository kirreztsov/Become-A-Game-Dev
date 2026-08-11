-- Server side of the quest/achievement ladder. Progress is derived from the
-- player's own stats (QuestData reads them), so there's nothing to track live --
-- we only handle CLAIM: validate the quest is complete + unclaimed, mark it,
-- grant the reward, save, and tell the client. Server-authoritative: the client
-- can render bars, but only the server decides a reward was earned.
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local QuestData = require(game.ReplicatedStorage.Shared.QuestData)
local PlayerData = require(script.Parent.PlayerData)

local QuestService = {}

local function grantReward(data, reward)
	if reward.cash then
		data.cash += reward.cash
	end
	if reward.luckySpins then
		data.luckySpinsOwned = (data.luckySpinsOwned or 0) + reward.luckySpins
	end
end

function QuestService.start()
	Remotes.RequestClaimQuest.OnServerEvent:Connect(function(player, questId)
		if type(questId) ~= "string" then
			return
		end
		local data = PlayerData.get(player)
		if not data or PlayerData.loadFailed(player) then
			return
		end
		-- applyClaim re-checks completion + not-already-claimed and marks it.
		local reward = QuestData.applyClaim(data, questId)
		if not reward then
			return -- not complete, already claimed, or unknown id
		end
		grantReward(data, reward)
		PlayerData.save(player)
		Remotes.PlayerStateUpdated:FireClient(player, data)
		-- claim result for a client celebration (id + what they got)
		Remotes.QuestsUpdated:FireClient(player, { claimed = questId, reward = reward })
	end)
end

return QuestService

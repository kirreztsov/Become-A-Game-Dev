-- Server side of the daily challenges. Two jobs:
--  1. Roll the player over to the current day when needed (snapshot the baseline
--     stats + clear yesterday's claims), on join and across the day boundary.
--  2. Handle CLAIM: re-validate the challenge is complete + unclaimed, grant the
--     reward, save, and tell the client.
-- Progress itself is derived (ChallengeData reads the player's stats), so there's
-- nothing to track live. Claim is server-authoritative.
local Players = game:GetService("Players")

local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local ChallengeData = require(game.ReplicatedStorage.Shared.ChallengeData)
local PlayerData = require(script.Parent.PlayerData)

local ChallengeService = {}

local function grantReward(data, reward)
	if reward.cash then
		data.cash += reward.cash
	end
	if reward.luckySpins then
		data.luckySpinsOwned = (data.luckySpinsOwned or 0) + reward.luckySpins
	end
end

-- Roll a player to today if their stored day is stale; push an update if so.
local function rollover(player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	if ChallengeData.rolloverIfNeeded(data, ChallengeData.dayIndex(os.time())) then
		Remotes.PlayerStateUpdated:FireClient(player, data)
	end
end

function ChallengeService.start()
	Remotes.RequestClaimChallenge.OnServerEvent:Connect(function(player, id)
		if type(id) ~= "string" then
			return
		end
		local data = PlayerData.get(player)
		if not data then
			return
		end
		-- Make sure we're on today's set before validating a claim.
		ChallengeData.rolloverIfNeeded(data, ChallengeData.dayIndex(os.time()))
		local reward = ChallengeData.applyClaim(data, id)
		if not reward then
			return -- not complete, already claimed, not in today's set, or unknown id
		end
		grantReward(data, reward)
		PlayerData.save(player)
		Remotes.PlayerStateUpdated:FireClient(player, data)
	end)

	-- Roll over on join (once the player's data has loaded).
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			for _ = 1, 20 do
				if PlayerData.get(player) then
					break
				end
				task.wait(0.5)
			end
			rollover(player)
		end)
	end)
	-- Players already present (e.g. a live script reload).
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			rollover(p)
		end)
	end

	-- Catch the day boundary for players who stay online across midnight.
	task.spawn(function()
		while true do
			task.wait(30)
			for _, p in ipairs(Players:GetPlayers()) do
				rollover(p)
			end
		end
	end)
end

return ChallengeService

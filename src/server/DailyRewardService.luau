-- Daily reward streak: come back each day for an escalating reward.
--
-- A reward is claimable once `DailyClaimCooldownSeconds` has passed since the
-- last claim. If the player returns within `DailyStreakResetSeconds`, the
-- streak climbs; otherwise it restarts at day 1. All timing uses os.time()
-- (real-world clock) so "daily" means an actual day.

local Players = game:GetService("Players")
local GameData = require(game.ReplicatedStorage.Shared.GameData)
local EventData = require(game.ReplicatedStorage.Shared.EventData)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)

local DailyRewardService = {}

local function nowSeconds()
	return os.time()
end

-- Applies one calendar reward to `data`. The reward must already be scaled (see
-- GameData.getScaledDailyReward). Returns a description of what was actually
-- granted, which can differ from the ladder entry: the day-30 Champion part
-- falls back to consolation cash once all 7 are collected.
local function grantReward(data, reward)
	if reward.kind == "champion" then
		local partId, bonus = EventData.rollChampionPart(data)
		if partId then
			EventData.applyChampionGrant(data, partId, bonus)
			return ("\240\159\143\134 Champion %s!"):format(partId)
		end
		local consolation = EventData.consolationCash(data)
		data.cash += consolation
		return ("$%d"):format(consolation)
	end

	if reward.spins then
		data.luckySpinsOwned = (data.luckySpinsOwned or 0) + reward.spins
	end
	if reward.amount then
		data.cash += reward.amount
	end
	if reward.mult then
		-- Shared rule: only the duration stacks; the multiplier takes the higher
		-- value (never the sum).
		GameData.applyBoost(data, reward.mult, reward.dur, "\240\159\142\129", "Daily Boost", workspace:GetServerTimeNow())
	end
	return GameData.describeDailyReward(reward)
end

-- Tell a player whether a daily reward is waiting (called after their data
-- loads on join). Also tells them when a broken streak can be repaired.
function DailyRewardService.checkForPlayer(player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local decision = GameData.evaluateDailyStreak(data, nowSeconds())
	if decision.available or decision.repairOffered then
		local reward = GameData.getScaledDailyReward(data, decision.nextStreak)
		Remotes.DailyRewardAvailable:FireClient(
			player,
			decision.nextStreak,
			GameData.describeDailyReward(reward),
			decision.repairOffered,
			decision.brokenStreak
		)
	end
end

function DailyRewardService.start()
	Remotes.RequestClaimDaily.OnServerEvent:Connect(function(player)
		local data = PlayerData.get(player)
		if not data then
			return
		end
		local decision = GameData.evaluateDailyStreak(data, nowSeconds())
		if not decision.available then
			return -- not claimable yet (or a double-fire); ignore
		end

		local reward = GameData.getScaledDailyReward(data, decision.nextStreak)
		data.lastDailyClaim = nowSeconds()
		data.dailyStreak = decision.nextStreak

		-- Apply the streak bookkeeping the pure evaluation reported.
		if decision.usedFreeSkip then
			data.dailySkipUsed = true
		end
		if decision.calendarRestart then
			data.dailySkipUsed = false -- a fresh calendar gets a fresh free skip
		end
		-- Claiming without repairing accepts the loss and clears the offer.
		data.dailyBrokenStreak = 0

		local grantedDesc = grantReward(data, reward)

		Remotes.PlayerStateUpdated:FireClient(player, data)
		Remotes.DailyRewardClaimed:FireClient(player, decision.nextStreak, grantedDesc)
	end)
end

return DailyRewardService

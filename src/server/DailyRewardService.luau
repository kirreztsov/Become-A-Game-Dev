-- Daily reward streak: come back each day for an escalating reward.
--
-- A reward is claimable once `DailyClaimCooldownSeconds` has passed since the
-- last claim. If the player returns within `DailyStreakResetSeconds`, the
-- streak climbs; otherwise it restarts at day 1. All timing uses os.time()
-- (real-world clock) so "daily" means an actual day.

local Players = game:GetService("Players")
local GameData = require(game.ReplicatedStorage.Shared.GameData)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)

local DailyRewardService = {}

local function nowSeconds()
	return os.time()
end

-- Is a reward claimable right now, and what streak day would it be?
local function evaluate(data)
	local now = nowSeconds()
	local last = data.lastDailyClaim or 0
	local elapsed = now - last
	local available = (last == 0) or (elapsed >= GameData.DailyClaimCooldownSeconds)
	-- Continue the streak if they returned before the reset window; else restart.
	local nextStreak
	if last == 0 or elapsed > GameData.DailyStreakResetSeconds then
		nextStreak = 1
	else
		nextStreak = (data.dailyStreak or 0) + 1
	end
	return available, nextStreak
end

-- Tell a player whether a daily reward is waiting (called after their data
-- loads on join). Fires DailyRewardAvailable with the streak day + a preview.
function DailyRewardService.checkForPlayer(player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local available, nextStreak = evaluate(data)
	if available then
		local reward = GameData.getDailyReward(nextStreak)
		Remotes.DailyRewardAvailable:FireClient(player, nextStreak, GameData.describeDailyReward(reward))
	end
end

function DailyRewardService.start()
	Remotes.RequestClaimDaily.OnServerEvent:Connect(function(player)
		local data = PlayerData.get(player)
		if not data then
			return
		end
		local available, nextStreak = evaluate(data)
		if not available then
			return -- not claimable yet (or double-fire); ignore
		end

		local reward = GameData.getDailyReward(nextStreak)
		data.lastDailyClaim = nowSeconds()
		data.dailyStreak = nextStreak

		if reward.kind == "boost" then
			-- Shared rule: only the duration stacks; the multiplier takes the
			-- higher value (never the sum).
			GameData.applyBoost(data, reward.mult, reward.dur, "\240\159\142\129", "Daily Boost", workspace:GetServerTimeNow())
		else
			data.cash += reward.amount
		end

		Remotes.PlayerStateUpdated:FireClient(player, data)
		Remotes.DailyRewardClaimed:FireClient(player, nextStreak, GameData.describeDailyReward(reward))
	end)
end

return DailyRewardService

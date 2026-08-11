-- Daily challenges (roadmap A3). Each day the game shows the same 3 challenges to
-- everyone (chosen deterministically from a pool by the day index), and progress
-- is measured as TODAY's gain: current stat minus a baseline snapshotted at the
-- start of the player's day. Reset + baseline are server-authoritative
-- (ChallengeService); all the math here is pure so the client renders from the
-- same data it already gets via PlayerStateUpdated. Tested in RunTests.
local ChallengeData = {}

ChallengeData.DAY_SECONDS = 86400
ChallengeData.PER_DAY = 3

-- Pool of daily challenges. stat is "games" or "subs" (both monotonic within a
-- day, so today's progress = current - baseline). Ordered so any 3 consecutive
-- picks mix the two stats. reward = { cash = n, luckySpins = n }.
ChallengeData.POOL = {
	{ id = "d_release_3", title = "Warm Up", desc = "Release 3 games today", icon = "🎮", stat = "games", target = 3, reward = { cash = 3000 } },
	{ id = "d_subs_200", title = "Get Noticed", desc = "Gain 200 subscribers today", icon = "⭐", stat = "subs", target = 200, reward = { cash = 2500 } },
	{ id = "d_release_6", title = "On a Roll", desc = "Release 6 games today", icon = "🎮", stat = "games", target = 6, reward = { cash = 8000 } },
	{ id = "d_subs_1000", title = "Going Up", desc = "Gain 1,000 subscribers today", icon = "⭐", stat = "subs", target = 1000, reward = { cash = 9000 } },
	{ id = "d_release_10", title = "Crunch Time", desc = "Release 10 games today", icon = "🎮", stat = "games", target = 10, reward = { cash = 16000, luckySpins = 1 } },
	{ id = "d_subs_3000", title = "Trending", desc = "Gain 3,000 subscribers today", icon = "⭐", stat = "subs", target = 3000, reward = { cash = 22000, luckySpins = 1 } },
}

local byId = {}
for _, c in ipairs(ChallengeData.POOL) do
	byId[c.id] = c
end

function ChallengeData.get(id)
	return byId[id]
end

-- Whole-day index for a unix time (UTC). Rolls at each 24h boundary.
function ChallengeData.dayIndex(now)
	return math.floor((now or 0) / ChallengeData.DAY_SECONDS)
end

-- Seconds until the next day boundary (for a "resets in" countdown).
function ChallengeData.secondsUntilReset(now)
	now = now or 0
	return ChallengeData.DAY_SECONDS - (now % ChallengeData.DAY_SECONDS)
end

-- The PER_DAY challenges for a given day index: a rotating window over the pool,
-- so the set changes every day and cycles through all pool entries.
function ChallengeData.dailySet(dayIndex)
	local n = #ChallengeData.POOL
	local out = {}
	for i = 0, ChallengeData.PER_DAY - 1 do
		out[i + 1] = ChallengeData.POOL[((dayIndex + i) % n) + 1]
	end
	return out
end

local function statCurrent(data, stat)
	if stat == "games" then
		return data.gamesReleased or 0
	elseif stat == "subs" then
		return data.subscribers or 0
	end
	return 0
end

-- Today's progress toward a challenge: (current stat - baseline), clamped to
-- [0, target]. Baseline lives in data.challengeBaseline (set on rollover).
function ChallengeData.progress(data, ch)
	local base = (data.challengeBaseline or {})[ch.stat] or 0
	local gained = statCurrent(data, ch.stat) - base
	return math.clamp(gained, 0, ch.target)
end

function ChallengeData.isComplete(data, ch)
	return ChallengeData.progress(data, ch) >= ch.target
end

function ChallengeData.isClaimed(data, id)
	return (data.challengeClaimed or {})[id] == true
end

function ChallengeData.canClaim(data, id)
	local ch = byId[id]
	if not ch then
		return false
	end
	return ChallengeData.isComplete(data, ch) and not ChallengeData.isClaimed(data, id)
end

-- If the player's stored challenge day is stale, start a fresh day: snapshot the
-- baseline stats and clear today's claims. Returns true if it changed anything.
-- Server-authoritative; the client must not call this (it only reads).
function ChallengeData.rolloverIfNeeded(data, dayIndex)
	if data.challengeDay == dayIndex then
		return false
	end
	data.challengeDay = dayIndex
	data.challengeBaseline = {
		games = data.gamesReleased or 0,
		subs = data.subscribers or 0,
	}
	data.challengeClaimed = {}
	return true
end

-- Mark a challenge claimed and return its reward. Pure: mutates
-- data.challengeClaimed only; caller grants the reward + saves. nil if not claimable.
function ChallengeData.applyClaim(data, id)
	if not ChallengeData.canClaim(data, id) then
		return nil
	end
	data.challengeClaimed = data.challengeClaimed or {}
	data.challengeClaimed[id] = true
	return byId[id].reward
end

-- Render list for the client: today's challenges with progress/flags/reward.
-- Pass the CLIENT's current dayIndex so it matches what the server rolled to.
function ChallengeData.list(data, dayIndex)
	local set = ChallengeData.dailySet(dayIndex)
	local out = {}
	for i, ch in ipairs(set) do
		local done = ChallengeData.isComplete(data, ch)
		out[i] = {
			id = ch.id,
			title = ch.title,
			desc = ch.desc,
			icon = ch.icon,
			progress = ChallengeData.progress(data, ch),
			target = ch.target,
			done = done,
			claimed = ChallengeData.isClaimed(data, ch.id),
			claimable = done and not ChallengeData.isClaimed(data, ch.id),
			reward = ch.reward,
		}
	end
	return out
end

function ChallengeData.claimableCount(data, dayIndex)
	local n = 0
	for _, ch in ipairs(ChallengeData.dailySet(dayIndex)) do
		if ChallengeData.canClaim(data, ch.id) then
			n += 1
		end
	end
	return n
end

return ChallengeData

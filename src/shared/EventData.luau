-- Sunday Showdown weekend event (roadmap B2). Active only on Sunday (server
-- UTC). A 6-quest arc whose targets scale continuously with the player's
-- progression; finishing all 6 grants a random "Champion" PC part worth 125% of
-- the player's best part. Progress is TODAY's gain vs a baseline snapshotted at
-- the start of the player's Sunday. All math here is pure (no side effects) so
-- the client renders from the same data it gets via PlayerStateUpdated, and the
-- server (EventService) owns baseline + claims. Tested in RunTests.
local GameData = require(script.Parent.GameData)

local EventData = {}

EventData.DAY_SECONDS = 86400
EventData.EVENT_DOW = 3 -- Unix day 0 is a Thursday, so day%7==3 is Sunday.
EventData.SUB_REF = 1000 -- progression scale reference (tunable)
EventData.CHAMPION_FACTOR = 1.25 -- a Champion part = 125% of your best part
EventData.MIN_CHAMPION_BONUS = 0.15 -- floor so a fresh winner still gets value

-- The 6 sequential quests. stat is one of "games"/"subs"/"cash"/"hits", all
-- monotonic-within-a-day counters so today's progress = current - baseline.
-- base = target at scale 1; rewardBase = cash reward at scale 1. cap (optional)
-- clamps the scaled target (used to keep the trendy-hit quest reachable).
EventData.QUESTS = {
	{ id = "e1_games", title = "Get Building", desc = "Release %d games today", icon = "🎮", stat = "games", base = 5, rewardBase = 3000 },
	{ id = "e2_subs", title = "Go Viral", desc = "Gain %d subscribers today", icon = "⭐", stat = "subs", base = 2000, rewardBase = 4000 },
	{ id = "e3_cash", title = "Cash In", desc = "Earn $%d today", icon = "💰", stat = "cash", base = 10000, rewardBase = 5000 },
	{ id = "e4_games", title = "Studio Grind", desc = "Release %d more games today", icon = "🎮", stat = "games", base = 12, rewardBase = 7000 },
	{ id = "e5_hits", title = "Chase the Trend", desc = "Release %d trendy hit(s) today", icon = "🔥", stat = "hits", base = 1, rewardBase = 9000, cap = 3 },
	{ id = "e6_cash", title = "Final Push", desc = "Earn $%d today", icon = "🏆", stat = "cash", base = 50000, rewardBase = 15000 },
}

function EventData.dayIndex(now)
	return math.floor((now or 0) / EventData.DAY_SECONDS)
end

-- True only on Sunday (server UTC).
function EventData.isEventActive(now)
	return EventData.dayIndex(now) % 7 == EventData.EVENT_DOW
end

-- Seconds until the current day ends (the "event ends in" countdown; only
-- meaningful while active).
function EventData.secondsUntilEnd(now)
	now = now or 0
	return EventData.DAY_SECONDS - (now % EventData.DAY_SECONDS)
end

-- Smooth, sub-linear progression multiplier from subscriber count. scale(0 subs)
-- == 1 and rises slowly (+1 per 10x subs past SUB_REF), so quest targets grow
-- with the player but stay achievable in a day. No bucketed tiers.
function EventData.scale(data)
	local subs = (data and data.subscribers) or 0
	return 1 + math.log(1 + subs / EventData.SUB_REF, 10)
end

-- The scale frozen at the start of the player's Sunday (data.eventScale, set by
-- rolloverIfNeeded), or live scale if a rollover hasn't happened yet. Targets
-- and rewards read this instead of live scale so a quest can't un-complete
-- itself when subscribers grow later the same day.
function EventData.frozenScale(data)
	return (data and data.eventScale) or EventData.scale(data)
end

function EventData.target(data, i)
	local q = EventData.QUESTS[i]
	if not q then return 0 end
	local t = math.ceil(q.base * EventData.frozenScale(data))
	if q.cap then
		t = math.min(q.cap, t)
	end
	return t
end

function EventData.rewardCash(data, i)
	local q = EventData.QUESTS[i]
	if not q then return 0 end
	return math.floor(q.rewardBase * EventData.frozenScale(data))
end

local function statCurrent(data, stat)
	if stat == "games" then
		return data.gamesReleased or 0
	elseif stat == "subs" then
		return data.subscribers or 0
	elseif stat == "cash" then
		return data.totalCashEarned or 0
	elseif stat == "hits" then
		return data.trendyHits or 0
	end
	return 0
end

-- Today's progress toward quest i: (current stat - baseline), clamped
-- [0, target]. Baseline lives in data.eventBaseline (set on rollover).
function EventData.progress(data, i)
	local q = EventData.QUESTS[i]
	if not q then return 0 end
	local base = (data.eventBaseline or {})[q.stat] or 0
	local gained = statCurrent(data, q.stat) - base
	return math.clamp(gained, 0, EventData.target(data, i))
end

function EventData.isComplete(data, i)
	return EventData.progress(data, i) >= EventData.target(data, i)
end

function EventData.isClaimed(data, i)
	return (data.eventQuestsClaimed or {})[i] == true
end

-- Sequential: quest i is claimable only if it is complete, unclaimed, and its
-- predecessor (if any) is already claimed. Time-gating (Sunday-only) is enforced
-- by the server; this stays pure and time-independent.
function EventData.canClaim(data, i)
	-- NaN fails every comparison, so check it explicitly (i ~= i) rather than
	-- relying on the range test to reject it.
	if type(i) ~= "number" or i ~= i or i < 1 or i > #EventData.QUESTS then
		return false
	end
	if EventData.isClaimed(data, i) then
		return false
	end
	if i > 1 and not EventData.isClaimed(data, i - 1) then
		return false
	end
	return EventData.isComplete(data, i)
end

-- Start a fresh Sunday arc when the stored event day is stale: snapshot the
-- baseline stats and clear this arc's claims. Keyed on dayIndex (like the daily
-- challenges); harmless on non-Sundays since the arc is inactive then. Returns
-- true if it changed anything. Server-authoritative; the client only reads.
function EventData.rolloverIfNeeded(data, dayIndex)
	if data.eventDay == dayIndex then
		return false
	end
	data.eventDay = dayIndex
	data.eventBaseline = {
		games = data.gamesReleased or 0,
		subs = data.subscribers or 0,
		cash = data.totalCashEarned or 0,
		hits = data.trendyHits or 0,
	}
	data.eventScale = EventData.scale(data)
	data.eventQuestsClaimed = {}
	return true
end

-- Mark quest i claimed and return its cash reward + whether it was the final
-- quest (the caller then rolls a Champion part). Pure: mutates
-- eventQuestsClaimed only; caller grants + saves. nil if not claimable.
function EventData.applyQuestClaim(data, i)
	if not EventData.canClaim(data, i) then
		return nil
	end
	data.eventQuestsClaimed = data.eventQuestsClaimed or {}
	data.eventQuestsClaimed[i] = true
	return { cash = EventData.rewardCash(data, i), final = (i == #EventData.QUESTS) }
end

-- The bonus of the player's single best-equipped shop part (max over all 7).
function EventData.bestPartBonus(data)
	local pcParts = (data and data.pcParts) or {}
	local best = 0
	for _, p in ipairs(GameData.PCParts) do
		local model = GameData.getPCPartModel(p.id, pcParts[p.id] or 0)
		if model and model.bonus > best then
			best = model.bonus
		end
	end
	return best
end

local function round2(x)
	return math.floor(x * 100 + 0.5) / 100
end

-- Roll a random PC-part category the player has NOT yet won a Champion of, and
-- the locked bonus for it (125% of their best current part, floored to a
-- meaningful minimum). Returns (nil, nil) when all 7 are already collected.
-- rng(n) -> integer in [1, n]; defaults to math.random for live play.
function EventData.rollChampionPart(data, rng)
	rng = rng or math.random
	local owned = data.eventParts or {}
	local pool = {}
	for _, p in ipairs(GameData.PCParts) do
		if owned[p.id] == nil then
			pool[#pool + 1] = p.id
		end
	end
	if #pool == 0 then
		return nil, nil
	end
	local partId = pool[rng(#pool)]
	local bonus = math.max(EventData.MIN_CHAMPION_BONUS, round2(EventData.CHAMPION_FACTOR * EventData.bestPartBonus(data)))
	return partId, bonus
end

function EventData.applyChampionGrant(data, partId, bonus)
	data.eventParts = data.eventParts or {}
	data.eventParts[partId] = bonus
end

-- Consolation cash when the final quest is finished but all 7 Champion parts are
-- already collected (the chase is complete).
function EventData.consolationCash(data)
	return math.floor(20000 * EventData.scale(data))
end

-- Client render: the 6 quests with progress/targets/flags/reward.
function EventData.list(data)
	local out = {}
	for i, q in ipairs(EventData.QUESTS) do
		local target = EventData.target(data, i)
		local done = EventData.isComplete(data, i)
		local claimed = EventData.isClaimed(data, i)
		local locked = (i > 1) and not EventData.isClaimed(data, i - 1)
		out[i] = {
			index = i,
			title = q.title,
			desc = string.format(q.desc, target),
			icon = q.icon,
			progress = EventData.progress(data, i),
			target = target,
			done = done,
			claimed = claimed,
			locked = locked,
			claimable = EventData.canClaim(data, i),
			rewardCash = EventData.rewardCash(data, i),
		}
	end
	return out
end

-- Client render: the 7-part Champion collection strip.
function EventData.championList(data)
	local owned = (data and data.eventParts) or {}
	local out = {}
	for _, p in ipairs(GameData.PCParts) do
		out[#out + 1] = {
			id = p.id,
			icon = p.icon,
			name = p.name,
			owned = owned[p.id] ~= nil,
			bonus = owned[p.id],
		}
	end
	return out
end

function EventData.championCount(data)
	local n = 0
	for _ in pairs((data and data.eventParts) or {}) do
		n += 1
	end
	return n
end

function EventData.claimableCount(data)
	local n = 0
	for i = 1, #EventData.QUESTS do
		if EventData.canClaim(data, i) then
			n += 1
		end
	end
	return n
end

return EventData

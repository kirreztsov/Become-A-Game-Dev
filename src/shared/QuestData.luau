-- Quest / achievement ladder. A flat list of goals a player works toward; each
-- reads a stat straight off the player's data table and completes when the stat
-- reaches its target. Claiming is server-authoritative (QuestService), but all
-- the progress math lives here (pure) so the client can render bars from the
-- same data it already receives via PlayerStateUpdated. Tested in RunTests.
local QuestData = {}

-- Stat readers: given a player data table, return the current numeric progress.
local STATS = {
	games = function(d)
		return d.gamesReleased or 0
	end,
	subs = function(d)
		return d.subscribers or 0
	end,
	cash = function(d)
		return d.cash or 0
	end,
	prestige = function(d)
		return d.prestigeLevel or 0
	end,
	streak = function(d)
		return d.dailyStreak or 0
	end,
	pcPower = function(d)
		local sum = 0
		for _, lvl in pairs(d.pcParts or {}) do
			sum += (lvl or 0)
		end
		return sum
	end,
	workersHired = function(d)
		local n = 0
		for _, w in pairs(d.workers or {}) do
			if w and w.hired then
				n += 1
			end
		end
		return n
	end,
	rooms = function(d)
		local n = 0
		for _, owned in pairs(d.roomsOwned or {}) do
			if owned then
				n += 1
			end
		end
		return n
	end,
}

-- Ordered quest ladder. reward = { cash = n, luckySpins = n }.
QuestData.QUESTS = {
	{ id = "first_game", title = "First Release", desc = "Release your first game", icon = "🎮", stat = "games", target = 1, reward = { cash = 100 } },
	{ id = "cash_10k", title = "Saver", desc = "Have $10,000 in the bank", icon = "💰", stat = "cash", target = 10000, reward = { cash = 2000 } },
	{ id = "games_10", title = "Getting Started", desc = "Release 10 games", icon = "🎮", stat = "games", target = 10, reward = { cash = 750 } },
	{ id = "subs_1k", title = "Rising Star", desc = "Reach 1,000 subscribers", icon = "⭐", stat = "subs", target = 1000, reward = { cash = 2000 } },
	{ id = "workers_all", title = "Full Team", desc = "Hire all 3 workers", icon = "👥", stat = "workersHired", target = 3, reward = { cash = 4000 } },
	{ id = "pc_power_10", title = "PC Builder", desc = "Upgrade PC parts 10 levels total", icon = "🖥️", stat = "pcPower", target = 10, reward = { cash = 3000 } },
	{ id = "rooms_all", title = "Property Mogul", desc = "Own both money rooms", icon = "🏢", stat = "rooms", target = 2, reward = { cash = 6000 } },
	{ id = "games_50", title = "Prolific", desc = "Release 50 games", icon = "🎮", stat = "games", target = 50, reward = { cash = 5000 } },
	{ id = "subs_25k", title = "Popular", desc = "Reach 25,000 subscribers", icon = "⭐", stat = "subs", target = 25000, reward = { cash = 15000 } },
	{ id = "streak_7", title = "Loyal", desc = "Hit a 7-day login streak", icon = "🔥", stat = "streak", target = 7, reward = { cash = 8000 } },
	{ id = "pc_power_25", title = "Rig Master", desc = "Upgrade PC parts 25 levels total", icon = "🖥️", stat = "pcPower", target = 25, reward = { cash = 12000 } },
	{ id = "prestige_1", title = "Reborn", desc = "Rebirth for the first time", icon = "🌟", stat = "prestige", target = 1, reward = { cash = 10000, luckySpins = 1 } },
	{ id = "cash_1m", title = "Millionaire", desc = "Have $1,000,000 in the bank", icon = "💰", stat = "cash", target = 1000000, reward = { cash = 50000 } },
	{ id = "subs_100k", title = "Viral", desc = "Reach 100,000 subscribers", icon = "⭐", stat = "subs", target = 100000, reward = { cash = 60000, luckySpins = 1 } },
	{ id = "games_200", title = "Studio Machine", desc = "Release 200 games", icon = "🎮", stat = "games", target = 200, reward = { cash = 30000 } },
}

local byId = {}
for _, q in ipairs(QuestData.QUESTS) do
	byId[q.id] = q
end

function QuestData.get(id)
	return byId[id]
end

-- Current progress toward a quest (capped at its target).
function QuestData.progress(data, quest)
	local reader = STATS[quest.stat]
	local cur = reader and reader(data) or 0
	return math.min(cur, quest.target)
end

function QuestData.isComplete(data, quest)
	local reader = STATS[quest.stat]
	return reader ~= nil and reader(data) >= quest.target
end

function QuestData.isClaimed(data, id)
	return (data.questsClaimed or {})[id] == true
end

-- A quest is claimable when it's complete and not already claimed.
function QuestData.canClaim(data, id)
	local quest = byId[id]
	if not quest then
		return false
	end
	return QuestData.isComplete(data, quest) and not QuestData.isClaimed(data, id)
end

-- Mark a quest claimed and return its reward table. Pure: mutates
-- data.questsClaimed only; the caller (server) grants the reward + saves.
-- Returns nil if the quest can't be claimed right now.
function QuestData.applyClaim(data, id)
	if not QuestData.canClaim(data, id) then
		return nil
	end
	data.questsClaimed = data.questsClaimed or {}
	data.questsClaimed[id] = true
	return byId[id].reward
end

-- Full render list for the client: progress, target, flags, reward per quest.
function QuestData.list(data)
	local out = {}
	for i, q in ipairs(QuestData.QUESTS) do
		local done = QuestData.isComplete(data, q)
		out[i] = {
			id = q.id,
			title = q.title,
			desc = q.desc,
			icon = q.icon,
			progress = QuestData.progress(data, q),
			target = q.target,
			done = done,
			claimed = QuestData.isClaimed(data, q.id),
			claimable = done and not QuestData.isClaimed(data, q.id),
			reward = q.reward,
		}
	end
	return out
end

-- How many quests are claimable right now (for a HUD badge).
function QuestData.claimableCount(data)
	local n = 0
	for _, q in ipairs(QuestData.QUESTS) do
		if QuestData.canClaim(data, q.id) then
			n += 1
		end
	end
	return n
end

return QuestData

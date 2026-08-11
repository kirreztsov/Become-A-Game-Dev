local DataStoreService = game:GetService("DataStoreService")
local GameData = require(game.ReplicatedStorage.Shared.GameData)

local playerStore = DataStoreService:GetDataStore("PlayerData_v2")

local PlayerData = {}
local cache = {}
local failedLoads = {}

local function defaultData()
	return {
		cash = GameData.StartingCash,
		gamesReleased = 0,
		houseTier = 0,
		pcTier = 0,
		-- PC Parts Shop: level (0..PCPartMaxLevel) per component. Money parts
		-- (CPU/RAM/Storage/Cooling) scale cash/game; follower parts
		-- (GPU/Monitor/RGB) scale subscribers/release. Replaces the pcTier upgrade.
		pcParts = { CPU = 0, RAM = 0, Storage = 0, Cooling = 0, GPU = 0, Monitor = 0, RGB = 0 },
		workers = {
			Coding = { hired = false, level = 0, rarity = nil },
			MapBuilding = { hired = false, level = 0, rarity = nil },
			Testing = { hired = false, level = 0, rarity = nil },
		},
		-- Uncollected idle earnings per side room (see PlotManager idle loop).
		idle = { Arcade = 0, Merch = 0 },
		-- Which money rooms the player has bought (tycoon buy-buttons). Rooms
		-- only earn once owned; no longer unlocked by house tier.
		roomsOwned = { Arcade = false, Merch = false },
		-- Server-time (Workspace:GetServerTimeNow) that the shop cash-boost
		-- runs until; 0 = no active boost. boostMult is that boost's size.
		boostUntil = 0,
		boostMult = 1,
		-- Icon + label of the active boost, for the on-screen boost timer.
		boostIcon = nil,
		boostLabel = nil,
		-- Chosen character tint + label from the Clothes shop (nil = default).
		outfitColor = nil,
		outfitLabel = nil,
		-- Studio decorations the player has placed: a list of
		-- { id, x, y, z, yaw } (DataStore-safe numbers).
		decorations = {},
		-- Channel subscribers, the highest Play Button milestone index reached,
		-- and a carry for fractional ad-revenue cash between ticks.
		subscribers = 0,
		subMilestone = 0,
		subAdAccum = 0,
		-- Daily reward streak: os.time() of the last claim, and the current
		-- streak length (see DailyRewardService).
		lastDailyClaim = 0,
		dailyStreak = 0,
		-- How many times the player has prestiged/rebirthed (permanent bonus).
		prestigeLevel = 0,
		-- os.time() of the player's last save (for offline earnings). 0 = no
		-- baseline yet, so the first-ever session never pays out.
		lastOnline = 0,
		-- Rebirth perk tree (see PerkData): unspent Prestige Points + bought perk
		-- levels (perkId -> level). Points are earned on each rebirth.
		perkPoints = 0,
		perks = {},
		-- Case pity counters (spins since the last guaranteed drop).
		normalPity = 0,
		luckyPity = 0,
		-- Unspun spins the player has bought and can open whenever (stackable).
		normalSpinsOwned = 0,
		luckySpinsOwned = 0,
		-- Whether the player has finished (or skipped) the onboarding tutorial.
		tutorialDone = false,
		-- Remembered UI preference: dark mode on/off.
		darkMode = false,
		-- Remembered UI preference: sound muted on/off.
		soundMuted = false,
		-- Chosen cosmetic studio skin ("Default", "Gold", "Neon", "Midnight").
		activeSkin = "Default",
		-- Owned game passes (key -> true), and whether the one-time Starter Pack
		-- has been bought. Passes are re-verified from Roblox on join.
		passes = {},
		starterPackBought = false,
		-- Robux receipt PurchaseIds already granted (dedupe so a retried receipt
		-- never double-grants). Set by MonetizationService.ProcessReceipt.
		processedReceipts = {},
		-- Quest/achievement ids the player has claimed the reward for (see QuestData).
		questsClaimed = {},
		-- Daily challenges (see ChallengeData): the day index the current set +
		-- baseline belong to, the stat snapshot taken at that day's start, and
		-- which of today's challenges have been claimed. -1 forces a fresh roll.
		challengeDay = -1,
		challengeBaseline = { games = 0, subs = 0 },
		challengeClaimed = {},
		-- Global-leaderboard "this week" gains (reset on week rollover) and the
		-- week index they belong to.
		weekAnchor = require(game.ReplicatedStorage.Shared.GameData).getWeekIndex(os.time()),
		weekly = { prestigeLevel = 0, subscribers = 0, cash = 0, gamesReleased = 0 },
		-- Placed furniture in the player's private Home room.
		homeItems = {},
	}
end

function PlayerData.load(player)
	local success, data = pcall(function()
		return playerStore:GetAsync("Player_" .. player.UserId)
	end)

	if success then
		if data then
			-- Existing save found in DataStore -- backfill any fields added since this save was written
			data.houseTier = data.houseTier or 0
			data.pcTier = data.pcTier or 0
			-- Backfill PC part levels (added with the PC Parts Shop).
			data.pcParts = data.pcParts or {}
			for _, p in ipairs(GameData.PCParts) do
				data.pcParts[p.id] = data.pcParts[p.id] or 0
			end
			data.idle = data.idle or { Arcade = 0, Merch = 0 }
			data.roomsOwned = data.roomsOwned or { Arcade = false, Merch = false }
			data.boostUntil = 0 -- boosts are session-only; never restore a stale one
			data.boostMult = data.boostMult or 1
			data.decorations = data.decorations or {}
			data.subscribers = data.subscribers or 0
			data.subMilestone = data.subMilestone or 0
			data.subAdAccum = data.subAdAccum or 0
			data.lastDailyClaim = data.lastDailyClaim or 0
			data.dailyStreak = data.dailyStreak or 0
			data.prestigeLevel = data.prestigeLevel or 0
			data.perkPoints = data.perkPoints or 0
			data.perks = data.perks or {}
			data.lastOnline = data.lastOnline or 0
			data.normalPity = data.normalPity or 0
			data.luckyPity = data.luckyPity or 0
			data.normalSpinsOwned = data.normalSpinsOwned or 0
			data.luckySpinsOwned = data.luckySpinsOwned or 0
			if data.tutorialDone == nil then
				data.tutorialDone = false
			end
			if data.darkMode == nil then
				data.darkMode = false
			end
			if data.soundMuted == nil then
				data.soundMuted = false
			end
			if data.activeSkin == nil then
				data.activeSkin = "Default"
			end
			data.passes = data.passes or {}
			if data.starterPackBought == nil then
				data.starterPackBought = false
			end
			data.processedReceipts = data.processedReceipts or {}
			data.questsClaimed = data.questsClaimed or {}
			if data.challengeDay == nil then
				data.challengeDay = -1
			end
			data.challengeBaseline = data.challengeBaseline or { games = 0, subs = 0 }
			data.challengeClaimed = data.challengeClaimed or {}
			local GameDataMod = require(game.ReplicatedStorage.Shared.GameData)
			if data.weekAnchor == nil then
				data.weekAnchor = GameDataMod.getWeekIndex(os.time())
			end
			if type(data.weekly) ~= "table" then
				data.weekly = { prestigeLevel = 0, subscribers = 0, cash = 0, gamesReleased = 0 }
			else
				data.weekly.prestigeLevel = data.weekly.prestigeLevel or 0
				data.weekly.subscribers = data.weekly.subscribers or 0
				data.weekly.cash = data.weekly.cash or 0
				data.weekly.gamesReleased = data.weekly.gamesReleased or 0
			end
			if type(data.homeItems) ~= "table" then
				data.homeItems = {}
			end
			-- outfitColor is stored as a DataStore-safe {r,g,b} table (or nil).
			cache[player.UserId] = data
			failedLoads[player.UserId] = nil
		else
			-- No prior save: truly a new player
			cache[player.UserId] = defaultData()
			failedLoads[player.UserId] = nil
		end
	else
		-- GetAsync errored: cache defaults for this session, but mark load as failed
		cache[player.UserId] = defaultData()
		failedLoads[player.UserId] = true
		warn(("Failed to load data for %s; saves will be skipped until load succeeds: %s"):format(player.Name, tostring(data)))
	end

	return cache[player.UserId]
end

function PlayerData.get(player)
	return cache[player.UserId]
end

-- True when this player's most recent load FAILED (so their cached data is
-- defaults, not their real save). Writers should refuse to persist in this
-- state, or they'd overwrite real data with zeros.
function PlayerData.loadFailed(player)
	return failedLoads[player.UserId] == true
end

-- Returns true only if the data was actually written to the DataStore. Callers
-- that gate a Robux grant on a successful save (ProcessReceipt) rely on this.
function PlayerData.save(player)
	-- Refuse to save if the most recent load failed; prevents overwriting real data with defaults
	if failedLoads[player.UserId] then
		warn(("Refusing to save data for %s: the most recent load failed; will not overwrite DataStore until a successful load clears this flag"):format(player.Name))
		return false
	end

	local data = cache[player.UserId]
	if not data then
		return false
	end

	-- Freshen the "last seen online" stamp so next join can pay offline earnings
	-- for the gap since this save. (Save runs on autosave, leave, and BindToClose.)
	data.lastOnline = os.time()

	-- retry a few times so a transient throttle doesn't silently drop progress
	local success, err
	for attempt = 1, 4 do
		success, err = pcall(function()
			playerStore:SetAsync("Player_" .. player.UserId, data)
		end)
		if success then
			return true
		end
		task.wait(attempt * 0.6) -- backoff before retrying
	end

	warn(("Failed to save data for %s after retries: %s"):format(player.Name, tostring(err)))
	return false
end

function PlayerData.remove(player)
	cache[player.UserId] = nil
	failedLoads[player.UserId] = nil
end

-- Reset this-week gains when a new week has started.
function PlayerData.rolloverWeekIfNeeded(data, now)
	local wk = GameData.getWeekIndex(now)
	if data.weekAnchor ~= wk then
		data.weekAnchor = wk
		data.weekly = { prestigeLevel = 0, subscribers = 0, cash = 0, gamesReleased = 0 }
	end
end

-- Credit a positive gain toward this week's leaderboard tally.
function PlayerData.addWeekly(data, stat, delta, now)
	if not data then return end
	PlayerData.rolloverWeekIfNeeded(data, now)
	if delta and delta > 0 and data.weekly[stat] ~= nil then
		data.weekly[stat] += math.floor(delta)
	end
end

return PlayerData

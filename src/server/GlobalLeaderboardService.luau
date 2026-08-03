-- Global, cross-server leaderboards backed by OrderedDataStores.
-- One all-time store + one week-keyed store per stat. A writer loop pushes each
-- player's current values (+ this-week gains); a reader loop pulls the top 100
-- into a cache the boards + client panel read from. All DataStore calls are
-- pcall-guarded: in Studio (API off) or on failure, getRows returns nil and the
-- UI shows a placeholder. Never errors the game.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local GameData = require(game.ReplicatedStorage.Shared.GameData)
local PlayerData = require(script.Parent.PlayerData)

local GlobalLeaderboardService = {}

local WRITE_SECONDS = 60
local READ_SECONDS = 45
local PAGE = 100

-- cache[statKey][period] = { {name, value, userId}, ... }  (nil until first good read)
local cache = {}
local nameCache = {}

local function getStore(period, key)
	local weekIndex = GameData.getWeekIndex(os.time())
	local name = GameData.leaderboardStoreName(period, key, weekIndex)
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(name)
	end)
	if ok then
		return store
	end
	return nil
end

local function valueFor(data, period, key)
	if period == "week" then
		return (data.weekly and data.weekly[key]) or 0
	end
	return data[key] or 0
end

-- Write one player's 8 values (4 stats x 2 periods). Each SetAsync in its own pcall.
local function writePlayer(player)
	local data = PlayerData.get(player)
	if not data then return end
	-- If this player's load failed, `data` is defaults (zeros) -- writing it
	-- would clobber their real global standing. Skip, like PlayerData.save does.
	if PlayerData.loadFailed(player) then return end
	PlayerData.rolloverWeekIfNeeded(data, os.time())
	for _, stat in ipairs(GameData.LeaderboardStats) do
		for _, period in ipairs({ "all", "week" }) do
			local store = getStore(period, stat.key)
			if store then
				local v = math.max(0, math.floor(valueFor(data, period, stat.key)))
				pcall(function()
					store:SetAsync(tostring(player.UserId), v)
				end)
			end
		end
	end
end

function GlobalLeaderboardService.flush(player)
	writePlayer(player)
end

local function resolveName(userId)
	-- Prefer a connected player's display name.
	local plr = Players:GetPlayerByUserId(userId)
	if plr then
		nameCache[userId] = plr.DisplayName
		return plr.DisplayName
	end
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local resolved = (ok and name) or ("Player" .. userId)
	nameCache[userId] = resolved
	return resolved
end

-- Read the top 100 for one (period, stat) into the cache. Leaves the old cache
-- intact on failure.
local function readOne(period, stat)
	local store = getStore(period, stat.key)
	if not store then return end
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, PAGE)
	end)
	if not ok or not pages then return end
	local okPage, page = pcall(function()
		return pages:GetCurrentPage()
	end)
	if not okPage or not page then return end
	local rows = {}
	for _, entry in ipairs(page) do
		local userId = tonumber(entry.key)
		if userId then
			rows[#rows + 1] = { userId = userId, value = entry.value, name = resolveName(userId) }
		end
	end
	cache[stat.key] = cache[stat.key] or {}
	cache[stat.key][period] = rows
end

function GlobalLeaderboardService.getRows(statKey, period)
	local byStat = cache[statKey]
	if not byStat then return nil end
	return byStat[period] -- may be nil until first successful read
end

function GlobalLeaderboardService.getSelfStanding(player, statKey, period)
	local data = PlayerData.get(player)
	local live = 0
	if data then
		live = math.floor(valueFor(data, period, statKey))
	end
	local rows = GlobalLeaderboardService.getRows(statKey, period) or {}
	return GameData.computeStanding(rows, player.UserId, live)
end

function GlobalLeaderboardService.start()
	-- Writer: push everyone's numbers on a timer, and on leave.
	task.spawn(function()
		while true do
			task.wait(WRITE_SECONDS)
			for _, player in ipairs(Players:GetPlayers()) do
				pcall(writePlayer, player)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		pcall(writePlayer, player)
	end)
	-- Reader: refresh the cache on a timer.
	task.spawn(function()
		while true do
			for _, stat in ipairs(GameData.LeaderboardStats) do
				for _, period in ipairs({ "all", "week" }) do
					pcall(readOne, period, stat)
				end
			end
			task.wait(READ_SECONDS)
		end
	end)
end

return GlobalLeaderboardService

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
		workers = {
			Coding = { hired = false, level = 0 },
			MapBuilding = { hired = false, level = 0 },
			Testing = { hired = false, level = 0 },
		},
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

function PlayerData.save(player)
	-- Refuse to save if the most recent load failed; prevents overwriting real data with defaults
	if failedLoads[player.UserId] then
		warn(("Refusing to save data for %s: the most recent load failed; will not overwrite DataStore until a successful load clears this flag"):format(player.Name))
		return
	end

	local data = cache[player.UserId]
	if not data then
		return
	end

	local success, err = pcall(function()
		playerStore:SetAsync("Player_" .. player.UserId, data)
	end)

	if not success then
		warn(("Failed to save data for %s: %s"):format(player.Name, tostring(err)))
	end
end

function PlayerData.remove(player)
	cache[player.UserId] = nil
	failedLoads[player.UserId] = nil
end

return PlayerData

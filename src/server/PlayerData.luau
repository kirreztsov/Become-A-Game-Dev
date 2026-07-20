local DataStoreService = game:GetService("DataStoreService")
local GameData = require(game.ReplicatedStorage.Shared.GameData)

local playerStore = DataStoreService:GetDataStore("PlayerData_v1")

local PlayerData = {}
local cache = {}

local function defaultData()
	return {
		cash = GameData.StartingCash,
		devSpeedLevel = 0,
		qualityBoostLevel = 0,
		gamesReleased = 0,
	}
end

function PlayerData.load(player)
	local success, data = pcall(function()
		return playerStore:GetAsync("Player_" .. player.UserId)
	end)

	if success and data then
		cache[player.UserId] = data
	else
		cache[player.UserId] = defaultData()
	end

	return cache[player.UserId]
end

function PlayerData.get(player)
	return cache[player.UserId]
end

function PlayerData.save(player)
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
end

return PlayerData

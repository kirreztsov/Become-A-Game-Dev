local GameData = require(game.ReplicatedStorage.Shared.GameData)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)

local TrendsService = {}

local currentTrend1
local currentTrend2

local function rollTrend()
	return {
		genre = GameData.Genres[math.random(1, #GameData.Genres)],
		topic = GameData.Topics[math.random(1, #GameData.Topics)],
	}
end

local function refresh()
	currentTrend1 = rollTrend()
	currentTrend2 = rollTrend()
	Remotes.TrendsUpdated:FireAllClients(currentTrend1, currentTrend2)
end

function TrendsService.start()
	refresh()
	task.spawn(function()
		while true do
			task.wait(GameData.TrendRefreshSeconds)
			refresh()
		end
	end)
end

function TrendsService.getCurrent()
	return currentTrend1, currentTrend2
end

function TrendsService.sendCurrentTo(player)
	Remotes.TrendsUpdated:FireClient(player, currentTrend1, currentTrend2)
end

return TrendsService

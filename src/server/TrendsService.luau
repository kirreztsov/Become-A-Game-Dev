local GameData = require(game.ReplicatedStorage.Shared.GameData)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)

local TrendsService = {}

local currentTrend1
local currentTrend2
-- Live content-unlock roll table (id -> percentage), server-owned. Rerolled
-- alongside trends every TrendRefreshSeconds; read directly by
-- DevelopmentService when it computes a release's cash payout, and broadcast
-- on TrendsUpdated for display only (see GameData.rollContentBonuses).
local currentContentRolls = {}

local function rollTrend()
	return {
		genre = GameData.Genres[math.random(1, #GameData.Genres)],
		topic = GameData.Topics[math.random(1, #GameData.Topics)],
	}
end

local function refresh()
	currentTrend1 = rollTrend()
	currentTrend2 = rollTrend()
	currentContentRolls = GameData.rollContentBonuses()
	Remotes.TrendsUpdated:FireAllClients(currentTrend1, currentTrend2, currentContentRolls)
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

-- The server's own live content-unlock roll table (id -> percentage). Never
-- sent by the client and never trusted from it -- DevelopmentService reads
-- this directly when it computes a release's cash payout.
function TrendsService.getContentRolls()
	return currentContentRolls
end

function TrendsService.sendCurrentTo(player)
	Remotes.TrendsUpdated:FireClient(player, currentTrend1, currentTrend2, currentContentRolls)
end

return TrendsService

local GameData = {}

GameData.Genres = { "Racing", "Horror", "Adventure", "Simulator" }
GameData.Topics = { "Space", "Zombies", "Sports", "Fantasy" }

GameData.StartingCash = 0
GameData.PayoutMultiplier = 10

GameData.TrendRefreshSeconds = 300
GameData.TrendBonusChance = 0.1
GameData.TrendBonusMultiplier = 5

GameData.Phases = { "Coding", "MapBuilding", "Testing" }
GameData.RoundsPerPhase = 3

GameData.CodingRoundSeconds = 3
GameData.CodingTargetTaps = 15

GameData.MapBuildingRoundSeconds = 2
GameData.MapBuildingZoneCenter = 0.5
GameData.MapBuildingZoneHalfWidth = 0.15
GameData.MapBuildingMaxWaitSeconds = 4

GameData.TestingMaxWaitSeconds = 15
GameData.TestingWrongAnswerScore = 0.3
GameData.TestingQuestions = {
	{
		prompt = "A player found a game-breaking bug the night before launch. What do you do?",
		options = { "Ship it anyway, patch later", "Fix it, even if launch slips" },
		correctIndex = 2,
	},
	{
		prompt = "Your loading screen takes 30 seconds. What's the fix?",
		options = { "Add a longer loading bar animation", "Optimize and compress assets" },
		correctIndex = 2,
	},
	{
		prompt = "Players say the tutorial is confusing. What do you do?",
		options = { "Assume they'll figure it out", "Rewrite the tutorial to be clearer" },
		correctIndex = 2,
	},
	{
		prompt = "You added a fun new feature but it lags the game. What now?",
		options = { "Ship it, lag builds character", "Optimize it before shipping" },
		correctIndex = 2,
	},
	{
		prompt = "A tester suggests a great idea outside the original plan. What do you do?",
		options = { "Cram it in right before launch", "Note it for a future update" },
		correctIndex = 2,
	},
}

GameData.WorkerHireCost = 150
GameData.WorkerUpgradeCostBase = 50
GameData.WorkerUpgradeCostGrowth = 1.15
GameData.WorkerBaseScore = 0.5
GameData.WorkerScorePerLevel = 0.05
GameData.WorkerAutoCompleteSeconds = 3

function GameData.getWorkerUpgradeCost(currentLevel)
	return math.floor(GameData.WorkerUpgradeCostBase * (GameData.WorkerUpgradeCostGrowth ^ currentLevel))
end

function GameData.getWorkerScore(level)
	return math.min(1, GameData.WorkerBaseScore + (level * GameData.WorkerScorePerLevel))
end

function GameData.getBaseCash(devQuality)
	return GameData.PayoutMultiplier * devQuality
end

function GameData.getMarkerPosition(elapsedSeconds, periodSeconds)
	local phase01 = (elapsedSeconds % periodSeconds) / periodSeconds

	if phase01 < 0.5 then
		return phase01 * 2
	end

	return 2 - (phase01 * 2)
end

return GameData

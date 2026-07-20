local GameData = {}

GameData.Genres = { "Racing", "Horror", "Adventure", "Simulator" }
GameData.Topics = { "Space", "Zombies", "Sports", "Fantasy" }

GameData.StartingCash = 0

GameData.BaseDevTimeSeconds = 30
GameData.DevSpeedDecayPerLevel = 0.95
GameData.DevSpeedCostBase = 10
GameData.DevSpeedCostGrowth = 1.15

GameData.QualityBoostPerLevel = 0.1
GameData.QualityBoostCostBase = 15
GameData.QualityBoostCostGrowth = 1.15

GameData.PayoutMultiplier = 10

GameData.TrendRefreshSeconds = 300
GameData.TrendBonusChance = 0.1
GameData.TrendBonusMultiplier = 5

function GameData.getDevTime(devSpeedLevel)
	return GameData.BaseDevTimeSeconds * (GameData.DevSpeedDecayPerLevel ^ devSpeedLevel)
end

function GameData.getDevSpeedCost(currentLevel)
	return math.floor(GameData.DevSpeedCostBase * (GameData.DevSpeedCostGrowth ^ currentLevel))
end

function GameData.getQualityMultiplier(qualityBoostLevel)
	return 1 + (qualityBoostLevel * GameData.QualityBoostPerLevel)
end

function GameData.getQualityBoostCost(currentLevel)
	return math.floor(GameData.QualityBoostCostBase * (GameData.QualityBoostCostGrowth ^ currentLevel))
end

function GameData.getBaseCash(qualityBoostLevel)
	return GameData.PayoutMultiplier * GameData.getQualityMultiplier(qualityBoostLevel)
end

return GameData

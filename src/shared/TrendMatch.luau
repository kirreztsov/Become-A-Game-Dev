local GameData = require(script.Parent.GameData)

local TrendMatch = {}

local function isExactMatch(genre, topic, trend)
	return genre == trend.genre and topic == trend.topic
end

local function isPartialMatch(genre, topic, trend)
	local genreMatches = genre == trend.genre
	local topicMatches = topic == trend.topic
	return genreMatches ~= topicMatches
end

function TrendMatch.classify(genre, topic, trend1, trend2)
	if isExactMatch(genre, topic, trend1) or isExactMatch(genre, topic, trend2) then
		return "copy"
	end

	if isPartialMatch(genre, topic, trend1) or isPartialMatch(genre, topic, trend2) then
		return "partial"
	end

	return "none"
end

function TrendMatch.computeCash(genre, topic, trend1, trend2, devQuality, randomFn)
	randomFn = randomFn or math.random
	local baseCash = math.floor(GameData.getBaseCash(devQuality))
	local classification = TrendMatch.classify(genre, topic, trend1, trend2)

	if classification == "copy" then
		return 0, classification, false
	end

	if classification == "partial" then
		if randomFn() <= GameData.TrendBonusChance then
			return baseCash * GameData.TrendBonusMultiplier, classification, true
		end
		return baseCash, classification, false
	end

	return baseCash, classification, false
end

return TrendMatch

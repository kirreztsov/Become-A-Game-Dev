local GameData = require(script.Parent.Parent.GameData)
local TestHarness = require(script.TestHarness)

local t = TestHarness.new()

t:assertEqual(GameData.getDevTime(0), 30, "getDevTime(0) is the base time")
t:assertEqual(GameData.getDevTime(1), 30 * 0.95, "getDevTime(1) applies one decay step")
t:assertEqual(GameData.getDevSpeedCost(0), 10, "getDevSpeedCost(0) is the base cost")
t:assertEqual(GameData.getDevSpeedCost(1), 11, "getDevSpeedCost(1) grows 15%, floored")
t:assertEqual(GameData.getQualityMultiplier(0), 1, "getQualityMultiplier(0) is 1x")
t:assertEqual(GameData.getQualityMultiplier(5), 1.5, "getQualityMultiplier(5) is +50%")
t:assertEqual(GameData.getQualityBoostCost(0), 15, "getQualityBoostCost(0) is the base cost")
t:assertEqual(GameData.getBaseCash(0), 10, "getBaseCash(0) equals the payout multiplier")
t:assertEqual(GameData.getBaseCash(5), 15, "getBaseCash(5) scales with quality multiplier")

local TrendMatch = require(script.Parent.Parent.TrendMatch)

local trend1 = { genre = "Horror", topic = "Zombies" }
local trend2 = { genre = "Racing", topic = "Space" }

t:assertEqual(TrendMatch.classify("Horror", "Zombies", trend1, trend2), "copy", "exact match on trend1 is a copy")
t:assertEqual(TrendMatch.classify("Racing", "Space", trend1, trend2), "copy", "exact match on trend2 is a copy")
t:assertEqual(TrendMatch.classify("Horror", "Sports", trend1, trend2), "partial", "matching only genre is partial")
t:assertEqual(TrendMatch.classify("Adventure", "Zombies", trend1, trend2), "partial", "matching only topic is partial")
t:assertEqual(TrendMatch.classify("Adventure", "Fantasy", trend1, trend2), "none", "matching neither is none")

local copyCash, copyClass, copyHit = TrendMatch.computeCash("Horror", "Zombies", trend1, trend2, 0, function() return 1 end)
t:assertEqual(copyCash, 0, "copy earns zero cash")
t:assertEqual(copyClass, "copy", "copy is classified as copy")
t:assertEqual(copyHit, false, "copy never hits the trend bonus")

local winCash, winClass, winHit = TrendMatch.computeCash("Horror", "Sports", trend1, trend2, 0, function() return 0.05 end)
t:assertEqual(winCash, GameData.getBaseCash(0) * GameData.TrendBonusMultiplier, "partial match + winning roll gives 5x")
t:assertEqual(winClass, "partial", "winning case is classified as partial")
t:assertEqual(winHit, true, "winning roll reports hitBonus true")

local loseCash, loseClass, loseHit = TrendMatch.computeCash("Horror", "Sports", trend1, trend2, 0, function() return 0.5 end)
t:assertEqual(loseCash, GameData.getBaseCash(0), "partial match + losing roll gives base cash")
t:assertEqual(loseHit, false, "losing roll reports hitBonus false")

local noneCash = TrendMatch.computeCash("Adventure", "Fantasy", trend1, trend2, 0, function() return 0.01 end)
t:assertEqual(noneCash, GameData.getBaseCash(0), "no match always gives base cash regardless of roll")

t:summary()

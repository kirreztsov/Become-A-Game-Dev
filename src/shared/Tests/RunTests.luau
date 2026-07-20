local GameData = require(script.Parent.Parent.GameData)
local TestHarness = require(script.TestHarness)

local t = TestHarness.new()

t:assertEqual(GameData.getWorkerUpgradeCost(0), 50, "getWorkerUpgradeCost(0) is the base cost")
t:assertEqual(GameData.getWorkerUpgradeCost(1), 57, "getWorkerUpgradeCost(1) grows 15%, floored")
t:assertEqual(GameData.getWorkerScore(0), 0.5, "getWorkerScore(0) is the base score")
t:assertEqual(GameData.getWorkerScore(5), 0.75, "getWorkerScore(5) adds 5% per level")
t:assertEqual(GameData.getWorkerScore(10), 1, "getWorkerScore(10) reaches the 100% cap")
t:assertEqual(GameData.getWorkerScore(20), 1, "getWorkerScore(20) stays capped at 100%")
t:assertEqual(GameData.getBaseCash(0.5), 5, "getBaseCash(0.5) is half the payout multiplier")
t:assertEqual(GameData.getBaseCash(1), 10, "getBaseCash(1) equals the full payout multiplier")
t:assertEqual(GameData.getMarkerPosition(0, 2), 0, "getMarkerPosition(0,...) starts at 0")
t:assertEqual(GameData.getMarkerPosition(0.5, 2), 0.5, "getMarkerPosition at quarter-period is at the midpoint")
t:assertEqual(GameData.getMarkerPosition(1, 2), 1, "getMarkerPosition at half-period is at the far end")
t:assertEqual(GameData.getMarkerPosition(1.5, 2), 0.5, "getMarkerPosition at three-quarter-period is back at the midpoint")
t:assertEqual(GameData.getMarkerPosition(2, 2), 0, "getMarkerPosition at a full period wraps back to 0")

local TrendMatch = require(script.Parent.Parent.TrendMatch)

local trend1 = { genre = "Horror", topic = "Zombies" }
local trend2 = { genre = "Racing", topic = "Space" }

t:assertEqual(TrendMatch.classify("Horror", "Zombies", trend1, trend2), "copy", "exact match on trend1 is a copy")
t:assertEqual(TrendMatch.classify("Racing", "Space", trend1, trend2), "copy", "exact match on trend2 is a copy")
t:assertEqual(TrendMatch.classify("Horror", "Sports", trend1, trend2), "partial", "matching only genre is partial")
t:assertEqual(TrendMatch.classify("Adventure", "Zombies", trend1, trend2), "partial", "matching only topic is partial")
t:assertEqual(TrendMatch.classify("Adventure", "Fantasy", trend1, trend2), "none", "matching neither is none")

local copyCash, copyClass, copyHit = TrendMatch.computeCash("Horror", "Zombies", trend1, trend2, 1, function() return 1 end)
t:assertEqual(copyCash, 0, "copy earns zero cash")
t:assertEqual(copyClass, "copy", "copy is classified as copy")
t:assertEqual(copyHit, false, "copy never hits the trend bonus")

local winCash, winClass, winHit = TrendMatch.computeCash("Horror", "Sports", trend1, trend2, 1, function() return 0.05 end)
t:assertEqual(winCash, GameData.getBaseCash(1) * GameData.TrendBonusMultiplier, "partial match + winning roll gives 5x")
t:assertEqual(winClass, "partial", "winning case is classified as partial")
t:assertEqual(winHit, true, "winning roll reports hitBonus true")

local loseCash, loseClass, loseHit = TrendMatch.computeCash("Horror", "Sports", trend1, trend2, 1, function() return 0.5 end)
t:assertEqual(loseCash, GameData.getBaseCash(1), "partial match + losing roll gives base cash")
t:assertEqual(loseHit, false, "losing roll reports hitBonus false")

local noneCash = TrendMatch.computeCash("Adventure", "Fantasy", trend1, trend2, 1, function() return 0.01 end)
t:assertEqual(noneCash, GameData.getBaseCash(1), "no match always gives base cash regardless of roll")

t:summary()

local GameData = require(script.Parent.Parent.GameData)
local TestHarness = require(script.Parent.TestHarness)

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

-- Studio level + difficulty
t:assertEqual(GameData.getStudioLevel({ gamesReleased = 0, subscribers = 0 }), 1, "fresh studio is level 1")
t:assertEqual(GameData.getStudioLevel({ gamesReleased = 2, subscribers = 0 }), 2, "2 games -> +1 level")
t:assertEqual(GameData.getStudioLevel({ gamesReleased = 0, subscribers = 100 }), 3, "100 subs -> +2 levels")
t:assertEqual(GameData.getStudioLevel({ gamesReleased = 999, subscribers = 99999 }), GameData.StudioLevelMax, "level clamps at max")
t:assertEqual(GameData.getDifficulty(1), 0, "level 1 -> difficulty 0")
t:assertEqual(GameData.getDifficulty(GameData.DifficultyRampLevels + 1), 1, "ramp end -> difficulty 1")
t:assertEqual(GameData.getDifficulty(9999), 1, "difficulty clamps at 1")

t:assertEqual(GameData.scoreMash(15, 15), 1, "mash hitting target = 1")
t:assertEqual(GameData.scoreMash(30, 15), 1, "mash over target clamps to 1")
t:assertEqual(GameData.scoreMash(6, 12), 0.5, "mash half target = 0.5")
t:assertEqual(GameData.scoreTiming(0.5, 0.5, 0.15), 1, "timing dead-center = 1")
t:assertEqual(GameData.scoreTiming(0.65, 0.5, 0.15), 0, "timing at zone edge = 0")
t:assertEqual(GameData.scoreTiming(0.9, 0.5, 0.15), 0, "timing outside zone = 0")
t:assertEqual(GameData.scoreSequence(3, 6), 0.5, "sequence 3 of 6 = 0.5")
t:assertEqual(GameData.scoreSequence(0, 0), 0, "sequence 0 of 0 = 0 (no divide error)")
t:assertEqual(GameData.scoreChoice(2, 2, 0.3), 1, "correct choice = 1")
t:assertEqual(GameData.scoreChoice(1, 2, 0.3), 0.3, "wrong choice = wrongScore")

-- param lerp + rounding
GameData.VariantParams.__test = { easy = { a = 0, n = 2 }, hard = { a = 10, n = 8 }, ints = { n = true } }
local p0 = GameData.getVariantParams("__test", 0)
t:assertEqual(p0.a, 0, "difficulty 0 -> easy value")
t:assertEqual(p0.n, 2, "difficulty 0 -> easy int")
local p1 = GameData.getVariantParams("__test", 1)
t:assertEqual(p1.a, 10, "difficulty 1 -> hard value")
t:assertEqual(p1.n, 8, "difficulty 1 -> hard int")
local ph = GameData.getVariantParams("__test", 0.5)
t:assertEqual(ph.a, 5, "midpoint float")
t:assertEqual(ph.n, 5, "midpoint int rounded")
GameData.VariantParams.__test = nil

-- rotation avoids repeats (inject a temp implemented pool so pool size > 1)
GameData.ImplementedVariantIds.__test = { "a", "b", "c" }
local first = GameData.pickVariantId("__test", "a", function() return 0 end)
t:assertEqual(first ~= "a", true, "pickVariantId never repeats lastId when pool > 1")
t:assertEqual(GameData.pickVariantId("__test", nil, function() return 0 end), "a", "pickVariantId with no lastId can return the first")
GameData.ImplementedVariantIds.__test = nil

t:assertEqual(GameData.getLoungeRate({ gamesReleased = 0, subscribers = 0 }), 8, "lounge rate at level 1 = per-level")
t:assertEqual(GameData.getLoungeRate({ gamesReleased = 999, subscribers = 99999 }), 400, "lounge rate clamps to cap")
t:assertEqual(GameData.getLoungeRate({ gamesReleased = 2, subscribers = 0 }) >= 8, true, "lounge rate never below per-level")

-- Global leaderboards: week index
t:assertEqual(GameData.getWeekIndex(0), 0, "week index at epoch is 0")
t:assertEqual(GameData.getWeekIndex(604799), 0, "week index stable within a week")
t:assertEqual(GameData.getWeekIndex(604800), 1, "week index rolls at the 7-day boundary")
t:assertEqual(GameData.getWeekIndex(604800 * 5 + 10), 5, "week index counts whole weeks")

-- Global leaderboards: store names
t:assertEqual(GameData.leaderboardStoreName("all", "cash", 5), "LB2_all_cash", "all-time store name ignores week")
t:assertEqual(GameData.leaderboardStoreName("week", "cash", 5), "LB2_wk_cash_5", "weekly store name includes the week index")

-- Global leaderboards: config
t:assertEqual(#GameData.LeaderboardStats, 4, "there are four leaderboard stats")
t:assertEqual(GameData.LeaderboardStats[1].key, "prestigeLevel", "first board is prestige")
t:assertEqual(GameData.LeaderboardStats[3].format(1234), "$1,234", "richest formats with a dollar sign + commas")
t:assertEqual(GameData.LeaderboardStats[2].format(1000000), "1,000,000", "subscribers formats with commas")

-- Global leaderboards: computeStanding
local sRows = { { userId = 11, value = 90, name = "A" }, { userId = 22, value = 80, name = "B" } }
t:assertEqual(GameData.computeStanding(sRows, 22, 80).rank, 2, "standing finds the player's rank in the rows")
t:assertEqual(GameData.computeStanding(sRows, 22, 80).value, 80, "standing reports the ranked value")
t:assertEqual(GameData.computeStanding(sRows, 99, 5).rank, nil, "not in rows -> no rank")
t:assertEqual(GameData.computeStanding(sRows, 99, 5).value, 5, "not in rows -> falls back to live value")

-- PlayerData weekly accumulator (pure table logic)
local PlayerData = require(game:GetService("ServerScriptService").Server.PlayerData)
local wd = { weekAnchor = 0, weekly = { prestigeLevel = 0, subscribers = 0, cash = 0, gamesReleased = 0 } }
PlayerData.addWeekly(wd, "cash", 100, 10)           -- same week (index 0)
t:assertEqual(wd.weekly.cash, 100, "addWeekly adds a positive gain")
PlayerData.addWeekly(wd, "cash", -50, 10)           -- negative ignored
t:assertEqual(wd.weekly.cash, 100, "addWeekly ignores non-positive deltas")
PlayerData.addWeekly(wd, "subscribers", 5, 10)
t:assertEqual(wd.weekly.subscribers, 5, "addWeekly tracks each stat independently")
PlayerData.addWeekly(wd, "cash", 25, 604800 + 1)    -- new week -> reset then add
t:assertEqual(wd.weekly.cash, 25, "a new week resets the tally before adding")
t:assertEqual(wd.weekly.subscribers, 0, "new week zeroes every stat")
t:assertEqual(wd.weekAnchor, 1, "week anchor advances to the new week index")
PlayerData.addWeekly(wd, "bogusStat", 10, 604800 + 2)  -- unknown stat is a no-op
t:assertEqual(wd.weekly.cash, 25, "unknown stat does not corrupt the tally")

t:summary()

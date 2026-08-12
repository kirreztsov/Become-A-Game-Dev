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

-- Home room: config + catalog
t:assertEqual(GameData.Home.cols, 16, "home grid is 16 columns wide")
t:assertEqual(GameData.Home.rows, 12, "home grid is 12 rows deep")
t:assertEqual(GameData.getHomeItem("Rug") ~= nil, true, "Rug is in the catalog")
t:assertEqual(GameData.getHomeItem("nope"), nil, "unknown id returns nil")

-- footprint rotates with yaw (90/270 swap w/d)
local fpw, fpd = GameData.homeFootprint("Bed", 0)
local rpw, rpd = GameData.homeFootprint("Bed", 90)
t:assertEqual(rpw, fpd, "yaw 90 swaps width->depth")
t:assertEqual(rpd, fpw, "yaw 90 swaps depth->width")

-- bounds
t:assertEqual(GameData.homeInBounds(0, GameData.Home.workRows, 2, 2, GameData.homeDims(0)), true, "footprint in living zone is in bounds")
t:assertEqual(GameData.homeInBounds(15, 11, 1, 1), true, "single cell at far corner in bounds")
t:assertEqual(GameData.homeInBounds(15, 0, 2, 1), false, "overhanging the right edge is out of bounds")
t:assertEqual(GameData.homeInBounds(-1, 0, 1, 1), false, "negative cell is out of bounds")

-- overlap
local items = { { id = "Rug", gx = 4, gz = 4, yaw = 0 } } -- Rug is 2x3 cells
t:assertEqual(GameData.homeOverlaps(items, 5, 5, 1, 1, nil), true, "a cell inside the rug overlaps")
t:assertEqual(GameData.homeOverlaps(items, 0, 0, 2, 2, nil), false, "a footprint clear of the rug does not overlap")
t:assertEqual(GameData.homeOverlaps(items, 4, 4, 2, 3, 1), false, "ignoreIndex lets an item overlap its own old cells")

-- cell -> world (corner at 0,0, floor y=0): cell (0,0) with 1x1 footprint centres at (CELL/2, y, CELL/2)
local wc = GameData.homeCellToWorld(0, 0, 0, 0, 0, 1, 1)
t:assertEqual(wc.X, 2, "cell 0 centre x = CELL/2")
t:assertEqual(wc.Z, 2, "cell 0 centre z = CELL/2")
local wc2 = GameData.homeCellToWorld(0, 0, 0, 2, 0, 2, 1)
t:assertEqual(wc2.X, 12, "cell gx=2 w=2 centre x = 2*4 + 2*4/2 = 12")

-- PC install minigame: snap + layout coverage
local PCInstall = require(script.Parent.Parent.PCInstall)
t:assertEqual(PCInstall.isWithinSnap(Vector3.new(0, 0, 0), Vector3.new(0, 0, 1), 2), true, "snap: within radius is true")
t:assertEqual(PCInstall.isWithinSnap(Vector3.new(0, 0, 0), Vector3.new(0, 0, 3), 2), false, "snap: beyond radius is false")
t:assertEqual(PCInstall.isWithinSnap(Vector3.new(0, 0, 0), Vector3.new(0, 0, 2), 2), true, "snap: exactly at radius is true")
local missing = {}
for _, p in ipairs(GameData.PCParts) do
	if not PCInstall.Layout[p.id] then
		missing[#missing + 1] = p.id
	end
end
t:assertEqual(#missing, 0, "every PC part has a bench layout entry")
for _, p in ipairs(GameData.PCParts) do
	local e = PCInstall.Layout[p.id]
	if e then
		t:assertEqual(e.snap > 0, true, ("layout %s has a positive snap radius"):format(p.id))
	end
end

-- PC install minigame: server reserve/apply rules (pure)
local PCService = require(game:GetService("ServerScriptService").Server.PCService)
local cpuCost0 = GameData.getPCPartUpgradeCost("CPU", 0)

local rich = { cash = 1e9, pcParts = {} }
local ok, cost, target = PCService.reserveDecision(rich, "CPU", nil)
t:assertEqual(ok, true, "reserve: rich player can buy CPU")
t:assertEqual(cost, cpuCost0, "reserve: cost is the level-0 upgrade cost")
t:assertEqual(target, 1, "reserve: target level is 1")

local broke = { cash = 0, pcParts = {} }
t:assertEqual((PCService.reserveDecision(broke, "CPU", nil)), false, "reserve: no cash -> false")
t:assertEqual((PCService.reserveDecision(rich, "NotAPart", nil)), false, "reserve: unknown part -> false")

local maxed = { cash = 1e9, pcParts = { CPU = GameData.getPCPartMaxLevel("CPU") } }
t:assertEqual((PCService.reserveDecision(maxed, "CPU", nil)), false, "reserve: maxed part -> false")

local dealed = { cash = 1e9, pcParts = {} }
local _, dcost = PCService.reserveDecision(dealed, "CPU", { partId = "CPU", discount = 0.5 })
t:assertEqual(dcost, math.floor(cpuCost0 * 0.5), "reserve: matching deal halves the cost")

local applyData = { cash = 1e9, pcParts = {} }
local applied = PCService.applyInstall(applyData, { partId = "CPU", cost = cpuCost0, targetLevel = 1 })
t:assertEqual(applied, true, "apply: valid install succeeds")
t:assertEqual(applyData.cash, 1e9 - cpuCost0, "apply: exact cost deducted")
t:assertEqual(applyData.pcParts.CPU, 1, "apply: level set to target")

local staleLevel = { cash = 1e9, pcParts = { CPU = 3 } }
t:assertEqual(PCService.applyInstall(staleLevel, { partId = "CPU", cost = cpuCost0, targetLevel = 1 }), false, "apply: level no longer matches -> false")
t:assertEqual(staleLevel.cash, 1e9, "apply: rejected install does not charge")

local poor = { cash = 1, pcParts = {} }
t:assertEqual(PCService.applyInstall(poor, { partId = "CPU", cost = cpuCost0, targetLevel = 1 }), false, "apply: not enough cash at apply time -> false")
t:assertEqual(poor.pcParts.CPU, nil, "apply: rejected install does not upgrade")

-- QuestData: pure progress + claim logic
local QuestData = require(script.Parent.Parent.QuestData)

local qGames = { gamesReleased = 0, questsClaimed = {} }
t:assertEqual(QuestData.isComplete(qGames, QuestData.get("first_game")), false, "quest: 0 games -> first_game incomplete")
t:assertEqual(QuestData.canClaim(qGames, "first_game"), false, "quest: incomplete cannot claim")
qGames.gamesReleased = 1
t:assertEqual(QuestData.isComplete(qGames, QuestData.get("first_game")), true, "quest: 1 game -> first_game complete")
t:assertEqual(QuestData.canClaim(qGames, "first_game"), true, "quest: complete + unclaimed -> claimable")

local reward = QuestData.applyClaim(qGames, "first_game")
t:assertEqual(reward and reward.cash, 100, "quest: applyClaim returns the reward")
t:assertEqual(qGames.questsClaimed.first_game, true, "quest: applyClaim marks claimed")
t:assertEqual(QuestData.canClaim(qGames, "first_game"), false, "quest: cannot claim twice")
t:assertEqual(QuestData.applyClaim(qGames, "first_game"), nil, "quest: second applyClaim returns nil")

t:assertEqual(QuestData.progress({ subscribers = 500 }, QuestData.get("subs_1k")), 500, "quest: progress reads the stat")
t:assertEqual(QuestData.progress({ subscribers = 5000 }, QuestData.get("subs_1k")), 1000, "quest: progress caps at target")

local qWork = { workers = { A = { hired = true }, B = { hired = true }, C = { hired = false } } }
t:assertEqual(QuestData.progress(qWork, QuestData.get("workers_all")), 2, "quest: workersHired counts only hired")

local qPc = { pcParts = { CPU = 4, GPU = 6, RAM = 0 } }
t:assertEqual(QuestData.progress(qPc, QuestData.get("pc_power_10")), 10, "quest: pcPower sums part levels (capped)")

t:assertEqual(QuestData.applyClaim({ gamesReleased = 0, questsClaimed = {} }, "unknown_quest_id"), nil, "quest: unknown id -> nil")

-- ChallengeData: daily rollover + delta progress + claim
local ChallengeData = require(script.Parent.Parent.ChallengeData)

t:assertEqual(ChallengeData.dayIndex(0), 0, "challenge: day index at epoch is 0")
t:assertEqual(ChallengeData.dayIndex(86400), 1, "challenge: day index rolls at 24h")
t:assertEqual(ChallengeData.secondsUntilReset(86400 * 3 + 100), 86300, "challenge: seconds until reset")
t:assertEqual(#ChallengeData.dailySet(0), 3, "challenge: 3 per day")
t:assertEqual(ChallengeData.dailySet(0)[1].id ~= ChallengeData.dailySet(1)[1].id, true, "challenge: set rotates by day")

local cd = { gamesReleased = 5, subscribers = 100, challengeDay = -1 }
local changed = ChallengeData.rolloverIfNeeded(cd, 10)
t:assertEqual(changed, true, "challenge: rollover on stale day")
t:assertEqual(cd.challengeDay, 10, "challenge: rollover sets the day")
t:assertEqual(cd.challengeBaseline.games, 5, "challenge: baseline snapshots games")
t:assertEqual(cd.challengeBaseline.subs, 100, "challenge: baseline snapshots subs")
t:assertEqual(ChallengeData.rolloverIfNeeded(cd, 10), false, "challenge: no rollover on same day")

local rel3 = ChallengeData.get("d_release_3")
t:assertEqual(ChallengeData.progress(cd, rel3), 0, "challenge: 0 progress right after baseline")
cd.gamesReleased = 7 -- released 2 today
t:assertEqual(ChallengeData.progress(cd, rel3), 2, "challenge: progress = today's delta")
t:assertEqual(ChallengeData.isComplete(cd, rel3), false, "challenge: 2 of 3 incomplete")
cd.gamesReleased = 9 -- 4 today, capped at 3
t:assertEqual(ChallengeData.progress(cd, rel3), 3, "challenge: progress caps at target")
t:assertEqual(ChallengeData.canClaim(cd, "d_release_3"), true, "challenge: complete + unclaimed claimable")
local rew = ChallengeData.applyClaim(cd, "d_release_3")
t:assertEqual(rew and rew.cash, 3000, "challenge: applyClaim returns reward")
t:assertEqual(ChallengeData.canClaim(cd, "d_release_3"), false, "challenge: cannot claim twice")

-- a new day wipes claims + resets the baseline
ChallengeData.rolloverIfNeeded(cd, 11)
t:assertEqual(cd.challengeClaimed.d_release_3, nil, "challenge: new day clears claims")
t:assertEqual(ChallengeData.progress(cd, rel3), 0, "challenge: new day resets progress to 0")

-- PerkData: multipliers + buy logic
local PerkData = require(script.Parent.Parent.PerkData)

local pd = { perkPoints = 3, perks = {} }
t:assertEqual(PerkData.cashMult(pd), 1, "perk: no perks -> 1x cash")
t:assertEqual(PerkData.canBuy(pd, "p_cash"), true, "perk: can buy with points")
t:assertEqual(PerkData.applyBuy(pd, "p_cash"), true, "perk: buy succeeds")
t:assertEqual(pd.perks.p_cash, 1, "perk: level incremented")
t:assertEqual(pd.perkPoints, 2, "perk: points deducted")
t:assertEqual(math.abs(PerkData.cashMult(pd) - 1.10) < 1e-9, true, "perk: 1 cash level -> 1.10x")
PerkData.applyBuy(pd, "p_cash")
t:assertEqual(math.abs(PerkData.cashMult(pd) - 1.20) < 1e-9, true, "perk: 2 cash levels -> 1.20x")
t:assertEqual(pd.perkPoints, 1, "perk: two buys cost two points")

t:assertEqual(PerkData.canBuy(pd, "p_headstart"), false, "perk: cannot afford 2-cost perk with 1 point")
t:assertEqual(PerkData.applyBuy(pd, "p_headstart"), false, "perk: unaffordable buy fails")

local maxed = { perkPoints = 100, perks = { p_speed = 5 } }
t:assertEqual(PerkData.isMaxed(maxed, "p_speed"), true, "perk: at maxLevel is maxed")
t:assertEqual(PerkData.canBuy(maxed, "p_speed"), false, "perk: cannot buy past max")
t:assertEqual(math.abs(PerkData.speedMult(maxed) - 1.40) < 1e-9, true, "perk: speed 5 -> 1.40x")

local hs = { perks = { p_headstart = 3 } }
t:assertEqual(PerkData.startCashBonus(hs), 3000, "perk: head start bonus = level*value")
t:assertEqual(PerkData.applyBuy({ perkPoints = 0, perks = {} }, "unknown"), false, "perk: unknown id -> false")

-- PerkData: offline cap perk
t:assertEqual(PerkData.offlineCapBonusHours({ perks = {} }), 0, "perk: no offline perk -> 0h bonus")
t:assertEqual(PerkData.offlineCapBonusHours({ perks = { p_offline = 3 } }), 3, "perk: 3 offline levels -> +3h")
t:assertEqual(PerkData.canBuy({ perkPoints = 1, perks = {} }, "p_offline"), true, "perk: offline perk buyable for 1 point")
t:assertEqual(PerkData.isMaxed({ perks = { p_offline = 6 } }, "p_offline"), true, "perk: offline perk maxes at 6")

-- GameData: offline cash formula (rate/sec, elapsed, cap)
t:assertEqual(GameData.getOfflineCash(10, 100, 7200), 1000, "offline: rate*elapsed under cap")
t:assertEqual(GameData.getOfflineCash(10, 999999, 7200), 72000, "offline: clamped to cap")
t:assertEqual(GameData.getOfflineCash(10, -50, 7200), 0, "offline: negative elapsed -> 0")
t:assertEqual(GameData.getOfflineCash(0, 7200, 7200), 0, "offline: zero rate -> 0")
t:assertEqual(GameData.getOfflineCash(1.5, 10, 7200), 15, "offline: floors fractional cash")

-- EventData: Sunday gating, scaling, sequential claims, champion roll
local EventData = require(script.Parent.Parent.EventData)

-- Sunday detection (Unix day 0 = Thursday; day 3 = Sunday)
t:assertEqual(EventData.isEventActive(0), false, "event: epoch (Thursday) is not active")
t:assertEqual(EventData.isEventActive(2 * 86400), false, "event: Saturday is not active")
t:assertEqual(EventData.isEventActive(3 * 86400), true, "event: Sunday IS active")
t:assertEqual(EventData.isEventActive(3 * 86400 + 5000), true, "event: still Sunday later in the day")
t:assertEqual(EventData.isEventActive(4 * 86400), false, "event: Monday is not active")
t:assertEqual(EventData.isEventActive(10 * 86400), true, "event: a later Sunday is active")
t:assertEqual(EventData.secondsUntilEnd(3 * 86400 + 100), 86300, "event: seconds until day ends")

-- Scaling is continuous and monotonic in subscribers
t:assertEqual(math.abs(EventData.scale({ subscribers = 0 }) - 1) < 1e-9, true, "event: scale at 0 subs is 1")
t:assertEqual(EventData.scale({ subscribers = 50000 }) > EventData.scale({ subscribers = 0 }), true, "event: scale rises with subs")
t:assertEqual(EventData.target({ subscribers = 50000 }, 1) >= EventData.target({ subscribers = 0 }, 1), true, "event: target scales up with subs")
t:assertEqual(EventData.target({ subscribers = 0 }, 1), 5, "event: quest 1 base target is 5 at scale 1")
t:assertEqual(EventData.target({ subscribers = 1e9 }, 5), 3, "event: trendy-hit target is capped at 3")

-- Rollover snapshots baseline + clears claims; progress is today's delta
local ed = { gamesReleased = 4, subscribers = 100, totalCashEarned = 500, trendyHits = 2, eventDay = -1 }
t:assertEqual(EventData.rolloverIfNeeded(ed, 3), true, "event: rollover on stale day")
t:assertEqual(ed.eventDay, 3, "event: rollover sets the day")
t:assertEqual(ed.eventBaseline.games, 4, "event: baseline snapshots games")
t:assertEqual(ed.eventBaseline.cash, 500, "event: baseline snapshots totalCashEarned")
t:assertEqual(EventData.rolloverIfNeeded(ed, 3), false, "event: no rollover on same day")
t:assertEqual(EventData.progress(ed, 1), 0, "event: 0 progress right after baseline")
ed.gamesReleased = 6 -- released 2 today
t:assertEqual(EventData.progress(ed, 1), 2, "event: progress = today's delta")

-- Sequential claiming: quest 2 locked until quest 1 claimed
ed.gamesReleased = ed.eventBaseline.games + EventData.target(ed, 1) -- complete quest 1
t:assertEqual(EventData.canClaim(ed, 1), true, "event: quest 1 complete -> claimable")
ed.subscribers = ed.eventBaseline.subs + EventData.target(ed, 2) -- also complete quest 2
t:assertEqual(EventData.canClaim(ed, 2), false, "event: quest 2 locked until quest 1 claimed")
local r1 = EventData.applyQuestClaim(ed, 1)
t:assertEqual(r1 ~= nil, true, "event: quest 1 is actually claimed")
t:assertEqual(r1.final, false, "event: quest 1 claim is not final")
t:assertEqual(EventData.isClaimed(ed, 1), true, "event: quest 1 marked claimed")
t:assertEqual(EventData.canClaim(ed, 1), false, "event: cannot claim quest 1 twice")
t:assertEqual(EventData.canClaim(ed, 2), true, "event: quest 2 unlocks after quest 1")

-- Malformed indices must never be claimable (NaN passes a bare type check)
t:assertEqual(EventData.canClaim(ed, 0 / 0), false, "event: NaN index is not claimable")
t:assertEqual(EventData.canClaim(ed, -1), false, "event: negative index is not claimable")
t:assertEqual(EventData.canClaim(ed, 999), false, "event: out-of-range index is not claimable")
t:assertEqual(EventData.applyQuestClaim(ed, 0 / 0), nil, "event: NaN index cannot be claimed")

-- Final quest reports final = true
local edF = { eventDay = 3, eventBaseline = { games = 0, subs = 0, cash = 0, hits = 0 }, eventQuestsClaimed = { [1]=true,[2]=true,[3]=true,[4]=true,[5]=true }, totalCashEarned = 0, subscribers = 0 }
edF.totalCashEarned = EventData.target(edF, 6)
local r6 = EventData.applyQuestClaim(edF, 6)
t:assertEqual(r6 ~= nil and r6.final, true, "event: quest 6 claim is final")

-- Champion part roll: locked bonus = 1.25 * the player's part IN THAT CATEGORY,
-- excludes already-won categories, nil at 7
local champData = { pcParts = { CPU = 5 }, eventParts = {} } -- CPU lvl 5 bonus 0.65
t:assertEqual(math.abs(EventData.partBonus(champData, "CPU") - 0.65) < 1e-9, true, "event: partBonus reads that category's equipped model")
t:assertEqual(EventData.partBonus(champData, "GPU"), 0, "event: partBonus does NOT inherit another category's bonus")
-- rng returns 1 and nothing is owned yet, so the pool is GameData.PCParts order
-- and index 1 is CPU -- forcing the roll onto the maxed category.
local pid, pbonus = EventData.rollChampionPart(champData, function() return 1 end)
t:assertEqual(pid, "CPU", "event: forced roll lands on the first unowned category (CPU)")
t:assertEqual(math.abs(pbonus - 0.81) < 1e-9, true, "event: champion bonus = round2(1.25*0.65)=0.81")
EventData.applyChampionGrant(champData, pid, pbonus)
t:assertEqual(champData.eventParts[pid], pbonus, "event: grant stores the bonus")
-- Fill all 7, then rolling returns nil
for _, p in ipairs(GameData.PCParts) do champData.eventParts[p.id] = 0.5 end
local nilId = EventData.rollChampionPart(champData, function() return 1 end)
t:assertEqual(nilId, nil, "event: nil when all 7 champion parts owned")
-- Minimum bonus floor for a fresh winner (no parts)
local _, freshBonus = EventData.rollChampionPart({ pcParts = {}, eventParts = {} }, function() return 1 end)
t:assertEqual(math.abs(freshBonus - EventData.MIN_CHAMPION_BONUS) < 1e-9, true, "event: fresh winner gets the minimum bonus floor")

-- Champion parts fold into the PC-parts multipliers (money vs followers split)
local baseCash = GameData.getPCPartsCashMultiplier({ CPU = 0 })
t:assertEqual(math.abs(GameData.getPCPartsCashMultiplier({ CPU = 0 }, { CPU = 0.5 }) - (baseCash + 0.5)) < 1e-9, true, "champion: CPU (money) adds to cash multiplier")
t:assertEqual(math.abs(GameData.getPCPartsSubsMultiplier({ GPU = 0 }, { CPU = 0.5 }) - GameData.getPCPartsSubsMultiplier({ GPU = 0 })) < 1e-9, true, "champion: a money part does NOT touch the subs multiplier")
t:assertEqual(math.abs(GameData.getPCPartsSubsMultiplier({ GPU = 0 }, { GPU = 0.4 }) - (GameData.getPCPartsSubsMultiplier({ GPU = 0 }) + 0.4)) < 1e-9, true, "champion: GPU (followers) adds to subs multiplier")
t:assertEqual(GameData.getPCPartsCashMultiplier({ CPU = 0 }, nil), baseCash, "champion: nil eventParts behaves as before")

-- Daily login calendar (B1): 30-day ladder, scaling, and streak decisions
t:assertEqual(GameData.DailyCalendarDays, 30, "daily: calendar is 30 days")
t:assertEqual(#GameData.DailyRewards, 30, "daily: ladder has 30 entries")
t:assertEqual(GameData.DailyRewards[7].milestone, true, "daily: day 7 is a milestone")
t:assertEqual(GameData.DailyRewards[14].milestone, true, "daily: day 14 is a milestone")
t:assertEqual(GameData.DailyRewards[30].milestone, true, "daily: day 30 is a milestone")
t:assertEqual(GameData.DailyRewards[14].kind, "case", "daily: day 14 grants a case spin")
t:assertEqual(GameData.DailyRewards[30].kind, "champion", "daily: day 30 grants a champion part")
t:assertEqual(GameData.DailyRewards[7].amount ~= nil and GameData.DailyRewards[7].mult ~= nil, true, "daily: day 7 grants cash AND a boost")

-- indexing no longer wraps every 7 days; it clamps at 30
local _, i1 = GameData.getDailyReward(1)
t:assertEqual(i1, 1, "daily: day 1 indexes entry 1")
local _, i8 = GameData.getDailyReward(8)
t:assertEqual(i8, 8, "daily: day 8 indexes entry 8 (no 7-day wrap)")
local _, i30 = GameData.getDailyReward(30)
t:assertEqual(i30, 30, "daily: day 30 indexes entry 30")
local _, i99 = GameData.getDailyReward(99)
t:assertEqual(i99, 30, "daily: past the end clamps to entry 30")
local _, i0 = GameData.getDailyReward(0)
t:assertEqual(i0, 1, "daily: day 0 clamps up to entry 1")

-- cash scales with progression; boosts and spins never do
local freshP = { subscribers = 0 }
local bigP = { subscribers = 100000 }
local base5 = GameData.DailyRewards[5].amount
t:assertEqual(GameData.getScaledDailyReward(freshP, 5).amount, base5, "daily: a fresh player gets the base amount")
t:assertEqual(GameData.getScaledDailyReward(bigP, 5).amount > base5, true, "daily: a big player gets more")
t:assertEqual(GameData.getScaledDailyReward(bigP, 3).mult, GameData.DailyRewards[3].mult, "daily: boost multiplier is never scaled")
t:assertEqual(GameData.getScaledDailyReward(bigP, 3).dur, GameData.DailyRewards[3].dur, "daily: boost duration is never scaled")
t:assertEqual(GameData.getScaledDailyReward(bigP, 14).spins, GameData.DailyRewards[14].spins, "daily: case spins are never scaled")
t:assertEqual(GameData.getScaledDailyReward(bigP, 5) ~= GameData.DailyRewards[5], true, "daily: scaling returns a copy, not the shared entry")
t:assertEqual(GameData.DailyRewards[5].amount, base5, "daily: scaling never mutates the authored ladder")

-- descriptions
t:assertEqual(GameData.describeDailyReward({ kind = "cash", amount = 500 }), "$500", "daily: cash description")
t:assertEqual(GameData.describeDailyReward({ kind = "case", spins = 1 }):find("Lucky") ~= nil, true, "daily: case description mentions Lucky")
t:assertEqual(GameData.describeDailyReward({ kind = "champion" }):find("Champion") ~= nil, true, "daily: champion description mentions Champion")

-- streak decisions. COOLDOWN = 20h, RESET = 48h
local DAY = 24 * 3600
local RESET = GameData.DailyStreakResetSeconds

-- brand new player: claimable immediately, day 1
local newbie = { lastDailyClaim = 0, dailyStreak = 0 }
local rNew = GameData.evaluateDailyStreak(newbie, 1000000)
t:assertEqual(rNew.available, true, "daily: a new player can claim at once")
t:assertEqual(rNew.nextStreak, 1, "daily: a new player is on day 1")

-- claimed 4h ago: not claimable yet
local tooSoon = { lastDailyClaim = 1000000, dailyStreak = 3 }
t:assertEqual(GameData.evaluateDailyStreak(tooSoon, 1000000 + 4 * 3600).available, false, "daily: cannot claim inside the cooldown")

-- claimed 25h ago (inside the reset window): streak continues
local onTime = { lastDailyClaim = 1000000, dailyStreak = 3 }
local rOn = GameData.evaluateDailyStreak(onTime, 1000000 + 25 * 3600)
t:assertEqual(rOn.available, true, "daily: claimable after the cooldown")
t:assertEqual(rOn.nextStreak, 4, "daily: an on-time return advances the streak")
t:assertEqual(rOn.usedFreeSkip, false, "daily: an on-time return uses no free skip")
t:assertEqual(rOn.repairOffered, false, "daily: an on-time return offers no repair")

-- missed (past the reset window) with the free skip available: streak survives
local missedOnce = { lastDailyClaim = 1000000, dailyStreak = 12, dailySkipUsed = false }
local rMiss = GameData.evaluateDailyStreak(missedOnce, 1000000 + RESET + DAY)
t:assertEqual(rMiss.nextStreak, 13, "daily: the free skip keeps the streak going")
t:assertEqual(rMiss.usedFreeSkip, true, "daily: the free skip is reported as used")
t:assertEqual(rMiss.repairOffered, false, "daily: no repair needed while the skip is available")
t:assertEqual(missedOnce.dailySkipUsed, false, "daily: evaluate is pure and does not mutate")

-- missed again with the skip already spent: streak held for repair
local missedTwice = { lastDailyClaim = 1000000, dailyStreak = 12, dailySkipUsed = true }
local rBroke = GameData.evaluateDailyStreak(missedTwice, 1000000 + RESET + DAY)
t:assertEqual(rBroke.nextStreak, 1, "daily: a second miss drops to day 1")
t:assertEqual(rBroke.repairOffered, true, "daily: a second miss offers the repair")
t:assertEqual(rBroke.brokenStreak, 12, "daily: the lost streak is reported so it can be repaired")

-- a streak already awaiting repair keeps offering it
local awaiting = { lastDailyClaim = 1000000, dailyStreak = 1, dailySkipUsed = true, dailyBrokenStreak = 20 }
local rAwait = GameData.evaluateDailyStreak(awaiting, 1000000 + 25 * 3600)
t:assertEqual(rAwait.repairOffered, true, "daily: a pending repair is still offered")
t:assertEqual(rAwait.brokenStreak, 20, "daily: the pending repair remembers the streak")

-- finishing day 30 restarts the calendar
local finished = { lastDailyClaim = 1000000, dailyStreak = 30, dailySkipUsed = true }
local rWrap = GameData.evaluateDailyStreak(finished, 1000000 + 25 * 3600)
t:assertEqual(rWrap.nextStreak, 1, "daily: after day 30 the calendar restarts at 1")
t:assertEqual(rWrap.calendarRestart, true, "daily: the restart is reported so the free skip can reset")

-- the repair product exists, unconfigured
t:assertEqual(GameData.Products.StreakRepair ~= nil, true, "daily: a StreakRepair product exists")
t:assertEqual(GameData.Products.StreakRepair.id, 0, "daily: StreakRepair ships as 'coming soon' (id 0)")

t:summary()

local GameData = {}

GameData.Genres = { "Racing", "Horror", "Adventure", "Simulator" }
GameData.Topics = { "Space", "Zombies", "Sports", "Fantasy" }

GameData.StartingCash = 0 -- launch value: everyone starts from scratch
-- Base cash a released game pays = PayoutMultiplier * devQuality (0..1 solo, higher
-- with better workers). Tuned so the FIRST game pays ~$25-30 and your first
-- worker/PC/floor upgrade is only a few games away -- no dead zone at the start.
GameData.PayoutMultiplier = 45
-- The highest a game's quality can reach (250%). Solo play tops out near 100%;
-- rare workers can push it higher, up to this bounded ceiling (a maxed Mythic
-- = 2.5x). Keeps rare/Robux workers a strong-but-fair edge, not a money printer.
GameData.MaxDevQuality = 2.5

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

-- Every floor you add to your studio (a house-tier upgrade) doubles BOTH
-- the price of the upgrades you buy AND the cash your games earn, so
-- building taller is a real trade-up: pricier to run, but it pays back
-- proportionally more. Floor 1 (houseTier 0) = base, floor 2 = 2x,
-- floor 3 = 4x, and so on -- matching "60 -> 120 -> 240".
GameData.FloorMultiplierBase = 2

function GameData.getFloorMultiplier(houseTier)
	return GameData.FloorMultiplierBase ^ (houseTier or 0)
end

-- Shop-bought cash boost: pay once for a temporary multiplier on cash you
-- earn (game releases, idle rooms, quests, basketball). The multiplier +
-- duration depend on which item was bought (see ShopCatalog).
function GameData.isBoostActive(data, now)
	return data ~= nil and data.boostUntil ~= nil and now < data.boostUntil
end

-- The cash multiplier from an active boost (1 if none). Uses the multiplier
-- stored when the boost was bought.
function GameData.getBoostMultiplier(data, now)
	if GameData.isBoostActive(data, now) then
		return data.boostMult or 2
	end
	return 1
end

-- Apply a timed cash boost. Only the DURATION stacks -- the multiplier takes
-- the HIGHER of the current and new value, never the sum (otherwise buying
-- several Mega Boosts would give an absurd 10x). Shared by shop boosts, daily
-- rewards, Mega Boost and the Starter Pack so the rule lives in one place.
function GameData.applyBoost(data, mult, dur, icon, label, now)
	if now < (data.boostUntil or 0) then
		data.boostUntil += dur
		data.boostMult = math.max(data.boostMult or 1, mult)
	else
		data.boostUntil = now + dur
		data.boostMult = mult
	end
	data.boostIcon = icon
	data.boostLabel = label
end

-- ---- Monetization: game passes & dev products -----------------------------
-- IDs are 0 until created on the Roblox site (Monetization page). With id 0 a
-- pass/product is skipped by ownership checks + receipts and shown as
-- "Coming soon" in the Store, so the whole system builds and tests before the
-- real IDs exist. Effects are read in-memory via the getPass* helpers below.
GameData.GamePasses = {
	Cash2x = { id = 1928262270, order = 1, icon = "\240\159\146\176", name = "2x Cash", desc = "Earn DOUBLE cash from everything, forever.", cashMult = 2 },
	VIP = { id = 1927380272, order = 2, icon = "\226\173\144", name = "VIP", desc = "+25% cash forever, a gold look and a VIP tag.", cashMult = 1.25 },
	FasterWorkers = { id = 1927680275, order = 3, icon = "\240\159\145\183", name = "Faster Workers", desc = "Your workers build games 1.5x faster.", workerSpeedMult = 1.5 },
	Subs2x = { id = 1927332286, order = 4, icon = "\240\159\147\136", name = "2x Subscribers", desc = "Get DOUBLE subscribers from every release.", subsMult = 2 },
}
GameData.Products = {
	StarterPack = { id = 3611343811, order = 1, icon = "\240\159\142\129", name = "Starter Pack", desc = "$500 cash + a 2x boost (10 min) + a guaranteed Rare worker!", cash = 500, boostMult = 2, boostDur = 600, worker = "Rare" },
	MegaBoost = { id = 3611343857, order = 2, icon = "\226\154\161", name = "Mega Boost", desc = "3x cash for 15 minutes. Buy anytime!", boostMult = 3, boostDur = 900 },
}

-- Cash multiplier from owned passes (2x Cash and VIP stack multiplicatively).
function GameData.getPassCashMultiplier(data)
	local m = 1
	local passes = data and data.passes
	if passes then
		if passes.Cash2x then
			m *= GameData.GamePasses.Cash2x.cashMult
		end
		if passes.VIP then
			m *= GameData.GamePasses.VIP.cashMult
		end
	end
	return m
end

function GameData.getPassWorkerSpeedMultiplier(data)
	local passes = data and data.passes
	if passes and passes.FasterWorkers then
		return GameData.GamePasses.FasterWorkers.workerSpeedMult
	end
	return 1
end

function GameData.getPassSubsMultiplier(data)
	local passes = data and data.passes
	if passes and passes.Subs2x then
		return GameData.GamePasses.Subs2x.subsMult
	end
	return 1
end

-- Per-shop catalogs -- each shop sells DIFFERENT items. Shared so the client
-- shows them and the server validates purchases against the same data.
--   kind "boost"    -> temporary cash multiplier (mult) for `dur` seconds
--   kind "cosmetic" -> gives the player a coloured cap (color)
-- Each item carries an `icon` emoji used as its graphic on the shop card (and,
-- for boosts, on the on-screen boost timer). Cosmetics also carry a short
-- `label` shown when equipped.
GameData.ShopCatalog = {
	Snacks = {
		title = "\240\159\141\148 Snack Bar",
		accent = Color3.fromRGB(224, 120, 90),
		items = {
			{ id = "energy", name = "Energy Drink", icon = "\226\154\161", desc = "2x cash \194\183 2 min", cost = 250, kind = "boost", mult = 2, dur = 120 },
			{ id = "combo", name = "Combo Meal", icon = "\240\159\141\159", desc = "1.5x cash \194\183 5 min", cost = 350, kind = "boost", mult = 1.5, dur = 300 },
		},
	},
	Clothes = {
		title = "\240\159\145\149 Clothes Shop",
		accent = Color3.fromRGB(110, 170, 210),
		items = {
			{ id = "red", name = "Red Cap", icon = "\240\159\167\162", label = "Red", desc = "A red cap for your head", cost = 150, kind = "cosmetic", color = Color3.fromRGB(200, 60, 60) },
			{ id = "blue", name = "Blue Cap", icon = "\240\159\167\162", label = "Blue", desc = "A blue cap for your head", cost = 150, kind = "cosmetic", color = Color3.fromRGB(60, 110, 200) },
			{ id = "gold", name = "Gold Cap", icon = "\240\159\145\145", label = "Gold", desc = "A fancy gold cap", cost = 500, kind = "cosmetic", color = Color3.fromRGB(230, 190, 90) },
		},
	},
	GameStore = {
		title = "\240\159\142\174 Game Store",
		accent = Color3.fromRGB(150, 120, 220),
		items = {
			{ id = "mega", name = "Mega Boost", icon = "\240\159\146\142", desc = "3x cash \194\183 3 min", cost = 800, kind = "boost", mult = 3, dur = 180 },
		},
	},
	Grocery = {
		title = "\240\159\143\170 Grocery",
		accent = Color3.fromRGB(120, 190, 130),
		items = {
			{ id = "value", name = "Value Pack", icon = "\240\159\155\146", desc = "1.5x cash \194\183 8 min", cost = 400, kind = "boost", mult = 1.5, dur = 480 },
			{ id = "party", name = "Party Pack", icon = "\240\159\142\137", desc = "2x cash \194\183 4 min", cost = 600, kind = "boost", mult = 2, dur = 240 },
		},
	},
}

function GameData.findShopItem(shopKey, itemId)
	local shop = GameData.ShopCatalog[shopKey]
	if not shop then
		return nil
	end
	for _, item in ipairs(shop.items) do
		if item.id == itemId then
			return item
		end
	end
	return nil
end

-- ---- Worker rarities & cases ----------------------------------------------
-- Workers now roll a rarity from a case. Better rarity = works FASTER
-- (auto-complete divided by `speed`) and EARNS MORE (score * `mult`).
-- `mult` = quality/earnings bonus (raw phase score = getWorkerScore(level) *
-- mult, and the whole game's quality is capped at MaxDevQuality = 250%).
-- `speed` = games finish this much faster (more games/minute). Mythic tops out
-- at 2.5x on BOTH -- a strong but BOUNDED advantage (not the old 6x that
-- printed money). Rarities ramp evenly up to it.
GameData.WorkerRarities = {
	{ name = "Common", color = Color3.fromRGB(178, 182, 192), mult = 1.0, speed = 1.0 },
	{ name = "Rare", color = Color3.fromRGB(88, 158, 240), mult = 1.3, speed = 1.3 },
	{ name = "Epic", color = Color3.fromRGB(170, 92, 240), mult = 1.7, speed = 1.7 },
	{ name = "Legendary", color = Color3.fromRGB(255, 180, 60), mult = 2.1, speed = 2.1 },
	{ name = "Mythic", color = Color3.fromRGB(255, 80, 120), mult = 2.5, speed = 2.5 },
}
GameData.RarityOrder = { Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythic = 5 }

-- Normal case (bought with in-game cash) + Lucky crate (bought with Robux).
-- Weights are the exact drop chances (percent). They each sum to 100.
GameData.NormalCaseCost = 1000
GameData.NormalCaseWeights = {
	{ rarity = "Common", weight = 62.5 },
	{ rarity = "Rare", weight = 35 },
	{ rarity = "Epic", weight = 2 },
	{ rarity = "Legendary", weight = 0.495 },
	{ rarity = "Mythic", weight = 0.005 },
}
GameData.LuckyCaseRobux = 29
GameData.LuckyCaseProductId = 3611281192 -- single "Lucky Crate" (29 R$)
-- Robux developer products -> how many lucky spins each grants (bundles).
GameData.LuckyCaseProducts = {
	[3611281192] = 1, -- 1 Lucky Crate
	[3611282275] = 5, -- 5 Lucky Crates
	[3611282333] = 10, -- 10 Lucky Crates
}
-- Bundle buttons shown on the Lucky Crate card: { label, productId }.
GameData.LuckyCaseBundles = {
	{ label = "x1", productId = 3611281192 },
	{ label = "x5", productId = 3611282275 },
	{ label = "x10", productId = 3611282333 },
}
GameData.LuckyCaseWeights = {
	{ rarity = "Epic", weight = 70 },
	{ rarity = "Legendary", weight = 29 },
	{ rarity = "Mythic", weight = 1 },
}

-- Pity: every 50th normal spin is guaranteed at least Epic (95% Epic / 5%
-- Legendary); every 10th lucky spin is a guaranteed Mythic.
GameData.NormalPityThreshold = 50
GameData.NormalPityWeights = {
	{ rarity = "Epic", weight = 95 },
	{ rarity = "Legendary", weight = 5 },
}
GameData.LuckyPityThreshold = 10 -- guaranteed Mythic on this spin

function GameData.getRarityInfo(name)
	for _, r in ipairs(GameData.WorkerRarities) do
		if r.name == name then
			return r
		end
	end
	return GameData.WorkerRarities[1]
end

function GameData.getRarityMultiplier(name)
	return GameData.getRarityInfo(name).mult
end

function GameData.getRaritySpeed(name)
	return GameData.getRarityInfo(name).speed
end

-- Weighted random pick from a {rarity, weight} list. `rng` optional (Random).
function GameData.rollCase(weights)
	local total = 0
	for _, w in ipairs(weights) do
		total += w.weight
	end
	local roll = math.random() * total
	local acc = 0
	for _, w in ipairs(weights) do
		acc += w.weight
		if roll <= acc then
			return w.rarity
		end
	end
	return weights[#weights].rarity
end

GameData.WorkerHireCost = 150
GameData.WorkerUpgradeCostBase = 50
GameData.WorkerUpgradeCostGrowth = 1.3
GameData.WorkerBaseScore = 0.5
GameData.WorkerScorePerLevel = 0.05
GameData.WorkerAutoCompleteSeconds = 3

-- houseTier is optional and defaults to 0 (no floor scaling) so older
-- call sites keep working; callers that know the player's floor pass it
-- to get the doubled-per-floor price.
function GameData.getWorkerHireCost(houseTier)
	return math.floor(GameData.WorkerHireCost * GameData.getFloorMultiplier(houseTier))
end

function GameData.getWorkerUpgradeCost(currentLevel, houseTier)
	local base = GameData.WorkerUpgradeCostBase * (GameData.WorkerUpgradeCostGrowth ^ currentLevel)
	return math.floor(base * GameData.getFloorMultiplier(houseTier))
end

function GameData.getWorkerScore(level)
	return math.min(1, GameData.WorkerBaseScore + (level * GameData.WorkerScorePerLevel))
end

function GameData.getBaseCash(devQuality)
	return GameData.PayoutMultiplier * devQuality
end

GameData.StudioLevelPerGames = 2
GameData.StudioLevelPerSubs  = 50
GameData.StudioLevelMax      = 50
GameData.DifficultyRampLevels = 19

function GameData.getStudioLevel(data)
	local lvl = 1
		+ math.floor((data.gamesReleased or 0) / GameData.StudioLevelPerGames)
		+ math.floor((data.subscribers or 0) / GameData.StudioLevelPerSubs)
	return math.min(lvl, GameData.StudioLevelMax)
end

function GameData.getDifficulty(studioLevel)
	return math.clamp((studioLevel - 1) / GameData.DifficultyRampLevels, 0, 1)
end

function GameData.getMarkerPosition(elapsedSeconds, periodSeconds)
	local phase01 = (elapsedSeconds % periodSeconds) / periodSeconds

	if phase01 < 0.5 then
		return phase01 * 2
	end

	return 2 - (phase01 * 2)
end

-- House tiers double as FLOORS: tier 0 = a 1-floor studio, and each
-- upgrade adds another floor (up to HouseTierCount floors, capped at 3).
-- The cost doubles each floor to match the "everything costs 2x per floor" rule.
GameData.HouseTierCount = 3
GameData.HouseUpgradeCostBase = 300
GameData.HouseUpgradeCostGrowth = 2

function GameData.getHouseUpgradeCost(currentTier)
	return math.floor(GameData.HouseUpgradeCostBase * (GameData.HouseUpgradeCostGrowth ^ currentTier))
end

-- PC tiers: index 0 is the starting computer, up to PCTierCount - 1 is the max tier.
-- Each tier permanently boosts cash earned per game release.
GameData.PCTierCount = 5
GameData.PCUpgradeCostBase = 200
GameData.PCUpgradeCostGrowth = 1.6
GameData.PCCashBonusPerTier = 0.25

function GameData.getPCUpgradeCost(currentTier, houseTier)
	local base = GameData.PCUpgradeCostBase * (GameData.PCUpgradeCostGrowth ^ currentTier)
	return math.floor(base * GameData.getFloorMultiplier(houseTier))
end

function GameData.getPCCashMultiplier(tier)
	return 1 + (tier * GameData.PCCashBonusPerTier)
end

-- ---- Subscribers -----------------------------------------------------------
-- Your channel audience. Gained when you release games (more for better games,
-- big bonus on a trend hit). Subscribers (1) earn passive "ad revenue" cash
-- over time, (2) give a permanent multiplier on cash you earn, and (3) unlock
-- Play Button milestones.
GameData.SubsPerQuality = 40 -- subs from a release = quality * this ...
GameData.SubTrendBonus = 3 -- ... times this when the game matched a trend
GameData.SubAdRevenuePerSec = 0.01 -- cash/sec earned per subscriber
GameData.SubMultiplierPer = 0.00005 -- +earnings multiplier per subscriber ...
GameData.SubMultiplierCap = 3 -- ... capped here (so max earnings mult is 4x)

function GameData.getSubsForRelease(devQuality, hitBonus)
	local mult = hitBonus and GameData.SubTrendBonus or 1
	return math.max(1, math.floor((devQuality or 0) * GameData.SubsPerQuality * mult + 0.5))
end

-- Permanent multiplier on earned cash from your subscriber count.
function GameData.getSubscriberMultiplier(subs)
	return 1 + math.min(GameData.SubMultiplierCap, (subs or 0) * GameData.SubMultiplierPer)
end

-- Play Button milestones: crossing one awards a cash bonus and a trophy in
-- the studio. `index` in player data is the highest milestone reached.
GameData.SubMilestones = {
	{ subs = 100, cash = 500, label = "Bronze Game Developer Button", color = Color3.fromRGB(184, 122, 74) },
	{ subs = 1000, cash = 3000, label = "Silver Game Developer Button", color = Color3.fromRGB(206, 210, 220) },
	{ subs = 10000, cash = 20000, label = "Gold Game Developer Button", color = Color3.fromRGB(240, 200, 90) },
	{ subs = 100000, cash = 150000, label = "Diamond Game Developer Button", color = Color3.fromRGB(140, 222, 236) },
	{ subs = 1000000, cash = 1000000, label = "Ruby Game Developer Button", color = Color3.fromRGB(224, 72, 96) },
}

-- Highest milestone index whose sub threshold `subs` has reached.
function GameData.getSubMilestoneIndex(subs)
	local reached = 0
	for i, m in ipairs(GameData.SubMilestones) do
		if (subs or 0) >= m.subs then
			reached = i
		end
	end
	return reached
end

-- ---- Studio decorations ----------------------------------------------------
-- Mirror of the server's plot layout so the client can work out its own
-- studio bounds + floor heights for drag-to-place (kept in sync with the
-- constants in PlotManager.luau).
GameData.PlotConfig = {
	origins = {
		Vector3.new(0, 0, 0),
		Vector3.new(160, 0, 0),
		Vector3.new(0, 0, 160),
		Vector3.new(160, 0, 160),
	},
	houseLotOffset = Vector3.new(0, 0, 45),
	buildingHalfW = 18, -- interior half-extent along X
	buildingHalfD = 16, -- interior half-extent along Z
	floorTop = 1, -- ground-floor slab top (Y)
	floorHeight = 13, -- vertical spacing between floors
	maxFloors = 3,
	wallMargin = 2, -- keep decorations this far off the walls
	gridSize = 2, -- decorations snap to a 2-stud grid aligned to the studio
}

-- Snap a world X/Z to the studio's placement grid (aligned to the studio
-- centre `base`), so the placement ghost and the server agree exactly.
function GameData.snapToStudioGrid(base, x, z)
	local g = GameData.PlotConfig.gridSize
	return base.X + math.floor((x - base.X) / g + 0.5) * g, base.Z + math.floor((z - base.Z) / g + 0.5) * g
end

-- The studio building's interior centre for a plot (where decorations live).
function GameData.getStudioBase(plotIndex)
	local origin = GameData.PlotConfig.origins[plotIndex]
	if not origin then
		return nil
	end
	return origin + GameData.PlotConfig.houseLotOffset
end

-- Catalog of buyable studio decorations. Each is a small procedural model
-- built by the shared DecorBuilder from these fields. `footprint` (X,Z) is
-- used to keep the item clear of the walls while placing.
GameData.DecorCatalog = {
	{ id = "plant", name = "Potted Plant", icon = "\240\159\170\180", cost = 120, footprint = Vector2.new(3, 3), color = Color3.fromRGB(96, 156, 92) },
	{ id = "rug", name = "Cozy Rug", icon = "\240\159\159\170", cost = 90, footprint = Vector2.new(9, 6), color = Color3.fromRGB(130, 96, 200) },
	{ id = "couch", name = "Couch", icon = "\240\159\155\139", cost = 300, footprint = Vector2.new(7, 3), color = Color3.fromRGB(210, 120, 90) },
	{ id = "arcade", name = "Arcade Machine", icon = "\240\159\149\185", cost = 450, footprint = Vector2.new(3, 3), color = Color3.fromRGB(96, 112, 220) },
	{ id = "shelf", name = "Bookshelf", icon = "\240\159\147\154", cost = 250, footprint = Vector2.new(5, 2), color = Color3.fromRGB(150, 110, 70) },
	{ id = "lamp", name = "Floor Lamp", icon = "\240\159\146\161", cost = 140, footprint = Vector2.new(2, 2), color = Color3.fromRGB(240, 225, 170) },
	{ id = "trophy", name = "Dev Trophy", icon = "\240\159\143\134", cost = 600, footprint = Vector2.new(2, 2), color = Color3.fromRGB(235, 200, 90) },
	{ id = "tv", name = "TV & Stand", icon = "\240\159\147\186", cost = 380, footprint = Vector2.new(6, 2), color = Color3.fromRGB(40, 44, 52) },
}

GameData.MaxDecorations = 40 -- per player, to keep studios sane

function GameData.findDecorItem(id)
	for _, item in ipairs(GameData.DecorCatalog) do
		if item.id == id then
			return item
		end
	end
	return nil
end

-- ---- Prestige / Rebirth ----------------------------------------------------
-- Reset your progress (cash, studio, PC, workers, subscribers, rooms) in
-- exchange for a permanent +bonus on ALL cash you earn, forever. The subscriber
-- requirement grows each prestige so it stays a long-term goal.
GameData.PrestigeBaseRequirement = 7500 -- subscribers needed for the 1st rebirth (grows each rebirth)
GameData.PrestigeBonusPerLevel = 0.5 -- +50% permanent earnings per prestige level

function GameData.getPrestigeRequirement(level)
	return GameData.PrestigeBaseRequirement * ((level or 0) + 1)
end

function GameData.getPrestigeMultiplier(level)
	return 1 + (level or 0) * GameData.PrestigeBonusPerLevel
end

function GameData.canPrestige(subscribers, level)
	return (subscribers or 0) >= GameData.getPrestigeRequirement(level)
end

-- ---- Daily reward streak ---------------------------------------------------
-- Come back each day for an escalating reward. A reward is claimable once the
-- cooldown has passed; the streak keeps climbing if you return before the
-- reset window, otherwise it restarts at day 1. Rewards cycle every 7 days.
GameData.DailyClaimCooldownSeconds = 20 * 3600 -- claimable ~once a day (20h)
GameData.DailyStreakResetSeconds = 48 * 3600 -- miss ~2 days and the streak resets

-- Tuned to the current economy (a game pays ~$27): day 1 is a small welcome
-- that does NOT skip your first upgrades, escalating to a real week-long prize.
GameData.DailyRewards = {
	{ kind = "cash", amount = 100 },
	{ kind = "cash", amount = 300 },
	{ kind = "boost", mult = 2, dur = 300 },
	{ kind = "cash", amount = 800 },
	{ kind = "cash", amount = 2000 },
	{ kind = "boost", mult = 3, dur = 300 },
	{ kind = "cash", amount = 6000 },
}

-- Reward for a given streak day (1-based; cycles every #DailyRewards days).
function GameData.getDailyReward(streakDay)
	local n = #GameData.DailyRewards
	local idx = ((math.max(1, streakDay) - 1) % n) + 1
	return GameData.DailyRewards[idx], idx
end

-- Short human label for a reward (client popup + confirmation).
function GameData.describeDailyReward(reward)
	if reward.kind == "boost" then
		return ("%gx cash boost \194\183 %dm"):format(reward.mult, math.floor(reward.dur / 60))
	end
	return ("$%d"):format(reward.amount)
end

-- ---- Minigame scoring functions (per input kind) ----------------------------
-- Each scoring function returns a 0..1 score based on player performance.

function GameData.scoreMash(count, targetTaps)
	return math.clamp(count / targetTaps, 0, 1)
end

function GameData.scoreTiming(markerPos, zoneCenter, zoneHalfWidth)
	local dist = math.abs(markerPos - zoneCenter)
	if dist > zoneHalfWidth then return 0 end
	return 1 - (dist / zoneHalfWidth)
end

function GameData.scoreSequence(correct, total)
	if total <= 0 then return 0 end
	return math.clamp(correct / total, 0, 1)
end

function GameData.scoreChoice(chosenIndex, correctIndex, wrongScore)
	if chosenIndex == correctIndex then return 1 end
	return wrongScore
end

-- ---- Minigame variants & difficulty scaling --------------------------------
-- Three phases, each with four minigame variants. Variants are picked in
-- rotation, avoiding repeats when possible. Parameters scale per difficulty.

GameData.StationVariantIds = {
	Coding      = { "CodeSprint", "BugSquash", "KeyCombo", "CompileCheck" },
	MapBuilding = { "PrecisionPlace", "BlueprintMemory", "TileDrop", "PathConnect" },
	Testing     = { "BugHunt", "QAQuiz", "PassOrFail", "CrashFix" },
}

-- The subset of StationVariantIds that is actually implemented + registered
-- client-side and therefore safe to pick. Each new variant task appends its
-- id here as it's built, until all of StationVariantIds is covered.
GameData.ImplementedVariantIds = {
	Coding      = { "CodeSprint", "BugSquash" },
	MapBuilding = { "PrecisionPlace" },
	Testing     = { "QAQuiz" },
}

GameData.VariantInputKind = {
	CodeSprint = "mash", BugSquash = "mash", KeyCombo = "sequence", CompileCheck = "choice",
	PrecisionPlace = "timing", BlueprintMemory = "sequence", TileDrop = "sequence", PathConnect = "sequence",
	BugHunt = "choice", QAQuiz = "choice", PassOrFail = "sequence", CrashFix = "mash",
}

-- Filled incrementally by each variant task. Values below are the final targets.
GameData.VariantParams = {
	CodeSprint     = { easy = { targetTaps = 12, windowSeconds = 3 },              hard = { targetTaps = 40, windowSeconds = 3 },              ints = { targetTaps = true } },
	BugSquash      = { easy = { targetBugs = 6, spawnInterval = 0.55, windowSeconds = 4 }, hard = { targetBugs = 16, spawnInterval = 0.28, windowSeconds = 4 }, ints = { targetBugs = true } },
	KeyCombo       = { easy = { len = 3, peekSeconds = 2.5, inputSeconds = 6 },    hard = { len = 8, peekSeconds = 0.8, inputSeconds = 5 },    ints = { len = true } },
	CompileCheck   = { easy = { answerSeconds = 10 },                              hard = { answerSeconds = 4 },                               ints = {} },
	PrecisionPlace = { easy = { zoneHalfWidth = 0.18, periodSeconds = 2.2 },       hard = { zoneHalfWidth = 0.05, periodSeconds = 1.0 },       ints = {} },
	BlueprintMemory= { easy = { gridN = 3, patternLen = 3, peekSeconds = 2.5 },    hard = { gridN = 4, patternLen = 8, peekSeconds = 1.0 },    ints = { gridN = true, patternLen = true } },
	TileDrop       = { easy = { pieces = 3, fallSeconds = 2.0 },                   hard = { pieces = 7, fallSeconds = 0.9 },                   ints = { pieces = true } },
	PathConnect    = { easy = { gridN = 4, timeSeconds = 8 },                      hard = { gridN = 6, timeSeconds = 5 },                      ints = { gridN = true } },
	BugHunt        = { easy = { gridN = 3, answerSeconds = 6 },                    hard = { gridN = 5, answerSeconds = 3 },                    ints = { gridN = true } },
	QAQuiz         = { easy = { optionCount = 2, answerSeconds = 12 },             hard = { optionCount = 4, answerSeconds = 5 },              ints = { optionCount = true } },
	PassOrFail     = { easy = { count = 5, flashSeconds = 2.0 },                   hard = { count = 12, flashSeconds = 0.8 },                  ints = { count = true } },
	CrashFix       = { easy = { targetCrashes = 6, spawnInterval = 0.6, windowSeconds = 5 }, hard = { targetCrashes = 18, spawnInterval = 0.25, windowSeconds = 5 }, ints = { targetCrashes = true } },
}

function GameData.getVariantParams(id, difficulty)
	local spec = GameData.VariantParams[id]
	local ints = spec.ints or {}
	local out = {}
	for key, easyVal in pairs(spec.easy) do
		local v = easyVal + (spec.hard[key] - easyVal) * difficulty
		if ints[key] then v = math.floor(v + 0.5) end
		out[key] = v
	end
	return out
end

function GameData.pickVariantId(station, lastId, rng)
	local ids = GameData.ImplementedVariantIds[station]
	local pool = {}
	for _, id in ipairs(ids) do
		if id ~= lastId or #ids == 1 then table.insert(pool, id) end
	end
	return pool[math.floor(rng() * #pool) + 1]
end

return GameData

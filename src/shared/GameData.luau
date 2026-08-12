local GameData = {}

-- The original 4 of each stay free forever and grant no bonus. Tiers 1-6 are
-- cash unlocks; the last 2 of each are Robux unlocks. Order matters: it's
-- free-4, then tier1..tier6, then the two Robux entries, matching the ladder
-- in ContentUnlocks below and the order the 2x6 unlock grid renders in.
GameData.Genres = {
	"Racing", "Horror", "Adventure", "Simulator",
	"Obby", "Tycoon", "Roleplay", "Fighting", "Puzzle", "Survival",
	"Battle Royale", "Anime",
}
GameData.Topics = {
	"Space", "Zombies", "Sports", "Fantasy",
	"Pets", "Ninjas", "Pirates", "Robots", "Dragons", "Superheroes",
	"Aliens", "Dinosaurs",
}

-- ---- Content unlocks (A1): paid genres & topics ----------------------------
-- Keyed by the genre/topic name itself (genres and topics never share a name,
-- so one table covers both kinds). Free entries (the original 4 of each) are
-- simply ABSENT from this table -- that absence IS the "is it free" check.
-- Cash entries: { kind, price, minBonus, maxBonus, icon, order }. The bonus is
-- a live roll inside [minBonus, maxBonus], refreshed by TrendsService on the
-- trend cycle (see rollContentBonuses below).
-- Robux entries: { kind, robuxProductKey, fixedBonus, icon, order } -- always
-- the same bonus, no roll. `robuxProductKey` names the matching GameData.Products
-- entry (ships with id = 0, "coming soon", until the real product exists).
-- `order` is the entry's 1-8 position within its kind's paid ladder (tier1..6,
-- then the two Robux entries) -- used by the client to lay out the grid.
GameData.ContentUnlocks = {
	-- Genres: cash tiers 1-6
	Obby = { kind = "genre", price = 20000, minBonus = 0.10, maxBonus = 0.15, icon = "\240\159\167\151", order = 1 },
	Tycoon = { kind = "genre", price = 60000, minBonus = 0.12, maxBonus = 0.17, icon = "\240\159\143\173", order = 2 },
	Roleplay = { kind = "genre", price = 150000, minBonus = 0.15, maxBonus = 0.20, icon = "\240\159\142\173", order = 3 },
	Fighting = { kind = "genre", price = 400000, minBonus = 0.18, maxBonus = 0.23, icon = "\240\159\165\138", order = 4 },
	Puzzle = { kind = "genre", price = 1000000, minBonus = 0.20, maxBonus = 0.25, icon = "\240\159\167\169", order = 5 },
	Survival = { kind = "genre", price = 2500000, minBonus = 0.22, maxBonus = 0.28, icon = "\240\159\143\149\239\184\143", order = 6 },
	-- Genres: Robux tiers
	["Battle Royale"] = { kind = "genre", robuxProductKey = "BattleRoyaleGenre", fixedBonus = 0.30, icon = "\226\154\148\239\184\143", order = 7 },
	Anime = { kind = "genre", robuxProductKey = "AnimeGenre", fixedBonus = 0.35, icon = "\240\159\140\184", order = 8 },

	-- Topics: cash tiers 1-6
	Pets = { kind = "topic", price = 20000, minBonus = 0.10, maxBonus = 0.15, icon = "\240\159\144\182", order = 1 },
	Ninjas = { kind = "topic", price = 60000, minBonus = 0.12, maxBonus = 0.17, icon = "\240\159\165\183", order = 2 },
	Pirates = { kind = "topic", price = 150000, minBonus = 0.15, maxBonus = 0.20, icon = "\226\154\147", order = 3 },
	Robots = { kind = "topic", price = 400000, minBonus = 0.18, maxBonus = 0.23, icon = "\240\159\164\150", order = 4 },
	Dragons = { kind = "topic", price = 1000000, minBonus = 0.20, maxBonus = 0.25, icon = "\240\159\144\137", order = 5 },
	Superheroes = { kind = "topic", price = 2500000, minBonus = 0.22, maxBonus = 0.28, icon = "\240\159\166\184", order = 6 },
	-- Topics: Robux tiers
	Aliens = { kind = "topic", robuxProductKey = "AliensTopic", fixedBonus = 0.30, icon = "\240\159\145\189", order = 7 },
	Dinosaurs = { kind = "topic", robuxProductKey = "DinosaursTopic", fixedBonus = 0.35, icon = "\240\159\166\150", order = 8 },
}

-- True when `id` is one of the original free genres/topics (absent from
-- ContentUnlocks entirely -- there is no separate "free list" to keep in sync).
function GameData.isContentFree(id)
	return GameData.ContentUnlocks[id] == nil
end

-- Free entries are always owned (nothing to buy). Paid entries are owned only
-- once the player's save says so.
function GameData.ownsContent(data, id)
	if GameData.isContentFree(id) then
		return true
	end
	return data ~= nil and data.contentOwned ~= nil and data.contentOwned[id] == true
end

-- The cash-release bonus contributed by owning `id`, given the CURRENT live
-- roll table (id -> percentage) from TrendsService. Always a fraction (0.10 =
-- +10%), matching PCParts' `bonus` convention.
--   * free entries -> 0 (they're absent from ContentUnlocks, so `entry` is nil)
--   * unowned paid entries -> 0 (you don't get the bonus until you buy it)
--   * owned Robux entries -> their fixedBonus, ALWAYS (never reads rollTable)
--   * owned cash entries -> rollTable[id] if the live roll is known, else the
--     entry's band minimum (a safe floor before the first roll ever lands)
function GameData.getContentBonus(data, id, rollTable)
	local entry = GameData.ContentUnlocks[id]
	if not entry then
		return 0
	end
	if not GameData.ownsContent(data, id) then
		return 0
	end
	if entry.fixedBonus then
		return entry.fixedBonus
	end
	return (rollTable and rollTable[id]) or entry.minBonus
end

-- Cash multiplier a released game earns from its genre + topic choice. Purely
-- ADDITIVE (never multiplicative) so the two content bonuses stack the same
-- way PC parts do, and stay well under the existing cash-stack ceiling.
function GameData.getReleaseContentMultiplier(data, genre, topic, rollTable)
	return 1 + GameData.getContentBonus(data, genre, rollTable) + GameData.getContentBonus(data, topic, rollTable)
end

-- Rolls a fresh live percentage for every CASH content unlock (Robux entries
-- are fixed and never rolled, so they're absent from the result). Called by
-- TrendsService once per trend refresh; the result is server-owned and
-- broadcast for display only.
--
-- rng contract: `rng` is a zero-argument function returning a float uniformly
-- distributed in [0, 1), i.e. the same contract as `math.random()` with no
-- arguments. Injected so tests can be deterministic; defaults to math.random.
function GameData.rollContentBonuses(rng)
	rng = rng or math.random
	local rolls = {}
	for id, entry in pairs(GameData.ContentUnlocks) do
		if entry.minBonus ~= nil and entry.maxBonus ~= nil then
			rolls[id] = entry.minBonus + rng() * (entry.maxBonus - entry.minBonus)
		end
	end
	return rolls
end

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
	{
		prompt = "Your game's fun but nobody's finding it. What's the best fix?",
		options = {
			"Spam every Discord server you can find",
			"Improve the thumbnail, icon, and store description",
			"Lower the price to zero forever",
			"Wait it out, good games find players eventually",
		},
		correctIndex = 2,
	},
	{
		prompt = "A whale offers to pay you directly outside the platform for a rare item. What do you do?",
		options = {
			"Take the deal, it's easy money",
			"Decline -- it breaks platform rules and risks a ban",
			"Ask for even more money first",
			"Give the item away free instead",
		},
		correctIndex = 2,
	},
	{
		prompt = "Your multiplayer game has a duplication exploit. What's the right response?",
		options = {
			"Patch it quickly and reset affected balances",
			"Ignore it, most players won't find it",
			"Turn it into a paid feature",
			"Blame the players who used it and do nothing else",
		},
		correctIndex = 1,
	},
	{
		prompt = "Reviews say your monetization feels too aggressive. What should you do?",
		options = {
			"Add even more ads and pop-ups",
			"Rebalance so free play still feels rewarding",
			"Ignore reviews, revenue is what matters",
			"Remove the free version entirely",
		},
		correctIndex = 2,
	},
	{
		prompt = "You're deciding between two features and only have time for one. How do you choose?",
		options = {
			"Whichever one you personally like more",
			"Flip a coin",
			"Whichever solves the bigger player pain point",
			"Whichever took less code to plan",
		},
		correctIndex = 3,
	},
}

-- Each entry is one QA triage statement: `ship = true` means it's fine to
-- release, `ship = false` means it's a blocker that should be cut/fixed
-- first. DevelopmentService.generateRoundInfo("PassOrFail", ...) draws
-- `count` of these (with repeats allowed) and records the truth array
-- alongside the item text so the client's SHIP/CUT taps can be scored.
GameData.PassOrFailItems = {
	{ text = "Runs at 60 FPS on mobile", ship = true },
	{ text = "Crashes on the loading screen", ship = false },
	{ text = "Saves player progress correctly", ship = true },
	{ text = "Players fall through the floor", ship = false },
	{ text = "All buttons respond to taps", ship = true },
	{ text = "Leaderboard shows the wrong names", ship = false },
	{ text = "Sound effects play on cue", ship = true },
	{ text = "Game freezes when two players join at once", ship = false },
	{ text = "Inventory items stack correctly", ship = true },
	{ text = "Currency can go negative", ship = false },
	{ text = "Menus close when you tap outside them", ship = true },
	{ text = "Textures fail to load half the time", ship = false },
	{ text = "Daily rewards give the advertised amount", ship = true },
	{ text = "Chat filter lets slurs through", ship = false },
	{ text = "Settings save between sessions", ship = true },
	{ text = "Purchasing an item doesn't grant it", ship = false },
}

-- Each set has one line that actually compiles/runs (`good`) and two that
-- look almost right but are broken (`bad`) -- a missing paren/brace/quote, a
-- typo'd keyword, or a typo'd identifier. DevelopmentService.generateRoundInfo
-- shuffles the three into `lines` and tracks which shuffled slot is correct.
GameData.CompileSnippets = {
	{ good = "local x = 5", bad = { "local x = ", "locl x = 5" } },
	{ good = "print(\"hi\")", bad = { "print(\"hi\"", "print((\"hi\")" } },
	{ good = "if x then end", bad = { "if x then", "iff x then end" } },
	{ good = "local t = {}", bad = { "local t = {", "locla t = {}" } },
	{ good = "for i = 1, 10 do end", bad = { "for i = 1 10 do end", "fr i = 1, 10 do end" } },
	{ good = "function foo() end", bad = { "function foo(", "functoin foo() end" } },
	{ good = "return true", bad = { "retrun true", "return true true" } },
	{ good = "local s = \"test\"", bad = { "local s = \"test", "local s = test\"" } },
	{ good = "while x do end", bad = { "while x do", "whille x do end" } },
	{ good = "local a, b = 1, 2", bad = { "local a, b = 1,", "locl a, b = 1, 2" } },
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
	VIPPlus      = { id = 1933034533, order = 5, icon = "\240\159\146\142", name = "VIP+", desc = "Unlocks the VIP+ Lounge -- earn passive cash while you relax." },
	Speed2x      = { id = 1933844495, order = 6, icon = "\240\159\143\131", name = "2x Speed", desc = "Move twice as fast around the world.", walkSpeed = 32 },
	SkinGold     = { id = 1933784486, order = 7, icon = "\240\159\142\168", name = "Gold Studio", desc = "A shiny gold look for your studio.", skin = "Gold" },
	SkinNeon     = { id = 1932164824, order = 8, icon = "\240\159\142\168", name = "Neon Studio", desc = "Dark walls with glowing neon trim.", skin = "Neon" },
	SkinMidnight = { id = 1932056863, order = 9, icon = "\240\159\142\168", name = "Midnight Studio", desc = "A deep midnight-blue look.", skin = "Midnight" },
}
GameData.Products = {
	StarterPack = { id = 3611343811, order = 1, icon = "\240\159\142\129", name = "Starter Pack", desc = "$500 cash + a 2x boost (10 min) + a guaranteed Rare worker!", cash = 500, boostMult = 2, boostDur = 600, worker = "Rare" },
	MegaBoost = { id = 3611343857, order = 2, icon = "\226\154\161", name = "Mega Boost", desc = "3x cash for 15 minutes. Buy anytime!", boostMult = 3, boostDur = 900 },
	StreakRepair = { id = 0, order = 3, icon = "\240\159\148\167", name = "Streak Repair", desc = "Broke your login streak? Put it back and carry on where you left off.", repair = true },
	-- Content unlocks (A1): four Robux genre/topic unlocks, each granting the
	-- matching ContentUnlocks entry (named by `contentId`) permanently, always
	-- at its fixedBonus -- ships "coming soon" (id = 0) until real IDs exist.
	BattleRoyaleGenre = { id = 0, order = 4, icon = "\226\154\148\239\184\143", name = "Battle Royale Genre", desc = "Unlock the Battle Royale genre. Always +30% cash on games that use it.", contentId = "Battle Royale" },
	AliensTopic = { id = 0, order = 5, icon = "\240\159\145\189", name = "Aliens Topic", desc = "Unlock the Aliens topic. Always +30% cash on games that use it.", contentId = "Aliens" },
	AnimeGenre = { id = 0, order = 6, icon = "\240\159\140\184", name = "Anime Genre", desc = "Unlock the Anime genre. Always +35% cash on games that use it.", contentId = "Anime" },
	DinosaursTopic = { id = 0, order = 7, icon = "\240\159\166\150", name = "Dinosaurs Topic", desc = "Unlock the Dinosaurs topic. Always +35% cash on games that use it.", contentId = "Dinosaurs" },
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

GameData.LoungeRatePerLevel = 8
GameData.LoungeRateCap = 400

-- Flat, capped, studio-scaling paycheck for the VIP+ lounge. NEVER a % of the
-- player's cash (so it can't snowball / AFK-break). Tune the two constants so
-- this stays below actively developing games.
function GameData.getLoungeRate(data)
	return math.min(GameData.LoungeRateCap, GameData.LoungeRatePerLevel * GameData.getStudioLevel(data))
end

-- Cosmetic studio-exterior skins. Default = the studio's normal look.
GameData.StudioSkins = {
	Default  = nil,
	Gold     = { wall = Color3.fromRGB(214, 164, 58), wallMat = Enum.Material.Metal, accent = Color3.fromRGB(244, 212, 120), floorAsset = "SkinFloorGold" },
	Neon     = { wall = Color3.fromRGB(30, 28, 46), wallMat = Enum.Material.SmoothPlastic, accent = Color3.fromRGB(120, 90, 235), accentMat = Enum.Material.Neon, floorAsset = "SkinFloorNeon" },
	Midnight = { wall = Color3.fromRGB(24, 26, 42), wallMat = Enum.Material.SmoothPlastic, accent = Color3.fromRGB(120, 130, 160), floorAsset = "SkinFloorMidnight" },
}

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

-- Cash earned while offline: reduced room income (ratePerSec already reduced by
-- the caller) over the away time, clamped to [0, capSeconds]. Floored to whole cash.
function GameData.getOfflineCash(ratePerSec, elapsedSeconds, capSeconds)
	local secs = math.clamp(elapsedSeconds or 0, 0, capSeconds or 0)
	return math.floor((ratePerSec or 0) * secs)
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

-- ---- PC Parts Shop ---------------------------------------------------------
-- A real shop: 7 categories, each an ordered ladder of NAMED models (tier 0 =
-- the free starter you begin with, up to the best). `pcParts[categoryId]` = the
-- owned tier index (0-based). "money" categories (CPU/RAM/Storage/Cooling) scale
-- CASH per released game; "followers" categories (GPU/Monitor/RGB Case) scale
-- SUBSCRIBERS per release. `bonus` is the multiplier ADDED when that exact model
-- is equipped (tier-0 starters are free with bonus 0, so a fresh PC = 1.0x).
-- Names are copyright-safe parodies of real hardware.
GameData.PCParts = {
	{ id = "CPU", name = "Processor (CPU)", icon = "\226\154\153\239\184\143", kind = "money", models = {
		{ name = "Celestron G1",         price = 0,     bonus = 0.00 },
		{ name = "Inteal Core i3-Z",     price = 250,   bonus = 0.08 },
		{ name = "Ryzem 5 Fury",         price = 700,   bonus = 0.16 },
		{ name = "Inteal Core i7-K",     price = 1800,  bonus = 0.28 },
		{ name = "Ryzem 9 Beast",        price = 4500,  bonus = 0.44 },
		{ name = "Threadribber XT",      price = 11000, bonus = 0.65 },
	} },
	{ id = "RAM", name = "Memory (RAM)", icon = "\240\159\146\190", kind = "money", models = {
		{ name = "4GB Basic Stick",      price = 0,     bonus = 0.00 },
		{ name = "Corsayr 8GB",          price = 200,   bonus = 0.05 },
		{ name = "G.Zkill 16GB",         price = 550,   bonus = 0.12 },
		{ name = "Vengance 32GB",        price = 1400,  bonus = 0.22 },
		{ name = "TridentX 64GB",        price = 3600,  bonus = 0.34 },
		{ name = "HyperFury 128GB",      price = 9000,  bonus = 0.50 },
	} },
	{ id = "Storage", name = "Storage", icon = "\240\159\151\132\239\184\143", kind = "money", models = {
		{ name = "250GB Old HDD",        price = 0,     bonus = 0.00 },
		{ name = "Seagit 1TB HDD",       price = 180,   bonus = 0.04 },
		{ name = "WesternDigi 1TB SSD",  price = 500,   bonus = 0.10 },
		{ name = "Samsang 2TB NVMe",     price = 1300,  bonus = 0.18 },
		{ name = "Crucal 4TB NVMe",      price = 3200,  bonus = 0.28 },
		{ name = "OptaneX 8TB",          price = 8000,  bonus = 0.42 },
	} },
	{ id = "Cooling", name = "Cooling", icon = "\240\159\140\128", kind = "money", models = {
		{ name = "Stock Fan",            price = 0,     bonus = 0.00 },
		{ name = "CoolMaster Air",       price = 150,   bonus = 0.03 },
		{ name = "BeQuiat Tower",        price = 450,   bonus = 0.08 },
		{ name = "Noctuah Silent",       price = 1100,  bonus = 0.15 },
		{ name = "NZXT Liquid 240",      price = 2800,  bonus = 0.24 },
		{ name = "ArcticStorm 360",      price = 7000,  bonus = 0.36 },
	} },
	{ id = "GPU", name = "Graphics (GPU)", icon = "\240\159\142\174", kind = "followers", models = {
		{ name = "Onboard Graphics",     price = 0,     bonus = 0.00 },
		{ name = "MyForce GTX 1650",     price = 300,   bonus = 0.10 },
		{ name = "MyForce RTX 3060",     price = 900,   bonus = 0.24 },
		{ name = "Radion RX 7800",       price = 2400,  bonus = 0.42 },
		{ name = "MyForce RTX 4080",     price = 6000,  bonus = 0.65 },
		{ name = "MyForce RTX 4090 Ti",  price = 15000, bonus = 1.00 },
	} },
	{ id = "Monitor", name = "Monitor", icon = "\240\159\150\165\239\184\143", kind = "followers", models = {
		{ name = "19\" Office CRT",      price = 0,     bonus = 0.00 },
		{ name = "AZUS 24\" 1080p",      price = 250,   bonus = 0.06 },
		{ name = "Dull 27\" 1440p",      price = 700,   bonus = 0.14 },
		{ name = "Samsang 32\" 4K",      price = 1800,  bonus = 0.26 },
		{ name = "LZ UltraWide 38\"",    price = 4500,  bonus = 0.42 },
		{ name = "PixelPro 49\" Dual",   price = 11000, bonus = 0.62 },
	} },
	{ id = "RGB", name = "RGB Case", icon = "\240\159\140\136", kind = "followers", models = {
		{ name = "Cardboard Box",        price = 0,     bonus = 0.00 },
		{ name = "Basic ATX Case",       price = 150,   bonus = 0.03 },
		{ name = "Glass Tower",          price = 450,   bonus = 0.08 },
		{ name = "RGB Flow Case",        price = 1100,  bonus = 0.16 },
		{ name = "MegaGlow 360",         price = 2800,  bonus = 0.26 },
		{ name = "Galaxy RGB Rig",       price = 7000,  bonus = 0.40 },
	} },
}

local _pcPartById = {}
for _, p in ipairs(GameData.PCParts) do
	_pcPartById[p.id] = p
end
function GameData.getPCPart(id)
	return _pcPartById[id]
end

-- Highest owned tier index for a category (== #models - 1).
function GameData.getPCPartMaxLevel(id)
	local p = _pcPartById[id]
	return p and (#p.models - 1) or 0
end

-- The model equipped at `level` (0-based) in a category.
function GameData.getPCPartModel(id, level)
	local p = _pcPartById[id]
	if not p then return nil end
	return p.models[(level or 0) + 1]
end

-- Cost to buy the NEXT model up from `currentLevel` (nil = already maxed).
function GameData.getPCPartUpgradeCost(id, currentLevel)
	local p = _pcPartById[id]
	if not p then return nil end
	local nextModel = p.models[(currentLevel or 0) + 2]
	return nextModel and nextModel.price or nil
end

local function _pcPartsMultiplier(pcParts, kind, eventParts)
	pcParts = pcParts or {}
	local m = 1
	for _, p in ipairs(GameData.PCParts) do
		if p.kind == kind then
			local model = p.models[(pcParts[p.id] or 0) + 1]
			if model then
				m += model.bonus
			end
		end
	end
	-- Champion parts (event reward): a permanent bonus per part, added on top of
	-- the shop level, in the same money/followers split.
	if eventParts then
		for id, bonus in pairs(eventParts) do
			local p = _pcPartById[id]
			if p and p.kind == kind then
				m += bonus
			end
		end
	end
	return m
end

-- Cash-per-game multiplier from the money categories (CPU/RAM/Storage/Cooling),
-- plus any Champion (event) parts in those categories.
function GameData.getPCPartsCashMultiplier(pcParts, eventParts)
	return _pcPartsMultiplier(pcParts, "money", eventParts)
end

-- Subscribers-per-release multiplier from the follower categories
-- (GPU/Monitor/RGB), plus any Champion (event) parts in those categories.
function GameData.getPCPartsSubsMultiplier(pcParts, eventParts)
	return _pcPartsMultiplier(pcParts, "followers", eventParts)
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
GameData.PrestigeBonusPerLevel = 0.15 -- +15% permanent earnings per prestige level (lowered from 0.5 now that rebirth also grants perk points; the perk tree is the main prestige reward)

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
-- reset window, otherwise it restarts at day 1. The ladder is a 30-day calendar:
-- day 30 is the last entry, and finishing it restarts the calendar at day 1.
GameData.DailyClaimCooldownSeconds = 20 * 3600 -- claimable ~once a day (20h)
GameData.DailyStreakResetSeconds = 48 * 3600 -- miss ~2 days and the streak resets

-- A 30-day login calendar. Ordinary days pay cash or a boost; days 7, 14 and 30
-- are milestones. `amount` is a BASE value -- it gets scaled to the player's
-- progression by getScaledDailyReward, so day 12 is worth about the same
-- relative amount to a new player and to someone on their fifth rebirth.
-- Boost multipliers/durations and case spins are authored values and never scale.
GameData.DailyCalendarDays = 30
GameData.DailyRewards = {
	{ kind = "cash", amount = 100 },
	{ kind = "cash", amount = 150 },
	{ kind = "boost", mult = 2, dur = 300 },
	{ kind = "cash", amount = 250 },
	{ kind = "cash", amount = 450 },
	{ kind = "boost", mult = 2, dur = 600 },
	-- Day 7 milestone: cash AND a long boost.
	{ kind = "cash", amount = 1500, mult = 3, dur = 900, milestone = true },
	{ kind = "cash", amount = 600 },
	{ kind = "cash", amount = 800 },
	{ kind = "boost", mult = 2, dur = 900 },
	{ kind = "cash", amount = 1100 },
	{ kind = "cash", amount = 1400 },
	{ kind = "boost", mult = 3, dur = 600 },
	-- Day 14 milestone: a Lucky Case spin.
	{ kind = "case", spins = 1, milestone = true },
	{ kind = "cash", amount = 1800 },
	{ kind = "cash", amount = 2100 },
	{ kind = "boost", mult = 3, dur = 900 },
	{ kind = "cash", amount = 2500 },
	{ kind = "cash", amount = 2900 },
	{ kind = "boost", mult = 3, dur = 900 },
	{ kind = "cash", amount = 3300 },
	{ kind = "cash", amount = 3800 },
	{ kind = "boost", mult = 3, dur = 1200 },
	{ kind = "cash", amount = 4300 },
	{ kind = "cash", amount = 4800 },
	{ kind = "boost", mult = 3, dur = 1200 },
	{ kind = "cash", amount = 5500 },
	{ kind = "cash", amount = 6000 },
	{ kind = "boost", mult = 3, dur = 1200 },
	-- Day 30 grand prize: a random Champion PC part (see DailyRewardService).
	{ kind = "champion", milestone = true },
}

-- The authored reward for a calendar day. Clamps into 1..30 rather than wrapping
-- (the calendar restarts by resetting the streak, not by indexing past the end).
function GameData.getDailyReward(streakDay)
	local idx = math.clamp(math.floor(streakDay or 1), 1, #GameData.DailyRewards)
	return GameData.DailyRewards[idx], idx
end

-- The reward as the player will actually receive it: a COPY with `amount` scaled
-- to their progression. Used by both the grant and the on-screen preview, so the
-- two can never disagree. Never mutates the authored ladder.
-- Roughly what the player earns per second while idle. Subscriber ad revenue is
-- the dominant passive source and grows linearly, which is exactly why a flat
-- ladder stops mattering: $6,000 is a fortune on day one and a rounding error
-- once you make $1,000/sec.
function GameData.getPassiveIncomePerSecond(data)
	return ((data and data.subscribers) or 0) * GameData.SubAdRevenuePerSec
end

-- How much to multiply the authored cash rewards by, so the calendar stays worth
-- opening at every stage. The authored values ARE the reward for a brand-new
-- player (multiplier 1); past the reference earning rate the reward tracks the
-- player's own income instead, so it keeps its relative value rather than
-- decaying into pocket change.
GameData.DailyIncomeReferencePerSec = 4
function GameData.getDailyRewardMultiplier(data)
	local rate = GameData.getPassiveIncomePerSecond(data)
	return math.max(1, rate / GameData.DailyIncomeReferencePerSec)
end

function GameData.getScaledDailyReward(data, streakDay)
	local base = GameData.getDailyReward(streakDay)
	local copy = {}
	for k, v in pairs(base) do
		copy[k] = v
	end
	if copy.amount then
		copy.amount = math.floor(copy.amount * GameData.getDailyRewardMultiplier(data))
	end
	return copy
end

-- Short human label for a reward (client popup + calendar cells).
function GameData.describeDailyReward(reward)
	if reward.kind == "champion" then
		return "\240\159\143\134 Champion Part!"
	end
	if reward.kind == "case" then
		return ("\240\159\142\129 %d Lucky Spin"):format(reward.spins or 1)
	end
	if reward.kind == "boost" then
		return ("%gx cash \194\183 %dm"):format(reward.mult, math.floor(reward.dur / 60))
	end
	-- Cash, optionally with a boost attached (the day 7 milestone).
	if reward.mult then
		return ("$%d + %gx \194\183 %dm"):format(reward.amount, reward.mult, math.floor(reward.dur / 60))
	end
	return ("$%d"):format(reward.amount)
end

-- Decides, from the player's data alone, whether a daily reward is claimable and
-- which calendar day it would be. PURE: it reports what should change but never
-- mutates `data` -- DailyRewardService applies the results.
--
-- Returns a table:
--   available       claimable right now (cooldown elapsed)
--   nextStreak      the calendar day this claim would be (1..30)
--   usedFreeSkip    true if a missed day was forgiven by the one free skip
--   repairOffered   true if the streak is broken and a Robux repair applies
--   brokenStreak    the streak being held for repair (0 when none)
--   calendarRestart true when the previous claim finished day 30
function GameData.evaluateDailyStreak(data, now)
	local last = data.lastDailyClaim or 0
	local prev = data.dailyStreak or 0
	local pending = data.dailyBrokenStreak or 0
	local elapsed = now - last
	local available = (last == 0) or (elapsed >= GameData.DailyClaimCooldownSeconds)

	local result = {
		available = available,
		nextStreak = 1,
		usedFreeSkip = false,
		repairOffered = false,
		brokenStreak = 0,
		calendarRestart = false,
	}

	-- A streak already awaiting repair keeps offering it; until it is bought the
	-- player is on day 1.
	if pending > 0 then
		result.repairOffered = true
		result.brokenStreak = pending
		return result
	end

	if last == 0 then
		return result -- first ever claim: day 1
	end

	if elapsed > GameData.DailyStreakResetSeconds then
		-- They missed. The first miss per calendar is forgiven.
		if not data.dailySkipUsed then
			result.usedFreeSkip = true
			result.nextStreak = prev + 1
		else
			result.repairOffered = true
			result.brokenStreak = prev
			result.nextStreak = 1
		end
	else
		result.nextStreak = prev + 1
	end

	-- Finishing day 30 restarts the calendar (and refreshes the free skip).
	if result.nextStreak > GameData.DailyCalendarDays then
		result.nextStreak = 1
		result.calendarRestart = true
	end

	return result
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
	Coding      = { "CodeSprint", "BugSquash", "KeyCombo", "CompileCheck" },
	MapBuilding = { "PrecisionPlace", "BlueprintMemory", "TileDrop", "PathConnect" },
	Testing     = { "QAQuiz", "BugHunt", "PassOrFail", "CrashFix" },
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
	PrecisionPlace = { easy = { zoneHalfWidth = 0.18, periodSeconds = 2.2 },       hard = { zoneHalfWidth = 0.08, periodSeconds = 1.3 },       ints = {} },
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

-- ===== Global leaderboards =====
local SECONDS_PER_WEEK = 7 * 24 * 60 * 60 -- 604800

function GameData.getWeekIndex(now)
	return math.floor((now or 0) / SECONDS_PER_WEEK)
end

local function lbCommas(n)
	local s = tostring(math.floor(n or 0))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

-- Ordered list; index order == board order on the beach + tab order in the panel.
GameData.LeaderboardStats = {
	{ key = "prestigeLevel", title = "\226\173\144 Top Prestige",   accent = Color3.fromRGB(150, 92, 255), format = function(v) return "P" .. lbCommas(v) end },
	{ key = "subscribers",   title = "\240\159\143\134 Most Subscribers", accent = Color3.fromRGB(224, 72, 96),  format = function(v) return lbCommas(v) end },
	{ key = "cash",          title = "\240\159\146\176 Richest",     accent = Color3.fromRGB(255, 209, 102), format = function(v) return "$" .. lbCommas(v) end },
	{ key = "gamesReleased", title = "\240\159\142\174 Most Games",  accent = Color3.fromRGB(140, 200, 120), format = function(v) return lbCommas(v) end },
}

function GameData.leaderboardStoreName(period, key, weekIndex)
	if period == "week" then
		return "LB2_wk_" .. key .. "_" .. tostring(weekIndex)
	end
	return "LB2_all_" .. key
end

-- rows: array of { userId, value, name } already sorted descending.
-- Returns { rank = n or nil, value = n }. rank is nil when the player is not
-- present in the (top-100) rows; value then falls back to their live value.
function GameData.computeStanding(rows, userId, liveValue)
	for i, row in ipairs(rows or {}) do
		if row.userId == userId then
			return { rank = i, value = row.value }
		end
	end
	return { rank = nil, value = liveValue or 0 }
end

-- ===== Personal Home room (Round 1) =====
GameData.Home = {
	roomW = 64, roomD = 48, cell = 4, wallH = 20,
	cols = 16, rows = 12,          -- tier-0 defaults (roomW/cell, roomD/cell)
	skyY = 10000, spacing = 400,   -- rooms stacked far up, offset per plot index on Z
	workRows = 7,                  -- back rows reserved for the work zone (no furniture) -- big
	                                -- enough to also clear the Arcade/Merch idle-zone footprints,
	                                -- which spill a few rows past the dev-station row alone
	tiers = {
		[0] = { roomW = 64, roomD = 48, cols = 16, rows = 12 },
		[1] = { roomW = 80, roomD = 56, cols = 20, rows = 14 },
		[2] = { roomW = 96, roomD = 64, cols = 24, rows = 16 },
	},
}

-- Room dimensions for a house/room tier (clamped to the valid tier range).
function GameData.homeDims(tier)
	tier = math.clamp(math.floor(tier or 0), 0, GameData.HouseTierCount - 1)
	return GameData.Home.tiers[tier] or GameData.Home.tiers[0]
end

-- Each item: id, name, icon, cells {w,d} footprint, and EITHER asset (a
-- StudioModels/assets name) OR build (a procedural kind handled by HomeService).
GameData.HomeCatalog = {
	{ id = "Desk",       name = "Desk",        icon = "\240\159\150\165\239\184\143", cells = {2, 1}, asset = "Desk" },
	{ id = "Chair",      name = "Chair",       icon = "\240\159\170\145", cells = {1, 1}, asset = "Chair" },
	{ id = "LoungeChair",name = "Lounge Chair",icon = "\240\159\155\139", cells = {1, 1}, asset = "LoungeChair" },
	{ id = "Table",      name = "Table",       icon = "\240\159\143\147", cells = {2, 2}, asset = "PicnicTable" },
	{ id = "Umbrella",   name = "Umbrella",    icon = "\226\155\177\239\184\143", cells = {2, 2}, asset = "Umbrella" },
	{ id = "Bench",      name = "Bench",       icon = "\240\159\170\145", cells = {2, 1}, asset = "Bench" },
	{ id = "TrashCan",   name = "Trash Can",   icon = "\240\159\151\145\239\184\143", cells = {1, 1}, asset = "TrashCan" },
	{ id = "Rug",        name = "Rug",         icon = "\240\159\159\165", cells = {2, 3}, build = "rug" },
	{ id = "TV",         name = "TV",          icon = "\240\159\147\186", cells = {2, 1}, build = "tv" },
	{ id = "Bookshelf",  name = "Bookshelf",   icon = "\240\159\147\154", cells = {2, 1}, build = "bookshelf" },
	{ id = "Bed",        name = "Bed",         icon = "\240\159\155\143\239\184\143", cells = {2, 3}, build = "bed" },
	{ id = "PC",         name = "PC",          icon = "\240\159\150\165\239\184\143", cells = {1, 1}, build = "pc" },
	-- Work stations = placeable "equipment" (station=<name>). They build as
	-- FUNCTIONAL stations (real seat + prompts) via PlotManager.buildHomeStation,
	-- so players arrange their own studio. Always available + free (equipment),
	-- so deleting one is never permanent -- you just re-place it.
	{ id = "NewProjectStation", name = "New Project PC", icon = "\240\159\134\149",             cells = {3, 2}, station = "NewProject",  equipment = true },
	{ id = "CodingStation",     name = "Coding PC",      icon = "\226\154\161",                 cells = {2, 2}, station = "Coding",      equipment = true },
	{ id = "MapStation",        name = "Map PC",         icon = "\240\159\151\186\239\184\143", cells = {2, 2}, station = "MapBuilding", equipment = true },
	{ id = "TestingStation",    name = "Testing PC",     icon = "\226\156\168",                 cells = {2, 2}, station = "Testing",     equipment = true },
	{ id = "WorkersStation",    name = "Workers Desk",   icon = "\240\159\145\183",             cells = {2, 2}, station = "Workers",     equipment = true },
}

local _homeById = {}
for _, it in ipairs(GameData.HomeCatalog) do _homeById[it.id] = it end
function GameData.getHomeItem(id) return _homeById[id] end

-- Footprint in cells, rotated: a 90/270 yaw swaps width<->depth.
function GameData.homeFootprint(id, yaw)
	local it = _homeById[id]
	if not it then return 1, 1 end
	local w, d = it.cells[1], it.cells[2]
	if yaw == 90 or yaw == 270 then
		return d, w
	end
	return w, d
end

-- In-bounds for FURNITURE: inside the grid AND in the living zone (furniture may
-- not sit in the back `workRows` band, which holds the work stations). `dims`
-- comes from GameData.homeDims(tier).
function GameData.homeInBounds(gx, gz, w, d, dims)
	dims = dims or GameData.Home.tiers[0]
	return gx >= 0
		and gz >= GameData.Home.workRows
		and (gx + w) <= dims.cols
		and (gz + d) <= dims.rows
end

-- True if the footprint (gx,gz,w,d) overlaps any placed item except items[ignoreIndex].
function GameData.homeOverlaps(items, gx, gz, w, d, ignoreIndex)
	for i, other in ipairs(items) do
		if i ~= ignoreIndex then
			local ow, od = GameData.homeFootprint(other.id, other.yaw)
			if gx < other.gx + ow and gx + w > other.gx and gz < other.gz + od and gz + d > other.gz then
				return true
			end
		end
	end
	return false
end

-- World centre of a footprint anchored at cell (gx,gz), given the room's -X,-Z
-- corner and floor Y. Footprint (w,d) is in cells.
function GameData.homeCellToWorld(cornerX, cornerZ, floorY, gx, gz, w, d)
	local c = GameData.Home.cell
	return Vector3.new(cornerX + gx * c + w * c / 2, floorY, cornerZ + gz * c + d * c / 2)
end

return GameData
